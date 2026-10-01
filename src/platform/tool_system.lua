local ToolSystem = {}
ToolSystem.__index = ToolSystem
local Depth = require("src.render.classic_depth")
local Effects = require("src.platform.effects")

local ORIGINAL_FPS = 50
local BOMB_FUSE = 80
local BOMB_FLASH = 40

local function scaledTicks(ticks, tickRate)
    return math.max(1, math.floor(ticks * tickRate / ORIGINAL_FPS + 0.5))
end

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function imagePath(group, sprite, frame)
    return "original-game-reference/source/extracted/spelunky/Sprites/" .. group .. "/"
        .. sprite .. ".images/image " .. frame .. ".png"
end

local function overlapsPointEntity(entity, x, y, radius)
    return math.abs(entity.x - x) <= radius and math.abs(entity.y - y) <= radius
end

local function snap(value, grid)
    return math.floor(value / grid + 0.5) * grid
end

local function ropeSideClear(world, gridX, candidateX, y)
    local left = candidateX < gridX and candidateX or candidateX - 1
    return not world:solidRect(left, y, left + 2, y + 17)
end

function ToolSystem.new(world, tickRate)
    return setmetatable({
        world = world,
        tickRate = tickRate or 30,
        bombs = {},
        ropes = {},
        explosions = {},
        effects = Effects.new(1),
        assets = nil,
        explosionSound = nil,
    }, ToolSystem)
end

