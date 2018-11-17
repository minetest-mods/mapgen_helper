local map_data = {}
local map_param2_data = {}
local perlin_buffers = {}

mapgen_helper.mapgen_vm_data = function()
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	vm:get_data(map_data)
	return vm, map_data, VoxelArea:new{MinEdge=emin, MaxEdge=emax}
end

mapgen_helper.mapgen_vm_data_param2 = function()
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	vm:get_data(map_data)
	vm:get_param2_data(map_param2_data)
	return vm, map_data, map_param2_data, VoxelArea:new{MinEdge=emin, MaxEdge=emax}
end

mapgen_helper.perlin3d = function(name, minp, maxp, perlin_params)
	local minx = minp.x
	local minz = minp.z
	local sidelen = maxp.x - minp.x + 1 --length of a mapblock
	local chunk_lengths = {x = sidelen, y = sidelen, z = sidelen} --table of chunk edges

	perlin_buffers[name] = perlin_buffers[name] or {}
	perlin_buffers[name].nvals_perlin_buffer = perlin_buffers[name].nvals_perlin_buffer or {}
	
	perlin_buffers[name].nobj_perlin = perlin_buffers[name].nobj_perlin or minetest.get_perlin_map(perlin_params, chunk_lengths)
	local nvals_perlin = perlin_buffers[name].nobj_perlin:get_3d_map_flat(minp, perlin_buffers[name].nvals_perlin_buffer) 
	return nvals_perlin, VoxelArea:new{MinEdge=minp, MaxEdge=maxp}
end

mapgen_helper.perlin2d = function(name, minp, maxp, perlin_params)
	local minx = minp.x
	local minz = minp.z
	local sidelen = maxp.x - minp.x + 1 --length of a mapblock
	local chunk_lengths = {x = sidelen, y = sidelen, z = sidelen} --table of chunk edges

	perlin_buffers[name] = perlin_buffers[name] or {}
	perlin_buffers[name].nvals_perlin_buffer = perlin_buffers[name].nvals_perlin_buffer or {}
	
	perlin_buffers[name].nobj_perlin = perlin_buffers[name].nobj_perlin or minetest.get_perlin_map(perlin_params, chunk_lengths)
	local nvals_perlin = perlin_buffers[name].nobj_perlin:get_2d_map_flat({x=minp.x, y=minp.z}, perlin_buffers[name].nvals_perlin_buffer)
	
	return nvals_perlin
end

-- TODO: need a nice iterator for this kind of thing, check whether VoxelArea's can do this or if something custom will be needed
mapgen_helper.index2d = function(minp, maxp, x, z) 
	return x - minp.x +
		(maxp.x - minp.x + 1) -- sidelen
		*(z - minp.z)
		+ 1
end