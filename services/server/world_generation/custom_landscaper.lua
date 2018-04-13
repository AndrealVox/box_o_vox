local Array2D = require 'stonehearth.services.server.world_generation.array_2D'
local SimplexNoise = require 'stonehearth.lib.math.simplex_noise'
local FilterFns = require 'stonehearth.services.server.world_generation.filter.filter_fns'
local WeightedSet = require 'stonehearth.lib.algorithms.weighted_set'
local water_shallow = 'water_1'
local water_deep = 'water_2'
local CustomLandscaper = class()

local Astar = require 'services.server.world_generation.astar'
local noise_height_map --this noise is to mess with the astar to avoid straight rivers
local region_sizes --small areas should be ignored, else it creates small pity rivers
local log = radiant.log.create_logger('meu_log')

function CustomLandscaper:mark_water_bodies(elevation_map, feature_map)
	local biome_name = stonehearth.world_generation:get_biome_alias()
	local colon_position = string.find (biome_name, ":", 1, true) or -1
	local mod_name_containing_the_biome = string.sub (biome_name, 1, colon_position-1)
	local fn = "mark_water_bodies_" .. mod_name_containing_the_biome
	if self[fn] ~= nil then
		--found a function for the biome being used, named:
		-- self:mark_water_bodies_<biome_name>(args,...)
		self[fn](self, elevation_map, feature_map)
	else
		--there is no function for this specific biome, so call a copy of the original from stonehearth
		self:mark_water_bodies_original(elevation_map, feature_map)
	end
end

function CustomLandscaper:mark_water_bodies_original(elevation_map, feature_map)
	local rng = self._rng
	local biome = self._biome
	local config = self._landscape_info.water.noise_map_settings
	local modifier_map, density_map = self:_get_filter_buffers(feature_map.width, feature_map.height)
	--fill modifier map to push water bodies away from terrain type boundaries
	local modifier_fn = function (i,j)
		if self:_is_flat(elevation_map, i, j, 1) then
			return 0
		else
			return -1*config.range
		end
	end
	--use density map as buffer for smoothing filter
	density_map:fill(modifier_fn)
	FilterFns.filter_2D_0125(modifier_map, density_map, modifier_map.width, modifier_map.height, 10)
	--mark water bodies on feature map using density map and simplex noise
	local old_feature_map = Array2D(feature_map.width, feature_map.height)
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local occupied = feature_map:get(i, j) ~= nil
			if not occupied then
				local elevation = elevation_map:get(i, j)
				local terrain_type = biome:get_terrain_type(elevation)
				local value = SimplexNoise.proportional_simplex_noise(config.octaves,config.persistence_ratio, config.bandlimit,config.mean[terrain_type],config.range,config.aspect_ratio, self._seed,i,j)
				value = value + modifier_map:get(i,j)
				if value > 0 then
					local old_value = feature_map:get(i, j)
					old_feature_map:set(i, j, old_value)
					feature_map:set(i, j, water_shallow)
				end
			end
		end
	end
	self:_remove_juts(feature_map)
	self:_remove_ponds(feature_map, old_feature_map)
	self:_fix_tile_aligned_water_boundaries(feature_map, old_feature_map)
	self:_add_deep_water(feature_map)
end

function CustomLandscaper:mark_water_bodies_box_o_vox(elevation_map, feature_map)
	local rng = self._rng
	local biome = self._biome

	noise_height_map = {}
	noise_height_map.width = feature_map.width
	noise_height_map.height = feature_map.height
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local elevation = elevation_map:get(i, j)
			local terrain_type = biome:get_terrain_type(elevation)

			local offset = (j-1)*feature_map.width+i
			--creates and set the points
			noise_height_map[offset] = {}
			noise_height_map[offset].x = i
			noise_height_map[offset].y = j
			noise_height_map[offset].plains = terrain_type == "plains"
			noise_height_map[offset].noise = rng:get_int(1,100)
		end
	end
	self:boxland_mark_borders()
	self:boxland_create_regions()
	self:boxland_add_rivers(feature_map)
end

function CustomLandscaper:boxland_mark_borders()
	local function neighbors_have_different_elevations(x,y)
		local neighbor_offset = (y-1)*noise_height_map.width+x
		if noise_height_map[neighbor_offset-1] then
			if not noise_height_map[neighbor_offset-1].plains then
				return true
			end
		end
		if noise_height_map[neighbor_offset+1] then
			if not noise_height_map[neighbor_offset+1].plains then
				return true
			end
		end
		if noise_height_map[neighbor_offset-noise_height_map.width] then
			if not noise_height_map[neighbor_offset-noise_height_map.width].plains then
				return true
			end
		end
		if noise_height_map[neighbor_offset+noise_height_map.width] then
			if not noise_height_map[neighbor_offset+noise_height_map.width].plains then
				return true
			end
		end
		return false
	end

	for y=1, noise_height_map.height do
		for x=1, noise_height_map.width do
			local offset = (y-1)*noise_height_map.width+x
			noise_height_map[offset].border = neighbors_have_different_elevations(x,y)
		end
	end
end

function CustomLandscaper:boxland_create_regions()
	region_sizes = {}
	local region = 0
	for y=1, noise_height_map.height do
		for x=1, noise_height_map.width do
			local offset = (y-1)*noise_height_map.width+x
			if not noise_height_map[offset].border and noise_height_map[offset].plains then
				if not noise_height_map[offset].region then
					region = region +1
					region_sizes[region] = self:boxland_flood_fill_region(x,y, region)
					-- log:error("Region %d - Size %d", region, region_sizes[region])
				end
			end
		end
	end
