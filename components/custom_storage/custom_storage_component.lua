local SvTable = require 'radiant.lib.sv_table'

local entity_forms_lib = require 'lib.entity_forms.entity_forms_lib'
local constants = require 'constants'
local TraceCategories = _radiant.dm.TraceCategories

local StorageComponent = class()
local log = radiant.log.create_logger('storage')

local INFINITE = 1000000

local VERSIONS = {
   ZERO = 0,
   SMALLER_BACKPACKS = 1,
}

local STORAGE_TYPES = {
   CRATE = 'crate',
   URN = 'urn',
   CRAFTER_BACKPACK = 'crafter_backpack',
   BACKPACK = 'backpack',
   ESCROW = 'escrow',
}

function StorageComponent:get_version()
   return VERSIONS.SMALLER_BACKPACKS
end

function StorageComponent:initialize()
   local json = radiant.entities.get_json(self) or {}

   self._sv.capacity = json.capacity or 8
   self._sv.num_items = 0
   self._sv.items = {}
   self._sv.item_tracker = nil
   self._type = json.type or STORAGE_TYPES.CRATE

   if json.public ~= nil then
      self._sv.is_public = json.public
   else
      self._sv.is_public = true
   end

   self._sv.filter = nil
   self._cancellable = true

   if self._sv.is_public then
       local default_filter_none = radiant.util.get_config('default_storage_filter_none', false)
       if default_filter_none then
         self._sv.filter = {}
       end
   end

   self._passed_items = {}
   self._filtered_items = {}
end

function StorageComponent:create()
   local basic_tracker = radiant.create_controller('stonehearth:basic_inventory_tracker')
   self._sv.item_tracker = radiant.create_controller('stonehearth:inventory_tracker', basic_tracker)
end

function StorageComponent:activate()
   self._kill_listener = radiant.events.listen(self._entity, 'stonehearth:kill_event', self, self._on_kill_event)
   self._parent_changed_listener = radiant.events.listen(self._entity, 'radiant:mob:parent_changed', self, self._on_parent_changed)

   self._player_id_trace = self._entity:trace_player_id('filter observer', TraceCategories.SYNC_TRACE)
                                          :on_changed(function()
                                                self:_update_player_id()
                                             end)

   local player_id = radiant.entities.get_player_id(self._entity)
   self._inventory = stonehearth.inventory:get_inventory(player_id)
   self:_update_cancellable()
end

function StorageComponent:post_activate()
   -- iterate through items and generate the passed items list
   for id, item in pairs(self._sv.items) do
      self:_filter_item(item)
      if self._inventory then
         self._inventory:add_item(item, self._entity) -- force add to inventory on load fix up.
      end
   end

   self:_on_contents_changed()
   self._player_id_trace:push_object_state()
end

--If we're killed, dump the things in our backpack
function StorageComponent:_on_kill_event()
   -- npc's don't drop what's in their pack
   if not stonehearth.player:is_npc(self._entity) then
      self:drop_all()
   end
end

function StorageComponent:drop_all()
   local items = {}
   for id, item in pairs(self._sv.items) do
      if item and item:is_valid() then
         table.insert(items, item)
      end
   end

   local location = radiant.entities.get_world_grid_location(self._entity)
   if not location then
      local player_id = radiant.entities.get_player_id(self._entity)
      local town = stonehearth.town:get_town(player_id)
      location = town:get_landing_location()
   end

   for _, item in ipairs(items) do
      self:remove_item(item:get_id())
      local placement_point = radiant.terrain.find_placement_point(location, 1, 4)
      radiant.terrain.place_entity(item, placement_point)
   end
   return items
end

function StorageComponent:_on_parent_changed()
   local inventory = self._inventory
   if not inventory then
      return
   end

   local position = radiant.entities.get_world_grid_location(self._entity)
   --Whether this storage is actually avilable for placing items into it.
   --Items like undeployed crates are not available.
   if position then
      inventory:add_storage(self._entity)
      self._filter_fn = inventory:set_storage_filter(self._entity, self._sv.filter)
   else
      inventory:remove_storage(self._entity:get_id())
   end
   self:_update_cancellable()
end

function StorageComponent:destroy()
   self._player_id_trace:destroy()
   self._player_id_trace = nil

   for id, item in pairs(self._sv.items) do
      self:remove_item(id)
      -- destroy the item if it has no location or is a child of the storage entity
      local parent = radiant.entities.get_parent(item)
      if not parent or parent == self._entity then
         radiant.entities.destroy_entity(item)
      end
   end

   if self._kill_listener then
      self._kill_listener:destroy()
      self._kill_listener = nil
   end

   if self._parent_changed_listener then
      self._parent_changed_listener:destroy()
      self._parent_changed_listener = nil
   end

   self._sv.items = nil