function ToolSystem:loadAssets()
    if self.assets then return end
    local weapons = "Items/Weapons"
    self.assets = {
        bomb = loadImage(imagePath(weapons, "sBomb", 0)),
        bombArmed = {
            loadImage(imagePath(weapons, "sBombArmed", 0)),
            loadImage(imagePath(weapons, "sBombArmed", 1)),
        },
        ropeEnd = loadImage(imagePath(weapons, "sRopeEnd", 0)),
        rope = loadImage(imagePath(weapons, "sRope", 0)),
        ropeTop = loadImage(imagePath(weapons, "sRopeTop", 0)),
        explosion = {},
    }
    for frame = 0, 9 do
        self.assets.explosion[#self.assets.explosion + 1] =
            loadImage(imagePath("Effects", "sExplosion", frame))
    end
    self.explosionSound = love.audio.newSource("original-game-reference/sound/explosion.wav", "static")
    Effects.loadAssets()
end

function ToolSystem:throwBomb(player, input)
    if player.whipping then return nil end
    input = input or {}
    local bomb = {
        x = player.x,
        y = player.y,
        vx = player.facing * 8 + player.vx,
        vy = input.up and -9 or input.down and 3 or -3,
        xRemainder = 0,
        yRemainder = 0,
        timer = scaledTicks(BOMB_FUSE + BOMB_FLASH, self.tickRate),
        flashStart = scaledTicks(BOMB_FLASH, self.tickRate),
        alive = true,
        armed = true,
        sticky = player.equipment and player.equipment.paste or false,
        stuck = false,
    }
    if input.down and self.world:groundBelow(player) then bomb.vx = bomb.vx * 0.1 end
    self.bombs[#self.bombs + 1] = bomb
    return bomb
end

function ToolSystem:throwRope(player, input)
    if player.whipping then return nil end
    local downward = input and input.down
    if not downward and self.world:collidesSolid(player, player.x, player.y - 1) then
        return nil
    end
    local rope = {
        x = player.x,
        y = player.y,
        vx = 0,
        vy = -12,
        deploying = false,
        deployed = false,
        segments = {},
        alive = true,
    }
    if downward then
        local direction = player.facing < 0 and -1 or 1
        local gridX = snap(player.x + direction * 16, self.world.tileSize)
        local gridY = snap(player.y, 1)
        -- oPlayer1 first checks the side of the player, then tries the edge
        -- nearest the player and finally the far edge of the snapped cell.
        if self.world:solidAtPoint(player.x + direction * 8, player.y) then return nil end
        local nearX = gridX - direction * 8
        local farX = gridX + direction * 8
        if ropeSideClear(self.world, gridX, nearX, gridY) then
            rope.x = nearX
        elseif ropeSideClear(self.world, gridX, farX, gridY) then
            rope.x = farX
        else
            return nil
        end
        rope.y = gridY
        rope.vy = 0
        self:deployRope(rope)
    end
    self.ropes[#self.ropes + 1] = rope
    return rope
end

local function bombCollision(world, bomb, nextX, nextY)
    return world:solidRect(nextX - 4, nextY - 4, nextX + 4, nextY + 4)
end

local function pixelStep(velocity, remainder)
    local travel = velocity + remainder
    local pixels = travel >= 0 and math.floor(travel) or math.ceil(travel)
    return pixels, travel - pixels
end

function ToolSystem:updateBomb(bomb, enemies)
    bomb.timer = bomb.timer - 1
    if bomb.timer <= 0 then
        bomb.alive = false
        self:explode(bomb.x, bomb.y)
        return
    end

    if bomb.attached then
        if bomb.attached.alive then
            bomb.x = bomb.attached.x - bomb.attachX
            bomb.y = bomb.attached.y - bomb.attachY
            return
        end
        bomb.attached, bomb.stuck = nil, false
    end
    if bomb.stuck then return end
    local horizontal
    horizontal, bomb.xRemainder = pixelStep(bomb.vx, bomb.xRemainder)
    local xDirection = horizontal < 0 and -1 or 1
    for _ = 1, math.abs(horizontal) do
        if bombCollision(self.world, bomb, bomb.x + xDirection, bomb.y) then
            bomb.xRemainder = 0
            if bomb.sticky then bomb.vx, bomb.vy, bomb.stuck = 0, 0, true
            else bomb.vx = -bomb.vx * 0.5 end
            break
        end
        bomb.x = bomb.x + xDirection
    end
    if bomb.stuck then return end
    local vertical
    vertical, bomb.yRemainder = pixelStep(bomb.vy, bomb.yRemainder)
    local yDirection = vertical < 0 and -1 or 1
    local landed = false
    for _ = 1, math.abs(vertical) do
        if bombCollision(self.world, bomb, bomb.x, bomb.y + yDirection) then
            bomb.yRemainder = 0
            if bomb.sticky then
                bomb.vx, bomb.vy, bomb.stuck = 0, 0, true
            elseif yDirection > 0 then
                bomb.vy = bomb.vy > 1 and -bomb.vy * 0.5 or 0
                bomb.vx = math.abs(bomb.vx) < 0.1 and 0 or bomb.vx * 0.3
                landed = true
            else
                bomb.vy = math.abs(bomb.vy) * 0.8
            end
            break
        end
        bomb.y = bomb.y + yDirection
    end
    if bomb.stuck then return end
    if bomb.sticky and math.abs(bomb.vx) + math.abs(bomb.vy) > 2 then
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and enemy:overlapsRectangle(
                bomb.x - 2, bomb.y - 2, bomb.x + 2, bomb.y + 2) then
                bomb.attached = enemy
                bomb.attachX = enemy.x - bomb.x
                bomb.attachY = enemy.y - bomb.y
                bomb.vx, bomb.vy, bomb.stuck = 0, 0, true
                break
            end
        end
    end
    if not landed and not bomb.stuck then bomb.vy = math.min(8, bomb.vy + 0.6) end
end

function ToolSystem:deployRope(rope)
    local tileSize = self.world.tileSize
    -- GameMaker's move_snap(16, 1) keeps the vertical hook position at
    -- pixel precision; only the horizontal axis snaps to the tile grid.
    rope.y = snap(rope.y, 1)
    rope.vx, rope.vy = 0, 0
    rope.deploying = true
    rope.deployed = true
    rope.deployY = rope.y
    rope.segmentCount = 0
    self.world:set("rope", math.floor(rope.x / tileSize), math.floor(rope.y / tileSize), "deployed")
end

function ToolSystem:anchorThrownRope(rope)
    -- oRopeThrow snaps to the grid, then shifts toward its launch point
    -- unless that half-cell is blocked.
    local gridX = snap(rope.x, self.world.tileSize)
    local nearX = gridX + (rope.x < gridX and -8 or 8)
    local farX = gridX + (rope.x < gridX and 8 or -8)
    rope.x = self.world:solidAtPoint(nearX, rope.y) and farX or nearX
    self:deployRope(rope)
end

function ToolSystem:updateRope(rope, enemies)
    if rope.deploying then
        local nextY = rope.deployY + 8
        rope.segmentCount = rope.segmentCount + 1
        if rope.segmentCount > 16
            or self.world:solidRect(rope.x - 3, nextY - 3, rope.x + 3, nextY + 4) then
            rope.deploying = false
            return
        end
        rope.deployY = nextY
        rope.segments[#rope.segments + 1] = nextY
        self.world:set("rope", math.floor(rope.x / self.world.tileSize),
            math.floor(nextY / self.world.tileSize), "deployed")
        return
    end
    if rope.deployed then return end

    local direction = rope.vy < 0 and -1 or 1
    for _ = 1, math.floor(math.abs(rope.vy)) do
        local nextY = rope.y + direction
        if self.world:solidRect(rope.x - 4, nextY - 4, rope.x + 4, nextY + 4) then
            rope.vy = 0
            self:anchorThrownRope(rope)
            return
        end
        rope.y = nextY
    end
    -- The moving oRopeThrow inherits oItem's fast-item collision. Its fixed
    -- oRope body does not: only the flying end can damage an enemy.
    if math.abs(rope.vy) > 2 then
        rope.hitEnemies = rope.hitEnemies or {}
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and not rope.hitEnemies[enemy]
                and enemy:overlapsRectangle(rope.x - 2, rope.y - 2, rope.x + 2, rope.y + 2)
                and enemy:damage(1, rope.x) then
                rope.hitEnemies[enemy] = true
                if self.onRopeHit then self:onRopeHit(enemy, rope) end
            end
        end
    end
    rope.vy = rope.vy + 0.6
    if rope.vy >= 0 then
        self:anchorThrownRope(rope)
    end
end

function ToolSystem:explode(x, y)
    local destroyed = self.world:destroyTerrain(x, y, 24)
    for _, cell in ipairs(destroyed) do
        self.effects:terrainBreak(cell.pixelX or (cell.x + 0.5) * self.world.tileSize,
            cell.pixelY or (cell.y + 0.5) * self.world.tileSize, self.world.tileSize)
    end
    self.explosions[#self.explosions + 1] = { x = x, y = y, age = 0, alive = true }
    self.effects:explosion(x, y)
    if self.explosionSound then self.explosionSound:clone():play() end
    if self.onExplosion then self:onExplosion(x, y, 24) end
end

function ToolSystem:update(player, enemies, items)
    for _, bomb in ipairs(self.bombs) do
        if bomb.alive then self:updateBomb(bomb, enemies) end
    end
    for _, rope in ipairs(self.ropes) do
        if rope.alive then self:updateRope(rope, enemies) end
    end
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            if explosion.age == 0 then
                if overlapsPointEntity(player, explosion.x, explosion.y, 25) then
                    player.health = 0
                elseif overlapsPointEntity(player, explosion.x, explosion.y, 34) then
                    player:hurt(explosion.x)
                end
                for _, enemy in ipairs(enemies or {}) do
                    if enemy.alive and overlapsPointEntity(enemy, explosion.x, explosion.y, 32) then
                        if enemy:damage(30) and not enemy.alive then
                            if enemy.kind == "skeleton" then
                                self.effects:skeletonBreak(enemy.x, enemy.y - 8)
                            else
                                self.effects:blood(enemy.x, enemy.y - 8, 3)
                            end
                            enemy.blastParticlesEmitted = true
                        end
                    end
                end
                for _, item in ipairs(items or {}) do
                    if not item.held and overlapsPointEntity(item, explosion.x, explosion.y, 32) then
                        local direction = item.x < explosion.x and -1 or 1
                        item.vx = direction * 5
                        item.vy = -6
                    end
                end
            end
            explosion.age = explosion.age + 1
            if explosion.age >= scaledTicks(10, self.tickRate) then explosion.alive = false end
        end
    end
    self.effects:update(self.world)
end

function ToolSystem:drawRope(rope)
    if not self.assets or not rope.alive then return end
    love.graphics.setColor(1, 1, 1, 1)
    if rope.deployed then
        love.graphics.draw(self.assets.ropeTop, math.floor(rope.x), math.floor(rope.y), 0, 1, 1, 4, 4)
        for _, segmentY in ipairs(rope.segments) do
            love.graphics.draw(self.assets.rope, math.floor(rope.x - 8), math.floor(segmentY), 0, 1, 1, 4, 4)
        end
    else
        love.graphics.draw(self.assets.ropeEnd, math.floor(rope.x), math.floor(rope.y), 0, 1, 1, 4, 4)
    end
end

function ToolSystem:drawBomb(bomb)
    if not self.assets or not bomb.alive then return end
    love.graphics.setColor(1, 1, 1, 1)
    local elapsed = scaledTicks(BOMB_FUSE + BOMB_FLASH, self.tickRate) - bomb.timer
    local speed = bomb.timer <= bomb.flashStart and 1 or 0.2
    local frame = math.floor(elapsed * speed * ORIGINAL_FPS / self.tickRate) % 2 + 1
    local image = self.assets.bombArmed[frame]
    love.graphics.draw(image, math.floor(bomb.x), math.floor(bomb.y), 0, 1, 1, 4, 4)
end

function ToolSystem:drawExplosions()
    if not self.assets then return end
    love.graphics.setColor(1, 1, 1, 1)
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            local frame = math.min(#self.assets.explosion,
                math.floor(explosion.age * #self.assets.explosion / scaledTicks(10, self.tickRate)) + 1)
            love.graphics.draw(self.assets.explosion[frame], math.floor(explosion.x),
                math.floor(explosion.y), 0, 1, 1, 24, 24)
        end
    end
    self.effects:draw()
end

function ToolSystem:submit(queue)
    for _, rope in ipairs(self.ropes) do
        if rope.alive then
            local current = rope
            queue:add(Depth.entity(current.deployed and "rope" or "rope_throw"),
                function() self:drawRope(current) end)
        end
    end
    for _, bomb in ipairs(self.bombs) do
        if bomb.alive then
            local current = bomb
            local state = current.sticky and "sticky" or current.armed and "armed" or nil
            queue:add(Depth.entity("bomb", state), function() self:drawBomb(current) end)
        end
    end
    queue:add(Depth.EFFECT, function() self:drawExplosions() end)
end

return ToolSystem
