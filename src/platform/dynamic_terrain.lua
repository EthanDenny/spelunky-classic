local DynamicTerrain = {}

local function playerStandingOn(player, block)
    local halfWidth = player:getCollisionHalfWidth()
    local _, bottomOffset = player:getVerticalBounds()
    local bottom = player.y + bottomOffset
    return player.x + halfWidth > block.x and player.x - halfWidth < block.x + block.width
        and bottom >= block.y - 1 and bottom <= block.y + 2 and player.vy >= 0
end

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

local function moveVertical(world, block, player)
    block.vy = math.min(10, (block.vy or 0) + (block.falling and 1 or 0))
    local pixels = math.floor(math.abs(block.vy))
    local direction = block.vy < 0 and -1 or 1
    for _ = 1, pixels do
        local nextY = block.y + direction
        if world:solidRect(block.x, nextY, block.x + block.width,
            nextY + block.height, block) then
            if block.kind == "falling" and block.falling then
                block.alive = false
            end
            block.vy = 0
            return
        end
        if player and nextY + block.height > player.y - 8
            and nextY < player.y + 8
            and block.x + block.width > player.x - player:getCollisionHalfWidth()
            and block.x < player.x + player:getCollisionHalfWidth() then
            player:hurt(block.x + block.width / 2)
        end
        block.y = nextY
    end
end

function DynamicTerrain.update(world, player)
    for _, block in ipairs(world.dynamicSolids) do
        if block.alive ~= false then
            local standing = playerStandingOn(player, block)
            if block.thinIce and standing and not block.falling then
                block.thickness = (block.thickness or 60) - 2
                if block.thickness <= 0 then
                    block.alive = false
                end
            elseif block.trigger and not block.falling then
                if standing then block.trigger = block.trigger - 1
                elseif block.trigger < 20 then block.trigger = block.trigger + 1 end
                if block.trigger <= 0 then block.falling = true end
            elseif block.moveable and not block.falling then
                if not world:solidRect(block.x, block.y + 1,
                    block.x + block.width, block.y + block.height + 1, block) then
                    block.falling = true
                end
            end

            moveHorizontal(world, block)
            if block.falling then moveVertical(world, block, player) end
        end
    end
end

function DynamicTerrain.draw(world, renderer)
    for _, block in ipairs(world.dynamicSolids) do
        if block.alive ~= false then
            renderer:drawTile({
                kind = block.kind,
                style = block.style,
                baseStyle = block.baseStyle,
                properties = block.properties,
            }, math.floor(block.x), math.floor(block.y))
        end
    end
end

return DynamicTerrain
