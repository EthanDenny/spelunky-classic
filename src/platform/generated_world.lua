local World = require("src.platform.world")

local GeneratedWorld = {}

local Tiles = require("src.platform.tiles.types")
local Objects = require("src.platform.objects")

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
            local definition = assert(Tiles[tile.kind], "Unknown tile: " .. tostring(tile.kind))
            if definition.dynamic then
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
                    moveable = definition.moveable,
                    vx = 0,
                    vy = 0,
                })
                level.tiles[y + 1][x + 1] = { kind = "empty" }
            elseif definition.worldLayer then
                world:set(definition.worldLayer, x, y)
            end
        end
    end

    for _, entity in ipairs(level.entities or {}) do
        local definition = Objects[entity.kind]
        if not entity.destroyed and definition and definition.worldLayer then
            for offset = 0, (definition.cellsWide or 1) - 1 do
                world:set(definition.worldLayer, math.floor(entity.x) + offset,
                    math.floor(entity.y), entity)
            end
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
