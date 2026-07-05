-- Mace System Mod for Luanti (Minetest)

-- STRICTLY requires 3d_armor

-- Fixed armor reading (proper return value handling)


local mace_cooldowns = {}

local original_player_physics = {}

local player_fall_anchors = {}

local active_mace_flights = {}

local last_ground_state = {}

-- Slowness HUD (same style as effect timers: countdown below Speed Boost)
local mace_slowness_hud = {}      -- player obj -> hud id
local active_mace_slowness = {}   -- player_name -> end_us_time (us_time)


-- ============================================

-- CORE DATA & ARCHETYPES

-- ============================================


local mace_tiers = {

    { id = "wood",    name = "Wood Mace",    archetype = "Mobility", damage_range = {3, 4},  launch_v = 11.0 },

    { id = "steel",   name = "Steel Mace",   archetype = "Mobility", damage_range = {4, 6},  launch_v = 13.0 },

    { id = "bronze",  name = "Bronze Mace",  archetype = "Mobility", damage_range = {5, 7},  launch_v = 14.8 },

    { id = "gold",    name = "Gold Mace",    archetype = "Damage",   damage_range = {7, 9},   launch_v = 16.5 },

    { id = "diamond", name = "Diamond Mace", archetype = "Damage",   damage_range = {9, 12},  launch_v = 19.5 },

    { id = "ember",   name = "Ember Mace",   archetype = "Damage",   damage_range = {11, 14}, launch_v = 22.0 },

    { id = "crystal", name = "Crystal Mace", archetype = "Control",  damage_range = {6, 8},  launch_v = 24.5 },

    { id = "void",    name = "Void Mace",    archetype = "Control",  damage_range = {5, 7},  launch_v = 28.0 },

}


local base_damage_table = {

    wood = { none=18, wood=14, steel=12, bronze=10, gold=8, diamond=6, ember=4 },

    steel = { none=20, wood=18, steel=14, bronze=12, gold=10, diamond=8, ember=6 },

    bronze = { none=20, wood=20, steel=18, bronze=16, gold=12, diamond=10, ember=8 },

    gold = { none=20, wood=20, steel=20, bronze=18, gold=16, diamond=12, ember=10 },

    diamond = { none=20, wood=20, steel=20, bronze=20, gold=18, diamond=16, ember=12 },

    ember = { none=20, wood=20, steel=20, bronze=20, gold=20, diamond=18, ember=16 },

    crystal = { none=20, wood=20, steel=20, bronze=20, gold=20, diamond=20, ember=18 },

    void = { none=20, wood=20, steel=20, bronze=20, gold=20, diamond=20, ember=20 },

}


local function get_tier_by_item(item_name)

    local tier_id = item_name:match("^mace_system:mace_(.+)$")

    if not tier_id then return nil end

    for _, tier in ipairs(mace_tiers) do

        if tier.id == tier_id then return tier end

    end

    return nil

end


local function is_armor_piece(item_name)

    if not item_name then return false end

    local n = item_name:lower()

    local name_without_mod = n:match("^[^:]+:(.+)$") or n

    return name_without_mod:find("helmet") or

           name_without_mod:find("chestplate") or

           name_without_mod:find("leggings") or

           name_without_mod:find("boots") or

           name_without_mod:find("shield")

end


local function get_armor_material(item_name)

    if not item_name then return "none" end

    local n = item_name:lower()

    local mat = n:match("([^_]+)$")

    if mat and base_damage_table.diamond[mat] then

        return mat

    end

    if n:find("diamond") then return "diamond" end

    if n:find("gold")    then return "gold" end

    if n:find("ember")   then return "ember" end

    if n:find("crystal") then return "crystal" end

    if n:find("void")    then return "void" end

    if n:find("bronze")  then return "bronze" end

    if n:find("steel")   then return "steel" end

    if n:find("wood")    then return "wood" end

    return "none"

end


local function get_base_damage(mace_id, armor_tier)

    local mace_data = base_damage_table[mace_id]

    if not mace_data then return 20 end

    return mace_data[armor_tier] or mace_data.none or 20

end


-- FIXED: Correct handling of armor:get_valid_player return values

