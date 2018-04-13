local Array2D = require 'stonehearth.services.server.world_generation.array_2D'
local SimplexNoise = require 'stonehearth.lib.math.simplex_noise'
local FilterFns = require 'stonehearth.services.server.world_generation.filter.filter_fns'
local CustomMicroMapGenerator = class()
-- local log = radiant.log.create_logger('meu_log')

function CustomMicroMapGenerator:generate_micro_map(size_x, size_y)
	local biome_name = stonehearth.world_generation:get_biome_alias()
	local colon_position = string.find (biome_name, ":", 1, true) or -1
	local mod_name_containing_the_biome = string.sub (biome_name, 1, colon_position-1)
	local fn = "generate_micro_map_" .. mod_name_containing_the_biome
	if self[fn] ~= nil then
		--found a function for the biome being used, named:
		-- self:generate_micro_map_<biome_name>(args,...)
		return self[fn](self, size_x, size_y)
	else
		--there is no function for this specific biome, so call a copy of the original from stonehearth
		return self:generate_micro_map_original(size_x, size_y)
	end
end

function CustomMicroMapGenerator:generate_micro_map_original(size_x, size_y)
	local micro_map, width, height

	-- create the noise map
	micro_map = self:generate_noise_map(size_x, size_y)

	--stylistic interpolating with tile centroids based on distance to centroid, creates chunkiness on the macroscale
	--self:_blockify(micro_map, size_x, size_y)

	self:_match_plains_percentile(micro_map)
	self:_accentuate_mountains(micro_map)
	-- quantize it
	self:_quantize(micro_map)
	-- postprocess it
	self:_postprocess(micro_map)

	local elevation_map = self:_convert_to_elevation_map(micro_map)

	return micro_map, elevation_map
end

function CustomMicroMapGenerator:generate_micro_map_box_o_vox(size_x, size_y)
	local micro_map, width, height

	-- create the noise map
	micro_map = self:generate_noise_map_box_o_vox(size_x, size_y)

	--stylistic interpolating with tile centroids based on distance to centroid, creates chunkiness on the macroscale
	--self:_blockify(micro_map, size_x, size_y)

	self:_match_plains_percentile(micro_map)
	self:_accentuate_mountains(micro_map)
	-- quantize it
	self:_quantize(micro_map)
	-- postprocess it
	self:_postprocess(micro_map)

	local elevation_map = self:_convert_to_elevation_map(micro_map)

	return micro_map, elevation_map
end

function CustomMicroMapGenerator:generate_noise_map_box_o_vox(size_x, size_y)
	local mountains_info = self._terrain_info.mountains
	local macro_blocks_per_tile = self._macro_blocks_per_tile
	-- +1 for half macro_block margin on each edge
	local width = size_x * macro_blocks_per_tile + 1
	local height = size_y * macro_blocks_per_tile + 1
	local noise_map = Array2D(width, height)

	local fn = function (x,y)
		local noise_config = self._terrain_info.noise_map_settings
		local mean = mountains_info.height_base
		local range = (mountains_info.height_max - mean)*2
		local height = SimplexNoise.proportional_simplex_noise(noise_config.octaves,noise_config.persistence_ratio,noise_config.bandlimit, mean,range, noise_config.aspect_ratio, self._seed,x,y)
		-- log:error("x: %d - y: %d - height: %d", x, y, height)
		return height*10
	end
	noise_map:fill(fn)
	return noise_map
end

function CustomMicroMapGenerator:generate_underground_micro_map(surface_micro_map)
	local mod_name = stonehearth.world_generation:get_biome_alias()
	--mod_name is the mod that has the current biome
	local colon_pos = string.find (mod_name, ":", 1, true) or -1
	mod_name = "generate_underground_micro_map_" .. string.sub (mod_name, 1, colon_pos-1)
	if self[mod_name]~=nil then
		return self[mod_name](self, surface_micro_map)
	else
		return self:generate_underground_micro_map_original(surface_micro_map)
	end
