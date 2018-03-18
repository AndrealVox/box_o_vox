local BotanistCropComponent = class()
local LootTable = require 'stonehearth.lib.loot_table.loot_table'

function BotanistCropComponent:initialize()
    -- Initializing save variables
    self._sv.harvestable = false
    self._sv.prunable = false
    self._sv.stage = nil
    self._sv.resource = nil
    
    local json = radiant.entities.get_json(self)
    self._renew_stage = json.renew_stage
    self._resource_table = json.resource_table
    self._pruning_pairings = json.pruning_pairings
    self._harvest_threshold = json.harvest_threshold
end

function BotanistCropComponent:restore()
    local growing_component = self._entity:get_component('stonehearth:growing')
    if growing_component then
        local stage = growing_component:get_current_stage_name()
        if stage ~= self._sv.stage then
            local e = {}
            e.stage = stage
            e.finished = growing_component:is_finished()
            self:_on_grow_period(e)
        end
    end
end

function BotanistCropComponent:activate()
    if self._entity:get_component('stonehearth:growing') then
        self._growing_listener = radiant.events.listen(self._entity, 'stonehearth:growing', self, self._on_grow_period)
    end
end

function BotanistCropComponent:post_activate()
    if self._sv.prunable then
        self:_notify_prunable()
    end
    
    if self._sv.harvestable then
        self:_notify_harvestable()
    end
end

function BotanistCropComponent:get_resource()
    return self._sv.resource
end

function BotanistCropComponent:destroy()
    if self._growing_listener then
        self._growing_listener:destroy()
        self._growing_listener = nil
    end
    
    if self._game_loaded_listener then
        self._game_loaded_listener:destroy()
        self._game_loaded_listener = nil
    end
end

--- As we grow, change the resource_table yielded and if appropriate command prune or harvest

function BotanistCropComponent:_on_grow_period(e)
    self._sv.stage = e.stage
    if e.stage then
        local resource_table = nil
        resource_table = self._resource_table[self._sv.stage]
        local loot = resource_table.resource
        local loot_table = nil
        if resource_table.resource_loot_table then
            loot_table = LootTable(resource_table.resource_loot_table)
        end
        if loot then
            self._sv.resource = loot
            if loot_table then
                self._sv.resource = loot_table:roll_loot()
            else
                self._sv.resource = {}
            end
        end
        local pruning_pairing = self._pruning_pairings[self._sv.stage]
        if pruning pairing then
            self._sv.prunable = true
            slef:_notify_prunable()
        end
        if self._sv.stage == self._harvest_threshold then
            self._sv.harvestable = true
            self:_notify_harvestable()
        end
    end
    if e.finished then
        if self._growing_listener then
            self._growing_listener:destroy()
            self._growing_listener = nil
        end
    end
    self.__saved_variables:mark_changed()
end

function BotanistCropComponent:is_harvestable()
    return self._sv.harvestable
end

function BotanistCropComponent:is_prunable()
    return self._sv.prunable
end


function BotanistCropComponent:_notify_prunable()
   radiant.assert(self._sv._field, 'crop %s has no field!', self._entity)
   
end


function BotanistCropComponent:_notify_harvestable()
   radiant.assert(self._sv._field, 'crop %s has no field!', self._entity)
   
end

return BotanistCropComponent