local function get_armor_list(player)

    if not player then return {} end


    if not (armor and armor.get_valid_player) then

        return {}

    end


    -- get_valid_player returns TWO values: (player, armor_inv)

    local ok, _, armor_inv = pcall(armor.get_valid_player, armor, player, "3d_armor")

    

    if not ok or not armor_inv then

        return {}

    end


    local pieces = {}

    local list = armor_inv:get_list("armor")

    if list then

        for _, stack in ipairs(list) do

            if not stack:is_empty() then

                table.insert(pieces, stack)

            end

        end

    end

    return pieces

end


-- Main damage calculation

local function calculate_air_strike_damage(hitter, target)

    if not target or not target:is_player() then return 20 end


    local wielded = hitter:get_wielded_item():get_name()

    local tier_info = get_tier_by_item(wielded)

    local mace_id = tier_info and tier_info.id or "wood"


    local total = 0

    local pieces_found = 0


    local armor_list = get_armor_list(target)


    for _, stack in ipairs(armor_list) do

        if not stack:is_empty() then

            local item_name = stack:get_name()

            if is_armor_piece(item_name) then

                local armor_tier = get_armor_material(item_name)

                total = total + get_base_damage(mace_id, armor_tier)

                pieces_found = pieces_found + 1

                if pieces_found >= 5 then break end

            end

        end

    end


    local missing = 5 - pieces_found

    if missing > 0 then

        total = total + (missing * get_base_damage(mace_id, "none"))

    end


    return math.floor((total / 5) + 0.5)

end


-- ============================================

-- UTILITY & PHYSICS PENALTIES

-- ============================================

-- HUD updater for slowness (countdown style, positioned below Speed Boost y=0.28)
local function update_mace_slowness_hud(player)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    local now = minetest.get_us_time()

    if active_mace_slowness[name] and now < active_mace_slowness[name] then
        local rem = math.ceil((active_mace_slowness[name] - now) / 1000000)
        local txt = "Fatigue Slowness: " .. rem .. "s"
        if mace_slowness_hud[player] then
            player:hud_change(mace_slowness_hud[player], "text", txt)
        else
            mace_slowness_hud[player] = player:hud_add({
                hud_elem_type = "text",
                position = {x = 1, y = 0.34},  -- just below speed boost
                alignment = {x = -1.2, y = 0},
                text = txt,
                number = 0xFF0000,  -- red warning color
                scale = {x = 1.3, y = 1.3},
            })
        end
    elseif mace_slowness_hud[player] then
        player:hud_remove(mace_slowness_hud[player])
        mace_slowness_hud[player] = nil
        active_mace_slowness[name] = nil
    end
end


local function apply_slowness_penalty(player)

    local player_name = player:get_player_name()

    -- Set HUD timer (no chat spam - HUD shows countdown below Speed Boost)
    local now = minetest.get_us_time()
    active_mace_slowness[player_name] = now + 5000000  -- 5 seconds in us_time


    if playerphysics then

        playerphysics.add_physics_factor(player, "speed", "mace_miss_slowness", 0.08)

        playerphysics.add_physics_factor(player, "jump", "mace_miss_slowness", 0.1)

        playerphysics.add_physics_factor(player, "acceleration_default", "mace_miss_slowness", 0.1)

        playerphysics.add_physics_factor(player, "acceleration_air", "mace_miss_slowness", 0.02)


        minetest.after(5, function()

            local p = minetest.get_player_by_name(player_name)

            if p then

                playerphysics.remove_physics_factor(p, "speed", "mace_miss_slowness")

                playerphysics.remove_physics_factor(p, "jump", "mace_miss_slowness")

                playerphysics.remove_physics_factor(p, "acceleration_default", "mace_miss_slowness")

                playerphysics.remove_physics_factor(p, "acceleration_air", "mace_miss_slowness")

            end
            active_mace_slowness[player_name] = nil  -- HUD will auto-remove on next update
        end)

    else

        if not original_player_physics[player_name] then

            original_player_physics[player_name] = player:get_physics_override()

        end

        player:set_physics_override({ speed = 0.08, jump = 0.1, acceleration_default = 0.1, acceleration_air = 0.02 })


        minetest.after(5, function()

            local p = minetest.get_player_by_name(player_name)

            if p then

                local base = original_player_physics[player_name] or {speed=1, jump=1, acceleration_default=1, acceleration_air=1}

                p:set_physics_override({

                    speed = base.speed or 1.0,

                    jump = base.jump or 1.0,

                    acceleration_default = base.acceleration_default or 1.0,

                    acceleration_air = base.acceleration_air or 1.0

                })

            end
            original_player_physics[player_name] = nil
            active_mace_slowness[player_name] = nil  -- HUD auto-cleanup
        end)

    end

