local World = {}
World.__index = World

local function key(x, y)
    return x .. ":" .. y
end

function World.new(width, height, tileSize)
    return setmetatable({
        width = width,
        height = height,
        tileSize = tileSize or 16,
        time = 0,
        solid = {},
        moveableSolid = {},
        platform = {},
        ladder = {},
        ladderTop = {},
        rope = {},
        labels = {},
    }, World)
end

function World:set(kind, x, y, value)
    assert(self[kind], "Unknown platform-world cell kind: " .. tostring(kind))
    self[kind][key(x, y)] = value == nil and true or value
end

function World:remove(kind, x, y)
    assert(self[kind], "Unknown platform-world cell kind: " .. tostring(kind))
    self[kind][key(x, y)] = nil
end

function World:fill(kind, x, y, width, height)
    for tileY = y, y + height - 1 do
        for tileX = x, x + width - 1 do
            self:set(kind, tileX, tileY)
        end
    end
end

function World:has(kind, tileX, tileY)
    local cells = self[kind]
    return cells and cells[key(tileX, tileY)] ~= nil
end

function World:cellAt(kind, x, y)
    return self:has(kind, math.floor(x / self.tileSize), math.floor(y / self.tileSize))
end

function World:each(kind, callback)
    for cellKey, value in pairs(self[kind]) do
        local x, y = cellKey:match("^(-?%d+):(-?%d+)$")
        callback(tonumber(x), tonumber(y), value)
    end
end

function World:solidAtPoint(x, y)
    return self:cellAt("solid", x, y)
end

function World:climbableAtPoint(x, y)
    local tileX = math.floor(x / self.tileSize)
    local tileY = math.floor(y / self.tileSize)
    if self:has("rope", tileX, tileY) then
        return "rope", tileX, tileY
    end
    if self:has("ladder", tileX, tileY) or self:has("ladderTop", tileX, tileY) then
        return "ladder", tileX, tileY
    end
end

function World:overlaps(kind, left, top, right, bottom)
    local tileSize = self.tileSize
    local firstX = math.floor(left / tileSize)
    local lastX = math.floor((right - 0.001) / tileSize)
    local firstY = math.floor(top / tileSize)
    local lastY = math.floor((bottom - 0.001) / tileSize)
    for tileY = firstY, lastY do
        for tileX = firstX, lastX do
            if self:has(kind, tileX, tileY) then
                return true, tileX, tileY
            end
        end
    end
    return false
end

function World:collidesSolid(player, x, y)
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    return self:overlaps("solid", x - halfWidth, y + topOffset,
        x + halfWidth, y + bottomOffset)
end

function World:overlapsPlayer(kind, player, x, y)
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    return self:overlaps(kind, x - halfWidth, y + topOffset,
        x + halfWidth, y + bottomOffset)
end

function World:platformLanding(player, previousY, nextY)
    if player.dropThroughTimer > 0 then
        return nil
    end
    local halfWidth = player:getCollisionHalfWidth()
    local _, bottomOffset = player:getVerticalBounds()
    local previousBottom = previousY + bottomOffset
    local nextBottom = nextY + bottomOffset
    if nextBottom <= previousBottom then
        return nil
    end

    local tileSize = self.tileSize
    local firstX = math.floor((player.x - halfWidth) / tileSize)
    local lastX = math.floor((player.x + halfWidth - 1) / tileSize)
    local firstY = math.floor(previousBottom / tileSize)
    local lastY = math.floor(nextBottom / tileSize)
    for tileY = firstY, lastY do
        local platformTop = tileY * tileSize
        if previousBottom <= platformTop and nextBottom >= platformTop then
            for tileX = firstX, lastX do
                if self:has("platform", tileX, tileY) or self:has("ladderTop", tileX, tileY) then
                    return platformTop - bottomOffset
                end
            end
        end
    end
end

function World:groundBelow(player)
    if self:collidesSolid(player, player.x, player.y + 1) then
        return "solid"
    end
    if self:platformLanding(player, player.y, player.y + 1) then
        return "platform"
    end
end

function World:ledgeFor(player, direction)
    if self:solidAtPoint(player.x, player.y + 9) then
        return nil
    end
    local halfWidth = player:getCollisionHalfWidth()
    local sideX = player.x + direction * (halfWidth + 1)
    local gripY = player.y - 5
    if not self:solidAtPoint(sideX, gripY) then
        gripY = player.y - 6
    end
    local aboveY = player.y - 9
    if not self:solidAtPoint(sideX, gripY) or self:solidAtPoint(sideX, aboveY) then
        return nil
    end

    local tileX = math.floor(sideX / self.tileSize)
    local tileY = math.floor(gripY / self.tileSize)
    local tileLeft = tileX * self.tileSize
    local tileTop = tileY * self.tileSize
    return {
        x = direction > 0 and tileLeft - halfWidth or tileLeft + self.tileSize + halfWidth,
        y = tileTop + 8,
        direction = direction,
        tileX = tileX,
        tileY = tileY,
    }
end

function World.makeTestCourse()
    local world = World.new(40, 24, 16)
    world:fill("solid", 0, 22, 40, 2)

    world:fill("solid", 2, 18, 7, 1)
    world:fill("solid", 9, 19, 2, 3)

    world:fill("solid", 12, 17, 7, 1)
    world:fill("solid", 12, 12, 7, 1)
    world:remove("solid", 15, 17)
    world:remove("solid", 15, 12)
    world:fill("ladder", 15, 13, 1, 9)
    world:set("ladderTop", 15, 12)
    world:set("ladderTop", 15, 17)

    world:fill("solid", 20, 19, 5, 1)
    world:fill("rope", 23, 9, 1, 10)

    world:fill("solid", 27, 16, 4, 1)
    world:fill("solid", 31, 13, 6, 1)
    world:fill("solid", 36, 14, 1, 8)

    world.labels = {
        { x = 4 * 16, y = 17 * 16, text = "RUN / CROUCH" },
        { x = 14 * 16, y = 11 * 16, text = "LADDER" },
        { x = 22 * 16, y = 8 * 16, text = "ROPE" },
        { x = 30 * 16, y = 12 * 16, text = "LEDGES" },
    }
    return world
end

return World
