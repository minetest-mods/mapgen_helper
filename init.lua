mapgen_helper = {}

mapgen_helper.mapgen_seed = tonumber(minetest.get_mapgen_setting("seed"))

local MP = minetest.get_modpath(minetest.get_current_modname())
dofile(MP.."/voxelarea_iterator.lua")
dofile(MP.."/voxeldata.lua")


-- For getting large regions that don't cross mapgen block boundaries
local region_mapblocks = 12 -- however many mapgen blocks you want the size of the region to be
local mapgen_chunksize = tonumber(minetest.get_mapgen_setting("chunksize"))
local region_size = region_mapblocks * mapgen_chunksize * 16
-- For some reason, map chunks generate with -32, -32, -32 as the "origin" minp. To make the large-scale grid align with map chunks it needs to be offset like this.
local get_region_corner = function(pos)
	return {x = math.floor((pos.x+32) / region_size) * region_size - 32, z = math.floor((pos.z+32) / region_size) * region_size - 32}
end

-- Returns a consistent list of random points within a volume.
-- Each call to this method will give the same set of points if the same parameters are provided
mapgen_helper.get_random_points = function(minp, maxp, min_output_size, max_output_size)

	local next_seed = math.random(1, 1000000000)
	math.randomseed(minp.x + minp.y*2^4 + minp.z*2^8 + mapgen_helper.mapgen_seed)
	
	local count = math.random(min_output_size, max_output_size)
	local result = {}
	while count > 0 do
		local point = {}
		point.x = math.random(minp.x, maxp.x)
		point.x = math.random(minp.y, maxp.y)
		point.z = math.random(minp.z, maxp.z)
		table.insert(result, point)
		count = count - 1
	end
	
	math.randomseed(next_seed)
	return result
end

-- Given a position and a grid scale, returns the minp corners of the four grids that the player is closest to.
-- For example, if we have a grid scale of 6 and the parameter position is at "*", the four points marked "R" would be returned.

-- |-----|-----|-----|      |-----|-----|-----|      |-----|-----|-----|
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |-----|-----|-----|      |-----|-----|-----|      |-----R-----R-----|
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |    *|     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     | *   |     |      |     |    *|     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- R-----R-----|-----|      |-----R-----R-----|      |-----R-----R-----|
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- |     |     |     |      |     |     |     |      |     |     |     |
-- R-----R-----|-----|      |-----R-----R-----|      |-----|-----|-----|

-- In this way you can be sure you aren't near an area you haven't tested.

mapgen_helper.get_nearest_grids = function(pos_xz, gridscale)
	local half_scale = gridscale / 2
	local grid_cell = {x = math.floor(pos_xz.x / gridscale) * gridscale, z = math.floor(pos_xz.z / gridscale) * gridscale}
	local pos_internal = {x = pos_xz.x % gridscale, z = pos_xz.z % gridscale}
	local result = {grid_cell}
	local shift_x = gridscale
	local shift_z = gridscale
	if (pos_internal.x < half_scale) then
		shift_x = -gridscale
	end
	if (pos_internal.z < half_scale) then
		shift_z = -gridscale
	end

	table.insert(result, {x = grid_cell.x + shift_x, z = grid_cell.z + shift_z})
	table.insert(result, {x = grid_cell.x + shift_x, z = grid_cell.z})
	table.insert(result, {x = grid_cell.x, z = grid_cell.z + shift_z})

	return result
end


-- |---|---|---|
-- |   |   |   |
-- |   |   |   |
-- R---R---R---|
-- |   |   |   |
-- |   |  *|   |
-- R---R---R---|
-- |   |   |   |
-- |   |   |   |
-- R---R---R---|

mapgen_helper.get_adjacent_grids = function(pos_xz, gridscale)
	local grid_cell = {x = math.floor(pos_xz.x / gridscale) * gridscale, z = math.floor(pos_xz.z / gridscale) * gridscale}
	local result = {grid_cell}
	table.insert(result, {x = grid_cell.x + gridscale, z = grid_cell.y + gridscale})
	table.insert(result, {x = grid_cell.x + gridscale, z = grid_cell.y})
	table.insert(result, {x = grid_cell.x, z = grid_cell.y + gridscale})
	table.insert(result, {x = grid_cell.x - gridscale, z = grid_cell.y - gridscale})
	table.insert(result, {x = grid_cell.x - gridscale, z = grid_cell.y})
	table.insert(result, {x = grid_cell.x, z = grid_cell.y - gridscale})
	return result
end


-- A cheap nearness test, using Manhattan distance.
mapgen_helper.is_within_distance = function(pos1, pos2, distance)
	return math.abs(pos1.x-pos2.x) <= distance and
		math.abs(pos1.y-pos2.y) <= distance and
		math.abs(pos1.z-pos2.z) <= distance
end

-- Finds an intersection between two axis-aligned bounding boxes (AABB)s, or nil if there's no overlap
mapgen_helper.intersect = function(minpos1, maxpos1, minpos2, maxpos2)
	--checking x and z first since they're more likely to fail to overlap
	if minpos1.x <= maxpos2.x and maxpos1.x >= minpos2.x and
		minpos1.z <= maxpos2.z and maxpos1.z >= minpos2.z and
		minpos1.y <= maxpos2.y and maxpos1.y >= minpos2.y then
		
		return {
				x = math.max(minpos1.x, minpos2.x),
				y = math.max(minpos1.y, minpos2.y),
				z = math.max(minpos1.z, minpos2.z)
			},
			{
				x = math.min(maxpos1.x, maxpos2.x),
				y = math.min(maxpos1.y, maxpos2.y),
				z = math.min(maxpos1.z, maxpos2.z)
			}
	end
	return nil, nil
end
