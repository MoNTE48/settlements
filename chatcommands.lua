-- internationalization boilerplate
local modpath = minetest.get_modpath(minetest.get_current_modname())
local S, NS = dofile(modpath.."/intllib.lua")

local visual_range = tonumber(minetest.settings:get("settlements_visibility_range")) or 600

minetest.register_chatcommand("settlements_list", {
	description = S("List the settlements you know about"),
	privs = {["server"]=true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local player_pos = player:get_pos()
		
		local settlement_list = settlements.settlements_in_world:get_areas_in_area(
			{x=-32000, y=-32000, z=-32000}, {x=32000, y=32000, z=32000}, true, true, true)
		
		for _, settlement in pairs(settlement_list) do
			local data = minetest.deserialize(settlement.data)
			if data.discovered_by[name] then
				local pos = settlement.min
				local distance = math.floor(vector.distance(player_pos, pos))
				local settlement_name = data.name or "Town"
				minetest.chat_send_player(name, S("@1 is located @2m away at @3",
					settlement_name, distance, minetest.pos_to_string(pos)))
			end
		end
	end,
})

local function set_all_discovered(player_name, state)
	local settlement_list = settlements.settlements_in_world:get_areas_in_area(
		{x=-32000, y=-32000, z=-32000}, {x=32000, y=32000, z=32000}, true, true, true)
	for id, settlement in pairs(settlement_list) do
		local data = minetest.deserialize(settlement.data)
		data.discovered_by[player_name] = state
		settlements.settlements_in_world:remove_area(id)
		settlements.settlements_in_world:insert_area(settlement.min, settlement.min, minetest.serialize(data), id)
	end
	settlements.settlements_save()
end

minetest.register_chatcommand("settlements_discover_all", {
	description = S("Set all settlements as known"),
	param = S("player_name, or nothing for yourself"),
	privs = {["server"]=true},
	func = function(name, param)
		if param ~= "" then
			name = param
		end
		set_all_discovered(name, true)
	end,
})

minetest.register_chatcommand("settlements_undiscover_all", {
	description = S("Set all settlements as unknown to you or another player"),
	param = S("player_name, or nothing for yourself"),
	privs = {["server"]=true},
	func = function(name, param)
		if param ~= "" then
			name = param
		end
		set_all_discovered(name, nil)
	end,
})

local function get_nearest_settlement_within_range(pos, range, name)
	local min_edge = vector.subtract(pos, range)
	local max_edge = vector.add(pos, range)
	local settlement_list = settlements.settlements_in_world:get_areas_in_area(min_edge, max_edge, true, true, true)
	
	local min_dist = range + 1 -- start with number beyond range
	local min_id = nil
	local min_data = nil
	local min_pos = nil
	for id, settlement in pairs(settlement_list) do
		local data = minetest.deserialize(settlement.data)
		local distance = vector.distance(pos, settlement.min)
		if distance < min_dist and data.discovered_by[name] then
			min_dist = distance
			min_id = id	
			min_data = data
			min_pos = settlement.min
		end
	end
	
	return min_pos, min_id, min_data
end

minetest.register_chatcommand("settlements_rename_nearest", {
	description = S("Change the name of the nearest settlement within visible range"),
	param = S("The new name for this settlement, or nothing to generate a new random name"),
	privs = {["server"]=true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local player_pos = player:get_pos()
		
		local min_pos, min_id, min_data = get_nearest_settlement_within_range(player_pos, visual_range, name)
		
		if min_id ~= nil then
			if param == "" then
				local def = settlements.settlement_defs[min_data.settlement_type]
				if not def then
					minetest.chat_send_player(name, S("Missing settlement definition for @1", min_data.settlement_type))
					return
				end
				param = def.generate_name(min_pos)
			end
			local oldname = min_data.name
			min_data.name = param
			settlements.settlements_in_world:remove_area(min_id)
			settlements.settlements_in_world:insert_area(min_pos, min_pos, minetest.serialize(min_data), min_id)
			settlements.settlements_save()
			minetest.log("action", "[settlements] Renamed " .. oldname .. " to " .. param)
			minetest.chat_send_player(name, S("Settlement successfully renamed from @1 to @2.", oldname, param)
				.. " " .. S("Existing HUD waypoints for nearby players won't update until they go out of range and the waypoint is recreated again."))
			return
		end
		
		minetest.chat_send_player(name, S("No known settlements within @1m found.", visual_range))
	end,
})

minetest.register_chatcommand("settlements_regenerate_names_for_type", {
	description = S("Regenerate the names for all settments of a particular type"),
	param = S("The settlement type"),
	privs = {["server"]=true},
	func = function(name, param)
		if param == "" then
			minetest.chat_send_player(name, S("A non-empty parameter is required"))
			return
		end
		local settlement_def = settlements.settlement_defs[param]
		if not settlement_def then
			minetest.chat_send_player(name, S("Unrecognized settlement type"))
			return
		end

		local settlement_list = settlements.settlements_in_world:get_areas_in_area(
			{x=-32000, y=-32000, z=-32000}, {x=32000, y=32000, z=32000}, true, true, true)
		for id, settlement in pairs(settlement_list) do
			local data = minetest.deserialize(settlement.data)
			if data.settlement_type == param then
				local pos = settlement.min
				local oldname = data.name
				data.name = settlement_def.generate_name(pos)
				minetest.chat_send_player(name, S("Renamed @1 to @2", oldname, data.name))
				minetest.log("action", "[settlements] Renamed " .. oldname .. " to " .. data.name)
				settlements.settlements_in_world:remove_area(id)
				settlements.settlements_in_world:insert_area(pos, pos, minetest.serialize(data), id)
			end
		end
		settlements.settlements_save()
	end,
})

minetest.register_chatcommand("settlements_remove_nearest", {
	description = S("Remove the nearest settlement within a certain range (default 40)"),
	param = S("range"),
	privs = {["server"] = true},
	func = function(name, param)
		local range = tonumber(param) or 40
		local player = minetest.get_player_by_name(name)
		local player_pos = player:get_pos()
		local min_pos, min_id, min_data = get_nearest_settlement_within_range(player_pos, range, name)
		
		if min_id ~= nil then
			local result = settlements.settlements_in_world:remove_area(min_id)
			if result then
				settlements.settlements_save()
				minetest.log("action", "[settlements] Removed " .. min_data.name)
				minetest.chat_send_player(name, S("Settlement @1 successfully removed.", min_data.name)
					.." "..S("Existing HUD waypoints for nearby players won't update until they go out of range and the waypoint is recreated again."))
				return
			else
				minetest.chat_send_player(name, S("Error removing settlement @1.", min_data.name))
				return
			end
		end
		minetest.chat_send_player(name, S("No known settlements within @1m found.", range))
	end,
})