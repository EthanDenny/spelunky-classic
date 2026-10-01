local TrapSystem = {}
TrapSystem.__index = TrapSystem
local Depth = require("src.render.classic_depth")
local Item = require("src.platform.item")

local TRAP_KINDS = {
    arrow_trap_left = true,
    arrow_trap_right = true,
    giant_tiki_head = true,
}

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function imagePath(group, sprite)
    return "original-game-reference/source/extracted/spelunky/Sprites/" .. group .. "/"
        .. sprite .. ".images/image 0.png"
end

local function clearLine(world, x1, x2, y)
    local direction = x2 < x1 and -4 or 4
    local x = x1
    while (direction < 0 and x > x2) or (direction > 0 and x < x2) do
        if world:solidAtPoint(x, y) then return false end
        x = x + direction
    end
    return true
end

function TrapSystem.new(world, level, renderer)
    local self = setmetatable({
        world = world,
        renderer = renderer,
        traps = {},
        projectiles = {},
        boulders = {},
        assets = nil,
        arrowSound = nil,
        thumpSound = nil,
        crunchSound = nil,
    }, TrapSystem)
    for _, entity in ipairs(level.entities or {}) do
        if TRAP_KINDS[entity.kind] then
            local trap = {
                entity = entity,
                kind = entity.kind,
                x = entity.x * 16,
                y = entity.y * 16,
                alive = true,
                fired = false,
                cooldown = 0,
                state = "idle",
            }
            self.traps[#self.traps + 1] = trap
        end
    end
    return self
end

function TrapSystem:loadAssets()
    if self.assets then return end
    self.assets = {
        arrowLeft = loadImage(imagePath("Items/Weapons", "sArrowLeft")),
        arrowRight = loadImage(imagePath("Items/Weapons", "sArrowRight")),
        boulder = loadImage(imagePath("Traps", "sBoulder")),
        tikiHole = loadImage(imagePath("Traps", "sGTHHole")),
        boulderLeft = {},
        boulderRight = {},
    }
    for frame = 0, 3 do
        self.assets.boulderLeft[frame + 1] = loadImage(string.format(
            "original-game-reference/source/extracted/spelunky/Sprites/Traps/sBoulderRotateL.images/image %d.png",
            frame))
        self.assets.boulderRight[frame + 1] = loadImage(string.format(
            "original-game-reference/source/extracted/spelunky/Sprites/Traps/sBoulderRotateR.images/image %d.png",
            frame))
    end
    self.arrowSound = love.audio.newSource("original-game-reference/sound/arrowtrap.wav", "static")
    self.thumpSound = love.audio.newSource("original-game-reference/sound/thump.wav", "static")
    self.crunchSound = love.audio.newSource("original-game-reference/sound/crunch.wav", "static")
end

function TrapSystem:fireArrow(trap, direction)
    self.projectiles[#self.projectiles + 1] = {
        kind = "arrow", x = trap.x + (direction > 0 and 18 or -2), y = trap.y + 4,
        vx = direction * 8, vy = 0, direction = direction, alive = true,
        launchTrapX = math.floor(trap.x / self.world.tileSize),
        launchTrapY = math.floor(trap.y / self.world.tileSize),
        clearOfLaunchTrap = false,
    }
    trap.fired = true
    if self.arrowSound then self.arrowSound:clone():play() end
end

local function arrowHitsWorld(world, projectile, x, y)
    local left, top, right, bottom = x - 4, y - 4, x + 4, y + 4
    if projectile.launchTrapX == nil then
        return world:solidRect(left, top, right, bottom)
    end
    local size = world.tileSize
    local overlapsLaunch = right > projectile.launchTrapX * size
        and left < (projectile.launchTrapX + 1) * size
        and bottom > projectile.launchTrapY * size
        and top < (projectile.launchTrapY + 1) * size
    if not overlapsLaunch then projectile.clearOfLaunchTrap = true end
    for cellY = math.floor(top / size), math.floor((bottom - 0.001) / size) do
        for cellX = math.floor(left / size), math.floor((right - 0.001) / size) do
            if world:has("solid", cellX, cellY)
                and (projectile.clearOfLaunchTrap
                    or cellX ~= projectile.launchTrapX or cellY ~= projectile.launchTrapY) then
                return true
            end
        end
    end
    return world:dynamicSolidAt(left, top, right, bottom) ~= nil
end

function TrapSystem:updateArrowTrap(trap, player, items)
    if trap.fired then return end
    local direction = trap.kind == "arrow_trap_left" and -1 or 1
    local originX, originY = trap.x + 8, trap.y + 8
    local function inBeam(x, y, moving)
        local delta = (x - originX) * direction
        return delta > 0 and delta <= 96 and math.abs(y - originY) < 8 and moving
            and clearLine(self.world, originX + direction * 10, x, originY)
    end
    if inBeam(player.x, player.y, math.abs(player.vx) > 0.05 or math.abs(player.vy) > 0.05) then
        self:fireArrow(trap, direction)
        return
    end
    for _, item in ipairs(items or {}) do
        if not item.held and inBeam(item.x, item.y, math.abs(item.vx) > 0.05 or math.abs(item.vy) > 0.05) then
            self:fireArrow(trap, direction)
            return
        end
    end
end


function TrapSystem:triggerIdol(player)
    local nearest, nearestDistance
    for _, trap in ipairs(self.traps) do
        if trap.alive and trap.kind == "giant_tiki_head" then
            local dx, dy = trap.x - player.x, trap.y - 64 - player.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = trap, distance
            end
        end
    end
    if nearest then nearest.state, nearest.cooldown = "armed", 100 end
end

function TrapSystem:spawnBoulder(trap)
    local boulder = {
        x = trap.x, y = trap.y, vx = 0, vy = 0, alive = true, bounced = false,
        animation = 0,
    }
    boulder.solid = self.world:addDynamicSolid({
        kind = "boulder", x = boulder.x - 14, y = boulder.y - 16,
        width = 28, height = 32, properties = { invincible = true },
    })
    self.boulders[#self.boulders + 1] = boulder
end

local function boulderPixels(velocity, time)
    local magnitude = math.abs(velocity)
    local pixels = math.floor(magnitude)
    local fractional = magnitude - pixels
    if fractional > 0 then
        local period = math.floor(1 / fractional + 0.5)
        if period > 0 and time % period == 0 then pixels = pixels + 1 end
    end
    return pixels, velocity < 0 and -1 or 1
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

function TrapSystem:moveBoulder(boulder, time, player)
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

function TrapSystem:updateBoulder(boulder, player, enemies)
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


function TrapSystem:updateProjectile(projectile, player, enemies, items)
    if not projectile.alive then return end
    projectile.vy = math.min(8, projectile.vy + 0.2)
    local steps = math.max(1, math.floor(math.max(math.abs(projectile.vx), math.abs(projectile.vy))))
    local dx, dy = projectile.vx / steps, projectile.vy / steps
    for _ = 1, steps do
        local nextX, nextY = projectile.x + dx, projectile.y + dy
        local solidHit = projectile.kind == "arrow"
            and arrowHitsWorld(self.world, projectile, nextX, nextY)
            or (projectile.kind ~= "arrow" and self.world:solidAtPoint(nextX, nextY))
        if solidHit then
            if projectile.kind == "arrow" and items then
                local arrow = Item.new({ kind = "arrow", x = projectile.x / 16,
                    y = projectile.y / 16 })
                arrow.vx, arrow.vy = projectile.vx, projectile.vy
                arrow.facing = projectile.direction
                items[#items + 1] = arrow
            end
            projectile.alive = false
            return
        end
        projectile.x, projectile.y = nextX, nextY
        if math.abs(projectile.x - player.x) < 7 and math.abs(projectile.y - player.y) < 8 then
            player:hurt(projectile.x)
            projectile.alive = false
            return
        end
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and math.abs(projectile.x - enemy.x) < 8
                and math.abs(projectile.y - enemy.y) < 8 then
                enemy:damage(2)
                projectile.alive = false
                return
            end
        end
    end
end

function TrapSystem:update(player, enemies, items)
    for _, trap in ipairs(self.traps) do
        if trap.alive and not trap.entity.destroyed then
            if trap.kind == "arrow_trap_left" or trap.kind == "arrow_trap_right" then
                self:updateArrowTrap(trap, player, items)
            elseif trap.kind == "giant_tiki_head" and trap.state == "armed" then
                trap.cooldown = trap.cooldown - 1
                if trap.cooldown <= 0 then
                    trap.state = "fired"
                    self:spawnBoulder(trap)
                    if self.thumpSound then self.thumpSound:clone():play() end
                end
            end
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        self:updateProjectile(projectile, player, enemies, items)
    end
    for _, boulder in ipairs(self.boulders) do
        if boulder.alive then self:updateBoulder(boulder, player, enemies) end
    end
end

function TrapSystem:explode(x, y, radius)
    for _, trap in ipairs(self.traps) do
        local dx, dy = trap.x + 8 - x, trap.y + 8 - y
        if trap.alive and dx * dx + dy * dy <= (radius + 8) ^ 2 then
            trap.alive = false
            self.world:remove("solid", math.floor(trap.entity.x), math.floor(trap.entity.y))
        end
    end
    for _, boulder in ipairs(self.boulders) do
        local dx, dy = boulder.x - x, boulder.y - y
        if boulder.alive and dx * dx + dy * dy <= (radius + 16) ^ 2 then
            boulder.alive = false
            if boulder.solid then self.world:removeDynamicSolid(boulder.solid) end
        end
    end
end

function TrapSystem:submit(queue)
    for _, trap in ipairs(self.traps) do
        if trap.alive and not trap.entity.destroyed then
            local current = trap
            queue:add(Depth.entity(current.kind), function()
                if current.kind == "giant_tiki_head" and current.state == "fired" then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(self.assets.tikiHole, math.floor(current.x - 16),
                        math.floor(current.y - 16))
                else
                    self.renderer:drawEntity({
                        kind = current.kind, x = current.x / 16, y = current.y / 16,
                        properties = current.entity.properties or {},
                    })
                end
            end)
        end
    end
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            local current = projectile
            queue:add(Depth.entity("arrow"), function()
                love.graphics.setColor(1, 1, 1, 1)
                local image = current.direction < 0 and self.assets.arrowLeft or self.assets.arrowRight
                love.graphics.draw(image, math.floor(current.x), math.floor(current.y), 0, 1, 1, 4, 4)
            end)
        end
    end
    for _, boulder in ipairs(self.boulders) do
        if boulder.alive then
            local current = boulder
            queue:add(Depth.entity("boulder"), function()
                love.graphics.setColor(1, 1, 1, 1)
                local frames = current.vx < 0 and self.assets.boulderLeft
                    or current.vx > 0 and self.assets.boulderRight
                local image = frames and frames[(math.floor((current.animation or 0)) % 4) + 1]
                    or self.assets.boulder
                love.graphics.draw(image, math.floor(current.x), math.floor(current.y),
                    0, 1, 1, 16, 16)
            end)
        end
    end
end

function TrapSystem.isTrap(kind)
    return TRAP_KINDS[kind] or false
end

return TrapSystem
