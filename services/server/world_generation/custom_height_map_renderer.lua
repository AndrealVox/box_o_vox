local Array2D = require 'services.server.world_generation.array_2D'
local Rect2 = _radiant.csg.Rect2
local Point2 = _radiant.csg.Point2
local Cube3 = _radiant.csg.Cube3
local Point3 = _radiant.csg.Point3
local Region2 = _radiant.csg.Region2
local Region3 = _radiant.csg.Region3
local HeightMapCPP = _radiant.csg.HeightMap

local log = radiant.log.create_logger('CHMR')
log:always("Created CHMR")
local CustomHeightMapRenderer = class()

function CustomHeightMapRenderer:_add_mountains_to_region(region3, rect, height)
	local rock_layers = self._rock_layers
	local num_rock_layers = self._num_rock_layers
	local i, block_min, block_max
	local stop = false

	block_min = 0

	--plains = 10, foothills = 15, mountains = 95
	local min_grass_height = 2 --last 2 steps
	for i=1, num_rock_layers do
		if (i == num_rock_layers) or (height <= rock_layers[i].max_height) then
			block_max = height
			stop = true
		else
			block_max = rock_layers[i].max_height
		end

		local has_grass = stop and block_max > min_grass_height
		local rock_top = has_grass and block_max-1 or block_max

		region3:add_unique_cube(Cube3(
			Point3(rect.min.x, block_min, rect.min.y),
			Point3(rect.max.x, rock_top, rect.max.y),
			rock_layers[i].terrain_tag
		))
		
		if has_grass then 
			local material = self._block_types.grass_hills or self._block_types.grass
			region3:add_unique_cube(Cube3(
				Point3(rect.min.x, rock_top, rect.min.y),
				Point3(rect.max.x, block_max, rect.max.y),
				material
			))
		end

		if stop then return end
		block_min = block_max
	end
end

return CustomHeightMapRenderer