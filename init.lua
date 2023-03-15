-- AUTOMATA mod for Minetest 4.12+
-- this is version 0.1.0 (released 21july2015)
-- source: github.com/bobombolo/automata
-- depends: WorldEdit mod if you want to use chat command //owncells
-- written by bobomb (find me on the forum.minetest.net)
-- license: WTFPL
local DEBUG = false
automata = {}
automata.patterns = {} -- master pattern list
automata.grow_queue = {}
automata.inactive_cells = {} -- automata:inactive nodes, activated with the remote
automata.sound_handler = nil
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
	if not automata.inactive_cells then return false end
	for hash, entry in next, automata.inactive_cells do
		if pos.x == entry.pos.x and pos.y == entry.pos.y and pos.z == entry.pos.z then
			if delete == true then
				automata.inactive_cells[hash] = nil
				return entry.creator
			end
		end
	end
	return false
end
-- REGISTER GLOBALSTEP
minetest.register_globalstep(function(dtime)
	automata.process_queue()
end)
--the grow_queue logic
function automata.process_queue()
	for pattern_id, v in next, automata.grow_queue do
		local delay = automata.patterns[pattern_id].rules.delay / 1000
		--if not delay then delay = 0 end
		if automata.grow_queue[pattern_id].lock == false --pattern is not paused or finished
		and minetest.get_player_by_name(v.creator) --player in game
		--commenting out the throttling
		and (os.clock() - automata.grow_queue[pattern_id].last_grow) >= delay 
		--	>= automata.grow_queue[pattern_id].size / 100
		--or (os.clock() - automata.grow_queue[pattern_id].last_grow) 
		--	>= math.log(automata.grow_queue[pattern_id].size) )
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
			--update "manage" formspec for creator if tab 6 open
			if automata.open_tab6[v.creator] then
				automata.show_rc_form(v.creator)
				--@TODO this sometimes fails to happen on finished patterns (issue #30)
				--also when lag is heavy this form can keep reopening on the player
			end
		end
	end
end
-- a function to check for the symmetry of a 3D pattern
-- this is mostly a debugging method since 3D patterns sometimes get jumbled
-- works only on patterns started with a single cell or a symmetrical starter
-- works only on unobstructed patterns or when destructive mode is on
-- returns a table full of block positions that need to be marked as asymmetrical
function automata.check_symmetry(indexes, center)
	local asymmetrical_cells = {}
	local cell_count = 0
	for k,v in pairs(indexes) do
		cell_count = cell_count + 1
	end
	--print(dump(indexes))
	for index, position in pairs(indexes) do
		--calculate the x, y and z offset of the block from the center
		local dist = {x = position.x - center.x, y = position.y - center.y, z = position.z - center.z}
		local function check_cells_across_axis(axis)
			local opposite_cell = {x=0, y=0, z=0}
			if dist[axis] < 0 then opposite_cell[axis] = 2 * -dist[axis]
			elseif dist[axis] > 0 then opposite_cell[axis] = 2 * -dist[axis] 
			end
			local offset_position = {x=position.x + opposite_cell.x,
									y=position.y + opposite_cell.y,
									z=position.z + opposite_cell.z}
			local found = false
			for k, v in pairs(indexes) do
				if v.x == offset_position.x
				and v.y == offset_position.y
				and v.z ==  offset_position.z then
					found = true
					break
				end
			end
			if found then
				return true
			else
				return false
			end
		end
		local asymmetries = 0
		if not check_cells_across_axis("x")  then asymmetries = asymmetries + 1 end
		if not check_cells_across_axis("y")  then asymmetries = asymmetries + 1 end
		if not check_cells_across_axis("z")  then asymmetries = asymmetries + 1 end
		if asymmetries > 0 then
			asymmetrical_cells[index] = position
			asymmetrical_cells[index].badness = asymmetries
		end
	end
	return asymmetrical_cells
end
-- looks at each pattern, applies the rules to generate a death list, birth list then
-- then sets the nodes and updates the pattern table settings and indexes (cell list)
function automata.grow(pattern_id, pname)
	local t1 = os.clock()
	--update the pattern values: iteration, last_cycle
	local iteration = automata.patterns[pattern_id].iteration +1
    local base = automata.patterns[pattern_id].base
	local death_list ={} --cells that will be set to rules.trail at the end of grow()
	local birth_list = {} --cells that will be set to automata:active at the end of grow()
    local leaves_list = {} -- cells that will become leaves in tree mode at the end of grow()	
    local empty_neighbors = {} --non-active neighbor cell list to be tested for births
	local cell_count = 0 --since the indexes is keyed by vi, can't do #indexes
	--load the rules
	local rules = automata.patterns[pattern_id].rules
	local is_final = false
	if iteration == rules.gens then is_final = true end
	--content types to reduce lookups
	local c_air = minetest.get_content_id("air")
	local c_trail
	local c_final
	--sequences
	local use_sequence = rules.use_sequence
	local sequence = automata.patterns[pattern_id].sequence
	if use_sequence and not rules.tree then
		if next(sequence) == nil then
			c_trail = c_air
		else 
			local trail = sequence[ ( iteration - 1 ) % #sequence + 1 ]
			c_trail = minetest.get_content_id(trail)
			if is_final and rules.final == "" then
				c_final = minetest.get_content_id(sequence[ ( iteration ) % #sequence + 1 ])
			end
		end
	else
		c_trail = minetest.get_content_id(rules.trail)
	end
	if is_final and not c_final then
		if rules.final == "" then
			c_final = c_trail
		else
			c_final = minetest.get_content_id(rules.final)
		end
	end
	local c_automata = minetest.get_content_id("automata:active")
    local c_leaves
    if c_final == minetest.get_content_id("default:jungletree") then
		c_leaves = minetest.get_content_id("default:jungleleaves")
	elseif c_final == minetest.get_content_id("default:pine_tree") then
		c_leaves = minetest.get_content_id("default:pine_needles")
	elseif c_final == minetest.get_content_id("default:acacia_tree") then
		c_leaves = minetest.get_content_id("default:acacia_leaves")
	elseif c_final == minetest.get_content_id("default:aspen_tree") then
		c_leaves = minetest.get_content_id("default:aspen_leaves")
	else
		c_leaves = minetest.get_content_id("default:leaves")
	end
    local c_apple = minetest.get_content_id("default:apple")
	--create a voxelManipulator instance
	local vm = minetest.get_voxel_manip()
	--expand the voxel extent by neighbors and growth beyond last pmin and pmax
	local e 
	if not rules.grow_distance or rules.grow_distance == "" or rules.grow_distance == 0 
	or rules.neighbors == 6  or rules.neighbors == 18 or rules.neighbors == 26 then 
		e = 2 -- 1 should work but irregularities are introduced sometimes at gen 8
		rules.grow_distance = 0
	else e = math.abs(rules.grow_distance) end
	local code1d
	if rules.neighbors == 2 then code1d = automata.toBits(rules.code1d, 8) end
	local old_pmin = automata.patterns[pattern_id].pmin
	local old_pmax = automata.patterns[pattern_id].pmax
	--shrink the old values by 1 so that the extent doesn't include the trail
	local xmin = old_pmin.x + 1
	local ymin = old_pmin.y + 1
	local zmin = old_pmin.z + 1
	local xmax = old_pmax.x - 1
	local ymax = old_pmax.y - 1
	local zmax = old_pmax.z - 1
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
		if p.x > xmax then xmax = p.x end
		if p.x < xmin then xmin = p.x end
		if p.y > ymax then ymax = p.y end
		if p.y < ymin then ymin = p.y end
		if p.z > zmax then zmax = p.z end
		if p.z < zmin then zmin = p.z end
	end
	--start compiling the absolute position and index offsets that represent neighbors and growth
	local neighborhood= {}
	local growth_offset = {x=0,y=0,z=0} --again this default is for 3D @TODO should skip the application of offset lower down
	-- determine neighborhood and growth offsets (works for 1D and 2D)
	if rules.neighbors == 2 or rules.neighbors == 4 or rules.neighbors == 8 then
		if rules.grow_axis == "x" then
			growth_offset = {x = rules.grow_distance, y=0, z=0}
		elseif rules.grow_axis == "z" then
			growth_offset = {x=0, y=0, z = -rules.grow_distance} --why this has to be negative?
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
    if rules.tree then --tree stuff
        --in tree mode everything survives by default
	    for old_pos_vi, pos in next, old_indexes do		
		    local survival = true
		    --we need to convert the old index to the new index regardless of survival/death
		    local new_pos_vi
		    if same_extent then
			    new_pos_vi = old_pos_vi
		    else	
			    new_pos_vi = new_area:indexp(pos)
		    end	
		    
		    --CELL SURVIVAL TESTING
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
		    local north = neighborhood_vis.n + old_pos_vi
            local south = neighborhood_vis.s + old_pos_vi
            local east = neighborhood_vis.e + old_pos_vi
            local west = neighborhood_vis.w + old_pos_vi
            local top = neighborhood_vis.t + old_pos_vi
            local bottom = neighborhood_vis.b + old_pos_vi
            local northeast = neighborhood_vis.ne + old_pos_vi
            local southeast = neighborhood_vis.se + old_pos_vi
            local southwest = neighborhood_vis.sw + old_pos_vi
            local northwest = neighborhood_vis.nw + old_pos_vi
            local bottomnorth = neighborhood_vis.bn + old_pos_vi
            local bottomeast = neighborhood_vis.be + old_pos_vi
            local bottomsouth = neighborhood_vis.bs + old_pos_vi
            local bottomwest = neighborhood_vis.bw + old_pos_vi
            local topnorth = neighborhood_vis.tn + old_pos_vi
            local topeast = neighborhood_vis.te + old_pos_vi
            local topsouth = neighborhood_vis.ts + old_pos_vi
            local topwest = neighborhood_vis.tw + old_pos_vi
            --the following survival rules eliminate stair-stepping 
            if old_indexes[northwest] and old_indexes[southeast] and old_indexes[northeast] and old_indexes[east]
            and old_indexes[north] and same_count == 5 then
                survival = false
            end
            if old_indexes[northeast] and old_indexes[southwest] and old_indexes[southeast] and old_indexes[south]
            and old_indexes[east] and same_count == 5 then
                survival = false
            end
            if old_indexes[south] and old_indexes[west] and old_indexes[southwest] and old_indexes[southeast] 
            and old_indexes[northwest] and same_count == 5 then
                survival = false
            end
            if old_indexes[west] and old_indexes[north] and old_indexes[northwest] and old_indexes[northeast]
            and old_indexes[southwest] and same_count == 5 then
                survival = false
            end
            if old_indexes[topnorth] and old_indexes[north] and old_indexes[bottom] and old_indexes[bottomnorth]
            and old_indexes[bottomsouth] and same_count == 5 then
                survival = false
            end
            if old_indexes[topeast] and old_indexes[east] and old_indexes[bottomeast] and old_indexes[bottom]
            and old_indexes[bottomwest] and same_count == 5 then
                survival = false
            end
            if old_indexes[topsouth] and old_indexes[south] and old_indexes[bottomsouth] and old_indexes[bottom]
            and old_indexes[bottomnorth] and same_count == 5 then
                survival = false
            end
            if old_indexes[topwest] and old_indexes[west] and old_indexes[bottomwest] and old_indexes[bottom]   
            and old_indexes[bottomeast] and same_count == 5 then
                survival = false
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
				    if is_final then
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
        --BIRTH testing for trees
        -- tests all empty_neighbors against remaining rules.birth or code1d[2,5,6]
	    for epos_vi, epos in next, empty_neighbors do
		    local birth = false
		    local leaves = false
		    --CELL BIRTH TESTING:
		    
		    local same_count = 0
            --print(dump(neighborhood_vis))
		    for k, vi_offset in next, neighborhood_vis do
			    --add the offsets to the position
			    local n_vi = epos_vi + vi_offset
			    --test for sameness
			    if old_indexes[n_vi] then
				    same_count = same_count + 1
			    end
		    end
            local chance = math.random()
            local bottom = neighborhood_vis.b + epos_vi
            local top = neighborhood_vis.t + epos_vi
            local north = neighborhood_vis.n + epos_vi
            local east = neighborhood_vis.e + epos_vi
            local south = neighborhood_vis.s + epos_vi
            local west = neighborhood_vis.w + epos_vi
            --if this block is on the top face of another block then it has a chance of growing if above the base.y
            if old_indexes[bottom] and same_count == 1 and chance < rules.up_branch_chance and epos.y > base.y then
                birth = true
			elseif old_indexes[bottom] and chance < rules.up_bud_chance then
                birth = true
            end
            if old_indexes[north] and same_count == 1 and ( epos.y - base.y > rules.side_branch_height or epos.y < base.y - rules.down_branch_height )
            and chance < rules.side_branch_chance then
                birth = true
			elseif old_indexes[north] and iteration > rules.bud_iter_delay and chance < rules.side_bud_chance then    
            birth = true
            end
            if old_indexes[south] and same_count == 1 and ( epos.y - base.y > rules.side_branch_height or epos.y < base.y - rules.down_branch_height )
            and chance < rules.side_branch_chance then
                birth = true
            elseif old_indexes[south] and iteration > rules.bud_iter_delay and chance < rules.side_bud_chance then
                birth = true
			end
            if old_indexes[east] and same_count == 1 and ( epos.y - base.y > rules.side_branch_height or epos.y < base.y - rules.down_branch_height )
            and chance < rules.side_branch_chance then
                birth = true
            elseif old_indexes[east] and iteration > rules.bud_iter_delay and chance < rules.side_bud_chance then
                birth = true
			end
            if old_indexes[west] and same_count == 1 and ( epos.y - base.y > rules.side_branch_height or epos.y < base.y - rules.down_branch_height )
            and chance < rules.side_branch_chance then
                birth = true
            elseif old_indexes[west] and iteration > rules.bud_iter_delay and chance < rules.side_bud_chance then
                birth = true
			end
            --down branching occurs below the base
            if old_indexes[top] and same_count == 1 and epos.y < base.y
            and chance < rules.down_branch_chance then
                birth = true
            elseif old_indexes[top] and chance < rules.down_bud_chance then
                birth = true
            end
            --leaves
            if birth == false and epos.y - base.y > rules.leaf_height and chance < rules.leaf_chance then
               leaves = true
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
            if leaves then
                --only if leaves happens convert old_index to new_index
			    local new_epos_vi
			    if same_extent then
				    new_epos_vi = epos_vi
			    else
				    new_epos_vi = new_area:indexp(epos)
			    end
			    --add to birth list
			    local lpos_vi = new_epos_vi + growth_vi
			    local lpos = {x=epos.x+growth_offset.x, y=epos.y+growth_offset.y, z=epos.z+growth_offset.z}
			    leaves_list[lpos_vi] = lpos --when node is actually set we will add to new_indexes

            end
	    end
    else --non-tree stuff
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
				    if is_final then
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
    end
	--apply deaths to data[]
    local death_count = 0
	for dpos_vi, dpos in next, death_list do
		death_count = death_count + 1
        data[dpos_vi] = c_trail
	end
	--apply births to data[]
    local birth_count = 0
	for bpos_vi, bpos in next, birth_list do
		--test for destructive mode and if the node is occupied
		if rules.destruct == "true" or data[bpos_vi] == c_air or data[bpos_vi] == c_leaves or data[bpos_vi] == c_apple then
			birth_count = birth_count + 1
			--test for final iteration
			if is_final then data[bpos_vi] = c_final
			else data[bpos_vi] = c_automata
			end
			--add to new_indexes even if final so that we can resume
			add_to_new_cell_list(bpos_vi, bpos)
		else
			data[bpos_vi] = c_final
		end
	end
    --set leaves
    for lpos_vi, bpos in next, leaves_list do
		--test for destructive mode and if the node is occupied
		if rules.destruct == "true" or data[lpos_vi] == c_air then
			if math.random() < rules.fruit_chance then
                data[lpos_vi] = c_apple
            else
                data[lpos_vi] = c_leaves
            end
	    end
	end
	for k,v in pairs(new_indexes) do
		if is_final then
			data[k] = c_final
		else
			data[k] = c_automata
		end
	end
	-- if DEBUG and 3D pattern and not a tree then test for asymmetry
	if DEBUG and ( rules.neighbors == 6 or rules.neighbors == 18 or rules.neighbors == 26 ) and not rules.tree then
		local bad_blocks = automata.check_symmetry(new_indexes, base)
		local colors = {"wool:yellow","wool:orange","wool:red"}
		if next(bad_blocks) ~= nil then
			minetest.chat_send_player(pname, "Your pattern, #"..pattern_id.." became asymmetrical at gen "..iteration)
			for k, v in pairs(bad_blocks) do
				data[k] = minetest.get_content_id(colors[v.badness])
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map()
	vm:update_map()
    --SOUND!
    if automata.sound_handler then
		minetest.sound_stop(automata.sound_handler)
    end
    local sound = rules.sound
    if sound == "piano" or sound == "bass" then
		automata.sound_handler = minetest.sound_play({name = sound})
    else
		local pitch1 = cell_count % 12
		-- got this number from https://music.stackexchange.com/questions/49803/how-to-reference-or-calculate-the-percentage-pitch-change-between-two-notes
		pitch1 = ( 1.0594630943592952645618252949463 ^ pitch1 ) / 2 -- divide by two to get an octave lower?
		if birth_count > 0 then
			automata.sound_handler = minetest.sound_play({name = sound},{pitch = pitch1})
		end
	end
	--update pattern values
	local timer = (os.clock() - t1) * 1000
	local values =  { pmin = {x=xmin,y=ymin,z=zmin}, pmax = {x=xmax,y=ymax,z=zmax}, 
				      cell_count = cell_count, emin = new_emin, emax = new_emax, base=base,
					  indexes = new_indexes, l_timer = timer, iteration = iteration,
					  t_timer = automata.patterns[pattern_id].t_timer + timer, sequence = sequence,
					  rules = rules, creator = pname
				    }
	automata.patterns[pattern_id] = values
	if is_final then
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
			local ppos = player:get_pos()
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
		--sequences
		local use_sequence = automata.get_player_setting(pname, "use_sequence")
		local sequence = {}
		if use_sequence and use_sequence ~= "none" and not rules.tree then
			rules.use_sequence = true
			for i=1, 12 do
				local setting = automata.get_player_setting(pname, "seq"..use_sequence.."slot"..i)
				if setting then
					table.insert(sequence, setting)
				end
			end
			--print(dump(sequence))
		else
			rules.use_sequence = false
		end
        local base = pmin --used by tree logic and sound
		local timer = (os.clock() - t1) * 1000
		--add the cell list to the active cell registry with the gens, rules hash, and cell list
		local values = { creator=pname, status="active", iteration=0, rules=rules, base=base, 
						 cell_count = cell_count, cell_list=hashed_cells, pmin=pmin, pmax=pmax,
						 sequence = sequence, emin=emin, emax=emax, t_timer=timer, indexes = new_indexes }
		automata.patterns[pattern_id] = values --overwrite placeholder
		automata.grow_queue[pattern_id] = { lock = false, size = cell_count,
											last_grow=os.clock(), creator = pname }
		return true
	else 
		return false 
	end
end
function automata.get_valid_blocks()
	local list = {}
	list[0] = ""
	list[minetest.get_content_id("default:glass")] = "default:glass"
	list[minetest.get_content_id("default:cactus")] = "default:cactus"
	for name, def in pairs(minetest.registered_nodes) do
        if def.drawtype == "normal" and string.sub(name, 1, 9) ~= "automata:" then
			list[minetest.get_content_id(name)] = name
		end
	end
	--print(dump(list))
	return list
end
-- called when new pattern is created
function automata.rules_validate(pname, rule_override)
	local rules = {}
	--read the player settings to get the last tab and then validate the fields relevant for that tab
	local tab = automata.get_player_setting(pname, "tab")
	--regardless we validate the growth options common to 1D, 2D and 3D automata
	--gens
	local gens = automata.get_player_setting(pname, "gens")
	if gens == "" then rules.gens = 30
	elseif tonumber(gens) and tonumber(gens) > 0 and tonumber(gens) < 1001 
	and tonumber(gens) == math.floor(tonumber(gens)) then rules.gens = tonumber(gens)
	else automata.show_popup(pname, "Generations must be an integer between 1 and 1000-- you said: "..gens) return false end
	--delay
	local delay = automata.get_player_setting(pname, "delay")
	if delay == "" then rules.delay = 0
	elseif tonumber(delay) and tonumber(delay) >= 0 and tonumber(delay) < 10001 
	and tonumber(delay) == math.floor(tonumber(delay)) then rules.delay = tonumber(delay)
	else automata.show_popup(pname, "Delay must be an integer between 0 and 10000-- you said: "..delay) return false end
	--trail
	local trail = automata.get_player_setting(pname, "trail")
    if not trail then rules.trail = "air" 
    else rules.trail = trail end
	--final
	local final = automata.get_player_setting(pname, "final")
	if not final then rules.final = ""
	else rules.final = final end
	--destructive
	local destruct = automata.get_player_setting(pname, "destruct")
	if not destruct then rules.destruct = "false" 
	else rules.destruct = destruct end
	local sound = automata.get_player_setting(pname, "sound")
	if not sound then rules.sound = "darkboom"
	else rules.sound = sound end
	--then validate fields common to 1D and 2D and importing 2D .LIF files (tab 4)
	if tab == "1" or tab == "2" or tab == "4" then
		--grow_distance
		local grow_distance = automata.get_player_setting(pname, "grow_distance")
		if not grow_distance then rules.grow_distance = 1
		elseif tonumber(grow_distance) and tonumber(grow_distance) >= -100 and tonumber(grow_distance) <= 100 
		and tonumber(grow_distance) == math.floor(tonumber(grow_distance)) then
			rules.grow_distance = tonumber(grow_distance)
		else automata.show_popup(pname, "Grow Distance needs to be an integer between -100 and 100\n-- you said: "..grow_distance) return false end
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
			if not code2d then code2d = "1234/14" end
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
		if not code3d then code3d = "1,2,3,4/1,4" end 
		rules.survive, rules.birth = automata.code3d_to_sb(code3d)
	elseif tab == "5" then --tree mode
        rules.neighbors = 26
        rules.birth = {}
        rules.survive = {}
        rules.tree = true
        rules.trail = "air"
        local up_bud_chance = automata.get_player_setting(pname, "up_bud_chance")
        if not up_bud_chance then rules.up_bud_chance = 0.08
	    elseif tonumber(up_bud_chance) >= 0 and tonumber(up_bud_chance) <= 1 then rules.up_bud_chance = tonumber(up_bud_chance)
	    else automata.show_popup(pname, "Up bud chance must be between 0 and 1 -- you said: "..up_bud_chance) return false end
        local up_branch_chance = automata.get_player_setting(pname, "up_branch_chance")
        if not up_branch_chance then rules.up_branch_chance = 0.5
	    elseif tonumber(up_branch_chance) >= 0 and tonumber(up_branch_chance) <= 1 then rules.up_branch_chance = tonumber(up_branch_chance)
	    else automata.show_popup(pname, "Up branch chance must be between 0 and 1 -- you said: "..up_branch_chance) return false end
        local side_bud_chance = automata.get_player_setting(pname, "side_bud_chance")
        if not side_bud_chance then rules.side_bud_chance = 0.01
	    elseif tonumber(side_bud_chance) >= 0 and tonumber(side_bud_chance) <= 1 then rules.side_bud_chance = tonumber(side_bud_chance)
	    else automata.show_popup(pname, "Side bud chance must be between 0 and 1 -- you said: "..side_bud_chance) return false end
        local side_branch_chance = automata.get_player_setting(pname, "side_branch_chance")
        if not side_branch_chance then rules.side_branch_chance = 0.5
	    elseif tonumber(side_branch_chance) >= 0 and tonumber(side_branch_chance) <= 1 then rules.side_branch_chance = tonumber(side_branch_chance)
	    else automata.show_popup(pname, "Side branch chance must be between 0 and 1 -- you said: "..side_branch_chance) return false end
        local down_bud_chance = automata.get_player_setting(pname, "down_bud_chance")
        if not down_bud_chance then rules.down_bud_chance = 0.01
	    elseif tonumber(down_bud_chance) >= 0 and tonumber(down_bud_chance) <= 1 then rules.down_bud_chance = tonumber(down_bud_chance)
	    else automata.show_popup(pname, "Down bud chance must be between 0 and 1 -- you said: "..down_bud_chance) return false end
        local down_branch_chance = automata.get_player_setting(pname, "down_branch_chance")
        if not down_branch_chance then rules.down_branch_chance = 0.5
	    elseif tonumber(down_branch_chance) >= 0 and tonumber(down_branch_chance) <= 1 then rules.down_branch_chance = tonumber(down_branch_chance)
	    else automata.show_popup(pname, "Down branch chance must be between 0 and 1 -- you said: "..down_branch_chance) return false end
        local bud_iter_delay = automata.get_player_setting(pname, "bud_iter_delay")
        if not bud_iter_delay then rules.bud_iter_delay = 15
	    elseif tonumber(bud_iter_delay) > 0 and tonumber(bud_iter_delay) < 1001 then rules.bud_iter_delay = tonumber(bud_iter_delay)
	    else automata.show_popup(pname, "Bud iteration delay must be between 1 and 1000 -- you said: "..bud_iter_delay) return false end
        local side_branch_height = automata.get_player_setting(pname, "side_branch_height")
        if not side_branch_height then rules.side_branch_height = 15
	    elseif tonumber(side_branch_height) > 0 and tonumber(side_branch_height) < 1001 then rules.side_branch_height = tonumber(side_branch_height)
	    else automata.show_popup(pname, "Side branch height must be between 1 and 1000 -- you said: "..side_branch_height) return false end
        local down_branch_height = automata.get_player_setting(pname, "down_branch_height")
        if not down_branch_height then rules.down_branch_height = 15
	    elseif tonumber(down_branch_height) > 0 and tonumber(down_branch_height) < 1001 then rules.down_branch_height = tonumber(down_branch_height)
	    else automata.show_popup(pname, "Root depth must be between 1 and 1000 -- you said: "..down_branch_height) return false end
        local leaf_height = automata.get_player_setting(pname, "leaf_height")
        if not leaf_height then rules.leaf_height = 14
	    elseif tonumber(leaf_height) > 0 and tonumber(leaf_height) < 1001 then rules.leaf_height = tonumber(leaf_height)
	    else automata.show_popup(pname, "Leaf height must be between 1 and 1000 -- you said: "..leaf_height) return false end
        local leaf_chance = automata.get_player_setting(pname, "leaf_chance")
        if not leaf_chance then rules.leaf_chance = 0.1
	    elseif tonumber(leaf_chance) >= 0 and tonumber(leaf_chance) <= 1 then rules.leaf_chance = tonumber(leaf_chance)
	    else automata.show_popup(pname, "Leaf chance must be between 0 and 1 -- you said: "..leaf_chance) return false end
        local fruit_chance = automata.get_player_setting(pname, "fruit_chance")
        if not fruit_chance then rules.fruit_chance = 0.3
	    elseif tonumber(fruit_chance) >= 0 and tonumber(fruit_chance) <= 1 then rules.fruit_chance = tonumber(fruit_chance)
	    else automata.show_popup(pname, "Fruit chance must be between 0 and 1 -- you said: "..fruit_chance) return false end
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
-- for converting code2d and code3d inputs to tables
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
function automata.code3d_to_sb(code3d)
	local survival, birth
	local split = string.find(code3d, "/")
	if split then
		-- take the values to the left and the values to the right
		survival = string.sub(code3d, 1, split-1)
		birth = string.sub(code3d, split+1)
	else
		--assume all rules are survival if no split
		survival = code3d
		birth = ""
	end
	survival = automata.explode(survival, ",")
	birth = automata.explode(birth, ",")
	return survival, birth
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
			if not string.find(k, "cid") then --this is so we don't record image item selections as settings
				automata.player_settings[pname][k] = v --we will preserve field entries exactly as entered 
			end
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
		--item image selection form
		if formname == "automata:image_items" then
			if fields.exit == "Cancel" then
				automata.show_rc_form(pname)
				return true
			else
				local list = automata.get_valid_blocks()
				for k,_ in pairs(fields) do
					if string.sub(k, 1, 5) == "trail" then
						local cid = tonumber(string.sub(k, 9, string.len(k)))
						automata.player_settings[pname].trail = list[cid]
						automata.show_rc_form(pname)
						return true
					end
					if string.sub(k, 1, 5) == "final" then
						local cid = tonumber(string.sub(k, 9, string.len(k)))
						automata.player_settings[pname].final = list[cid]
						automata.show_rc_form(pname)
						return true
					end
					if string.sub(k,1,3) == "seq" then
						local cid = tonumber(string.sub(k, (string.find(k,"cid")+3), string.len(k)))
						--print(string.sub(k,1,(string.find(k,"cid")-1)))
						--print(cid)
						automata.player_settings[pname][string.sub(k,1,(string.find(k,"cid")-1))] = list[cid]
						--print(dump(automata.player_settings))
						automata.show_rc_form(pname)
					end
				end
			end
			return true
		end
		--the main form
		if formname == "automata:rc_form" then
			-- if any tab but 6 selected unlist the player as having tab6 open
			if fields.quit or ( fields.tab ~= "6" and not fields.pid_id ) then 
				if fields.exit == "Resume" or fields.exit == "Add Gens" 
				or fields.pause or fields.finish or fields.delete or fields.purge then
					--do nothing
				else
					automata.open_tab6[pname] = nil
				end
			end 
			--detect tab change	
			if old_tab and old_tab ~= automata.get_player_setting(pname, "tab") then
				automata.show_rc_form(pname)
				return true
			end
			if fields.trail then
				local blocks = automata.get_valid_blocks()
				automata.show_item_images(pname, blocks, "trail")
			end
			if fields.final then
				local blocks = automata.get_valid_blocks()
				automata.show_item_images(pname, blocks, "final")
			end
			--if a lif was clicked show the popup form summary
			if fields.lif_id and string.sub(fields.lif_id, 1, 4) == "DCL:" then
				automata.show_lif_summary(pname)
			end
			--manage tab stuff
			if fields.pause or fields.exit == "Resume" or fields.finish or fields.delete
			or fields.exit == "Add Gens" then
				local pid_id = tonumber(string.sub(automata.get_player_setting(pname, "pid_id"), 5,
											#automata.get_player_setting(pname, "pid_id")))
				local pattern_id = automata.open_tab6[pname][tonumber(pid_id)]
				if not pattern_id then return false end
				if fields.pause == "Pause" then
					if automata.patterns[pattern_id].status == "active" then	
						automata.grow_queue[pattern_id] = nil
						automata.patterns[pattern_id].status = "paused"
						
						automata.show_rc_form(pname)
						return true
					else
						automata.show_popup(pname, "You can only pause an active pattern")
					end
				end
				if fields.exit == "Resume" then 
					if automata.patterns[pattern_id].status == "paused" then
						automata.patterns[pattern_id].status = "active"
						automata.grow_queue[pattern_id] = { lock = false, last_grow=os.clock(), creator = pname,
															size = automata.patterns[pattern_id].cell_count }
						automata.open_tab6[pname] = nil
						return true
					else
						automata.show_popup(pname, "You can only resume a paused pattern")
					end
				end
				if fields.finish == "Finish" then
					if automata.patterns[pattern_id].status == "active"
					or automata.patterns[pattern_id].status == "paused" then
						automata.patterns[pattern_id].rules.gens = automata.patterns[pattern_id].iteration
						automata.patterns[pattern_id].status = "finished"
						automata.grow_queue[pattern_id] = nil
						local vm = minetest.get_voxel_manip()
						vm:read_from_map(automata.patterns[pattern_id].pmin, automata.patterns[pattern_id].pmax)
						local data = vm:get_data()
						local active = minetest.get_content_id("automata:active")
						local air = minetest.get_content_id("air")
						for index, cid in pairs(data) do
							if cid == active then
								data[index] = air
							end
						end
						vm:set_data(data)
						vm:write_to_map()
						vm:update_map()
						automata.show_rc_form(pname)
						return true
					else
						automata.show_popup(pname, "You can only finish an active or paused pattern")
					end
				end
				if fields.delete == "Delete" then
					if automata.patterns[pattern_id].status == "finished"
					or automata.patterns[pattern_id].status == "extinct" then
						automata.patterns[pattern_id] = nil
						automata.grow_queue[pattern_id] = nil
						automata.show_rc_form(pname)
						return true
					else
						automata.show_popup(pname, "You can only delete a finished or extinct pattern")
					end
				end
				if fields.exit == "Add Gens" then
					if automata.patterns[pattern_id].status == "finished" then
						local add_gens = tonumber(fields.add_gens)
						add_gens = math.floor(add_gens)
						if add_gens then
							add_gens = math.floor(add_gens)
							automata.player_settings[pname][add_gens] = add_gens
							automata.patterns[pattern_id].rules.gens = automata.patterns[pattern_id].rules.gens + add_gens
							automata.grow_queue[pattern_id] = { lock = false, last_grow=os.clock(), creator = pname,
																size = automata.patterns[pattern_id].cell_count }
							automata.open_tab6[pname] = nil
						else
							automata.show_popup(pname, "Add gens field must be a number")
						end
					else
						automata.show_popup(pname, "You can only add gens to a finished pattern")
					end
				end
			end
			if fields.purge == "Purge Finished" then
				for pattern_id, values in pairs(automata.patterns) do
					if values.creator == pname and ( values.status == "finished" or values.status == "extinct" ) then
						automata.patterns[pattern_id] = nil
						automata.grow_queue[pattern_id] = nil
					end
				end
				automata.show_rc_form(pname)
				return true
			end
			--sequences
			local list = automata.get_valid_blocks()
			for k,_ in pairs(fields) do
				if string.sub(k, 1, 3) == "seq" then
					local i = string.sub(k,4,(string.find(k,"slot")-1))
					local j = string.sub(k,(string.find(k,"slot")+4), string.len(k))
					automata.show_item_images(pname, list, "seq"..i.."slot"..j)
					return true
				end
			end
			if fields.use_sequence then
				automata.player_settings[pname].use_sequence = fields.use_sequence
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
automata.open_tab6 = {} --who has tab 6 (Manage) open at any moment
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
function automata.show_item_images(pname, items, setting)
	local f_images = ""
	local i = 0.75
	local j = 0.75
	for cid, item in pairs(items) do
		f_images = f_images .. 	"item_image_button["..i..","..j..";0.75,0.75;"..
								item..";"..setting.."cid"..cid..";]"
		if i < 12.5 then
			i = i + 0.75
		else
			i = 0.75
			j = j + 0.75
		end
	end
	local f_body = "size[14,10]" ..
					"button_exit[12,0;2,1;exit;Cancel]"
	--print(f_images)	
	minetest.show_formspec(pname,   "automata:image_items",
                                    f_body..f_images
	)
	return true
end
function automata.get_sequences(pname)
	local list = {}
	for j=1,12 do
		list[j] = {}
		for i=1,12 do
			local slot_value = automata.get_player_setting(pname, "seq"..j.."slot"..i)
			if not slot_value then slot_value = "" end
			list[j][i] = slot_value
		end
	end
	--print(dump(list))
	return list
end
-- show the main remote control form
function automata.show_rc_form(pname)
    local player = minetest.get_player_by_name(pname)
	local ppos = player:get_pos()
	local degree = 180-math.deg(player:get_look_horizontal())
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
	--handle open tab6, system needs to know who has tab6 open at any moment so that
	-- it can be refreshed by globalstep activity...
	if tab == "6" then automata.open_tab6[pname] = {} end --gets reset to nil in on_player_receive_fields()
	--load the default fields for the forms based on player's last settings
	--gens
	local gens = automata.get_player_setting(pname, "gens")
	if not gens then gens = "30" end
	--delay
	local delay = automata.get_player_setting(pname, "delay")
	if not delay then delay = "0" end
	--trail
	local trail = automata.get_player_setting(pname, "trail")
	if not trail then trail = "" end
	--final
	local final = automata.get_player_setting(pname, "final")
	if not final then final = "" end
	--destructive
	local destruct = automata.get_player_setting(pname, "destruct")
	if not destruct then destruct = "false" end
	local sound_id
	local sound = automata.get_player_setting(pname, "sound")
	if not sound then sound_id = 2
	else 
		local idx = {gong=1,darkboom=2,bowls=3,warblast=4,crystal=5,piano=6,bass=7,autechre=8,oizo=9}
		sound_id = idx[sound]
	end
	--set some formspec sections for re-use on all tabs
	local f_header = 			"size[12,10]" ..
								"tabheader[0,0;tab;1D, 2D, 3D, Import, Tree, Manage, Sequences;"..tab.."]"
	--1D, 2D, 3D, Import, Tree
	local f_grow_settings = 	"label[0,0;You are at x= "..math.floor(ppos.x)..
								" y= "..math.floor(ppos.y).." z= "..math.floor(ppos.z).." and mostly facing "..dir.."]" ..
								"label[1,5.5; Final Block]"..
								"item_image_button[3,5.5;0.8,0.8;"..final..";final;]" ..
								"checkbox[0.7,7.5;destruct;Destructive?;"..destruct.."]"..
								"field[1,7;2,1;gens;Generations;"..minetest.formspec_escape(gens).."]" ..
								"field[3,7;2,1;delay;Delay (ms);"..minetest.formspec_escape(delay).."]" ..
								"label[8,7.4; Sound]"..
								"dropdown[8,7.8;4,1;sound;gong,darkboom,bowls,warblast,crystal,piano,bass,autechre,oizo;"..sound_id.."]"
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
	-- add trailt o tabs 1 - 4 but not tree
	if tab == "1" or tab == "2" or tab == "3" or tab == "4" then
		local f_trail = "label[1,4.7; Trail Block]"
		local use_sequence = automata.get_player_setting(pname, "use_sequence")
		if use_sequence and use_sequence ~= "none" then
			f_trail = f_trail .. 	"label[3,4.7; Using Sequence # ".. 
									automata.get_player_setting(pname, "use_sequence") .. "]"
		else
			f_trail = f_trail ..	"item_image_button[3,4.7;0.8,0.8;"..trail..";trail;]" 
		end
		f_grow_settings = f_grow_settings ..f_trail
	end
	--then populate defaults common to 1D and 2D (and importing)
	if tab == "1" or tab == "2" or tab == "4" then
		--grow_distance
		local grow_distance = automata.get_player_setting(pname, "grow_distance")
		if not grow_distance then grow_distance = "1" end
		--grow_axis (for 2D implies the calculation plane, for 1D cannot be the same as "axis")
		local grow_axis_id
		local grow_axis = automata.get_player_setting(pname, "grow_axis")
		if not grow_axis then grow_axis_id = 2
		else 
			local idx = {x=1,y=2,z=3}
			grow_axis_id = idx[grow_axis]
		end
		local f_grow_distance = "field[1,4;2,1;grow_distance;Grow Distance;"..minetest.formspec_escape(grow_distance).."]"
		local f_grow_axis = 	"label[1,2.5; Growth Axis]"..
								"dropdown[3,2.5;1,1;grow_axis;x,y,z;"..grow_axis_id.."]"
		--fields specific to 1D
		if tab == "1"  then
			--code1d (must be between 1 and 256 -- NKS rule numbers for 1D automata)
			local code1d = automata.get_player_setting(pname, "code1d")
			if not code1d then code1d = "30" end
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
			if not code2d then code2d = "1234/14" end
			local s, b, nks = automata.code2d_to_sb_and_nks(code2d)
			local f_n2d = 				"label[1,0.5;Neighbors]"..
										"dropdown[3,0.5;1,1;n2d;4,8;"..n2d_id.."]"
			local f_code2d = 			"field[6,1;6,1;code2d;Rules (eg: survival/birth);"..
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
		if not code3d then code3d = "1,2,3,4/1,4" end
		local f_n3d = 		"label[1,0.5;Neighbors]"..
							"dropdown[3,0.5;1,1;n3d;6,18,26;"..n3d_id.."]"
		local f_code3d = 	"field[6,1;6,1;code3d;Rules (eg: survival/birth);"..minetest.formspec_escape(code3d).."]"
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..
								f_grow_settings ..
								f_n3d .. f_code3d ..
								f_footer
		)
		return true
	end
	if tab == "5" then --tree mode
        local up_bud_chance = automata.get_player_setting(pname, "up_bud_chance") or "0.08"
        local up_branch_chance = automata.get_player_setting(pname, "up_branch_chance") or "0.5"
        local side_bud_chance = automata.get_player_setting(pname, "side_bud_chance") or "0.01"
        local side_branch_chance = automata.get_player_setting(pname, "side_branch_chance") or "0.5"
        local down_bud_chance = automata.get_player_setting(pname, "down_bud_chance") or "0.01"
        local down_branch_chance = automata.get_player_setting(pname, "down_branch_chance") or "0.5"
        local bud_iter_delay = automata.get_player_setting(pname, "bud_iter_delay") or "15"
        local side_branch_height = automata.get_player_setting(pname, "side_branch_height") or "15"
        local down_branch_height = automata.get_player_setting(pname, "down_branch_height") or "15"
        local leaf_height = automata.get_player_setting(pname, "leaf_height") or "14"
        local leaf_chance = automata.get_player_setting(pname, "leaf_chance") or "0.1"
        local fruit_chance = automata.get_player_setting(pname, "fruit_chance") or "0.3"

        local f_tree_settings = "field[6,1;2,1;up_bud_chance;Up bud;"..minetest.formspec_escape(up_bud_chance).."]" ..
                                "field[8,1;2,1;up branch_chance;Up branch;"..minetest.formspec_escape(up_branch_chance).."]" ..
                                "field[6,2;2,1;side_bud_chance;Side bud;"..minetest.formspec_escape(side_bud_chance).."]" ..
                                "field[8,2;2,1;side_branch_chance;Side branch;"..minetest.formspec_escape(side_branch_chance).."]" ..
                                "field[6,3;2,1;down_bud_chance;Down bud;"..minetest.formspec_escape(down_bud_chance).."]" ..
                                "field[8,3;2,1;down_branch_chance;Down branch;"..minetest.formspec_escape(down_branch_chance).."]" ..
                                "field[6,4;2,1;bud_iter_delay;Bud delay;"..minetest.formspec_escape(bud_iter_delay).."]" ..
                                "field[8,4;2,1;side_branch_height;Branch height;"..minetest.formspec_escape(side_branch_height).."]" ..
                                "field[6,5;2,1;down_branch_height;Root depth;"..minetest.formspec_escape(down_branch_height).."]" ..
                                "field[8,5;2,1;leaf_height;Leaf height;"..minetest.formspec_escape(leaf_height).."]" ..
                                "field[6,6;2,1;leaf_chance;Leaf chance;"..minetest.formspec_escape(leaf_chance).."]" ..
                                "field[8,6;2,1;fruit_chance;Fruit chance;"..minetest.formspec_escape(fruit_chance).."]"

        minetest.show_formspec(pname, "automata:rc_form", 
                                    f_header .. 
                                    f_grow_settings ..
                                    f_tree_settings ..
                                    f_footer
        )
    end
    if tab == "6" then --manage patterns
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
							..pmin.x.."."..pmin.y.."."..pmin.z.." max:"..pmax.x.."."..pmax.y.."."..pmax.z )
				automata.open_tab6[pname][i]=k --need this table to decode the form's pid_ids back to pattern_ids
			end
		end
		local pid_id = automata.get_player_setting(pname, "pid_id")
		if not pid_id then pid_id = 1 end
		local f_plist
		local add_gens = automata.get_player_setting(pname, "add_gens")
		if not add_gens then add_gens = 1 end
		local pid_id = automata.get_player_setting(pname, "pid_id")
		if not pid_id then
			pid_id = 1
		else
			pid_id = tonumber(string.sub(pid_id, 5, #pid_id))
		end
		if patterns == "" then f_plist = "label[1,1;no patterns]"
		else f_plist = 	"button[1,0;2,1;pause;Pause]"..
						"button_exit[3,0;2,1;exit;Resume]"..
						"button[5,0;2,1;finish;Finish]"..
						"button[7,0;2,1;delete;Delete]"..
						"button_exit[9,0;2,1;exit;Add Gens]"..
						"field[9.3,1;2,1;add_gens;;"..minetest.formspec_escape(add_gens).."]"..
						"label[1,1;Your patterns]"..
						"textlist[1,1.5;10,8;pid_id;"..patterns..";"..pid_id.."]"..
						"button[8.5,9.5;3,1;purge;Purge Finished]"
		end
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header ..	f_plist					
		)
		return true
	end
	--sequences
	if tab == "7" then
		local id = automata.get_player_setting(pname, "use_sequence")
		local seq_id
		if not id then id = 1
		else 
			local idx = {}; idx["none"]=1; idx["1"]=2; idx["2"]=3; idx["3"]=4; idx["4"]=5
							idx["5"]=6; idx["6"]=7; idx["7"]=8; idx["8"]=9
							idx["9"]=10; idx["10"]=11; idx["11"]=12; idx["12"]=13
			id = idx[id]
		end
		local f_seq_settings = 	"label[0,0;Use Sequence]" ..
								"dropdown[2,0;2,1;use_sequence;none,1,2,3,4,5,6,7,8,9,10,11,12;"..id.."]"
		local f_slist = ""
		local i = 1
		local j = 1
		local sequences = automata.get_sequences(pname)
		--print(dump(sequences))
		for seqnum, sequence in pairs(sequences) do
			for slotnum, slot_value in pairs(sequence) do
				f_slist = f_slist 	.. "label[0,"..(j*0.75)..";"..j.."]"
									.. "item_image_button["..(i*0.75)..","..(j*0.75)..";0.75,0.75;"
									..slot_value..";seq"..j.."slot"..i..";]"
				if i < 12 then
					i = i + 1
				else
					i = 1
				end
			end
			if j < 12 then
				j = j + 1
			else
				j = 1
			end
		end
		--print(dump(f_slist))
		minetest.show_formspec(pname, "automata:rc_form", 
								f_header .. f_seq_settings .. f_slist					
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
