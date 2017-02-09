-- AUTOMATA mod for Minetest 4.12+
-- this is version 0.1.0 (released 21july2015)
-- source: github.com/bobombolo/automata
-- depends: WorldEdit mod if you want to use chat command //owncells
-- written by bobomb (find me on the forum.minetest.net)
-- license: WTFPL
automata = {}
automata.patterns = {} -- master pattern list
automata.grow_queue = {}
automata.inactive_cells = {} -- automata:inactive nodes, activated with the remote
-- new cell that requires activation
minetest.register_node("automata:inactive", {
	description = "Programmable Automata",
	tiles = {"inactive.png"},
	light_source = 3,
	groups = {oddly_breakable_by_hand=1},
	
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local pname  = placer:get_player_name()
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "\"Inactive Automata\" placed by "..pname)
		--register the cell in the cell registry
		automata.inactive_cells[minetest.hash_node_position(pos)] = { pos = pos,
																	  creator = pname }
	end,
	on_dig = function(pos)
		--delete the node and remove from the inactive cell registry
		automata.in_inactive(pos, true)
		minetest.set_node(pos, {name="air"})
		return true
	end,
})
-- an activated automata cell -- further handling of this node done by grow() via globalstep
minetest.register_node("automata:active", {
	description = "Active Automata",
	tiles = {"active.png"},
	drop = { max_items = 1, items = { "automata.inactive" } }, -- change back to inactive when dug 
	light_source = 5,
	groups = {oddly_breakable_by_hand=1, not_in_creative_inventory=1},
	on_dig = function(pos)
		--delete the node and remove from any pattern it might belong to
		automata.in_patterns(pos, true)
		minetest.set_node(pos, {name="air"})
		return true
	end,
})
-- the controller for activating cells
minetest.register_tool("automata:remote" , {
	description = "Automata Trigger",
	inventory_image = "remote.png",
	--left-clicking the tool
	on_use = function (itemstack, user, pointed_thing)
		local pname = user:get_player_name()
		automata.show_rc_form(pname)
	end,
})
minetest.register_craft({
	output = "automata:inactive 32",
	recipe = {
		{"default:sand", "default:sand", "default:sand"},
		{"default:sand", "default:mese_crystal", "default:sand"},
		{"default:sand", "default:sand", "default:sand"}
	}
})
minetest.register_craft({
	output = "automata:remote",
	recipe = {
		{"automata:inactive", "automata:inactive", "automata:inactive"},
		{"automata:inactive", "default:mese_crystal", "automata:inactive"},
		{"automata:inactive", "automata:inactive", "automata:inactive"}
	}
})
-- if WorldEdit is installed then this chat command can be used as a way to handle
-- mass block conversions (//replace), pattern imports with WE (//save //load),
-- random fields (//mix) and as a way to revive patterns from crashes or quitting the game.
-- acts on automata blocks that got lost on quit/crash or were created with WE
minetest.register_chatcommand("/owncells", {
	params = "",
	description = "load orphaned automata blocks back into your remote control",
	privs = {worldedit=true},
	func = function(name, param)
		local pos1, pos2 = worldedit.pos1[name], worldedit.pos2[name]
		--for each automata:inactive block found in the area, if it is not owned by a
		--player in the game then it will load it into the automata.inactive table
		if pos1 == nil or pos2 == nil then
			minetest.chat_send_player(name, "No worldedit region selected!")
		else
			--identify the pmin and pmax from pos1 and pos2
			pos1, pos2 = worldedit.sort_pos(pos1, pos2)
			local vm = minetest.get_voxel_manip()
			local emin, emax = vm:read_from_map(pos1, pos2)
			local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
			local data = vm:get_data()
			local c_automata_active = minetest.get_content_id("automata:active")
			local c_automata_inactive = minetest.get_content_id("automata:inactive")
			local convert = false
			local added = false
			for i in area:iterp(pos1, pos2) do
				local found = false
				if data[i] == c_automata_inactive or data[i] == c_automata_active then
					local pos = area:position(i)
					if data[i] == c_automata_active then
						local pid = automata.in_patterns(pos)
						if pid then
							if minetest.get_player_by_name(automata.patterns[pid].creator) then 
								found = true
							else
								automata.in_patterns(pos, true) --delete it
								if not convert then convert = true end
								data[i] = c_automata_inactive
							end
						else
							-- if the cell is active then convert to inactive
							if not convert then convert = true end
							data[i] = c_automata_inactive
						end
					elseif data[i] == c_automata_inactive then
							local owner_name = automata.in_inactive(pos)
						if owner_name then
							if minetest.get_player_by_name(owner_name) then
								found = true
							else
								automata.in_inactive(pos, true)
							end
						end
					end
					if not found then 
						automata.inactive_cells[minetest.hash_node_position(pos)] = { pos = pos,
																				creator = name }
						added = true
					end
				end
			end
			if added then 
				if convert then
					vm:set_data(data)
					vm:write_to_map()
					vm:update_map()
				end
				minetest.chat_send_player(name, "you own new inactive automata cells")
				return true
			else
				minetest.chat_send_player(name, "nothing to own in that region")
			end
		end
		return false
	end,
})
-- check if a position is in the pattern list, second arg deletes it
function automata.in_patterns(pos, delete)
	for pid, values in next, automata.patterns do
		for vi, p in next, values.indexes do
			if pos.x == p.x and pos.y == p.y and pos.z == p.z then
				if delete == true then
					automata.patterns[pid].indexes[vi] = nil
					return pid
				end
			end
		end
	end
	return false
end
-- check if a position is in the pattern list, second arg deletes it
function automata.in_inactive(pos, delete)
	for hash, entry in next, automata.inactive do
		if pos.x == entry.pos.x and pos.y == entry.pos.y and pos.z == entry.pos.z then
			if delete == true then
				automata.inactive_cells[hash] = nil
				return entry.creator
			end
		end
	end
	return false
end
-- check if a position is in the inactive list, second arg deletes it
function automata.in_inactive(pos, delete)
	
end
-- REGISTER GLOBALSTEP
minetest.register_globalstep(function(dtime)
	automata.process_queue()
end)
--the grow_queue logic
function automata.process_queue()
	for pattern_id, v in next, automata.grow_queue do
	--print(dump(automata.patterns[pattern_id]))
		if automata.grow_queue[pattern_id].lock == false --pattern is not paused or finished
		and minetest.get_player_by_name(v.creator) --player in game
		and ( (os.clock() - automata.grow_queue[pattern_id].last_grow) 
			>= automata.grow_queue[pattern_id].size / 100
		or (os.clock() - automata.grow_queue[pattern_id].last_grow) 
			>= math.log(automata.grow_queue[pattern_id].size) )
		then
			--lock pattern and do the grow()
			automata.grow_queue[pattern_id].lock = true
			local size = automata.grow(pattern_id, v.creator)
			--update stats or kill the pattern
			if size then
				automata.grow_queue[pattern_id].size = size
				automata.grow_queue[pattern_id].lock = false
				automata.grow_queue[pattern_id].last_grow = os.clock()
			else
				automata.grow_queue[pattern_id] = nil
			end
			--update "manage" formspec for creator if tab 5 open
			if automata.open_tab5[v.creator] then
				automata.show_rc_form(v.creator)
				--@TODO this sometimes fails to happen on finished patterns (issue #30)
				--also when lag is heavy this form can keep reopening on the player
			end
		end
	end
end
-- looks at each pattern, applies the rules to generate a death list, birth list then
-- then sets the nodes and updates the pattern table settings and indexes (cell list)
function automata.grow(pattern_id, pname)
	local t1 = os.clock()
	--update the pattern values: iteration, last_cycle
	local iteration = automata.patterns[pattern_id].iteration +1
	local death_list ={} --cells that will be set to rules.trail at the end of grow()
	local birth_list = {} --cells that will be set to automata:active at the end of grow()
	local empty_neighbors = {} --non-active neighbor cell list to be tested for births
	local cell_count = 0 --since the indexes is keyed by vi, can't do #indexes
	local xmin,ymin,zmin,xmax,ymax,zmax --for the new pmin and pmax -- used to pace grow()
	--load the rules
	local rules = automata.patterns[pattern_id].rules
	local is_final = 0
	if iteration == rules.gens then is_final = 1 end
	--content types to reduce lookups
	local c_trail
	local c_final
	local rainbow = { "black","brown","dark_green","dark_grey","grey","white","pink",
					  "red","orange","yellow","green","cyan","blue","magenta","violet"}
	if rules.trail == "RAINBOW" then 
		c_trail = "wool:"..rainbow[ iteration - 1 - ( #rainbow * math.floor((iteration - 1) / #rainbow) ) + 1 ]
		c_trail = minetest.get_content_id(c_trail)	
		if rules.final == "RAINBOW" then
			c_final = c_trail
		else
			c_final = minetest.get_content_id(rules.final)
		end
	else
		c_trail = minetest.get_content_id(rules.trail)
		c_final = minetest.get_content_id(rules.final)
	end
	local c_air      = minetest.get_content_id("air")
	local c_automata = minetest.get_content_id("automata:active")
	--create a voxelManipulator instance
	local vm = minetest.get_voxel_manip()
	--expand the voxel extent by neighbors and growth beyond last pmin and pmax
	local e 
	if not rules.grow_distance or rules.grow_distance == "" or rules.grow_distance == 0 
	or rules.neighbors == 6  or rules.neighbors == 18 or rules.neighbors == 26 then 
		e = 1
		rules.grow_distance = 0
	else e = math.abs(rules.grow_distance) end
	local code1d
	if rules.neighbors == 2 then code1d = automata.toBits(rules.code1d, 8) end
	local old_pmin = automata.patterns[pattern_id].pmin
	local old_pmax = automata.patterns[pattern_id].pmax
	local new_emin, new_emax = vm:read_from_map({x=old_pmin.x-e, y=old_pmin.y-e, z=old_pmin.z-e},
												{x=old_pmax.x+e, y=old_pmax.y+e, z=old_pmax.z+e} )
	local new_area = VoxelArea:new({MinEdge=new_emin, MaxEdge=new_emax})
	local new_indexes = {}
	local new_xstride = new_emax.x-new_emin.x+1
	local new_ystride = new_emax.y-new_emin.y+1
	local data = vm:get_data()
	--pull the old values which will make the indexes valid
	local old_emin = automata.patterns[pattern_id].emin
	local old_emax = automata.patterns[pattern_id].emax
	local same_extent = false
	if old_emin == new_emin and old_emax == new_emax then same_extent = true end
	local old_xstride = old_emax.x-old_emin.x+1
	local old_ystride = old_emax.y-old_emin.y+1
	--load the cell list from last iteration
	local old_indexes = automata.patterns[pattern_id].indexes
	local zeroNbirth = false
	local zero_ns = {}
	local old_area
	-- if zero neighbor birth rule set then build up the zero neighbor list
	if ( rules.neighbors > 2 and rules.birth[0] ) or ( code1d and code1d[1] == 1) then 
		zeroNbirth = true
		if same_extent then
			old_area = new_area
		else
			old_area = VoxelArea:new({MinEdge=old_emin, MaxEdge=old_emax})
		end
		for i in old_area:iterp(old_pmin, old_pmax) do
			zero_ns[i] = true
		end
		for vi, pos in next, old_indexes do
			zero_ns[vi] = nil
		end
	end
	--simple function that adds a position to new_indexes, detects a new pmin and/or pmax, count+1
	local function add_to_new_cell_list(vi, p)
		new_indexes[vi] = p
		cell_count = cell_count + 1
		if xmin == nil then
			xmin = p.x ; xmax = p.x ; ymin = p.y ; ymax = p.y ; zmin = p.z ; zmax = p.z
		else
			if p.x > xmax then xmax = p.x end
			if p.x < xmin then xmin = p.x end
			if p.y > ymax then ymax = p.y end
			if p.y < ymin then ymin = p.y end
			if p.z > zmax then zmax = p.z end
			if p.z < zmin then zmin = p.z end
		end
	end
	--start compiling the absolute position and index offsets that represent neighbors and growth
	local neighborhood= {}
	local growth_offset = {x=0,y=0,z=0} --again this default is for 3D @TODO should skip the application of offset lower down
	-- determine neighborhood and growth offsets (works for 1D and 2D)
	if rules.neighbors == 2 or rules.neighbors == 4 or rules.neighbors == 8 then
		if rules.grow_axis == "x" then
			growth_offset = {x = rules.grow_distance, y=0, z=0}
		elseif rules.grow_axis == "z" then
			growth_offset = {x=0, y=0, z = rules.grow_distance}
		else --grow_axis is y
			growth_offset = {x=0, y = rules.grow_distance, z=0}
		end
	end
	-- 1D neighbors
	if rules.neighbors ==2 then
		if rules.axis == "x" then
			neighborhood.plus =  {x=  1,y=  0,z=  0}
			neighborhood.minus = {x= -1,y=  0,z=  0}
		elseif rules.axis == "z" then
			neighborhood.plus =  {x=  0,y=  0,z=  1}
			neighborhood.minus = {x=  0,y=  0,z= -1}
		else --rules.axis == "y"
			neighborhood.plus =  {x=  0,y=  1,z=  0}
			neighborhood.minus = {x=  0,y= -1,z=  0}
		end
	else --2D and 3D neighbors
		if rules.neighbors == 4 or rules.neighbors == 8 -- 2D von Neumann neighborhood
		or rules.neighbors == 6 or rules.neighbors == 18 or rules.neighbors == 26 then
			if rules.grow_axis == "x" then --actually the calculation plane yz
				neighborhood.n  = {x=  0,y=  1,z=  0}
				neighborhood.e  = {x=  0,y=  0,z=  1}
				neighborhood.s  = {x=  0,y= -1,z=  0}
				neighborhood.w  = {x=  0,y=  0,z= -1}
			elseif rules.grow_axis == "z" then --actually the calculation plane xy
				neighborhood.n  = {x=  0,y=  1,z=  0}
				neighborhood.e  = {x= -1,y=  0,z=  0}
				neighborhood.s  = {x=  0,y= -1,z=  0}
				neighborhood.w  = {x=  1,y=  0,z=  0}
			else --grow_axis == "y"  --actually the calculation plane xz (or we are in 3D)
				neighborhood.n  = {x=  0,y=  0,z=  1}
				neighborhood.e  = {x=  1,y=  0,z=  0}
				neighborhood.s  = {x=  0,y=  0,z= -1}
				neighborhood.w  = {x= -1,y=  0,z=  0}
			end
		end
		if rules.neighbors == 8 -- add missing 2D Moore corners
		or rules.neighbors == 18 or rules.neighbors == 26 then
			if rules.grow_axis == "x" then
				neighborhood.ne = {x=  0,y=  1,z=  1}
				neighborhood.se = {x=  0,y= -1,z=  1}
				neighborhood.sw = {x=  0,y= -1,z= -1}
				neighborhood.nw = {x=  0,y=  1,z= -1}
			elseif rules.grow_axis == "z" then
				neighborhood.ne = {x= -1,y=  1,z=  0}
				neighborhood.se = {x= -1,y= -1,z=  0}
				neighborhood.sw = {x=  1,y= -1,z=  0}
				neighborhood.nw = {x=  1,y=  1,z=  0}
			else --grow_axis is y or we are in 18n or 26n 3D
				neighborhood.ne = {x=  1,y=  0,z=  1}
				neighborhood.se = {x=  1,y=  0,z= -1}
				neighborhood.sw = {x= -1,y=  0,z= -1}
				neighborhood.nw = {x= -1,y=  0,z=  1}
			end
		end
		if rules.neighbors == 6 or rules.neighbors == 18 or rules.neighbors == 26 then --the 3D top and bottom neighbors
			neighborhood.t = {x=  0,y=  1,z=  0}
			neighborhood.b = {x=  0,y= -1,z=  0}
		end
		if rules.neighbors == 18 or rules.neighbors == 26 then -- the other 3D planar edge neighbors
			neighborhood.tn = {x=  0,y=  1,z=  1}
			neighborhood.te = {x=  1,y=  1,z=  0}
			neighborhood.ts = {x=  0,y=  1,z= -1}
			neighborhood.tw = {x= -1,y=  1,z=  0}		
			neighborhood.bn = {x=  0,y= -1,z=  1}
			neighborhood.be = {x=  1,y= -1,z=  0}
			neighborhood.bs = {x=  0,y= -1,z= -1}
			neighborhood.bw = {x= -1,y= -1,z=  0}
		end
		if rules.neighbors == 26 then -- the extreme 3D Moore corner neighbors
			neighborhood.tne = {x=  1,y=  1,z=  1}
			neighborhood.tse = {x=  1,y=  1,z= -1}
			neighborhood.tsw = {x= -1,y=  1,z= -1}
			neighborhood.tnw = {x= -1,y=  1,z=  1}		
			neighborhood.bne = {x=  1,y= -1,z=  1}
			neighborhood.bse = {x=  1,y= -1,z= -1}
			neighborhood.bsw = {x= -1,y= -1,z= -1}
			neighborhood.bnw = {x= -1,y= -1,z=  1}
		end
	end	
	--convert the neighbor position offsets to voxelArea index offsets in old area
	local neighborhood_vis = {}
	for k, offset in next, neighborhood do
		neighborhood_vis[k] = (offset.z * old_ystride * old_xstride)
						    + (offset.y * old_xstride)
						    +  offset.x
	end
	--convert the growth offset to index offset for new area
	local growth_vi = (growth_offset.z * new_ystride * new_xstride)
					+ (growth_offset.y * new_xstride) 
					+  growth_offset.x
	--CELL SURVIVAL TESTING LOOP: tests all old_indexes against rules.survival or code1d[3,4,7,8]
	for old_pos_vi, pos in next, old_indexes do		
		local survival = false
		--we need to convert the old index to the new index regardless of survival/death
		local new_pos_vi
		if same_extent then
			new_pos_vi = old_pos_vi
		else	
			new_pos_vi = new_area:indexp(pos)
		end	
		--CELL SURVIVAL TESTING: non-totalistic rules (ie, 1D)
		if rules.neighbors == 2 then
			local plus, minus
			--test the plus neighbor
			local pluspos_vi  = old_pos_vi + neighborhood_vis.plus
			if old_indexes[pluspos_vi] then plus  = 1
			else empty_neighbors[pluspos_vi] = {x=pos.x+neighborhood.plus.x,
												y=pos.y+neighborhood.plus.y,
												z=pos.z+neighborhood.plus.z}
			end
			--test the minus neighbor
			local minuspos_vi = old_pos_vi + neighborhood_vis.minus
			if old_indexes[minuspos_vi] then minus = 1 
			else empty_neighbors[minuspos_vi] = {x=pos.x+neighborhood.minus.x,
												 y=pos.y+neighborhood.minus.y,
												 z=pos.z+neighborhood.minus.z}
			end
			--apply the survival rules
			if ( not plus and not minus and code1d[3]==1 )
			or (     plus and not minus and code1d[4]==1 )
			or ( not plus and     minus and code1d[7]==1 )
			or (     plus and     minus and code1d[8]==1 ) then
				survival = true
			end
		--CELL SURVIVAL TESTING: totalistic ruleset (ie 2D and 3D)
		else
			local same_count = 0
			for k, vi_offset in next, neighborhood_vis do
				--add the neighbor offsets to the position
				local n_vi = old_pos_vi + vi_offset
				--test for sameness
				if old_indexes[n_vi] then
					same_count = same_count + 1
				else
					empty_neighbors[n_vi] = {x=pos.x+neighborhood[k].x,
											 y=pos.y+neighborhood[k].y,
											 z=pos.z+neighborhood[k].z}
				end
			end
			--now we have a same neighbor count, apply life and death rules
			if rules.survive[same_count] then
				survival = true
			end
		end
		if survival then
		--add to birth list with new position and death of old cell if growth is not 0
			if rules.grow_distance ~= 0 then
				local gpos_vi = new_pos_vi + growth_vi
				local gpos = {x=pos.x+growth_offset.x, y=pos.y+growth_offset.y, z=pos.z+growth_offset.z}
				birth_list[gpos_vi] = gpos --when node is actually set we will add to new_cell_list
				death_list[new_pos_vi] = pos --with grow_distance ~= 0, the old pos dies leaving rules.trail
			else
				--in the case that this is the final iteration, we need to pass it to the life list afterall
				if is_final == 1 then
					birth_list[new_pos_vi] = pos --when node is actually set we will add to new_indexes
				else
					add_to_new_cell_list(new_pos_vi, pos) --bypass birth_list go straight to new_indexes
				end
			end
		else
			--death of old cell in new voxelArea
			death_list[new_pos_vi] = pos
		end
	end
	--CELL BIRTH TESTING:
	-- all guaranteed zero-neighbor cells give birth if zero-n birth is active
	if zeroNbirth then
		-- remove neighbors we know to be empty but have an active cell neighbor
		for vi, p in next, empty_neighbors do
			zero_ns[vi] = nil
		end
		-- turn on all the remaining cells that have zero neighbors
		for vi in next, zero_ns do
			local epos = old_area:position(vi)
			--only if birth happens convert old_index to new_index
			local new_epos_vi = new_area:indexp(epos)
			--add to birth list
			local bpos_vi = new_epos_vi + growth_vi
			local bpos = {x=epos.x+growth_offset.x, y=epos.y+growth_offset.y, z=epos.z+growth_offset.z}
			birth_list[bpos_vi] = bpos --when node is actually set we will add to new_indexes
		end
	end
	-- tests all empty_neighbors against remaining rules.birth or code1d[2,5,6]
	for epos_vi, epos in next, empty_neighbors do
		local birth = false
		--CELL BIRTH TESTING: non-totalistic rules (ie. 1D)
		if rules.neighbors == 2 then
			local plus, minus
			--test the plus neighbor
			local pluspos_vi  = epos_vi + neighborhood_vis.plus
			if old_indexes[pluspos_vi] then plus  = 1
			end
			--test the minus neighbor
			local minuspos_vi = epos_vi + neighborhood_vis.minus
			if old_indexes[minuspos_vi] then minus = 1
			end
			--apply the birth rules
			if (     plus and not minus and code1d[2]==1 )
			or ( not plus and     minus and code1d[5]==1 )
			or (     plus and     minus and code1d[6]==1 ) then
				birth = true
			end
		--CELL BIRTH TESTING: totalistic rules (ie. 2D and 3D)
		else
			local same_count = 0
			for k, vi_offset in next, neighborhood_vis do
				--add the offsets to the position
				local n_vi = epos_vi + vi_offset
				--test for sameness
				if old_indexes[n_vi] then
					same_count = same_count + 1
				end
			end
			if rules.birth[same_count] then
				birth = true
			end
		end
		if birth then
			--only if birth happens convert old_index to new_index
			local new_epos_vi
			if same_extent then
				new_epos_vi = epos_vi
			else
				new_epos_vi = new_area:indexp(epos)
			end
			--add to birth list
			local bpos_vi = new_epos_vi + growth_vi
			local bpos = {x=epos.x+growth_offset.x, y=epos.y+growth_offset.y, z=epos.z+growth_offset.z}
			birth_list[bpos_vi] = bpos --when node is actually set we will add to new_indexes
		end
	end
	--apply deaths to data[]
	for dpos_vi, dpos in next, death_list do
		data[dpos_vi] = c_trail
	end
	--apply births to data[]
	for bpos_vi, bpos in next, birth_list do
		--test for destructive mode and if the node is occupied
		if rules.destruct == "true" or data[bpos_vi] == c_air then
			--test for final iteration
			if is_final == 1 then data[bpos_vi] = c_final
			else data[bpos_vi] = c_automata
			end
			--add to new_indexes even if final so that we can resume
			add_to_new_cell_list(bpos_vi, bpos)
		end
	end
	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
	--update pattern values
	local timer = (os.clock() - t1) * 1000
	local values =  { pmin = {x=xmin,y=ymin,z=zmin}, pmax = {x=xmax,y=ymax,z=zmax}, 
				      cell_count = cell_count, emin = new_emin, emax = new_emax,
					  indexes = new_indexes, l_timer = timer, iteration = iteration,
					  t_timer = automata.patterns[pattern_id].t_timer + timer,
					  rules = rules, creator = pname
				    }
	automata.patterns[pattern_id] = values
	if is_final == 1 then
		automata.patterns[pattern_id].status = "finished"
		minetest.chat_send_player(pname, "Your pattern, #"..pattern_id.." hit it's generation limit, "..iteration)
		return false
	end
	if next(new_indexes) == nil then
		automata.patterns[pattern_id].status = "extinct"
		minetest.chat_send_player(pname, "Your pattern, #"..pattern_id.." grew to zero at gen "..iteration)
		return false
	end
	automata.patterns[pattern_id].status = "active"
	return cell_count
end
-- create a new pattern either from single cell or import offsets, or from inactive_cells
function automata.new_pattern(pname, offsets, rule_override)
	local t1 = os.clock()
	-- form validation
	local rules = automata.rules_validate(pname, rule_override) --will be false if rules don't validate
	local c_automata = minetest.get_content_id("automata:active")
	if rules then
		--create the new pattern id empty
		table.insert(automata.patterns, true) --placeholder to get id
		local pattern_id = #automata.patterns
		local pos = {}
		local hashed_cells = {}
		local cell_count=0
		--are we being supplied with a list of offsets? (single or import lif)
		if offsets then
			local player = minetest.get_player_by_name(pname)
			local ppos = player:getpos()
			ppos = {x=math.floor(ppos.x), y=math.floor(ppos.y), z=math.floor(ppos.z)} --remove decimals
			--minetest.log("action", "rules: "..dump(rules))
			for k,offset in next, offsets do
				local cell = {}
				if rules.grow_axis == "x" then
					cell = {x = ppos.x, y=ppos.y+offset.n, z=ppos.z+offset.e}
				elseif rules.grow_axis == "y" then 
					cell = {x = ppos.x+offset.e, y=ppos.y, z=ppos.z+offset.n}
				elseif rules.grow_axis == "z" then
					cell = {x = ppos.x-offset.e, y=ppos.y+offset.n, z=ppos.z}
				else --3D, no grow_axis
					cell = ppos
				end
				hashed_cells[minetest.hash_node_position(cell)] = cell
			end
		else
			for hash, v in next, automata.inactive_cells do
				if v.creator == pname then
					hashed_cells[hash] = v.pos
				end					
			end
		end
		local xmin,ymin,zmin,xmax,ymax,zmax
		--update pmin and pmax
		--it would be nice to do this at each new_cell_list assignment above, but it is cleaner to just loop through all of them here
		for k,v in next, hashed_cells  do
			local p = minetest.get_position_from_hash(k) --this prevents lua table pass by ref
			if xmin == nil then --this should only run on the very first cell
				xmin = p.x ; xmax = p.x ; ymin = p.y ; ymax = p.y ; zmin = p.z ; zmax = p.z
			else
				if p.x > xmax then xmax = p.x end
				if p.x < xmin then xmin = p.x end
				if p.y > ymax then ymax = p.y end
				if p.y < ymin then ymin = p.y end
				if p.z > zmax then zmax = p.z end
				if p.z < zmin then zmin = p.z end
			end
		end
		local pmin = {x=xmin,y=ymin,z=zmin}
		local pmax = {x=xmax,y=ymax,z=zmax}
		local new_indexes = {}
		local vm = minetest.get_voxel_manip()
		local emin, emax = vm:read_from_map(pmin, pmax)
		local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
		local data = vm:get_data()
		local single_pos
		for pos_hash, pos in next, hashed_cells do
			single_pos = pos
			local vi = area:indexp(pos)
			data[vi] = c_automata
			new_indexes[vi] = pos
			cell_count = cell_count + 1
		end
		--for some bizzare reason a single cell isn't getting set by VM so using set_node(), issue #59
		if cell_count == 1 then
			minetest.set_node(single_pos, {name="automata:active"})
		else
			vm:set_data(data)
			vm:write_to_map()
			vm:update_map()
		end
		local timer = (os.clock() - t1) * 1000
		--add the cell list to the active cell registry with the gens, rules hash, and cell list
		local values = { creator=pname, status="active", iteration=0, rules=rules, 
						 cell_count = cell_count, cell_list=hashed_cells, pmin=pmin, pmax=pmax,
						 emin=emin, emax=emax, t_timer=timer, indexes = new_indexes }
		automata.patterns[pattern_id] = values --overwrite placeholder
		automata.grow_queue[pattern_id] = { lock = false, size = cell_count,
											last_grow=os.clock(), creator = pname }
		return true
	else 
		return false 
	end
end
-- called when new pattern is created
function automata.rules_validate(pname, rule_override)
	local rules = {}
	--read the player settings to get the last tab and then validate the fields relevant for that tab
	local tab = automata.get_player_setting(pname, "tab")
	--regardless we validate the growth options common to 1D, 2D and 3D automata
	--gens
	local gens = automata.get_player_setting(pname, "gens")
	if not gens then rules.gens = 100
	elseif tonumber(gens) > 0 and tonumber(gens) < 1001 then rules.gens = tonumber(gens)
	else automata.show_popup(pname, "Generations must be between 1 and 1000-- you said: "..gens) return false end
	--trail
	local trail = automata.get_player_setting(pname, "trail")
	if not trail then rules.trail = "air" 
	elseif trail == "RAINBOW" or minetest.get_content_id(trail) ~= 127 then rules.trail = trail
	else automata.show_popup(pname, trail.." is not a valid trail block type") return false end
	--final
	local final = automata.get_player_setting(pname, "final")
	if not final then rules.final = rules.trail 
	elseif minetest.get_content_id(final) ~= 127 then rules.final = final
	else automata.show_popup(pname, final.." is not a valid final block type") return false end
	--destructive
	local destruct = automata.get_player_setting(pname, "destruct")
	if not destruct then rules.destruct = "false" 
	else rules.destruct = destruct end
	--then validate fields common to 1D and 2D and importing 2D .LIF files (tab 4)
	if tab == "1" or tab == "2" or tab == "4" then
		--grow_distance
		local grow_distance = automata.get_player_setting(pname, "grow_distance")
		if not grow_distance then rules.grow_distance = 0
		elseif tonumber(grow_distance) then rules.grow_distance = tonumber(grow_distance) --@todo take modf()
		else automata.show_popup(pname, "the grow distance needs to be an integer-- you said: "..grow_distance) return false end
		--grow_axis (for 2D implies the calculation plane, for 1D cannot be the same as "axis")
		local grow_axis = automata.get_player_setting(pname, "grow_axis")
		if not grow_axis then rules.grow_axis = "y" --with the dropdown on the form this default should never be used
		else rules.grow_axis = grow_axis end
		--fields specific to 1D
		if tab == "1"  then
			rules.neighbors = 2 --implied (neighbors is used by grow() to determine dimensionality)
			--code1d (must be between 0 and 255 -- NKS rule numbers for 1D automata)
			local code1d = automata.get_player_setting(pname, "code1d")
			if not code1d then rules.code1d = 30 
			elseif tonumber(code1d) >= 0 and tonumber(code1d) <= 255 then rules.code1d = tonumber(code1d)
			else automata.show_popup(pname, "the 1D rule should be between 0 and 255-- you said: "..code1d) return false end
			--axis (this is the calculation axis and must not be the same as the grow_axis, only matters if tab=1)
			rules.axis = automata.get_player_setting(pname, "axis")
			if rules.axis == grow_axis then
				automata.show_popup(pname, "the grow axis and main axis cannot be the same") --not working most of time
				return false 
			end
		elseif tab == "2" then--fields specific to 2D
			--n2d
			local n2d = automata.get_player_setting(pname, "n2d")
			rules.neighbors = tonumber(n2d)
			local code2d = automata.get_player_setting(pname, "code2d")
			if not code2d then code2d = "23/3" end
			rules.survive, rules.birth = automata.code2d_to_sb_and_nks(code2d)
		elseif tab == "4" then
			rules.neighbors = 8
			--process the rule override if passed in to rules_validate() as "rule_override"
			if not rule_override then rule_override = "23/3" end
			rules.survive, rules.birth = automata.code2d_to_sb_and_nks(rule_override)
		end
	elseif tab == "3" then --fields specific to 3D
		--n3d
		local n3d = automata.get_player_setting(pname, "n3d")
		rules.neighbors = tonumber(n3d)
		local code3d = automata.get_player_setting(pname, "code3d")
		if not code3d then code3d = "2,3/3" end 
		rules.survive, rules.birth = automata.code2d_to_sb_and_nks(code3d)
	end
	return rules
end
-- function to convert integer to bigendian binary string needed frequently
-- to convert from NKS codes to usefulness
-- modified from http://stackoverflow.com/a/26702880/3765399
function automata.toBits(num, bits)
    -- returns a table of bits, most significant first.
    bits = bits or select(2,math.frexp(num))
    local t={} -- will contain the bits        
    for b=1,bits,1 do --left to right binary table
        t[b]=math.fmod(num,2)
        num=(num-t[b])/2
    end
    return t
end
-- explode function modified from http://stackoverflow.com/a/29497100/3765399
-- for converting code3d inputs to tables
-- with delimiter set to ", " this will discard all non-numbers,
-- and accept commas and/or spaces as delimiters
-- with no delimiter set, the entire string is exploded character by character
function automata.explode(source, delimiters)
	local elements = {}
	if not delimiters then --then completely explode every character
		delimiters = " "
		local temp = ""
		for i=1, string.len(source) do
			temp = temp .. " "..string.sub(source, i, i)
		end
		source = temp.." " --extra space to avoid nil
	end
	local pattern = '([^'..delimiters..']+)'
	string.gsub(source, pattern, function(value) if tonumber(value) then elements[tonumber(value)] = true; end  end);
	return elements
end

-- validate and convert the survival / birth rules to NKS code
function automata.code2d_to_sb_and_nks(code2d)
	local survival, birth
	local nks = 0
	local split = string.find(code2d, "/")
	if split then
		-- take the values to the left and the values to the right
		survival = string.sub(code2d, 1, split-1)
		birth = string.sub(code2d, split+1)
	else
		--assume all rules are survival if no split
		survival = code2d
		birth = ""
	end
	survival = automata.explode(survival)
	birth = automata.explode(birth)
	for i = 0, 8, 1 do
		--odd (birth)
		if birth[i] then --when i=0, power is 0, when i=1 power is 2, i=2 p=4
			nks = nks + ( 2 ^ (i*2) )
		end
		--even (survival)
		if survival[i] then --when i=0 power is 1, when i=1 power is 3, 1=2 p=5
			nks = nks + ( 2 ^ (2*i+1) )
		end
	end
	return survival, birth, nks
end
-- Processing the form from the RC
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 1, 9) == "automata:" then
		local wait = os.clock()
		while os.clock() - wait < 0.05 do end --popups don't work without this see issue #30
		--print("fields submitted: "..dump(fields))
		local pname = player:get_player_name()
		-- recover the old tab to detect tab change later
		local old_tab = automata.get_player_setting(pname, "tab")
		-- always save any form fields
		for k,v in next, fields do
			automata.player_settings[pname][k] = v --we will preserve field entries exactly as entered 
		end
		automata.save_player_settings()
		if formname == "automata:popup" then
			if fields.exit == "Back" then
				automata.show_rc_form(pname)
				return true
			end
		end
		if formname == "automata:nks1d" then
			if fields.exit == "Convert" then
				local bits = {}
				local code1d = 0
				for b = 1, 8, 1 do
					local bit = automata.player_settings[pname]["bit"..b]
					if bit and bit == "true" then
						code1d = code1d + ( 2 ^ ( b - 1) )
					end
				end
				automata.player_settings[pname].code1d = code1d
				automata.save_player_settings()
				automata.show_rc_form(pname)
			end
			return true
		end
		if formname == "automata:nks2d" then
			if fields.exit == "Convert" then
				local nks = automata.player_settings[pname].nks
				local survival = ""
				local birth = ""
				local code2d = ""
				nks = tonumber(nks)
				if nks and nks > 0 then
					--convert the NKS code back to a survival / birth code
					code2d = automata.toBits(nks)
					for i=1,9,1 do
						--birth
						if code2d[i*2-1] == 1 then
							birth = birth .. (i-1)
						end
						--survival
						if code2d[i*2] == 1 then
							survival = survival .. (i-1)
						end
					end
					code2d = survival .. "/" .. birth
				end
				automata.player_settings[pname].code2d = code2d
				automata.save_player_settings()
				automata.show_rc_form(pname)
			end
			return true
		end
		--the main form
		if formname == "automata:rc_form" then 
			-- if any tab but 5 selected unlist the player as having tab5 open
			if fields.quit or ( fields.tab ~= "5" and not fields.pid_id ) then 
				automata.open_tab5[pname] = nil
			end 
			--detect tab change	
			if old_tab and old_tab ~= automata.get_player_setting(pname, "tab") then
				automata.show_rc_form(pname)
				return true
			end	
			--if a lif was clicked show the popup form summary
			if fields.lif_id and string.sub(fields.lif_id, 1, 4) == "DCL:" then
				automata.show_lif_summary(pname)
			end
			--if the pid_id click or double-click field is submitted, we pause or unpause the pattern
			if fields.pid_id then
				--translate the pid_id back to a pattern_id
				local pid_id = string.sub(fields.pid_id, 5)
				local pattern_id = automata.open_tab5[pname][tonumber(pid_id)] --this table is created in show_rcform() survives changes to patterns table
				if string.sub(fields.pid_id, 1, 4) == "CHG:" and automata.patterns[pattern_id].status == "active" then
					automata.grow_queue[pattern_id] = nil
					automata.patterns[pattern_id].status = "paused"
				elseif string.sub(fields.pid_id, 1, 4) == "DCL:" then
					if automata.patterns[pattern_id].status == "paused" then
						automata.patterns[pattern_id].status = "active"
						automata.grow_queue[pattern_id] = { lock = false, last_grow=os.clock(), creator = pname,
															size = automata.patterns[pattern_id].cell_count }
					elseif automata.patterns[pattern_id].status == "finished" then
						local add_gens = tonumber(fields.add_gens)
						if add_gens then
							add_gens = math.floor(add_gens)
							automata.player_settings[pname][add_gens] = add_gens
							automata.patterns[pattern_id].rules.gens = automata.patterns[pattern_id].rules.gens + add_gens
							automata.grow_queue[pattern_id] = { lock = false, last_grow=os.clock(), creator = pname,
																size = automata.patterns[pattern_id].cell_count }
						else automata.show_popup(pname, "Add gens field must be a number")
						end
					end
				end
				--update the form
				automata.show_rc_form(pname)
				return true
			end
			--actual form submissions
			if fields.exit == "Activate" then
				if automata.new_pattern(pname) then
					automata.inactive_cells = {} --reset the inactive cell lsit
					minetest.chat_send_player(pname, "You activated all inactive cells!")
					return true
				end
			elseif fields.exit == "Import" then
				if automata.import_lif(pname) then
					minetest.chat_send_player(pname, "You imported a LIF to your current location!")
					return true
				end
			elseif fields.exit == "Single" then
				if automata.singlenode(pname) then
					minetest.chat_send_player(pname, "You started a single cell at your current location!")
					return true
				end
			elseif fields.exit == "NKS Code" then
				automata.nks_code2d_popup(pname)
				return true
			elseif fields.exit == "8 Rules" then
				automata.explicit_rules1d_popup(pname)
				return true
			end
			return true
		end
		return true
	end
end)
--the formspecs and related settings and functions / selected field variables
automata.player_settings = {} --per player form persistence
automata.open_tab5 = {} --who has tab 5 (Manage) open at any moment
automata.lifs = {} --indexed table of lif names
automata.lifnames = "" --string of all lif file names
--this is run at load time (see EOF)
function automata.load_lifs()
	local lifsfile = io.open(minetest.get_modpath("automata").."/lifs/_list.txt", "r")
	if lifsfile then
		for line in lifsfile:lines() do
			if line ~= "" then
			table.insert(automata.lifs, line)
			end
		end
		lifsfile:close()
	end
	for k,v in next, automata.lifs do
		automata.lifnames = automata.lifnames .. v .. ","
	end
end
--called at each form submission
function automata.save_player_settings()
	local file = io.open(minetest.get_worldpath().."/automata_settings", "w")
	if file then
		for k,v in next, automata.player_settings do
			local line = {key=k, values=v}
			file:write(minetest.serialize(line).."\n")
		end
		file:close()
	end
end
-- load settings run at EOF at mod start
function automata.load_player_settings()
	local file = io.open(minetest.get_worldpath().."/automata_settings", "r")
	if file then
		for line in file:lines() do
			if line ~= "" then
				local tline = minetest.deserialize(line)
				automata.player_settings[tline.key] = tline.values
			end
		end
		file:close()
	end
end
--retrieve individual form field
function automata.get_player_setting(pname, setting)
	if automata.player_settings[pname] then
		if automata.player_settings[pname][setting] then
			if automata.player_settings[pname][setting] ~= "" then
				return automata.player_settings[pname][setting]
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end
end
-- show the main remote control form
function automata.show_rc_form(pname)
	local player = minetest.get_player_by_name(pname)
	local ppos = player:getpos()
	local degree = player:get_look_yaw()*180/math.pi - 90
	if degree < 0 then degree = degree + 360 end
	local dir
	if     degree <= 45 or degree > 315 then dir = "+ Z"
	elseif degree <= 135 then dir = "- X"
	elseif degree <= 225 then dir = "- Z"
	else   dir = "+ X" end
	local tab = automata.get_player_setting(pname, "tab")
	if not tab then 
		tab = "2"
		automata.player_settings[pname] = {tab=tab}
	end
	--handle open tab5, system needs to know who has tab5 open at any moment so that
	-- it can be refreshed by globalstep activity...
	if tab == "5" then automata.open_tab5[pname] = {} end --gets reset to nil in on_player_receive_fields()
	--load the default fields for the forms based on player's last settings
	--gens
	local gens = automata.get_player_setting(pname, "gens")
	if not gens then gens = "" end
	--trail
	local trail = automata.get_player_setting(pname, "trail")
	if not trail then trail = "" end
	--final
	local final = automata.get_player_setting(pname, "final")
	if not final then final = "" end
	--destructive
	local destruct = automata.get_player_setting(pname, "destruct")
	if not destruct then destruct = "false" end
	--set some formspec sections for re-use on all tabs
	local f_header = 			"size[12,10]" ..
								"tabheader[0,0;tab;1D, 2D, 3D, Import, Manage;"..tab.."]"..
								"label[0,0;You are at x= "..math.floor(ppos.x)..
								" y= "..math.floor(ppos.y).." z= "..math.floor(ppos.z).." and mostly facing "..dir.."]"
	--1D, 2D, 3D, Import
	local f_grow_settings = 	"field[1,5;4,1;trail;Trail Block (eg: dirt);"..minetest.formspec_escape(trail).."]" ..
								"field[1,6;4,1;final;Final Block (eg: default:mese);"..minetest.formspec_escape(final).."]" ..
								"checkbox[0.7,7.5;destruct;Destructive?;"..destruct.."]"..
								"field[1,7;4,1;gens;Generations (eg: 30);"..minetest.formspec_escape(gens).."]"
	--1D,2D,and 3D
	--make sure the inactive cell registry is not empty
	local activate_section = 	"label[1,8.5;No inactive cells in map]"
	if next(automata.inactive_cells) then
		activate_section = 		"label[1,8.5;Activate inactive cells]"..
								"button_exit[1,9;2,1;exit;Activate]"
	end
	local f_footer = 			activate_section ..
								"label[4.5,8.5;Start one cell here.]"..
								"button_exit[4.5,9;2,1;exit;Single]"
	
	--then populate defaults common to 1D and 2D (and importing)
	if tab == "1" or tab == "2" or tab == "4" then
		--grow_distance
		local grow_distance = automata.get_player_setting(pname, "grow_distance")
		if not grow_distance then grow_distance = "" end
		--grow_axis (for 2D implies the calculation plane, for 1D cannot be the same as "axis")
		local grow_axis_id
		local grow_axis = automata.get_player_setting(pname, "grow_axis")
		if not grow_axis then grow_axis_id = 2
		else 
			local idx = {x=1,y=2,z=3}
			grow_axis_id = idx[grow_axis]
		end
		local f_grow_distance = "field[1,4;4,1;grow_distance;Grow Distance (-1, 0, 1, 2 ...);"..minetest.formspec_escape(grow_distance).."]"
		local f_grow_axis = 	"label[1,2.5; Growth Axis]"..
								"dropdown[3,2.5;1,1;grow_axis;x,y,z;"..grow_axis_id.."]"
		--fields specific to 1D
		if tab == "1"  then
			--code1d (must be between 1 and 256 -- NKS rule numbers for 1D automata)
			local code1d = automata.get_player_setting(pname, "code1d")
			if not code1d then code1d = "" end
			--axis (this is the calculation axis and must not be the same as the grow_axis)
			local axis_id
			local axis = automata.get_player_setting(pname, "axis")
			if not axis then axis_id = 1
			else 
				local idx = {x=1,y=2,z=3}
				axis_id = idx[axis]
			end
			local f_code1d = 			"field[6,1;2,1;code1d;Rule# (eg: 30);"..
										minetest.formspec_escape(code1d).."]"..
										"button_exit[6,2;2,1;exit;8 Rules]"
			local f_axis = 				"label[1,1.5; Main Axis]"..
										"dropdown[3,1.5;1,1;axis;x,y,z;"..axis_id.."]"
			minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_grow_axis .. 
								f_grow_distance .. 
								f_code1d .. f_axis ..
								f_footer
			)
			return true
		--fields specific to 2D and LIF import
		elseif tab == "2" then
			--n2d
			local n2d_id
			local n2d = automata.get_player_setting(pname, "n2d")
			if not n2d then n2d_id = 2
			else 
				local idx = {}; idx["4"]=1; idx["8"]=2
				n2d_id = idx[n2d]
			end
			--code2d
			local code2d = automata.get_player_setting(pname, "code2d")
			if not code2d then code2d = "" end
			local s, b, nks = automata.code2d_to_sb_and_nks(code2d)
			local f_n2d = 				"label[1,0.5;Neighbors]"..
										"dropdown[3,0.5;1,1;n2d;4,8;"..n2d_id.."]"
			local f_code2d = 			"field[6,1;6,1;code2d;Rules (eg: 23/3);"..
												minetest.formspec_escape(code2d).."]"..
										"button_exit[6,2;2,1;exit;NKS Code]"..
										"label[8,2.2;Currently NKS code "..nks.."]"
			minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_grow_axis .. 
								f_grow_distance .. 
								f_n2d .. f_code2d ..
								f_footer
			)
			return true
		else --tab == 4
			local lif_id = automata.get_player_setting(pname, "lif_id")
			if not lif_id then lif_id = 1 else lif_id = tonumber(string.sub(lif_id, 5)) end
			minetest.show_formspec(pname, "automata:rc_form", 
									f_header ..
									f_grow_settings ..
									f_grow_axis .. 
									f_grow_distance .. 
									"textlist[8,0;4,7;lif_id;"..automata.lifnames..";"..lif_id.."]"..
									"label[8,8.5;Import Selected LIF here]"..
									"button_exit[8,9;2,1;exit;Import]"
			)
			return true
		end
	end
	if tab == "3"  then
		--n3d
		local n3d_id
		local n3d = automata.get_player_setting(pname, "n3d")
		if not n3d then n3d_id = 3
		else 
			local idx = {}; idx["6"]=1; idx["18"]=2; idx["26"]=3
			n3d_id = idx[n3d]
		end
		--code3d
		local code3d = automata.get_player_setting(pname, "code3d")
		if not code3d then code3d = "" end
		local f_n3d = 		"label[1,0.5;Neighbors]"..
							"dropdown[3,0.5;1,1;n3d;6,18,26;"..n3d_id.."]"
		local f_code3d = 	"field[6,1;6,1;code3d;Rules (eg: 2,3,24,25/3,14,15,16);"..minetest.formspec_escape(code3d).."]"
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_n3d .. f_code3d ..
								f_footer
		)
		return true
	end
	if tab == "5" then --manage patterns
		local patterns = ""
		local i = 1
		for k,v in next, automata.patterns do
			if v.creator == pname then
				i = i+1
				local pmin = v.pmin
				local pmax = v.pmax				
				patterns = 	patterns..","..minetest.formspec_escape(k
							.." ["..v.status.."] gen:"..v.iteration.." cells:"
							..v.cell_count.." time:"..math.ceil(v.t_timer).."ms min:"
							..pmin.x.."."..pmin.y.."."..pmin.z.." max:"..pmax.x.."."..pmax.y.."."..pmax.z)
				automata.open_tab5[pname][i]=k --need this table to decode the form's pid_ids back to pattern_ids
			end
		end
		local pid_id = automata.get_player_setting(pname, "pid_id")
		if not pid_id then pid_id = 1 end
		local f_plist
		local add_gens = automata.get_player_setting(pname, "add_gens")
		if not add_gens then add_gens = 1 end
		if patterns == "" then f_plist = "label[1,1;no active patterns]"
		else f_plist = 	"label[1,1;Your patterns]"..
						"textlist[1,1.5;10,8;pid_id;"..patterns..";1]"..
						"label[3,1;Single Click to Pause]"..
						"label[6,1;Double Click to Resume]"..
						"field[9.5,1;2,1;add_gens;More Gens:;"..minetest.formspec_escape(add_gens).."]"
		end
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..	f_plist
								
		)
		return true
	end