end

function CustomMicroMapGenerator:generate_underground_micro_map_original(surface_micro_map)
	local mountains_info = self._terrain_info.mountains
	local mountains_base_height = mountains_info.height_base
	local mountains_step_size = mountains_info.step_size
	local rock_line = mountains_step_size
	local width, height = surface_micro_map:get_dimensions()
	local size = width*height
	local unfiltered_map = Array2D(width, height)
	local underground_micro_map = Array2D(width, height)

	-- seed the map using the above ground mountains
	for i=1, size do
		local surface_elevation = surface_micro_map[i]
		local value

		if surface_elevation > mountains_base_height then
			value = surface_elevation
		else
			value = math.max(surface_elevation - mountains_step_size*2, rock_line)
		end

		unfiltered_map[i] = value
	end

	-- filter the map to generate the underground height map
	FilterFns.filter_2D_0125(underground_micro_map, unfiltered_map, width, height, 10)

	local quantizer = self._biome:get_mountains_quantizer()

	-- quantize the height map
	for i=1, size do
		local surface_elevation = surface_micro_map[i]
		local rock_elevation

		if surface_elevation > mountains_base_height then
			-- if the mountain breaks the surface just use its height
			rock_elevation = surface_elevation
		else
			-- quantize the filtered value
			rock_elevation = quantizer:quantize(underground_micro_map[i])

			-- make sure the sides of the rock faces stay beneath the surface
			-- e.g. we don't want a drop in an adjacent foothills block to expose the rock
			if rock_elevation > surface_elevation - mountains_step_size then
				rock_elevation = rock_elevation - mountains_step_size
			end

			-- make sure we have a layer of rock beneath everything
			if rock_elevation <= 0 then
				rock_elevation = rock_line
			end
		end

		underground_micro_map[i] = rock_elevation
	end

	local underground_elevation_map = self:_convert_to_elevation_map(underground_micro_map)

	return underground_micro_map, underground_elevation_map
end


function CustomMicroMapGenerator:generate_underground_micro_map_box_o_vox(surface_micro_map)
	local mountains_info = self._terrain_info.mountains
	local mountains_base_height = mountains_info.height_base
	local mountains_step_size = mountains_info.step_size
	local rock_line = mountains_step_size
	local width, height = surface_micro_map:get_dimensions()
	local size = width*height
	local unfiltered_map = Array2D(width, height)
	local underground_micro_map = Array2D(width, height)

	-- seed the map using the above ground mountains
	for i=1, size do
		local surface_elevation = surface_micro_map[i]
		local value

		if surface_elevation > mountains_base_height then
			value = surface_elevation
		else
			value = math.max(surface_elevation - mountains_step_size*2, rock_line)
		end

		unfiltered_map[i] = value-30
	end

	-- filter the map to generate the underground height map
	FilterFns.filter_2D_0125(underground_micro_map, unfiltered_map, width, height, 10)

	local quantizer = self._biome:get_mountains_quantizer()

	-- quantize the height map
	for i=1, size do
		local surface_elevation = surface_micro_map[i]
		local rock_elevation

		if surface_elevation > mountains_base_height then
			-- if the mountain breaks the surface just use its height
			rock_elevation = surface_elevation
		else
			-- quantize the filtered value
			rock_elevation = quantizer:quantize(underground_micro_map[i])

			-- make sure the sides of the rock faces stay beneath the surface
			-- e.g. we don't want a drop in an adjacent foothills block to expose the rock
			if rock_elevation > surface_elevation - mountains_step_size then
				rock_elevation = rock_elevation - mountains_step_size
			end

			-- make sure we have a layer of rock beneath everything
			if rock_elevation <= 0 then
				rock_elevation = rock_line
			end
		end

		underground_micro_map[i] = rock_elevation-30
	end

	local underground_elevation_map = self:_convert_to_elevation_map(underground_micro_map)

	return underground_micro_map, underground_elevation_map
end

return CustomMicroMapGenerator
