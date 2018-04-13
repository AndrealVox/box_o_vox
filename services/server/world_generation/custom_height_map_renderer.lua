local Cube3 = _radiant.csg.Cube3
local Point3 = _radiant.csg.Point3

local CustomHeightMapRenderer = class()

function CustomHeightMapRenderer:_add_mountains_to_region(region3, rect, height)
	local mod_name = stonehearth.world_generation:get_biome_alias()
	--mod_name is the mod that has the current biome
	local colon_pos = string.find (mod_name, ":", 1, true) or -1
	mod_name = "_add_mountains_to_region_" .. string.sub (mod_name, 1, colon_pos-1)
	if self[mod_name]~=nil then
		self[mod_name](self,region3,rect,height)
	else
		self:_add_mountains_to_region_original(region3, rect, height)
	end
end

function CustomHeightMapRenderer:_add_mountains_to_region_original(region3, rect, height)
	local rock_layers = self._rock_layers
	local num_rock_layers = self._num_rock_layers
	local i, block_min, block_max
	local stop = false

	block_min = 0

	for i=1, num_rock_layers do
		if (i == num_rock_layers) or (height <= rock_layers[i].max_height) then
			block_max = height
			stop = true
		else
			block_max = rock_layers[i].max_height
		end

		region3:add_unique_cube(Cube3(
				Point3(rect.min.x, block_min, rect.min.y),
				Point3(rect.max.x, block_max, rect.max.y),
				rock_layers[i].terrain_tag
			))

		if stop then return end
		block_min = block_max
	end
end

function CustomHeightMapRenderer:_add_mountains_to_region_box_o_vox(region3, rect, height)
	local rock_layers = self._rock_layers
	local num_rock_layers = self._num_rock_layers
	local i, block_min, block_max
	local stop = false

	block_min = 0

	--plains = 10, foothills = 15, mountains = 95
	local min_grass_height = 55 --last 2 steps

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