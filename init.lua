-- === ELEMENTAL PVP - Safe & Low-Lag Version ===
local elements = {
    fire      = {name = "Fire",     color = "#ff4400", particle = "fire_basic_flame.png"},
    ice       = {name = "Ice",      color = "#88ddff", particle = "default_ice.png"},
    wind      = {name = "Wind",     color = "#aaffcc", particle = "default_grass.png"},
    earth     = {name = "Earth",    color = "#bb9966", particle = "default_dirt.png"},
    lightning = {name = "Lightning",color = "#ffee44", particle = "default_torch.png"},
    water     = {name = "Water",    color = "#4488ff", particle = "default_water.png"}
}

local advantage = {
    fire = "wind", wind = "earth", earth = "lightning",
    lightning = "water", water = "ice", ice = "fire"
}

local player_cooldown = {}

local function get_multiplier(att, vic)
    if not att or not vic or att == "" or vic == "" then return 1.0 end
    if att == vic then return 1.0 end
    if advantage[att] == vic then return 1.85 end
    if advantage[vic] == att then return 0.55 end
    return 1.2
end

-- === COMMAND ===
minetest.register_chatcommand("element", {
    params = "<fire|ice|wind|earth|lightning|water>",
    func = function(name, param)
        if not name then return false end
        param = (param or ""):lower()
        if not elements[param] then
            return false, "Invalid element! Use: fire, ice, wind, earth, lightning, water"
        end
        local player = minetest.get_player_by_name(name)
        if not player then return false end

        player:get_meta():set_string("element", param)
        minetest.chat_send_player(name, minetest.colorize(elements[param].color,
            "⚡ You are now " .. elements[param].name .. " Elemental!"))
        return true
    end
})

-- === PUNCH DAMAGE (Safe) ===
minetest.register_on_punchplayer(function(player, hitter, _, _, _, damage)
    if not player or not hitter or not hitter:is_player() then return end

    local att_elem = hitter:get_meta():get_string("element")
    local vic_elem = player:get_meta():get_string("element")

    local mult = get_multiplier(att_elem, vic_elem)
    if mult > 1.0 then
        local extra = math.floor(damage * (mult - 1))
        if extra > 0 then
            local hp = player:get_hp()
            if hp then
                player:set_hp(hp - extra)
            end
        end

        if mult > 1.5 then
            minetest.add_particlespawner({
                amount = 10,
                time = 0.4,
                minpos = player:get_pos() or vector.new(0,0,0),
                maxpos = (player:get_pos() or vector.new(0,0,0)) + vector.new(0.6, 1.4, 0.6),
                texture = elements[att_elem].particle,
                size = 3,
                expirationtime = 0.6,
            })
        end
    end
end)

