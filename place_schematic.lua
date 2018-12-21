-- These functions are a modification of the schematic placement code from src/mapgen/mg_schematic.cpp.
-- As such, this file is separately licened under the LGPL as follows:

-- License of Minetest source code
-------------------------------

--Minetest
--Copyright (C) 2010-2018 celeron55, Perttu Ahola <celeron55@gmail.com>

--This program is free software; you can redistribute it and/or modify
--it under the terms of the GNU Lesser General Public License as published by
--the Free Software Foundation; either version 2.1 of the License, or
--(at your option) any later version.

--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Lesser General Public License for more details.

--You should have received a copy of the GNU Lesser General Public License along
--with this program; if not, write to the Free Software Foundation, Inc.,
--51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


local c_air = minetest.get_content_id("air")
local c_ignore = minetest.get_content_id("ignore")

-- Table value = rotated facedir
-- Columns: 90, 180, 270 degrees rotation around vertical axis
-- Rotation is anticlockwise as seen from above (+Y)
local rotate_facedir_y =
{
	[0] = {1, 2, 3}     ,
	[1] = {2, 3, 0}     ,
	[2] = {3, 0, 1}     ,
	[3] = {0, 1, 2}     ,
	[4] = {13, 10, 19}  ,
	[5] = {14, 11, 16}  ,
	[6] = {15, 8, 17}   ,
	[7] = {12, 9, 18}   ,
	[8] = {17, 6, 15}   ,
	[9] = {18, 7, 12}   ,
	[10] = {19, 4, 13}  ,
	[11] = {16, 5, 14}  ,
	[12] = {9, 18, 7}   ,
	[13] = {10, 19, 4}  ,
	[14] = {11, 16, 5}  ,
	[15] = {8, 17, 6}   ,
	[16] = {5, 14, 11}  ,
	[17] = {6, 15, 8}   ,
	[18] = {7, 12, 9}   ,
	[19] = {4, 13, 10}  ,
	[20] = {23, 22, 21} ,
	[21] = {20, 23, 22} ,
	[22] = {21, 20, 23} ,
	[23] = {22, 21, 20} ,
}

local random_rotations = {0, 90, 180, 270}

local rotate_param2 = function(param2, paramtype2, rotation)
	param2 = param2 or 0
	if paramtype2 == "facedir" then
		if rotation == 90 then
			param2 = rotate_facedir_y[param2][1]
		elseif rotation == 180 then
			param2 = rotate_facedir_y[param2][2]
		elseif rotation == 270 then
			param2 = rotate_facedir_y[param2][3]
		end
	elseif paramtype2 == "wallmounted" then
		--TODO
	elseif paramtype2 == "colorfacedir" then
		--TODO
	elseif paramtype2 == "colorfacedir" then
		--TODO
	end

	return param2
end

-- Takes a lua-format schematic and applies it to the data and param2_data arrays produced by vmanip instead of being applied to the vmanip directly. Useful in a mapgen loop that's doing other things with the data before and after applying schematics. A VoxelArea for the data also needs to be provided.

-- TODO: support all flags formats

-- Enhancement: node defs can have a "place_on_condition" property defined, which is a function that takes a node content ID and returns true to indicate the schematic should replace it or false to indicate it should not. Useful for, for example, a schematic that should replace water but not stone, or a schematic that replaces all buildable_to nodes.

-- returns true if the schematic was entirely contained within the area, false otherwise.

mapgen_helper.place_schematic_on_data = function(data, data_param2, area, pos, schematic, rotation, replacements, force_placement, flags)
	replacements = replacements or {}
	flags = flags or {}
	if rotation == "random" then rotation = random_rotations[math.random(1,4)] end
	
	local schemdata = schematic.data
	local slice_probs = schematic.yslice_prob or {}
	
	local size = schematic.size
	local size_x = size.x
	local size_y = size.y
	local size_z = size.z

	local xstride = 1
	local ystride = size_x
	local zstride = size_x * size_y

	local i_start, i_step_x, i_step_z
	if rotation == 90 then
		i_start  = size_x
		i_step_x = zstride
		i_step_z = -xstride
		local temp = size_x -- swap size_x and size_z
		size_x = size_z
		size_z = temp
	elseif rotation == 180 then
		i_start  = zstride * (size_z - 1) + size_x
		i_step_x = -xstride
		i_step_z = -zstride
	elseif rotation == 270 then
		i_start  = zstride * (size_z - 1) + 1
		i_step_x = -zstride
		i_step_z = xstride
		local temp = size_x -- swap size_x and size_z
		size_x = size_z
		size_z = temp
	else
		i_start = 1
		i_step_x = xstride
		i_step_z = zstride
	end

	--	Adjust placement position if necessary
	if flags.place_center_x then
		pos.x = math.floor(pos.x - (size_x - 1) / 2)
	end
	if flags.place_center_y then
		pos.y = math.floor(pos.y - (size_y - 1) / 2)
	end
	if flags.place_center_z then
		pos.z = math.floor(pos.z - (size_z - 1) / 2)
	end
	
	local minpos1 = pos
	local maxpos1 = vector.add(pos, {x=size_x-1, y=size_y-1, z=size_z-1})
	local minpos2 = area.MinEdge
	local maxpos2 = area.MaxEdge
	if not (minpos1.x <= maxpos2.x and maxpos1.x >= minpos2.x and
			minpos1.z <= maxpos2.z and maxpos1.z >= minpos2.z and
			minpos1.y <= maxpos2.y and maxpos1.y >= minpos2.y) then
		return false -- the bounding boxes of the area and the schematic don't overlap
	end	
	
	local contained_in_area = true
	
	local y_map = pos.y
	for y = 0, size_y-1 do
		if slice_probs[y] == nil or slice_probs[y] == 255 or slice_probs[y] <= math.random(1, 255) then
			for z = 0, size_z-1 do
				local i = z * i_step_z + y * ystride + i_start
				for x = 0, size_x-1 do
					local vi = area:index(pos.x + x, y_map, pos.z + z)
					if area:containsi(vi) then						
						local node_def = schemdata[i]
						local node_name = replacements[node_def.name] or node_def.name
						if node_name ~= "ignore" then
							local placement_prob = node_def.prob or 255
							if placement_prob ~= 0 then

								local force_place_node = node_def.force_place
								local place_on_condition = node_def.place_on_condition
								local old_node_id = data[vi]

								if (force_placement or force_place_node
									or (place_on_condition and place_on_condition(old_node_id))
									or (not place_on_condition and (old_node_id == c_air or old_node_id == c_ignore)))
									and (placement_prob == 255 or math.random(1,255) <= placement_prob)
								then
									local paramtype2 = minetest.registered_nodes[node_name].paramtype2
									data[vi] = minetest.get_content_id(node_name)
									data_param2[vi] = rotate_param2(node_def.param2, paramtype2, rotation)			
								end
							end
						end
					else
						contained_in_area = false
					end
					i = i + i_step_x
				end
			end
		end
		y_map = y_map + 1
	end
	
	return contained_in_area
end