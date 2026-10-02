local PushBlock = { solid = true, dynamic = true, moveable = true, depth = 110, image = "block" }

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

function PushBlock.update(world, block)
    if block.moveable and not block.falling then
        if not world:solidRect(block.x, block.y + 1,
            block.x + block.width, block.y + block.height + 1, block) then
            block.falling = true
        end
    end
    if block.falling then moveVertical(world, block) end
end

return PushBlock