-- === ABILITIES (Right click) - Very Safe ===
minetest.register_on_player_rightclick(function(player, pointed_thing)
    if not player then return end

    local name = player:get_player_name()
    if not name or name == "" then return end

    local elem = player:get_meta():get_string("element")
    if not elem or elem == "" then return end

    -- Cooldown check
    local now = minetest.get_us_time() / 1000000
    if (player_cooldown[name] or 0) > now then return end
    player_cooldown[name] = now + 3.0   -- 3s cooldown

    local pos = player:get_pos()
    if not pos then return end

    local dir = player:get_look_dir()
    if not dir then dir = vector.new(0, 0, 1) end   -- fallback

    local look_pos = pos + vector.multiply(dir, 1.5)

    -- Fire
    if elem == "fire" then
        local obj = minetest.add_entity(look_pos, "elemental_pvp:fireball")
        if obj then
            obj:setvelocity(vector.multiply(dir, 26))
            local entity = obj:get_luaentity()
            if entity then entity.thrower = name end
        end
        minetest.sound_play("fire_flint_and_steel", {pos = pos, gain = 0.6, max_hear_distance = 16})

    -- Ice
    elseif elem == "ice" then
        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 6)) do
            if obj:is_player() and obj ~= player then
                local v = obj:get_velocity() or {x=0, y=0, z=0}
                obj:set_velocity({x = v.x * 0.25, y = v.y, z = v.z * 0.25})
            end
        end
        minetest.add_particlespawner({
            amount = 18, time = 0.7,
            minpos = pos - vector.new(5,2,5),
            maxpos = pos + vector.new(5,4,5),
            texture = "default_ice.png", size = 2.5
        })

    -- Wind
    elseif elem == "wind" then
        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 8)) do
            if obj:is_player() and obj ~= player then
                local vec = vector.direction(pos, obj:get_pos() or pos)
                obj:add_velocity(vector.multiply(vec, 20))
            end
        end

    -- Earth
    elseif elem == "earth" then
        local p = pos + vector.new(0, -1, 0)
        minetest.set_node(p, {name = "default:stone"})

    -- Lightning
    elseif elem == "lightning" then
        local target = pos + vector.multiply(dir, 14)
        minetest.add_particlespawner({
            amount = 6, time = 0.4,
            minpos = target + vector.new(0,12,0),
            maxpos = target + vector.new(0,15,0),
            minvel = {x=0, y=-35, z=0},
            texture = "default_torch.png", size = 5
        })
        minetest.sound_play("thunder", {pos = target, gain = 0.8, max_hear_distance = 40})

        for _, obj in ipairs(minetest.get_objects_inside_radius(target, 3.5)) do
            if obj:is_player() and obj ~= player then
                local hp = obj:get_hp()
                if hp then obj:set_hp(hp - 11) end
            end
        end

    -- Water
    elseif elem == "water" then
        local obj = minetest.add_entity(look_pos, "elemental_pvp:waterblast")
        if obj then
            obj:setvelocity(vector.multiply(dir, 22))
        end
        local hp = player:get_hp()
        local maxhp = player:get_hp_max()
        if hp and maxhp then
            player:set_hp(math.min(hp + 4, maxhp))
        end
    end
end)

-- === ENTITIES (Safe) ===
minetest.register_entity("elemental_pvp:fireball", {
    initial_properties = {
        visual = "sprite",
        textures = {"fire_basic_flame.png"},
        visual_size = {x=0.9, y=0.9},
        collisionbox = {-0.2,-0.2,-0.2,0.2,0.2,0.2}
    },
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if pos then
            minetest.add_particle({
                pos = pos,
                size = 4,
                texture = "fire_basic_flame.png",
                expirationtime = 0.12
            })
        end
    end,
    on_punch = function(self, hitter)
        if hitter and hitter:is_player() then
            local hp = hitter:get_hp()
            if hp then hitter:set_hp(hp - 8) end
        end
        self.object:remove()
    end
})

minetest.register_entity("elemental_pvp:waterblast", {
    initial_properties = {
        visual = "sprite",
        textures = {"default_water.png"},
        visual_size = {x=1.1, y=1.1}
    },
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if pos then
            minetest.add_particle({
                pos = pos,
                size = 5,
                texture = "default_water.png",
                expirationtime = 0.18
            })
        end
    end,
    on_punch = function(self, hitter)
        if hitter and hitter:is_player() then
            hitter:add_velocity({x=0, y=9, z=0})
            local hp = hitter:get_hp()
            if hp then hitter:set_hp(hp - 7) end
        end
        self.object:remove()
    end
})

-- Cleanup
minetest.register_on_leaveplayer(function(player)
    if player then
        player_cooldown[player:get_player_name()] = nil
    end
end)

minetest.register_on_joinplayer(function(player)
    if not player then return end
    minetest.after(2, function()
        if player and player:get_player_name() then
            minetest.chat_send_player(player:get_player_name(),
                "🌊 Use /element fire | ice | wind | earth | lightning | water")
        end
    end)
end)

print("[Elemental PVP] Safe & Optimized version loaded!")
