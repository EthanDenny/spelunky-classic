local World = require("src.platform.world")

local GeneratedWorld = {}

local SOLID_TILES = {
    brick = true,
    block = true,
    smooth_brick = true,
    solid = true,
    push_block = true,
    falling = true,
}

-- These generated entities replace a solid tile in the original generator.
-- Treating them as terrain keeps the traversal map intact until their active
-- trap behavior is implemented in the integration screen.
local SOLID_ENTITIES = {
    arrow_trap_left = true,
    arrow_trap_right = true,
    barrier_emitter = true,
    ceiling_trap = true,
    giant_tiki_head = true,
    smash_trap = true,
    thwomp_trap = true,
    trap_block = true,
}

function GeneratedWorld.fromLevel(level)
    assert(level and level.tiles, "A generated level is required")
    local world = World.new(level.width, level.height, level.tileSize or 16)

    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            local tile = level.tiles[y + 1][x + 1]
            if SOLID_TILES[tile.kind] then
                world:set("solid", x, y)
                if tile.kind == "push_block" then world:set("moveableSolid", x, y) end
            elseif tile.kind == "ladder" then
                world:set("ladder", x, y)
            elseif tile.kind == "ladder_top" then
                world:set("ladderTop", x, y)
            end
        end
    end

    for _, entity in ipairs(level.entities or {}) do
        if SOLID_ENTITIES[entity.kind] then
            world:set("solid", math.floor(entity.x), math.floor(entity.y))
        end
    end

    return world
end

function GeneratedWorld.spawnPoint(level)
    assert(level and level.entrance, "Generated level has no entrance")
    local tileSize = level.tileSize or 16
    return level.entrance.x * tileSize + tileSize / 2,
        level.entrance.y * tileSize + tileSize / 2
end

return GeneratedWorld
