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

local function playerWouldOverlap(player, block, blockY)
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    return blockY + block.height > player.y + topOffset
        and blockY < player.y + bottomOffset
        and block.x + block.width > player.x - halfWidth
        and block.x < player.x + halfWidth
end

local function playerCanMoveVertically(world, player, direction, ignoredBlock)
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    local left = player.x - halfWidth
    local top = player.y + direction + topOffset
    local right = player.x + halfWidth
    local bottom = player.y + direction + bottomOffset
    return not world:staticSolidRect(left, top, right, bottom)
        and not world:dynamicSolidAt(left, top, right, bottom, false, ignoredBlock)
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
        -- Dark falling platforms inherit oMovingSolid. The original engine
        -- pushes the character one pixel and stops the solid if that push
        -- would collide with another solid. Gravity-driven oMoveableSolid
        -- blocks do not use this path; their overlap is handled as crushing.
        if player and block.kind == "falling" and playerWouldOverlap(player, block, nextY) then
            if not playerCanMoveVertically(world, player, direction, block) then
                block.vy = 0
                return
            end
            player.y = player.y + direction
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
