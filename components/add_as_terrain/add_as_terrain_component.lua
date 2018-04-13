-- local log = radiant.log.create_logger('Boxland_add_as_terrain')
local Boxland_add_as_terrain = class()
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local rng = _radiant.math.get_default_rng()

function Boxland_add_as_terrain:post_activate()
	self._world_generated_listener = radiant.events.listen_once(stonehearth.game_creation, 'stonehearth:world_generation_complete', self, self._on_world_generation_complete)
end

function Boxland_add_as_terrain:_on_world_generation_complete()
	local location = radiant.entities.get_world_grid_location(self._entity)
	if location then
		local stone_block = radiant.terrain.get_block_types()
		local entity_region = self._entity:get_component("region_collision_shape"):get_region():get()
		entity_region = radiant.entities.local_to_world(entity_region, self._entity)
		for cube in entity_region:each_cube() do
			radiant.terrain.add_cube(Cube3(cube.min, cube.max, stone_block["rock_layer_"..rng:get_int(1,16)]))
		end
	end
	radiant.entities.destroy_entity(self._entity)
end

return Boxland_add_as_terrain