end
-- 1D code breakdown
function automata.explicit_rules1d_popup(pname)
	local code1d = automata.get_player_setting(pname, "code1d")
	local bits = {}
	if not code1d then 
		code1d = "" 
		for b = 1, 8, 1 do
			bits[b] = "false"
		end
	else 
		code1d = tonumber(code1d)
		if code1d >= 0 and code1d < 256 then
			bits = automata.toBits(code1d, 8)
		end
	end
	-- flush the saved bits and populate the form
	for b = 1, 8, 1 do
		if bits[b] == 1 then 
			bits[b] = "true" 
			automata.player_settings[pname]["bit"..b] = "true"
		else 
			bits[b] = "false"
			automata.player_settings[pname]["bit"..b] = nil
		end
	end
	minetest.show_formspec(pname, 	"automata:nks1d",
									"size[10,4]" ..
									"checkbox[8,3;bit1;;"..bits[1].."]"..
									"label[7.95,2.5;OOO]"..
									"checkbox[7,3;bit2;;"..bits[2].."]"..
									"label[6.95,2.5;OOX]"..
									"checkbox[6,3;bit3;;"..bits[3].."]"..
									"label[5.95,2.5;OXO]"..
									"checkbox[5,3;bit4;;"..bits[4].."]"..
									"label[4.95,2.5;OXX]"..
									"checkbox[4,3;bit5;;"..bits[5].."]"..
									"label[3.95,2.5;XOO]"..
									"checkbox[3,3;bit6;;"..bits[6].."]"..
									"label[2.9,2.5;XOX]"..
									"checkbox[2,3;bit7;;"..bits[7].."]"..
									"label[1.9,2.5;XXO]"..
									"checkbox[1,3;bit8;;"..bits[8].."]"..
									"label[0.9,2.5;XXX]"..
									"button_exit[1,1;2,1;exit;Convert]"..
									"label[1,0.5;NKS code: "..minetest.formspec_escape(code1d).."]"
	)
	return true
