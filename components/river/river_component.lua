-- local log = radiant.log.create_logger('BoxlandRiver')
local BoxlandRiver = class()
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Region3 = _radiant.csg.Region3
local rng = _radiant.math.get_default_rng()

function BoxlandRiver:post_activate()
	self._world_generated_listener = radiant.events.listen_once(stonehearth.game_creation, 'stonehearth:world_generation_complete', self, self._on_world_generation_complete)
end

function BoxlandRiver:_on_world_generation_complete()
	local location = radiant.entities.get_world_grid_location(self._entity)
	if location then
		location = location + Point3(-7,0,-7) --moving to chunk corner, easier math

		for x=1,2 do
			for z=1,2 do
				if rng:get_int(1,10) == 1 then
					self:add_mini_island(location+Point3(x*4,0,z*4))
				end
			end
		end
	end
	radiant.entities.destroy_entity(self._entity)
end

function BoxlandRiver:add_mini_island(location)
	local dirt_block = radiant.terrain.get_block_types()["soil_dark"]
	local grass_block = radiant.terrain.get_block_types()["grass"]
	radiant.terrain.add_cube(Cube3(location,location+Point3(8,1,8),dirt_block))
	radiant.terrain.add_cube(Cube3(location+Point3(0,1,0),location+Point3(8,2,8),grass_block))
end

return BoxlandRiver