end

--[[

   space reservation in crates is very very weird.  we need a better way for many
   hearthlings carrying many items to reserve space for things they might do with those
   items.

   for now, just check for full (which leads to some weird abort behavior, but is better
   than spinning when can_reserve_space gives back conflicting results!)

   -- tony
]]
function StorageComponent:can_reserve_space()
   return not self:is_full()
end

function StorageComponent:reserve_space()
   return not self:is_full()
end

function StorageComponent:unreserve_space()
   -- nop
end

-- Call to increase/decrease backpack size
-- @param capacity_change - add this number to capacity. For decrease, us a negative number
function StorageComponent:change_max_capacity(capacity_change)
   self._sv.capacity = self:get_capacity() + capacity_change

   if self._type == 'backpack' then
      local max_supported_capacity = constants.backpack.MAX_CAPACITY
      radiant.verify(self._sv.capacity <= max_supported_capacity,
         'New backpack capacity (%d) exceeds supported capacity (%d)', self._sv.capacity, max_supported_capacity)
   end
end

function StorageComponent:get_num_items()
   return self._sv.num_items
end

function StorageComponent:get_items()
   return self._sv.items
end

function StorageComponent:get_passed_items()
   return self._passed_items
end

function StorageComponent:add_item(item, force_add)
   if self:is_full() and not force_add then
      return false
   end

   local id = item:get_id()
   if self._sv.items[id] then
      return true
   end

   -- At one point in time we had (and still may have) a bug where an entity's
   -- root form could be placed in the world *AND* the iconic form was in storage.
   -- Certainly that's a bug and should be found and fixed, but if we encounter it here
   -- (e.g. in a save file or an unfortunate series of events that leads to an error()
   -- at just the right moment causing this discrepencey) just silently ignore the add
   -- request.  This has the effect of "removing" the iconic entity from the world, since
   -- the guy who asked for it to be put into storage has released the previous reference
   -- to it (e.g. taken it off the carry bone).
   local root, iconic = entity_forms_lib.get_forms(item)
   if iconic and item == iconic then
      local in_world_item = entity_forms_lib.get_in_world_form(item)
      if in_world_item == root then
         log:error('cannot add %s to storage, root form %s is currently in world!', iconic, root)
         self:remove_item(item:get_id())
         return false
      end
   elseif iconic and item == root then
      radiant.verify(false, 'cannot add %s to storage because it is the root form!', root)
      self:remove_item(item:get_id())
      return false
   end

   self._sv.items[id] = item
   self._sv.num_items = self._sv.num_items + 1
   self:_filter_item(item)
   self._sv.item_tracker:add_item(item, self._entity)

   local player_id = radiant.entities.get_player_id(self._entity)

   local inventory = self._inventory
   if inventory then
      inventory:add_item(item, self._entity) -- force add to inventory
   end

   if item:is_valid() and not force_add then
      stonehearth.ai:reconsider_entity(item, 'added item to storage')
      -- Don't need to let AI know to reconsider this container because reconsider_entity already calls on the storage
   end
   self:_on_contents_changed()
   self.__saved_variables:mark_changed()

   radiant.events.trigger_async(self._entity, 'stonehearth:storage:item_added', {
         item = item,
         item_id = item:get_id(),
      })
   return true
end

function StorageComponent:remove_item(id, inventory_predestroy)
   assert(type(id) == 'number', 'expected entity id')

   local item = self._sv.items[id]
   if not item then
      return nil
   end
   self._sv.num_items = self._sv.num_items - 1
   self._sv.items[id] = nil
   self._passed_items[id] = nil
   self._filtered_items[id] = nil
   self._sv.item_tracker:remove_item(id)

   if not inventory_predestroy then
      local player_id = radiant.entities.get_player_id(self._entity)
      local inventory = self._inventory
      if inventory then
         --Item isn't part of storage anymore, so storage is now nil
         inventory:update_item_container(id, nil)
      end

      if item:is_valid() then
         stonehearth.ai:reconsider_entity(item, 'removed item from storage')

         -- Note: We need to reconsider the storage container here because the item is no longer part of storage
         -- and therefore the ai service will not automatically reconsider the storage.
         -- But we need the storage to be reconsidered because it's possible it was full and now is not.
         stonehearth.ai:reconsider_entity(self._entity, 'removed item from storage')
      end
   end

   self:_on_contents_changed()
   self.__saved_variables:mark_changed()

   local event_item = not inventory_predestroy and item:is_valid() and item or nil

   radiant.events.trigger_async(self._entity, 'stonehearth:storage:item_removed', {
         item_id = id,
         item = event_item,
      })
   return item
