local Boulder = { depth = 200 }

function Boulder.spawn(self, trap)
    local boulder = {
        kind = "boulder",
        x = trap.x, y = trap.y, vx = 0, vy = 0, alive = true, bounced = false,
        animation = 0,
    }
    boulder.solid = self.world:addDynamicSolid({
        kind = "boulder", x = boulder.x - 14, y = boulder.y - 16,
        width = 28, height = 32, properties = { invincible = true },
    })
    self.boulders[#self.boulders + 1] = boulder
end

local SourceMath = require("src.platform.source_math")
local function boulderPixels(velocity, time)
    return math.abs(SourceMath.halfUpPixels(velocity, time)), velocity < 0 and -1 or 1
end

local function slowBoulder(boulder)
    if boulder.vx > 0 then boulder.vx = math.max(0, boulder.vx - 0.1)
    elseif boulder.vx < 0 then boulder.vx = math.min(0, boulder.vx + 0.1) end
    if math.abs(boulder.vx) < 1 then boulder.vx = 0 end
end

local function movePlayerWithBoulder(world, boulder, player, dx, dy)
    if not player or player:isDead() then return true end
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    local playerLeft, playerRight = player.x - halfWidth, player.x + halfWidth
    local playerTop, playerBottom = player.y + topOffset, player.y + bottomOffset
    local overBoulder = playerRight > boulder.x - 14 and playerLeft < boulder.x + 14
    local standing = overBoulder and math.abs(playerBottom - (boulder.y - 16)) <= 1
    local touched = playerRight > boulder.x + dx - 14
        and playerLeft < boulder.x + dx + 14
        and playerBottom > boulder.y + dy - 16
        and playerTop < boulder.y + dy + 16
    if not standing and (not touched or dy < 0) then return true end
    local nextX, nextY = player.x + dx, player.y + dy
    if world:solidRect(nextX - halfWidth, nextY + topOffset,
        nextX + halfWidth, nextY + bottomOffset, boulder.solid) then return false end
    player.x, player.y = nextX, nextY
    return true
end

function Boulder.move(self, boulder, time, player)
    local xSteps, xDirection = boulderPixels(boulder.vx, time)
    for _ = 1, xSteps do
        local nextX = boulder.x + xDirection
        if self.world:solidRect(nextX - 14, boulder.y - 11,
            nextX + 14, boulder.y + 16, boulder.solid) then
            -- getIdCollisionRight/Left checks from top+5, not the top edge.
            local sparedFloor = false
            local protectedSolid = false
            local edgeX = xDirection > 0 and nextX + 13 or nextX - 14
            local tileX = math.floor(edgeX / self.world.tileSize)
            for tileY = math.floor((boulder.y - 11) / self.world.tileSize),
                math.floor((boulder.y + 15) / self.world.tileSize) do
                if self.world:has("solid", tileX, tileY)
                    and math.abs(boulder.vx) >= 1 then
                    if self.world:isProtectedCell(tileX, tileY) then
                        protectedSolid = true
                    elseif tileY * self.world.tileSize > boulder.y + 13 then
                        boulder.y = boulder.y - 1
                        slowBoulder(boulder)
                        sparedFloor = true
                    else
                        local destroyed = self.world:destroyTerrain(tileX * self.world.tileSize
                            + self.world.tileSize / 2,
                            tileY * self.world.tileSize + self.world.tileSize / 2, 0)
                        if #destroyed > 0 then
                            self.world:cleanBoulderTerrain(tileX*16, tileY*16, 16)
                            slowBoulder(boulder)
                            if self.crunchSound then self.crunchSound:clone():play() end
                        end
                    end
                end
            end
            if math.abs(boulder.vx) >= 1 then
                for _, block in ipairs(self.world.dynamicSolids) do
                    if block ~= boulder.solid and block.alive ~= false and block.x < nextX + 14
                        and block.x + block.width > nextX - 14
                        and block.y < boulder.y + 16
                        and block.y + block.height > boulder.y - 16 then
                        if block.properties
                            and (block.properties.invincible or block.properties.fixed) then
                            protectedSolid = true
                        elseif block.y > boulder.y + 13 then
                            boulder.y = boulder.y - 1
                            slowBoulder(boulder)
                            sparedFloor = true
                        else
                            self.world:cleanBoulderTerrain(block.x, block.y, block.width)
                            self.world:removeDynamicSolid(block)
                            slowBoulder(boulder)
                            if self.crunchSound then self.crunchSound:clone():play() end
                        end
                    end
                end
            end
            if self.world:solidRect(nextX - 14, boulder.y - 11,
                nextX + 14, boulder.y + 16, boulder.solid) then
                if protectedSolid or not sparedFloor then boulder.vx = -boulder.vx * 0.5 end
                break
            end
        end
        if not movePlayerWithBoulder(self.world, boulder, player, xDirection, 0) then break end
        boulder.x = nextX
    end
    local ySteps, yDirection = boulderPixels(boulder.vy, time)
    for _ = 1, ySteps do
        if self.world:solidRect(boulder.x - 14, boulder.y + yDirection - 16,
            boulder.x + 14, boulder.y + yDirection + 16, boulder.solid) then
            break
        end
        if not movePlayerWithBoulder(self.world, boulder, player, 0, yDirection) then break end
        boulder.y = boulder.y + yDirection
    end
end

function Boulder.update(self, boulder, player, enemies)
    -- Classic moves every oMovingSolid in gameStepEvent, then oBoulder calls
    -- moveTo a second time in its own Step event. Both use the same game time.
    boulder.tick = (boulder.tick or 0) + 1
    local time = self.world.time > 0 and self.world.time or boulder.tick
    self:moveBoulder(boulder, time, player)
    self:moveBoulder(boulder, time)
    if boulder.vy < 8 then boulder.vy = boulder.vy + 0.6 end

    if boulder.x - 17 <= self.world.tileSize and boulder.vx < 0 then
        boulder.x = boulder.x + 1
        boulder.vx = -boulder.vx
    elseif boulder.x + 17 >= (self.world.width + 1) * self.world.tileSize
        and boulder.vx > 0 then
        boulder.x = boulder.x - 1
        boulder.vx = -boulder.vx
    end
    if boulder.vy < 0 and self.world:solidRect(boulder.x - 14,
        boulder.y - 17, boulder.x + 14, boulder.y - 16, boulder.solid) then
        boulder.vy = -boulder.vy * 0.8
    end
    if self.world:solidRect(boulder.x - 14, boulder.y + 16,
        boulder.x + 14, boulder.y + 17, boulder.solid) then
        boulder.vy = boulder.vy > 3 and -boulder.vy * 0.3 or 0
        boulder.vx = boulder.vx * 0.99
        if not boulder.bounced and boulder.vx == 0 then
            boulder.vx = player.x < boulder.x and -4.5 or 4.5
            boulder.bounced = true
        end
        if math.abs(boulder.vx) < 0.5 then boulder.vx = 0 end
    end
    if not self.world:solidRect(boulder.x, boulder.y + 16,
        boulder.x + 0.001, boulder.y + 16.001, boulder.solid) then
        local left = self.world:solidRect(boulder.x - 16, boulder.y - 16,
            boulder.x - 8, boulder.y + 16, boulder.solid)
        local right = self.world:solidRect(boulder.x + 8, boulder.y - 16,
            boulder.x + 16, boulder.y + 16, boulder.solid)
        if left and not right then boulder.x = boulder.x + 1
        elseif right and not left then boulder.x = boulder.x - 1 end
    end
    if player.x >= boulder.x - 14 and player.x < boulder.x + 14
        and player.y >= boulder.y - 16 and player.y < boulder.y + 16 then
        player:kill("crushed", 0, -3)
    end
    for _, enemy in ipairs(enemies or {}) do
        if enemy.alive and math.abs(enemy.x - boulder.x) < 20
            and math.abs(enemy.y - boulder.y) < 20 then enemy:damage(99) end
    end
    if boulder.solid then
        boulder.solid.x, boulder.solid.y = boulder.x - 14, boulder.y - 16
    end
    boulder.animation = (boulder.animation or 0) + math.abs(boulder.vx) / 5
    if boulder.y > self.world.height * self.world.tileSize + 48 then
        boulder.alive = false
        if boulder.solid then self.world:removeDynamicSolid(boulder.solid) end
    end
end


function Boulder.draw(system, boulder)
    love.graphics.setColor(1, 1, 1, 1)
    local frames = boulder.vx < 0 and system.assets.boulderLeft
        or boulder.vx > 0 and system.assets.boulderRight
    local image = frames and frames[(math.floor((boulder.animation or 0)) % 4) + 1]
        or system.assets.boulder
    love.graphics.draw(image, math.floor(boulder.x), math.floor(boulder.y), 0, 1, 1, 16, 16)
end

function Boulder.loadAssets(assets)
    local Assets = require("src.platform.object_assets")
    assets.boulder = Assets.image("Traps", "sBoulder")
    assets.boulderLeft, assets.boulderRight = {}, {}
    for frame = 0, 3 do
        assets.boulderLeft[frame + 1] = Assets.image("Traps", "sBoulderRotateL", frame)
        assets.boulderRight[frame + 1] = Assets.image("Traps", "sBoulderRotateR", frame)
    end
end

return Boulder
