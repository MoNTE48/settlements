local modpath = minetest.get_modpath(minetest.get_current_modname())
-- internationalization boilerplate
local S, NS = dofile(modpath.."/intllib.lua")
local schem_path = modpath.."/schematics/"

-- Various settlements' schematics depend on different mods. These paths are used to ensure settlements don't get generated
-- without the corresponding mods being enabled.
local modpath_default = minetest.get_modpath("default")
local modpath_beds = minetest.get_modpath("beds")
local modpath_doors = minetest.get_modpath("doors")
local modpath_stairs = minetest.get_modpath("stairs")
local modpath_farming = minetest.get_modpath("farming")
local modpath_fire = minetest.get_modpath("fire")
local modpath_walls = minetest.get_modpath("walls")
local modpath_xpanes = minetest.get_modpath("xpanes")

local generate_books = minetest.settings:get_bool("settlements_generate_books", true) and modpath_default -- books are defined in the default mod

local medieval_enabled = minetest.settings:get_bool("settlements_medieval", true)
	and modpath_default
	and modpath_beds
	and modpath_doors
	and modpath_stairs
	and modpath_farming
	and modpath_fire
	and modpath_walls
	and modpath_xpanes

if medieval_enabled then

if minetest.get_modpath("namegen") then
	namegen.parse_lines(io.lines(modpath.."/namegen_towns.cfg"))
end

-------------------------------------
-- Node initialization
local function fill_chest(pos)
	-- fill chest
	local inv = minetest.get_inventory( {type="node", pos=pos} )
	-- always
	inv:add_item("main", "default:apple "..math.random(1,3))
	-- low value items
	if math.random(0,1) < 1 then
		inv:add_item("main", "farming:bread "..math.random(0,3))
		inv:add_item("main", "default:steel_ingot "..math.random(0,3))
		-- additional fillings when farming mod enabled
		if minetest.get_modpath("farming") ~= nil and farming.mod == "redo" then
			if math.random(0,1) < 1 then
				inv:add_item("main", "farming:melon_slice "..math.random(0,3))
				inv:add_item("main", "farming:carrot "..math.random(0,3))
				inv:add_item("main", "farming:corn "..math.random(0,3))
			end
		end
	end
	-- medium value items
	if math.random(0,3) < 1 then
		inv:add_item("main", "default:pick_steel "..math.random(0,1))
		inv:add_item("main", "default:pick_bronze "..math.random(0,1))
		inv:add_item("main", "fire:flint_and_steel "..math.random(0,1))
		inv:add_item("main", "bucket:bucket_empty "..math.random(0,1))
		inv:add_item("main", "default:sword_steel "..math.random(0,1))
	end
end