end

function StorageComponent:contains_item(id)
   checks('self', 'number')
   return self._sv.items[id] ~= nil
end

function StorageComponent:get_items()
   return self._sv.items
end

function StorageComponent:num_items()
   return self._sv.num_items
end

function StorageComponent:get_capacity()
   return self._sv.capacity or INFINITE
end

function StorageComponent:is_public()
   return self._sv.is_public
end

function StorageComponent:set_capacity(value)
   self._sv.capacity = value
   self.__saved_variables:mark_changed()
end

function StorageComponent:is_empty()
   return self._sv.num_items == 0
end

function StorageComponent:is_full()
   return self._sv.num_items >= self:get_capacity()
end

function StorageComponent:_filter_item(item)
   if self:passes(item) then
      self._passed_items[item:get_id()] = item
   else
      self._filtered_items[item:get_id()] = item
   end
end

function StorageComponent:_on_contents_changed()
   -- Crates cannot undeploy when they are carrying stuff.
   local commands_component = self._entity:get_component('stonehearth:commands')
   if commands_component then
      commands_component:set_command_enabled('stonehearth:commands:undeploy_item', self:is_empty())
   end
   -- Crate cancellable status may have changed now
   self:_update_cancellable()
end

function StorageComponent:passes(item)
   local filter_function = self:get_filter_function()
   return filter_function(item, self._sv.filter)
end

function StorageComponent:get_type()
   return self._type
end

function StorageComponent:get_filter_function()
   if not self._filter_fn then
      radiant.assert(self._inventory, "No inventory found for storage component %s", self._entity)
      self._filter_fn = self._inventory:set_storage_filter(self._entity, self._sv.filter)
   end
   return self._filter_fn
end

function StorageComponent:get_filter()
   return self._sv.filter
end

function StorageComponent:set_filter(filter)
   local player_id = radiant.entities.get_player_id(self._entity)

   self._sv.filter = filter
   assert(self._inventory)
   self._filter_fn = self._inventory:set_storage_filter(self._entity, filter)
   local old_passed = self._passed_items
   local old_filtered = self._filtered_items
   local newly_passed = {}
   local newly_filtered = {}
   self._passed_items = {}
   self._filtered_items = {}

   for id, item in pairs(self._sv.items) do
      self:_filter_item(item)

      if old_passed[id] and self._filtered_items[id] then
         newly_filtered[id] = item
         if item:is_valid() then
            stonehearth.ai:reconsider_entity(item, 'storage filter changed')
         end
      elseif old_filtered[id] and self._passed_items[id] then
         newly_passed[id] = item
         if item:is_valid() then
            stonehearth.ai:reconsider_entity(item, 'storage filter changed')
         end
      end
   end

   self.__saved_variables:mark_changed()

   -- Let the AI know that _we_ (the storage entity) have changed, so reconsider us, too!
   stonehearth.ai:reconsider_entity(self._entity, 'storage filter changed (self)')
   radiant.events.trigger_async(self._entity, 'stonehearth:storage:filter_changed', self, newly_filtered, newly_passed)

   radiant.events.trigger_async(self._inventory, 'stonehearth:inventory:filter_changed')
end

function StorageComponent:is_cancellable()
   return self._cancellable
end

-- Set whether the entity can have tasks cancelled on it
-- For storage entities, don't allow player to cancel tasks on it if it's in iconic form and the container has items
function StorageComponent:_update_cancellable()
   local entity_forms = self._entity:get_component('stonehearth:entity_forms')
   if entity_forms then
      local cancellable = true
      local item, form = entity_forms_lib.get_in_world_form(self._entity)
      if form == 'iconic' and next(self._sv.items) ~= nil then
         cancellable = false -- don't cancel tasks on us
      end
      self._cancellable = cancellable
   end
end

function StorageComponent:_update_player_id()
   local player_id = radiant.entities.get_player_id(self._entity)
   self._inventory = stonehearth.inventory:get_inventory(player_id)
   -- xxx: we also need to add/remove all the items in the
   -- box to the new/old inventory
   self:_on_parent_changed() --This will cause us to re-evaluate whether to add or remove from new inventory
end

function StorageComponent:fixup_post_load(old_save_data)
   if old_save_data.version < VERSIONS.SMALLER_BACKPACKS then
      -- clamp max capacity of old backpacks
      if self._type == STORAGE_TYPES.BACKPACK then
         if self._sv.capacity > constants.backpack.MAX_CAPACITY then
            self._sv.capacity = constants.backpack.MAX_CAPACITY
         end
      end
   end
end

return StorageComponent
