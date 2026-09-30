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
        web = {},
        dynamicSolids = {},
        labels = {},
    }, World)
end

function World:set(kind, x, y, value)
    assert(self[kind], "Unknown platform-world cell kind: " .. tostring(kind))
    self[kind][key(x, y)] = value == nil and true or value
    if self.playtestLog then self.playtestLog:record("world_cell", {
        action = "set", kind = kind, x = x, y = y, value = self[kind][key(x, y)], worldTime = self.time,
    }) end
end

function World:remove(kind, x, y)
    assert(self[kind], "Unknown platform-world cell kind: " .. tostring(kind))
    local existed = self[kind][key(x, y)] ~= nil
    self[kind][key(x, y)] = nil
    if existed and self.playtestLog then self.playtestLog:record("world_cell", {
        action = "remove", kind = kind, x = x, y = y, worldTime = self.time,
    }) end
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
    if self:cellAt("solid", x, y) then return true end
    return self:dynamicSolidAt(x, y, x + 0.001, y + 0.001) ~= nil
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
    if kind == "solid" or kind == "moveableSolid" then
        for _, block in ipairs(self.dynamicSolids) do
            if block.alive ~= false and (kind ~= "moveableSolid" or block.moveable)
                and right > block.x and left < block.x + block.width
                and bottom > block.y and top < block.y + block.height then
                return true, block
            end
        end
    end
    return false
end

function World:addDynamicSolid(block)
    block.width = block.width or self.tileSize
    block.height = block.height or self.tileSize
    block.alive = block.alive ~= false
    self.dynamicSolids[#self.dynamicSolids + 1] = block
    if self.playtestLog then self.playtestLog:record("dynamic_solid_added", {
        index = #self.dynamicSolids, kind = block.kind, x = block.x, y = block.y,
        width = block.width, height = block.height, worldTime = self.time,
    }) end
    return block
end

function World:removeDynamicSolid(block)
    block.alive = false
    if self.playtestLog then self.playtestLog:record("dynamic_solid_removed", {
        kind = block.kind, x = block.x, y = block.y, worldTime = self.time,
    }) end
end

function World:dynamicSolidAt(left, top, right, bottom, moveableOnly, ignored)
    for _, block in ipairs(self.dynamicSolids) do
        if block ~= ignored and block.alive ~= false and (not moveableOnly or block.moveable)
            and right > block.x and left < block.x + block.width
            and bottom > block.y and top < block.y + block.height then
            return block
        end
    end
end

function World:staticSolidRect(left, top, right, bottom)
    local tileSize = self.tileSize
    local firstX = math.floor(left / tileSize)
    local lastX = math.floor((right - 0.001) / tileSize)
    local firstY = math.floor(top / tileSize)
    local lastY = math.floor((bottom - 0.001) / tileSize)
    for tileY = firstY, lastY do
        for tileX = firstX, lastX do
            if self:has("solid", tileX, tileY) then return true, tileX, tileY end
        end
    end
    return false
end

function World:solidRect(left, top, right, bottom, ignored)
    local hit = self:staticSolidRect(left, top, right, bottom)
    if hit then return true end
    return self:dynamicSolidAt(left, top, right, bottom, false, ignored) ~= nil
end

function World:tryPush(player, direction)
    if direction == 0 then return false end
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    local block = self:dynamicSolidAt(
        player.x + direction - halfWidth,
        player.y + topOffset,
        player.x + direction + halfWidth,
        player.y + bottomOffset,
        true)
    if not block or block.targetX or math.abs(block.vy or 0) > 0.01 then return false end

    local destinationX = block.x + direction * self.tileSize
    if self:staticSolidRect(destinationX, block.y,
        destinationX + block.width, block.y + block.height)
        or self:dynamicSolidAt(destinationX, block.y,
            destinationX + block.width, block.y + block.height, false, block) then
        return false
    end
    block.targetX = destinationX
    block.vx = direction
    return true
end

function World:isProtectedCell(tileX, tileY)
    if tileX <= 0 or tileY <= 0 or tileX >= self.width - 1 or tileY >= self.height - 1 then
        return true
    end
    if not self.level then return false end
    local row = self.level.tiles[tileY + 1]
    local tile = row and row[tileX + 1]
    return tile and tile.properties and (tile.properties.invincible or tile.properties.fixed)
end

function World:destroyTerrain(centerX, centerY, radius)
    radius = radius or 24
    local destroyed = {}
    local tileSize = self.tileSize
    local firstX = math.floor((centerX - radius) / tileSize)
    local lastX = math.floor((centerX + radius) / tileSize)
    local firstY = math.floor((centerY - radius) / tileSize)
    local lastY = math.floor((centerY + radius) / tileSize)
    for tileY = firstY, lastY do
        for tileX = firstX, lastX do
            local dx = tileX * tileSize + tileSize / 2 - centerX
            local dy = tileY * tileSize + tileSize / 2 - centerY
            if dx * dx + dy * dy <= (radius + tileSize * 0.35) ^ 2
                and self:has("solid", tileX, tileY) and not self:isProtectedCell(tileX, tileY) then
                self:remove("solid", tileX, tileY)
                self:remove("moveableSolid", tileX, tileY)
                if self.level and self.level.tiles[tileY + 1] then
                    self.level.tiles[tileY + 1][tileX + 1] = { kind = "empty" }
                end
                destroyed[#destroyed + 1] = { x = tileX, y = tileY }
            end
        end
    end
    for _, block in ipairs(self.dynamicSolids) do
        local dx = block.x + block.width / 2 - centerX
        local dy = block.y + block.height / 2 - centerY
        if block.alive ~= false and dx * dx + dy * dy <= (radius + 8) ^ 2 then
            block.alive = false
        end
    end
    return destroyed
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
    world:fill("solid", 0, 0, world.width, 1)
    world:fill("solid", 0, 1, 1, world.height - 1)
    world:fill("solid", world.width - 1, 1, 1, world.height - 1)

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
