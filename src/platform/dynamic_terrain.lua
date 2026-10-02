local DynamicTerrain = {}
local Depth = require("src.render.classic_depth")
local Tiles = require("src.platform.tiles.types")
local PushBlock = require("src.platform.tiles.push_block")

function DynamicTerrain.update(world)
    for _, block in ipairs(world.dynamicSolids) do
        if block.alive ~= false then
            local definition = Tiles[block.kind]
            local update = definition and definition.update or PushBlock.update
            update(world, block)
        end
    end
end

function DynamicTerrain.submit(queue, world, renderer)
    for _, block in ipairs(world.dynamicSolids) do
        if block.alive ~= false and block.kind ~= "boulder" then
            local current = block
            queue:add(Depth.tile(current.kind), function()
                renderer:drawTile(current, math.floor(current.x), math.floor(current.y))
            end)
        end
    end
end

return DynamicTerrain