local function fill_shelf(pos, town_name)
	-- TODO: more book types
	local callbacks = {}
	table.insert(callbacks, {func = settlements.generate_travel_guide, param1=pos, param2=town_name})
	if settlements.generate_ledger then
		table.insert(callbacks, {func = settlements.generate_ledger, param1="kings", param2=town_name})
	end

	local inv = minetest.get_inventory( {type="node", pos=pos} )
	for i = 1, math.random(2, 8) do
		local callback = callbacks[math.random(#callbacks)]
		local book = callback.func(callback.param1, callback.param2)
		if book then
			inv:add_item("books", book)
		end
	end
end

local initialize_node = function(pos, node, node_def, settlement_info)
	if settlement_info.name and node.name == "default:sign_wall_steel" then
		local meta = minetest.get_meta(pos)
		meta:set_string("text", S("@1 Town Hall", settlement_info.name))
		meta:set_string("infotext", S("@1 Town Hall", settlement_info.name))
	end
	-- when chest is found -> fill with stuff
	if node.name == "default:chest" then
		fill_chest(pos)
	end
	if generate_books and node.name == "default:bookshelf" then
		fill_shelf(pos, settlement_info.name)
	end
	if minetest.get_item_group(node.name, "plant") > 0 then
		minetest.get_node_timer(pos):start(1000) -- start crops growing
	end
end

--------------------------------------------
-- Schematics

local townhall_schematic = {
	name = "townhall",
	schematic = dofile(schem_path.."medieval_townhall.lua"),
	buffer = 2, -- buffer space around the building, footprint is treated as radius max(size.x, size.z) + buffer for spacing purposes
	max_num = 0.1, -- This times the number of buildings in a settlement gives the maximum number of these buildings in a settlement.
					-- So for example, 0.1 means at most 1 of these buildings in a 10-building settlement and 2 in a 20-building settlement.
	replace_nodes_optional = true, -- If true, default:cobble will be replaced with a random wall material
	initialize_node = initialize_node, -- allows additional post-creation actions to be executed on schematic nodes once they're constructed
}
local kingsmarket_schematic = {
	name = "kingsmarket",
	schematic = dofile(schem_path.."medieval_kingsmarket.lua"),
	buffer = 1,
	max_num = 0.1,
	replace_nodes_optional = true,
	initialize_node = initialize_node,
}

-- list of schematics
local schematic_table = {
	{
		name = "well",
		schematic = dofile(schem_path.."medieval_well.lua"),
		buffer = 2,
		max_num = 0.045,
		height_adjust = -2, -- adjusts the y axis of where the schematic is built, to allow for "basement" stuff
	},
	{
		name = "hut",
		schematic = dofile(schem_path.."medieval_hut.lua"),
		buffer = 1,
		max_num = 0.9,
		replace_nodes_optional = true,
		initialize_node = initialize_node,
	},
	{
		name = "garden",
		schematic = dofile(schem_path.."medieval_garden.lua"),
		max_num = 0.1,
		initialize_node = initialize_node,
	},
	{
		name = "lamp",
		schematic = dofile(schem_path.."medieval_lamp.lua"),
		buffer = 3,
		max_num = 0.05,
	},
	{
		name = "tower",
		schematic = dofile(schem_path.."medieval_tower.lua"),
		buffer = 3,
		max_num = 0.055,
	},
	{
		name = "church",
		schematic = dofile(schem_path.."medieval_church.lua"),
		buffer = 2,
		max_num = 0.075,
	},
	{
		name = "blacksmith",
		schematic = dofile(schem_path.."medieval_blacksmith.lua"),
		buffer = 2,
		max_num = 0.050,
	},
	kingsmarket_schematic,
	{
		name = "nightmarket",
		schematic = dofile(schem_path.."medieval_nightmarket.lua"),
		buffer = 1,
		max_num = 0.025,
		replace_nodes_optional = true,
		initialize_node = initialize_node,
	},
}

local medieval_settlements = {
	-- this settlement will be placed on nodes with this surface material type.
	surface_materials = {
		"default:dirt",
		"default:dirt_with_grass",
		"default:dry_dirt_with_dry_grass",
		"default:dirt_with_snow",
		"default:dirt_with_dry_grass",
		"default:dirt_with_coniferous_litter",
		"default:sand",
		"default:silver_sand",
		"default:snow_block",
	},
	
	-- TODO: add a biome list. The tricky part here is, what if a biome list but not a surface materials list is provided?
	-- How to find the surface, and how to know what to replace surface material nodes with in the schematic?

	-- nodes in  all schematics will be replaced with these nodes, or a randomly-selected node
	-- from a list of choices if a list is provided
	replacements = {
		["default:junglewood"] = "settlements:junglewood",
	},
	
	-- Affected by per-building replace_nodes flag
	replacements_optional = {
		["default:cobble"] = {
			"default:junglewood", 
			"default:pine_wood", 
			"default:wood", 
			"default:aspen_wood", 
			"default:acacia_wood",	 
			"default:stonebrick", 
			"default:cobble", 
			"default:desert_stonebrick", 
			"default:desert_cobble", 
			"default:sandstone",
		},
	},
	
	-- This node will be replaced with the surface material of the location the building is placed on.
	replace_with_surface_material = "default:dirt_with_grass",
	
	-- Trees often interfere with surface detection. These nodes will be ignored when detecting surface level.
	ignore_surface_materials = {
		"default:tree",
		"default:jungletree",
		"default:pine_tree",
		"default:acacia_tree",
		"default:aspen_tree",
		"default:bush_stem",
		"default:bush_leaves",
		"default:acacia_bush_stem",
		"default:acacia_bush_leaves",
		"default:pine_bush_stem",
		"default:pine_bush_needles",
		"default:blueberry_bush_leaves_with_berries",
		"default:blueberry_bush_leaves",
	},
	
	platform_shallow = "default:dirt",
	platform_deep = "default:stone",
	path_material = "default:gravel",
	
	schematics = schematic_table,
	
	-- Select one of these to form the center of town. If not defined, one will be picked from the regular schematic table
	central_schematics = {
		townhall_schematic,
		kingsmarket_schematic,
	},
	
	building_count_min = 5,
	building_count_max = 25,
	
	altitude_min = 2,
	altitude_max = 300,
	
	generate_name = function(pos)
		if minetest.get_modpath("namegen") then
			return namegen.generate("settlement_towns")
		end
		return "Town"
	end,
}

settlements.register_settlement("medieval", medieval_settlements)

end

local function test_if_medieval_settlements_exist()
	local settlement_list = settlements.settlements_in_world:get_areas_in_area(
		{x=-32000, x=-32000, x=-32000}, {x=32000, x=32000, x=32000}, true, true, true)
	for _, settlement in pairs(settlement_list) do
		local data = minetest.deserialize(settlement.data)
		if data.settlement_type == "medieval" then
			return true
		end
	end
	return false
end

-- If medieval villages are present, register settlements:junglewood even if medieval villages
-- are no longer enabled for further generation.
if medieval_enabled or (test_if_medieval_settlements_exist() and modpath_default) then
---------------------------------------------------------------------------
-- register block for npc spawn
local function deep_copy(table_in)
	local table_out = {}
	for index, value in pairs(table_in) do
		if type(value) == "table" then
			table_out[index] = deep_copy(value)
		else
			table_out[index] = value
		end
	end
	return table_out
end

local junglewood_def = deep_copy(minetest.registered_nodes["default:junglewood"])
minetest.register_node("settlements:junglewood", junglewood_def)
-- register inhabitants
if minetest.get_modpath("mobs_npc") ~= nil then
	mobs:register_spawn("mobs_npc:npc", --name
		{"settlements:junglewood"}, --nodes
		20, --max_light
		0, --min_light
		20, --chance
		2, --active_object_count
		31000, --max_height
		nil) --day_toggle
	mobs:register_spawn("mobs_npc:trader", --name
		{"settlements:junglewood"}, --nodes
		20, --max_light
		0, --min_light
		20, --chance
		2, --active_object_count
		31000, --max_height
		nil)--day_toggle
end

end