end
-- 2D NKS code conversion
function automata.nks_code2d_popup(pname)
	local code2d = automata.get_player_setting(pname, "code2d")
	local nks = 0
	if not code2d then 
		code2d = ""
	else
		local survival, birth
		survival, birth, nks = automata.code2d_to_sb_and_nks(code2d)
	end
	minetest.show_formspec(pname, 	"automata:nks2d",
									"size[10,4]" ..
									"field[1.2,3;3,1;nks;NKS Code;"..minetest.formspec_escape(nks).."]"..
									"button_exit[1,1;2,1;exit;Convert]"..
									"label[1,0.5;"..minetest.formspec_escape("Survival/Birth rules: "..code2d).."]"
	)
	return true
end
-- show a popup form of the lif file summary
function automata.show_lif_summary(pname)
	local lif_id = automata.get_player_setting(pname, "lif_id")
	if lif_id then lif_id = tonumber(string.sub(lif_id, 5)) else return false end
	local liffile = io.open(minetest.get_modpath("automata").."/lifs/"..automata.lifs[lif_id]..".LIF", "r")
	local message = ""
	local count = 0
	local byte_char = string.byte("*")
	if liffile then
		local title = ""
		local desc = ""
		local ruleset = ""
		local i = 1
		for line in liffile:lines() do
			--minetest.log("action", "line: "..line)
			if string.sub(line, 1,2) == "#D" then
				if i == 1 then title = string.sub(line, 4) else
				desc = desc .. string.sub(line, 4).."\n"
				end
				i = i+1
			end
			if string.sub(line, 1,2) == "#N" then
				ruleset = "Standard Rules: 23/3"
			end
			if string.sub(line, 1,2) == "#R" then
				ruleset = "Non-standard Rules: " .. string.sub(line, 4)
			end
			if string.sub(line, 1,1) ~= "#" then
				-- count all the cells
				for i = 1, #line do
					if string.byte(line, i) == byte_char then
						count = count + 1 
					end 
				end 
			end
		end
		if count then
			message = title.."\nThis pattern has "..count.." cells. "..ruleset.."\n"..desc
		end
	end
	minetest.show_formspec(pname, "automata:popup",
								"size[10,8]" ..
								"button_exit[0.5,0.1;2,1;exit;Back]"..
								"label[1,1;"..minetest.formspec_escape(message).."]"
	)
