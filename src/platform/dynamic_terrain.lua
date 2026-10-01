local DynamicTerrain = {}
local Depth = require("src.render.classic_depth")

local function moveHorizontal(world, block)
    if not block.targetX then return end
    local direction = block.targetX > block.x and 1 or -1
    if not world:solidRect(block.x + direction, block.y,
        block.x + direction + block.width, block.y + block.height, block) then
        block.x = block.x + direction
    else
        block.targetX = nil
        block.vx = 0
        return
    end
    if block.x == block.targetX then
        block.targetX = nil
        block.vx = 0
    end
end

local function moveVertical(world, block)
    block.vy = math.min(10, (block.vy or 0) + (block.falling and 1 or 0))
    local pixels = math.floor(math.abs(block.vy))
    local direction = block.vy < 0 and -1 or 1
    for _ = 1, pixels do
        local nextY = block.y + direction
        if world:solidRect(block.x, nextY, block.x + block.width,
            nextY + block.height, block) then
            block.vy = 0
            return
        end
        block.y = nextY
    end
end

function DynamicTerrain.update(world)
    for _, block in ipairs(world.dynamicSolids) do
        if block.alive ~= false then
            if block.moveable and not block.falling then
                if not world:solidRect(block.x, block.y + 1,
                    block.x + block.width, block.y + block.height + 1, block) then
                    block.falling = true
                end
            end

            moveHorizontal(world, block)
            if block.falling then moveVertical(world, block) end
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