end

function CustomLandscaper:boxland_flood_fill_region(x,y, region)
	local offset = (y-1)*noise_height_map.width+x
	local size = 0
	local openset = {}

	table.insert( openset, noise_height_map[offset] )

	while #openset>0 do
		local current = table.remove(openset)
		current.region = region
		size = size +1

		local offset_left = (current.y-1)*noise_height_map.width+current.x -1
		if current.x>1 and noise_height_map[offset_left].border==false and not noise_height_map[offset_left].region then
			table.insert( openset, noise_height_map[offset_left] )
		end

		local offset_right = (current.y-1)*noise_height_map.width+current.x +1
		if current.x<noise_height_map.width and noise_height_map[offset_right].border==false and not noise_height_map[offset_right].region then
			table.insert( openset, noise_height_map[offset_right] )
		end

		local offset_up = (current.y-2)*noise_height_map.width+current.x
		if current.y>1 and noise_height_map[offset_up].border==false and not noise_height_map[offset_up].region then
			table.insert( openset, noise_height_map[offset_up] )
		end

		local offset_down = (current.y)*noise_height_map.width+current.x
		if current.y<noise_height_map.height and noise_height_map[offset_down].border==false and not noise_height_map[offset_down].region then
			table.insert( openset, noise_height_map[offset_down] )
		end
	end

	return size
end

function CustomLandscaper:boxland_add_rivers(feature_map)

	local function grab_random_region()
		local region_number
		repeat
			region_number = self._rng:get_int(1, #region_sizes)
		until
			--should only get big regions
			region_sizes[region_number]>2000
		return region_number
	end

	local function grab_random_point(region)
		local x,y,point_offset
		repeat
			x = self._rng:get_int(1, noise_height_map.width)
			y = self._rng:get_int(1, noise_height_map.height)
			point_offset = (y-1)*noise_height_map.width+x
		until
			noise_height_map[point_offset].border==false and
			--same region means there is path between the points
			noise_height_map[point_offset].region == region
		return point_offset
	end
	
	local function grab_distance_between_points(offset, offset2)
		local dx = noise_height_map[offset2].x-noise_height_map[offset].x
		local dy = noise_height_map[offset2].y-noise_height_map[offset].y
		return math.sqrt(dx*dx + dy*dy)
	end
	
	local function grab_the_two_most_distance_points(points)
		local far_point1, far_point2
		local biggest_distance = 0
		for first_point=1, #points-1 do
			for second_point=first_point+1, #points do
				local current_distance = grab_distance_between_points(points[first_point], points[second_point])
				if current_distance > biggest_distance then
					biggest_distance = current_distance
					far_point1 = points[first_point]
					far_point2 = points[second_point]
				end
			end
		end
		return far_point1, far_point2
	end

	for rivers=1, 8 do
		local region = grab_random_region()
		local points = {}
		for i=1,8 do
			table.insert(points, grab_random_point(region))
		end
		--sometimes the chosen two points are too close, making boring rivers.
		--thats why I'm using multiple points and from that grabbing the two most far from each other.
		--this decreases the chances of having super close starting and ending points
		local offset,offset2 = grab_the_two_most_distance_points(points)

		self:boxland_draw_river(noise_height_map[offset], noise_height_map[offset2], feature_map)
	end
end

function CustomLandscaper:boxland_draw_river(start,goal,feature_map)
	local path = Astar.path ( start, goal, noise_height_map, true )

	if not path then
		log:error('Error. No valid river path found!')
	else
		for i, node in ipairs ( path ) do
			feature_map:set(node.x, node.y, water_shallow)
		end
	end
end

--- water spawning
function CustomLandscaper:place_features(tile_map, feature_map, place_item)
	local biome_name = stonehearth.world_generation:get_biome_alias()
	local colon_position = string.find (biome_name, ":", 1, true) or -1
	local mod_name_containing_the_biome = string.sub (biome_name, 1, colon_position-1)
	local fn = "place_features_" .. mod_name_containing_the_biome
	if self[fn] ~= nil then
		--found a function for the biome being used, named:
		-- self:place_features_<biome_name>(args,...)
		self[fn](self, tile_map, feature_map, place_item)
	else
		--there is no function for this specific biome, so call a copy of the original from stonehearth
		self:place_features_original(tile_map, feature_map, place_item)
	end
end

function CustomLandscaper:place_features_original(tile_map, feature_map, place_item)
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local feature_name = feature_map:get(i, j)
			self:_place_feature(feature_name, i, j, tile_map, place_item)
		end
	end
end

function CustomLandscaper:place_features_box_o_vox(tile_map, feature_map, place_item)
	local water_1_table = WeightedSet(self._rng)
	for item, weight in pairs(self._landscape_info.water.spawn_objects.water_1) do
		water_1_table:add(item,weight)
	end

	local new_feature
	for j=1, feature_map.height do
		for i=1, feature_map.width do
			local feature_name = feature_map:get(i, j)
			if feature_name == "water_1" then
				new_feature = water_1_table:choose_random()
				if new_feature ~= "none" then
					feature_name = new_feature
				end
			end
			self:_place_feature(feature_name, i, j, tile_map, place_item)
		end
	end
end

return CustomLandscaper