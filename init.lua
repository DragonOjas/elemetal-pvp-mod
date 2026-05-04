-- === ELEMENTAL PVP - With Cool Animations ===
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
local player_element = {}  -- Cache for faster access

-- Cool element selection animation
local function play_element_activation(player, elem)
    local pos = player:get_pos()
    if not pos then return end
    
    local data = elements[elem]
    
    -- Big vertical burst
    minetest.add_particlespawner({
        amount = 40,
        time = 0.8,
        minpos = pos + vector.new(-1, 0.5, -1),
        maxpos = pos + vector.new(1, 2.5, 1),
        minvel = {x=-3, y=6, z=-3},
        maxvel = {x=3, y=12, z=3},
        minacc = {x=0, y=-9, z=0},
        texture = data.particle,
        size = 5,
        glow = 8
    })
    
    -- Ring effect
    for i = 1, 6 do
        minetest.after(i/12, function()
            if player then
                minetest.add_particlespawner({
                    amount = 15,
                    time = 0.3,
                    minpos = player:get_pos() + vector.new(0,1,0),
                    maxpos = player:get_pos() + vector.new(0,1,0),
                    minvel = {x=-8, y=0, z=-8},
                    maxvel = {x=8, y=1, z=8},
                    texture = data.particle,
                    size = 3,
                    glow = 6
                })
            end
        end)
    end
end

-- === COMMAND ===
minetest.register_chatcommand("element", {
    params = "<fire|ice|wind|earth|lightning|water>",
    func = function(name, param)
        param = (param or ""):lower()
        if not elements[param] then
            return false, "Invalid element!"
        end
        local player = minetest.get_player_by_name(name)
        if not player then return false end

        player:get_meta():set_string("element", param)
        player_element[name] = param

        minetest.chat_send_player(name, minetest.colorize(elements[param].color, "⚡ You are now " .. elements[param].name .. " Elemental!"))
        play_element_activation(player, param)
        return true
    end
})

-- Passive Aura (light)
local function start_aura()
    minetest.register_globalstep(function(dtime)
        for _, player in ipairs(minetest.get_connected_players()) do
            local name = player:get_player_name()
            local elem = player_element[name] or player:get_meta():get_string("element")
            if elem and elements[elem] and math.random() < 0.12 then  -- Low chance = low lag
                local pos = player:get_pos()
                minetest.add_particle({
                    pos = pos + vector.new(math.random(-1,1), 1.2 + math.random(), math.random(-1,1)),
                    velocity = {x=0, y=1.5, z=0},
                    size = 2.5,
                    texture = elements[elem].particle,
                    expirationtime = 0.6,
                    glow = 4
                })
            end
        end
    end)
end

-- Get multiplier (safe)
local function get_multiplier(att, vic)
    if not att or not vic or att == "" or vic == "" then return 1.0 end
    if att == vic then return 1.0 end
    if advantage[att] == vic then return 1.85 end
    if advantage[vic] == att then return 0.55 end
    return 1.2
end

-- Punch + Impact Animation
minetest.register_on_punchplayer(function(player, hitter, _, _, _, damage)
    if not player or not hitter or not hitter:is_player() then return end

    local att_elem = hitter:get_meta():get_string("element")
    local vic_elem = player:get_meta():get_string("element")

    local mult = get_multiplier(att_elem, vic_elem)
    if mult > 1.0 then
        local extra = math.floor(damage * (mult - 1))
        if extra > 0 then
            player:set_hp(player:get_hp() - extra)
        end

        if mult > 1.5 then
            local pos = player:get_pos()
            minetest.add_particlespawner({
                amount = 14,
                time = 0.35,
                minpos = pos,
                maxpos = pos + vector.new(0.8,1.6,0.8),
                texture = elements[att_elem].particle,
                size = 4,
                glow = 8
            })
        end
    end
end)

