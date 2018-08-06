local Necromancer = class()

local log = radiant.log.create_logger('vox')
function Necromancer:initialize()
   self._sv._entity = nil
   self._sv._uri = nil
end

function Necromancer:create(entity, uri)
   self._sv._entity = entity
   self._sv._uri = uri
end

function Necromancer:activate()
   local json = radiant.resources.load_json(self._sv._uri)
   local population = stonehearth.population:get_population(self._sv._entity:get_player_id())

   self.pop_listener = radiant.events.listen_once(population, 'stonehearth:population:citizen_count_changed', function()
      if not self._sv._entity:get_component('stonehearth:unit_info')._sv._made_necromancer then
         local options = {}
         options.dont_drop_talisman = true
         options.skip_visual_effects = true
         self._sv._entity:get_component('stonehearth:job'):promote_to('box_o_vox:jobs:necromancer', options)
         self._sv._entity:get_component('stonehearth:unit_info')._sv._made_necromancer = true
      end
   end)
   
end

function Necromancer:destroy()
   self._sv._entity:get_component('stonehearth:equipment'):equip_item('box_o_vox:jobs:worker:boxling_outfit')
    self.pop_listener:destroy()
end



return Necromancer