end


local function apply_gravity_crush(target)

    if not target or not target:is_player() then return end

    local target_name = target:get_player_name()

    target:set_physics_override({ speed = 0.3, jump = 0.0 })

    minetest.chat_send_player(target_name, minetest.colorize(""))

    minetest.after(2.5, function()

        local t = minetest.get_player_by_name(target_name)

        if t then t:set_physics_override({ speed = 1.0, jump = 1.0 }) end

    end)

end


-- ============================================

-- GAME MECHANICS

-- ============================================


minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)

    if not hitter or not hitter:is_player() then return end

    local hitter_name = hitter:get_player_name()


    if active_mace_flights[hitter_name] then

        local wielded_item = hitter:get_wielded_item():get_name()

        local tier_info = get_tier_by_item(wielded_item)


        if tier_info then

            active_mace_flights[hitter_name] = nil


            local final_damage = calculate_air_strike_damage(hitter, player)

            local current_hp = player:get_hp()

            player:set_hp(math.max(0, current_hp - final_damage))


            if tier_info.id == "ember" then

                if fire_plus and fire_plus.burn_player then

                    if math.random(1, 10) == 1 and player:get_hp() > 0 then

                        fire_plus.burn_player(player, 3, 3)

                        minetest.chat_send_player(player:get_player_name(), minetest.colorize(""))

                    end

                end

            elseif tier_info.id == "void" then

                apply_gravity_crush(player)

            elseif tier_info.id == "crystal" then

                if math.random(1, 3) == 1 then

                    player:set_physics_override({ speed = 0.4, jump = 0.3 })

                    minetest.chat_send_player(player:get_player_name(), minetest.colorize(""))

                    minetest.after(4, function()

                        local t = minetest.get_player_by_name(player:get_player_name())

                        if t then t:set_physics_override({ speed = 1.0, jump = 1.0 }) end

                    end)

                end

            elseif tier_info.archetype == "Damage" then

                if math.random(1, 4) == 1 then

                    local extra = math.random(2, 4)

                    player:set_hp(math.max(0, player:get_hp() - extra))

                    minetest.chat_send_player(hitter_name, minetest.colorize(""))

                end

            elseif tier_info.archetype == "Mobility" then

                local kb_dir = vector.subtract(player:get_pos(), hitter:get_pos())

                kb_dir = vector.normalize(kb_dir)

                player:add_velocity({ x = kb_dir.x * 8, y = 4, z = kb_dir.z * 8 })

                minetest.chat_send_player(player:get_player_name(), minetest.colorize(""))

            end


            minetest.chat_send_player(hitter_name, minetest.colorize(""))

            return true

        end

    end

end)


minetest.register_globalstep(function(dtime)

    for _, player in ipairs(minetest.get_connected_players()) do

        local name = player:get_player_name()

        local pos = player:get_pos()

        if pos then

            local vel = player:get_velocity() or {y = 0}

            local feet_check = {x = pos.x, y = pos.y - 0.1, z = pos.z}

            local node = minetest.get_node(feet_check)

            local nodedef = minetest.registered_nodes[node.name]

            local currently_on_ground = nodedef and nodedef.walkable and (vel.y <= 0.1)


            local was_on_ground = last_ground_state[name] or false


            if currently_on_ground and not was_on_ground then

                player_fall_anchors[name] = pos.y

                if active_mace_flights[name] then

                    active_mace_flights[name] = nil

                    apply_slowness_penalty(player)

                end

            end

            last_ground_state[name] = currently_on_ground

            -- Update slowness HUD every frame (cheap text element)
            update_mace_slowness_hud(player)

        end

    end

end)


