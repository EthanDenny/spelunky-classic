local World = {}
World.__index = World

local function key(x, y)
    return x .. ":" .. y
end

local function destroySpikesAbove(world, left, top, width)
    if not world.level then return end
    local pointX, pointY = left + width / 2, top - 1
    for _, entity in ipairs(world.level.entities or {}) do
        if entity.kind == "spikes" and not entity.destroyed
            and pointX >= entity.x * world.tileSize
            and pointX < (entity.x + 1) * world.tileSize
            and pointY >= entity.y * world.tileSize
            and pointY < (entity.y + 1) * world.tileSize then
            entity.destroyed = true
        end
    end
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
        water = {},
        dynamicWebs = {},
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
    local value = self[kind][key(x, y)]
    local existed = value ~= nil
    self[kind][key(x, y)] = nil
    if kind == "solid" and existed then
        local row = self.level and self.level.tiles and self.level.tiles[y+1]
        local tile = row and row[x+1]
        self.destructions = self.destructions or {}
        self.destructions[#self.destructions+1] = { x = x, y = y, tile = tile,
            entity = type(value) == "table" and value or nil }
        if row and tile then row[x+1] = { kind = "empty" } end
    end
    if kind == "solid" and existed and self.level then
        local tile = self.destructions[#self.destructions].tile
        if tile and tile.shopWall then
            self.destroyedShopWalls = self.destroyedShopWalls or {}
            self.destroyedShopWalls[#self.destroyedShopWalls + 1] = {
                x = (x + 0.5) * self.tileSize, y = (y + 0.5) * self.tileSize,
            }
        end
        -- Cave lips are generated one cell above their supporting brick.
        -- The original removes that depth-3 tile when the solid is destroyed.
        for index = #(self.level.decorations or {}), 1, -1 do
            local decoration = self.level.decorations[index]
            if decoration.x == x and decoration.y + 1 == y then
                table.remove(self.level.decorations, index)
            end
        end
        -- oSolid's Destroy event also destroys oSpikes immediately above it.
        destroySpikesAbove(self, x * self.tileSize, y * self.tileSize, self.tileSize)
        if type(value) == "table" then
            value.destroyed = true
            -- A two-cell entity such as the sacrifice altar must not leave
            -- its second collision cell behind after the object is destroyed.
            for cell, occupant in pairs(self.solid) do
                if occupant == value then self.solid[cell] = nil end
            end
        end
    end
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

function World:webAtPoint(x, y)
    for _, web in ipairs(self.dynamicWebs) do
        if x >= web.x and x < web.x + 16
            and y >= web.y and y < web.y + 16 then
            return true
        end
    end
    return self:cellAt("web", x, y)
end

function World:damageWebAtPoint(x, y, damage)
    damage = damage or 1
    for index, web in ipairs(self.dynamicWebs) do
        if x >= web.x and x < web.x + 16 and y >= web.y and y < web.y + 16 then
            web.life = (web.life or 12) - damage
            if web.life <= 1 then
                web.destroyed = true
                table.remove(self.dynamicWebs, index)
            end
            return true
        end
    end
    local tileX, tileY = math.floor(x / self.tileSize), math.floor(y / self.tileSize)
    local web = self.web[key(tileX, tileY)]
    if web then
        if type(web) ~= "table" then
            web = { life = 12 }
            self.web[key(tileX, tileY)] = web
        end
        web.life = (web.life or 12) - damage
        if web.life <= 1 then
            web.destroyed = true
            self:remove("web", tileX, tileY)
        end
        return true
    end
    return false
end

function World:webRect(left, top, right, bottom)
    if self:overlaps("web", left, top, right, bottom) then return true end
    for _, web in ipairs(self.dynamicWebs) do
        if right > web.x and left < web.x + 16
            and bottom > web.y and top < web.y + 16 then return true end
    end
    return false
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
    if block.alive == false then return end
    if block.kind ~= "boulder" then
        self.destructions = self.destructions or {}
        self.destructions[#self.destructions+1] = { entity = block,
            x = block.x/16, y = block.y/16, pixelX = block.x+block.width/2, pixelY = block.y+block.height/2 }
    end
    block.alive = false
    if block.kind ~= "boulder" then
        destroySpikesAbove(self, block.x, block.y, block.width)
    end
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

function World:tryPush(player, direction, block)
    if direction == 0 then return false end
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    block = block or self:dynamicSolidAt(
        player.x + direction - halfWidth,
        player.y + topOffset,
        player.x + direction + halfWidth,
        player.y + bottomOffset,
        true)
    if not block or not block.moveable then return false end

    local destinationX = block.x + direction
    if self:staticSolidRect(destinationX, block.y,
        destinationX + block.width, block.y + block.height)
        or self:dynamicSolidAt(destinationX, block.y,
            destinationX + block.width, block.y + block.height, false, block) then
        return false
    end
    block.x = destinationX
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
                local entity = self.solid[key(tileX, tileY)]
                self:remove("solid", tileX, tileY)
                self:remove("moveableSolid", tileX, tileY)
                if self.level and self.level.tiles[tileY + 1] then
                    self.level.tiles[tileY + 1][tileX + 1] = { kind = "empty" }
                end
                destroyed[#destroyed + 1] = { x = tileX, y = tileY,
                    entity = type(entity) == "table" and entity or self.destructions[#self.destructions].tile }
            end
        end
    end
    for _, block in ipairs(self.dynamicSolids) do
        local dx = block.x + block.width / 2 - centerX
        local dy = block.y + block.height / 2 - centerY
        if block.alive ~= false and block.kind ~= "boulder"
            and dx * dx + dy * dy <= (radius + 8) ^ 2 then
            self:removeDynamicSolid(block)
            destroyed[#destroyed + 1] = {
                x = math.floor(block.x / tileSize),
                y = math.floor(block.y / tileSize),
                pixelX = block.x + block.width / 2,
                pixelY = block.y + block.height / 2,
            }
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

function World:ledgeFor(player, direction, wallGrip)
    if not wallGrip and self:solidAtPoint(player.x, player.y + 9) then
        return nil
    end
    local sideX = player.x + direction * 9
    local gripY = player.y - 5
    if not self:solidAtPoint(sideX, gripY) then
        gripY = player.y - 6
    end
    local aboveY = player.y - 9
    if not self:solidAtPoint(sideX, gripY)
        or (not wallGrip and self:solidAtPoint(sideX, aboveY)) then
        return nil
    end

    local tileX = math.floor(sideX / self.tileSize)
    local tileY = math.floor(gripY / self.tileSize)
    return {
        x = player.x,
        y = math.floor(player.y / 8 + 0.5) * 8,
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