-- === ABILITIES with Cool Animations ===
minetest.register_on_player_rightclick(function(player, pointed_thing)
    if not player then return end
    local name = player:get_player_name()
    if not name then return end

    local elem = player_element[name] or player:get_meta():get_string("element")
    if not elem or elem == "" then return end

    local now = minetest.get_us_time() / 1000000
    if (player_cooldown[name] or 0) > now then return end
    player_cooldown[name] = now + 3.0

    local pos = player:get_pos()
    if not pos then return end
    local dir = player:get_look_dir() or vector.new(0,0,1)

    local data = elements[elem]

    -- Cast Animation (Ring + Burst)
    minetest.add_particlespawner({
        amount = 20,
        time = 0.4,
        minpos = pos + vector.new(0,0.8,0),
        maxpos = pos + vector.new(0,1.2,0),
        minvel = {x=-7,y=0,z=-7},
        maxvel = {x=7,y=2,z=7},
        texture = data.particle,
        size = 3.5,
        glow = 6
    })

    -- Element Specific Abilities
    if elem == "fire" then
        local obj = minetest.add_entity(pos + vector.multiply(dir, 1.5), "elemental_pvp:fireball")
        if obj then obj:setvelocity(vector.multiply(dir, 28)) end

    elseif elem == "ice" then
        minetest.add_particlespawner({amount=25, time=0.9, minpos=pos-vector.new(6,1,6), maxpos=pos+vector.new(6,3,6), texture="default_ice.png", size=3})

    elseif elem == "wind" then
        minetest.add_particlespawner({amount=35, time=0.6, minpos=pos, maxpos=pos+vector.new(8,4,8), texture="default_grass.png", size=4})

    elseif elem == "earth" then
        minetest.set_node(pos + vector.new(0,-1,0), {name="default:stone"})

    elseif elem == "lightning" then
        local target = pos + vector.multiply(dir, 16)
        minetest.add_particlespawner({
            amount = 12, time = 0.5,
            minpos = target + vector.new(0,14,0),
            maxpos = target + vector.new(0,18,0),
            minvel = {x=0,y=-50,z=0},
            texture = "default_torch.png", size=7, glow=12
        })

    elseif elem == "water" then
        local obj = minetest.add_entity(pos + vector.multiply(dir, 1.5), "elemental_pvp:waterblast")
        if obj then obj:setvelocity(vector.multiply(dir, 24)) end
        player:set_hp(math.min(player:get_hp() + 4, player:get_hp_max()))
    end
end)

-- Fireball Entity with Trail
minetest.register_entity("elemental_pvp:fireball", {
    initial_properties = {visual = "sprite", textures = {"fire_basic_flame.png"}, visual_size = {x=1.1, y=1.1}},
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if pos then
            minetest.add_particle({pos=pos, size=6, texture="fire_basic_flame.png", expirationtime=0.15, glow=10})
        end
    end,
    on_punch = function(self, hitter)
        if hitter and hitter:is_player() then hitter:set_hp(hitter:get_hp() - 9) end
        self.object:remove()
    end
})

-- Waterblast Entity
minetest.register_entity("elemental_pvp:waterblast", {
    initial_properties = {visual = "sprite", textures = {"default_water.png"}, visual_size = {x=1.3, y=1.3}},
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if pos then
            minetest.add_particle({pos=pos, size=7, texture="default_water.png", expirationtime=0.2, glow=4})
        end
    end,
    on_punch = function(self, hitter)
        if hitter and hitter:is_player() then
            hitter:add_velocity({x=0, y=10, z=0})
            hitter:set_hp(hitter:get_hp() - 8)
        end
        self.object:remove()
    end
})

-- Cleanup
minetest.register_on_leaveplayer(function(player)
    if player then
        local name = player:get_player_name()
        player_cooldown[name] = nil
        player_element[name] = nil
    end
end)

minetest.register_on_joinplayer(function(player)
    minetest.after(1.5, function()
        if player then
            minetest.chat_send_player(player:get_player_name(), "🌊 Use /element <name> to choose your power!")
        end
    end)
end)

start_aura()  -- Start passive auras
print("[Elemental PVP] Loaded with Cool Animations!")
