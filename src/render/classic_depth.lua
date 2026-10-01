-- Depths are from original-game-reference/source/extracted/spelunky/Objects/*.xml
-- and the tile_add calls in scrInitLevel, scrRoomGen and scrSetupWalls.
-- Add new Mines object kinds here after checking their original object XML.
local Depth = {
    BACKDROP = 10001,
    AMBIENT = 10002,
    TERRAIN = 100,
    CAVE_LIP = 3,
    PLAYER = 50,
    HELD_ITEM = 0,
    EFFECT = 1,
}

local entities = {
    entrance = 9000, exit = 9000,
    kali_head = 997, giant_tiki_head = 997,
    bones = 900, fake_bones = 900, chest = 900, locked_chest = 900, crate = 900,
    lamp = 201, web = 200, rope = 200, boulder = 200,
    rope_throw = 100,
    spikes = 120, sacrifice_altar = 110, altar_left = 110, altar_right = 110,
    shop_sign = 110, -- the k room marker creates oSign, not the 9004 dice-sign tile
    arrow_trap_left = 110, arrow_trap_right = 110,
    emerald_big = 101, sapphire_big = 101, ruby_big = 101,
    mattock = 101, key = 101, bow = 101, machete = 101,
    pistol = 101, shotgun = 101, teleporter = 101, web_cannon = 101,
    rock = 100, jar = 100, skull = 100, gold_idol = 100,
    gold_bar = 100, gold_bars = 100, damsel = 100,
    bomb_bag = 100, bomb_box = 100, rope_pile = 100,
    spectacles = 100, compass = 100, cape = 100, jetpack = 100,
    gloves = 100, mitt = 100, parachute = 100, paste = 100,
    spike_shoes = 100, spring_shoes = 100, kapala = 100, udjat_eye = 100,
    die = 100,
    snake = 60, caveman = 60, skeleton = 60, shopkeeper = 60,
    bat = 40, spider = 40, giant_spider = 40, scarab = 40,
    ghost = 0,
    arrow = 100, bullet = 0, pellet = 0, web_ball = 1,
}

function Depth.entity(kind, state)
    if kind == "bomb" then
        if state == "sticky" then return 1 end
        if state == "armed" then return 49 end
        return 99
    end
    if kind == "player" then
        if state == "exiting" or state == "lava" then return 999 end
        return Depth.PLAYER
    end
    local depth = entities[kind]
    assert(depth, "Missing Classic draw depth for " .. tostring(kind))
    return depth
end

function Depth.heldItem(player)
    if player.state == "climbing" and (player.equipment.jetpack or player.equipment.cape) then
        return 51
    end
    return Depth.HELD_ITEM
end

function Depth.tile(kind)
    if kind == "ladder" or kind == "ladder_top" then return 1000 end
    if kind == "block" or kind == "push_block" or kind == "smooth_brick" then return 110 end
    if kind == "brick" or kind == "solid" then return 100 end
    if kind == "empty" then return nil end
    error("Missing Classic tile depth for " .. tostring(kind))
end

return Depth