end
-- this is the form-error popup
function automata.show_popup(pname, message)
	minetest.chat_send_player(pname, "Form error: "..message)
	minetest.show_formspec(pname, "automata:popup",
								"size[10,8]" ..
								"button_exit[1,1;2,1;exit;Back]"..
								"label[1,3;"..minetest.formspec_escape(message).."]"
	)
	return true
end
-- prepare offsets for a single node
function automata.singlenode(pname)
	local offset_list = {}
	table.insert(offset_list, {n=0, e=0}) --no offset, single node, at player's position
	if automata.new_pattern(pname, offset_list) then return true end
end
-- prepare offsets from a lif file
function automata.import_lif(pname)
	local lif_id = automata.get_player_setting(pname, "lif_id")
	if not lif_id then lif_id = 1 else lif_id = tonumber(string.sub(lif_id, 5)) end
	local liffile = io.open(minetest.get_modpath("automata").."/lifs/"..automata.lifs[lif_id]..".LIF", "r")
	if liffile then
		local origin = nil
		local offset_list = {}
		local rule_override = nil
		--start parsing the LIF file. ignore all lines except those starting with #R, #P, * or .
		for line in liffile:lines() do
			--minetest.log("action", "line: "..line)
			if string.sub(line, 1,2) == "#R" then
				rule_override = string.sub(line, 4)
			end
			if string.sub(line, 1,2) == "#P" then
				local split = string.find(string.sub(line, 4), " ")
				origin = {e = tonumber(string.sub(line, 4, 3+split)), n = tonumber(string.sub(line, split+4))}
			end
			--an origin must be set for any lines to be processed otherwise lif file corrupt
			if string.sub(line, 1,1) == "." or string.sub(line, 1,1) == "*" then
				if origin ~= nil then
					
					for i = 0, string.len(line), 1 do --trying to avoid going past the end of the string
						--read each line into the offset table
						if string.sub(line, i+1, i+1) == "*" then
							table.insert(offset_list, {e=origin.e+i, n=origin.n})
						end
					end
					origin.n = origin.n-1 --so that the next row is using the correct n
				end
			end
		end
		--minetest.log("action", "cells: "..dump(offset_list))
		liffile:close()		
		if automata.new_pattern(pname, offset_list, rule_override) then return true end
	end	
	return false
end
--read from file, various persisted settings
automata.load_player_settings()
automata.load_lifs()