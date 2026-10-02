-- Depths are from original-game-reference/source/extracted/spelunky/Objects/*.xml
-- and the tile_add calls in scrInitLevel, scrRoomGen and scrSetupWalls.
-- Per-object modules own their depths; this module resolves them for the queue.
local Depth = {
    BACKDROP = 10001,
    AMBIENT = 10002,
    TERRAIN = 100,
    CAVE_LIP = 3,
    PLAYER = 50,
    HELD_ITEM = 0,
    EFFECT = 1,
}

function Depth.entity(kind, state)
    if kind == "player" then return require("src.platform.player").drawDepth(state) end
    local definition = require("src.platform.objects")[kind]
    local depth = definition and definition.depth
    if type(depth) == "function" then depth = depth(state) end
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
    local definition = require("src.platform.tiles.types")[kind]
    assert(definition, "Missing Classic tile depth for " .. tostring(kind))
    return definition.depth
end

return Depth
