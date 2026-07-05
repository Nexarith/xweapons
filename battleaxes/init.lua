local S = core.get_translator(core.get_current_modname())
local MODNAME = core.get_current_modname()

local cooldowns = {}

local STRENGTH_BONUS = 2
local STRENGTH_DURATION = 10
local STRENGTH_COOLDOWN = 70

-- ========================================================================
-- ENGINE LINKING: Re-use/declare the core tables and helpers
-- ========================================================================
if not active_strength then active_strength = {} end
if not strength_hud then strength_hud = {} end

local function add_effect_duration(active_table, player_name, duration_seconds)
    local now = core.get_us_time()
    local current = active_table[player_name]
    if not current or current < now then
        current = now
    end
    active_table[player_name] = current + (duration_seconds * 1000000)
end

local function update_effect_hud(player, hud_table, active_table, label, color, y_pos)
    local name = player:get_player_name()
    local now = core.get_us_time()

    if active_table[name] and now < active_table[name] then
        local rem = math.ceil((active_table[name] - now) / 1000000)
        if hud_table[player] then
            player:hud_change(hud_table[player], "text", label .. ": " .. rem .. "s")
        else
            hud_table[player] = player:hud_add({
                hud_elem_type = "text",
                position = {x = 1, y = y_pos},
                alignment = {x = -1.2, y = 0},
                text = label .. ": " .. rem .. "s",
                number = color,
                scale = {x = 1.3, y = 1.3},
            })
        end
    elseif hud_table[player] then
        player:hud_remove(hud_table[player])
        hud_table[player] = nil
        active_table[name] = nil
    end
end

-- =========================
-- Battleaxe Stats
-- =========================

local battleaxes = {
	wood = { damage = 3, uses = 10, maxlevel = 1, image = "battleaxe_wood.png" },
	stone = { damage = 5, uses = 20, maxlevel = 1, image = "battleaxe_stone.png" },
	bronze = { damage = 7, uses = 25, maxlevel = 2, image = "battleaxe_bronze.png" },
	steel = { damage = 7, uses = 30, maxlevel = 2, image = "battleaxe_steel.png" },
	mese = { damage = 8, uses = 30, maxlevel = 3, image = "battleaxe_mese.png" },
	diamond = { damage = 9, uses = 40, maxlevel = 3, image = "battleaxe_diamond.png" },
	ember = { damage = 11, uses = 50, maxlevel = 4, image = "battleaxe_ember.png" },
}

-- ========================================================================
-- ENGINE: STRENGTH TRAIL GENERATOR
-- ========================================================================
local function spawn_strength_trail(player)
	local name = player:get_player_name()
	local pos = player:get_pos()
	pos.y = pos.y + 0.5
	local now = core.get_us_time()

	if active_strength[name] and now < active_strength[name] then
		core.add_particlespawner({
			amount = 3, 
			time = 0.5,
			minpos = vector.subtract(pos, 0.3), 
			maxpos = vector.add(pos, 0.3),
			minvel = {x=-0.2, y=0.1, z=-0.2}, 
			maxvel = {x=0.2, y=0.5, z=0.2},
			minexptime = 0.8, 
			maxexptime = 1.2,
			minsize = 1, 
			maxsize = 2, 
			glow = 10,
			texture = "strength_trail.png",
		})
	end
end

-- =========================
-- Strength Ability 
-- =========================

local function activate_strength(player)
	local name = player:get_player_name()
	local now = core.get_us_time()

	if cooldowns[name] and now < cooldowns[name] then
		local rem_cd = math.ceil((cooldowns[name] - now) / 1000000)
		core.chat_send_player(name, "Strength is on cooldown for " .. rem_cd .. " seconds.")
		return
	end

	cooldowns[name] = now + (STRENGTH_COOLDOWN * 1000000)
	
	add_effect_duration(active_strength, name, STRENGTH_DURATION)

	core.chat_send_player(
		name,
		""
	)

	core.sound_play("strength_activate", {
		object = player,
		gain = 1.0
	})
end

-- ========================================================================
-- HUD & TRAIL REFRESH LOOP
-- ========================================================================
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 then return end
	timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		-- Handle visual trail spawning
		spawn_strength_trail(player)
		
		-- Handle HUD updates
		update_effect_hud(player, strength_hud, active_strength, "Strength", 0xD12323, 0.22)
	end
end)

-- =========================
-- Register Battleaxes
-- =========================

for material, def in pairs(battleaxes) do
	core.register_tool(
		MODNAME .. ":battleaxe_" .. material,
		{
			description =
				S(material:gsub("^%l", string.upper)
				.. " Battleaxe\n"
				.. "Sneak + Right Click: Strength"),

			inventory_image = def.image,

			tool_capabilities = {
				full_punch_interval = 1.0,
				max_drop_level = 1,
				groupcaps = {
					snappy = {
						times = { [1] = 2.0, [2] = 1.0, [3] = 0.35 },
						uses = def.uses,
						maxlevel = def.maxlevel
					},
				},
				damage_groups = {
					fleshy = def.damage
				},
			},
			sound = {
				breaks = "default_tool_breaks"
			},
			groups = {
				battleaxe = 1
			},
			on_place = function(itemstack, user, pointed_thing)
				if user and user:get_player_control().sneak then
					activate_strength(user)
				end
				return itemstack
			end,
			on_secondary_use = function(itemstack, user, pointed_thing)
				if user and user:get_player_control().sneak then
					activate_strength(user)
				end
				return itemstack
			end,
		}
	)
end

-- =========================
-- Bonus Strength Damage
-- =========================

core.register_on_punchplayer(function(player, hitter)
	if not hitter or not hitter:is_player() then
		return
	end

	local name = hitter:get_player_name()
	local now = core.get_us_time()

	if not active_strength[name] or now >= active_strength[name] then
		return
	end

	local wielded = hitter:get_wielded_item()
	if not wielded or wielded:get_name():find(MODNAME .. ":battleaxe_") == nil then
		return
	end

	core.after(0, function()
		if player and player:is_player() and player:get_hp() > 0 then
			player:set_hp(player:get_hp() - STRENGTH_BONUS)
		end
	end)
end)
