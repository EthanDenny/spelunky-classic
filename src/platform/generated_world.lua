local World = require("src.platform.world")

local GeneratedWorld = {}

local SOLID_TILES = {
    brick = true,
    block = true,
    smooth_brick = true,
    solid = true,
    push_block = true,
}

-- These generated entities replace a solid tile in the original generator.
-- Treating them as terrain keeps the traversal map intact until their active
-- trap behavior is implemented in the integration screen.
local SOLID_ENTITIES = {
    arrow_trap_left = true,
    arrow_trap_right = true,
    giant_tiki_head = true,
}

function GeneratedWorld.fromLevel(level)
    assert(level and level.tiles, "A generated level is required")
    for _, cell in ipairs(level._dynamicCells or {}) do
        level.tiles[cell.y + 1][cell.x + 1] = cell.tile
    end
    level._dynamicCells = {}
    local world = World.new(level.width, level.height, level.tileSize or 16)
    world.level = level

    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            local tile = level.tiles[y + 1][x + 1]
            if tile.kind == "push_block" then
                level._dynamicCells[#level._dynamicCells + 1] = { x = x, y = y, tile = tile }
                world:addDynamicSolid({
                    x = x * world.tileSize,
                    y = y * world.tileSize,
                    sourceX = x,
                    sourceY = y,
                    kind = tile.kind,
                    style = tile.style,
                    baseStyle = tile.baseStyle,
                    properties = tile.properties or {},
                    moveable = tile.kind == "push_block",
                    vx = 0,
                    vy = 0,
                })
                level.tiles[y + 1][x + 1] = { kind = "empty" }
            elseif SOLID_TILES[tile.kind] then
                world:set("solid", x, y)
            elseif tile.kind == "ladder" then
                world:set("ladder", x, y)
            elseif tile.kind == "ladder_top" then
                world:set("ladderTop", x, y)
            end
        end
    end

    for _, entity in ipairs(level.entities or {}) do
        if SOLID_ENTITIES[entity.kind] then
            world:set("solid", math.floor(entity.x), math.floor(entity.y), entity)
        elseif entity.kind == "web" then
            world:set("web", math.floor(entity.x), math.floor(entity.y), entity)
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