minetest.register_on_player_hpchange(function(player, hp_change, modifier)

    if hp_change < 0 and modifier.type == "fall" then

        local name = player:get_player_name()

        if active_mace_flights[name] then

            return 0

        end

    end

    return hp_change

end)


local function activate_mace_ability(itemstack, user, tier_info)

    local player_name = user:get_player_name()

    local current_time = os.time()


    if mace_cooldowns[player_name] and (current_time - mace_cooldowns[player_name]) < 90 then

        local time_left = 90 - (current_time - mace_cooldowns[player_name])

        minetest.chat_send_player(player_name, minetest.colorize("#FFFF00", "Mace ability on cooldown! Wait " .. time_left .. "s."))

        return itemstack

    end


    local start_y = player_fall_anchors[player_name] or user:get_pos().y

    local calculated_fall_dist = start_y - user:get_pos().y


    if calculated_fall_dist > 4.0 and not active_mace_flights[player_name] then

        user:set_hp(user:get_hp() - 4)

        minetest.chat_send_player(player_name, minetest.colorize("#FF5500", "Anti-Pillar Infraction Triggered! Drops penalized."))

        mace_cooldowns[player_name] = current_time

        return itemstack

    end


    mace_cooldowns[player_name] = current_time

    active_mace_flights[player_name] = true


    user:add_velocity({ x = 0, y = tier_info.launch_v, z = 0 })


    minetest.chat_send_player(player_name, minetest.colorize(""))

    minetest.sound_play("default_dig_cracky", {pos = user:get_pos(), gain = 0.8, max_hear_distance = 15}, true)


    return itemstack

end


-- ============================================

-- TOOL REGISTRATION

-- ============================================


for _, tier in ipairs(mace_tiers) do

    local archetype_color = "#00FF00"

    if tier.archetype == "Damage" then archetype_color = "#FF1111"

    elseif tier.archetype == "Control" then archetype_color = "#AA00FF" end


    local extra_desc = ""

    if tier.id == "ember" then

        extra_desc = minetest.colorize("#FF5500", "Special: 5s fire_plus Target Ignition DOT\n")

    elseif tier.id == "void" then

        extra_desc = minetest.colorize("#AA00FF", "Special: 2.5s Void Crush (Locks Jump & Slows Momentum)\n")

    end


    minetest.register_tool("mace_system:mace_" .. tier.id, {

        description = tier.name .. "\n" ..

                      minetest.colorize(archetype_color, "Archetype: " .. tier.archetype .. "\n") ..

                      minetest.colorize("#FFAA00", "Ability: Shift + Right Click [Instant Launch]\n") ..

                      extra_desc ..

                      "Base Damage: " .. tier.damage_range[1] .. "-" .. tier.damage_range[2] .. " HP\n" ..

                      "Launch Vector Boost: +" .. tier.launch_v .. "\n" ..

                      "Cooldown Loop: 90s",

        inventory_image = "mace_system_" .. tier.id .. ".png",

        wield_scale = {x = 1.25, y = 1.25, z = 1.25},

        

        tool_capabilities = {

            full_punch_interval = 1.0,

            max_drop_level = 3,

            groupcaps = {

                fleshy = {times={[1]=2.0, [2]=1.0, [3]=0.5}, uses=0, maxlevel=3}

            },

            damage_groups = {fleshy = tier.damage_range[2]},

        },


        on_secondary_use = function(itemstack, user, pointed_thing)

            local control = user:get_player_control()

            if control.sneak then return activate_mace_ability(itemstack, user, tier) end

            return itemstack

        end,

        on_place = function(itemstack, placer, pointed_thing)

            local control = placer:get_player_control()

            if control.sneak then return activate_mace_ability(itemstack, placer, tier) end

            return itemstack

        end

    })

end


minetest.register_on_leaveplayer(function(player)

    local name = player:get_player_name()

    mace_cooldowns[name] = nil

    original_player_physics[name] = nil

    player_fall_anchors[name] = nil

    active_mace_flights[name] = nil

    active_mace_slowness[name] = nil
    if mace_slowness_hud[player] then
        player:hud_remove(mace_slowness_hud[player])
        mace_slowness_hud[player] = nil
    end

end)