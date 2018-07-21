converter = {}
dofile(minetest.get_modpath("converter") .. "/recipes.lua")



-- Converter Block

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then return 0 end

	local meta = minetest.get_meta(pos)
	if not meta then return 0 end

	local stack_name = stack:get_name()

	if listname == "src" then
		-- must be a valid ingredient, or valid result if reversed enabled for recipe
		for i,recipe in pairs(converter.recipes) do
			if stack_name == recipe[1] then
				local count = stack:get_count()
				minetest.log("action", player:get_player_name().." moves ".. count.." "..stack_name.." to converter at ".. minetest.pos_to_string(pos))
				return count
			elseif recipe[3] and stack_name == recipe[2] then
				local count = stack:get_count()
				minetest.log("action", player:get_player_name().." moves ".. count.." "..stack_name.." to converter at ".. minetest.pos_to_string(pos))
				return count
			end
		end
		return 0
	elseif listname == "dst" then
		-- must be a valid result, or valid ingredient if reversed enabled for recipe
		-- only allow one item in the slot
		local inv = meta:get_inventory()
		local dst_stack = inv:get_stack("dst", 1)
		if dst_stack ~= nil and stack_name == dst_stack:get_name() then
			-- dst slot already contains one of this item
			return 0
		end
		for i,recipe in pairs(converter.recipes) do
			if stack_name == recipe[2] then
				minetest.log("action", player:get_player_name().." moves 1 "..stack_name.." to converter at "..minetest.pos_to_string(pos))
				return 1
			elseif recipe[3] and stack_name == recipe[1] then
				minetest.log("action", player:get_player_name().." moves 1 "..stack_name.." to converter at "..minetest.pos_to_string(pos))
				return 1
			end
		end
		return 0
	end
end

minetest.register_node("converter:converter", {
	description = "Converter",
	tiles = {"converter.png"},
	sounds = default.node_sound_stone_defaults(),
	groups = {dig_immediate = 2},
	is_ground_content = false,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		if meta ~= nil then
			local inv = meta:get_inventory()
			inv:set_size('src', 8)
			inv:set_size('dst', 1)
		end
	end,

	on_rightclick = function(pos, node, clicker, itemstack)
		if minetest.is_protected(pos, clicker:get_player_name()) then return end

		local spos = pos.x .. "," .. pos.y .. "," .. pos.z
		minetest.show_formspec(clicker:get_player_name(), "converter:converter_"..minetest.pos_to_string(pos),
			"size[8,7.45]"..default.gui_bg..default.gui_bg_img..default.gui_slots
			.."list[nodemeta:" .. spos .. ";src;0,0;8,1;]"
			.."button[6,1.2;2,0.5;toinv;To Inventory]"
			.."list[nodemeta:" .. spos .. ";dst;3.5,1.2;1,1;]"
			.."button[3,2.5;2,0.5;convert;Convert]"
			.."list[current_player;main;0,3.45;8,1;]"..default.get_hotbar_bg(0, 3.45)
			.."list[current_player;main;0,4.7;8,3;8]"
			.."listring[nodemeta:" .. spos .. ";src]"
			.."listring[current_player;main]"
		)
	end,

	can_dig = function(pos, player)
		if minetest.is_protected(pos, player:get_player_name()) then return end

		local meta = minetest.get_meta(pos);
		if meta ~= nil then
			local inv = meta:get_inventory()
			if inv:is_empty("src") and inv:is_empty("dst") then
				return true
			end
		end
	end,
	on_blast = function(pos, intensity)
		local drops = {}
		default.get_inventory_drops(pos, "src", drops)
		default.get_inventory_drops(pos, "dst", drops)
		drops[#drops+1] = "converter:converter"
		minetest.remove_node(pos)
		return drops
	end,

	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		if not meta then return 0 end

		local inv = meta:get_inventory()
		-- moving stuff around in the converter produces log messages identical to putting stuff in converter
--		minetest.log("action", player:get_player_name().." moves stuff in converter at "..minetest.pos_to_string(pos))
		return allow_metadata_inventory_put(pos, to_list, to_index, inv:get_stack(from_list, from_index), player)
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if minetest.is_protected(pos, player:get_player_name()) then return 0 end

		local count = stack:get_count()
		minetest.log("action", player:get_player_name().." takes "..count.." "..stack:get_name().." from converter at "..minetest.pos_to_string(pos))
		return count
	end
})

minetest.register_craft({
	output = "converter:converter 1",
	recipe = {
		{"","default:steel_ingot",""},
		{"group:wood","group:wood","group:wood"},
		{"default:stone","default:stone","default:stone"},
	}
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 0, string.len("converter:converter_")) ~= "converter:converter_" then return end

	local pos_str = string.sub(formname, string.len("converter:converter_")+1)
	local pos = minetest.string_to_pos(pos_str)
	if minetest.is_protected(pos, player:get_player_name()) then return end

	local meta = minetest.get_meta(pos)
	if not meta then return end

	local inv = meta:get_inventory()

	if fields.convert then
		-- convert first valid src stack to type in dst stack
		local dst_stack = inv:get_stack("dst", 1)
		if dst_stack ~= nil and dst_stack:get_count() > 0 then
			local dst_name = dst_stack:get_name()
			local src_list = inv:get_list('src') or {}
			local src_stack = nil
			local src_index = 0
			for i,v in pairs(src_list) do
				local stack = src_list[i]
				if stack ~= nil and stack:get_count() > 0 and dst_name ~= stack:get_name() then
					src_stack = stack
					src_index = i
					break
				end
			end
			if src_stack ~= nil and src_stack:get_count() > 0 then
				local src_name = src_stack:get_name()
				local count = src_stack:get_count()
				for i,recipe in pairs(converter.recipes) do
					if src_name == recipe[1] and dst_name == recipe[2] then
						-- convert src stack to dst type
--						print("CONVERT "..count.." "..src_name.." TO "..dst_name)  
						dst_stack:set_count(count)
						inv:set_stack('src', src_index, dst_stack)
						minetest.sound_play("convert", {pos = pos, gain = 0.5, max_hear_distance = 5})
						break
					elseif recipe[3] and src_name == recipe[2] and dst_name == recipe[1] then
						-- convert src stack to dst type
--						print("CONVERT-REVERSE "..count.." "..src_name.." TO "..dst_name)  
						dst_stack:set_count(count)
						inv:set_stack('src', src_index, dst_stack)
						minetest.sound_play("convert", {pos = pos, gain = 1.0, max_hear_distance = 5})
						break
					end
				end
			end
		end
	elseif fields.toinv then
		-- move all src stacks to player inventory
		local player_inv = player:get_inventory()
		local leftover
		for i,v in pairs(inv:get_list('src') or {}) do
			if player_inv:room_for_item("main", v) then
				leftover = player_inv:add_item("main", v)
				inv:remove_item('src', v)
				if leftover ~= nil and not leftover:is_empty() then
					inv:add_item('src', v)
				end
			end
		end
	end
end)



print("[MOD] Converter loaded")
