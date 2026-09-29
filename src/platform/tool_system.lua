local ToolSystem = {}
ToolSystem.__index = ToolSystem

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

function ToolSystem.new(world, tickRate)
    return setmetatable({
        world = world,
        tickRate = tickRate or 30,
        bombs = {},
        ropes = {},
        explosions = {},
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
end

function ToolSystem:throwBomb(player)
    local bomb = {
        x = player.x + player.facing * 4,
        y = player.y,
        vx = player.facing * 3.2 + player.vx,
        vy = -3,
        timer = scaledTicks(BOMB_FUSE + BOMB_FLASH, self.tickRate),
        flashStart = scaledTicks(BOMB_FLASH, self.tickRate),
        alive = true,
        sticky = player.equipment and player.equipment.paste or false,
        stuck = false,
    }
    self.bombs[#self.bombs + 1] = bomb
    return bomb
end

function ToolSystem:throwRope(player, input)
    if not (input and input.down) and self.world:collidesSolid(player, player.x, player.y - 1) then
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
    if input and input.down then
        rope.x = player.x + player.facing * 16
        rope.vy = 0
        self:deployRope(rope)
    end
    self.ropes[#self.ropes + 1] = rope
    return rope
end

local function bombCollision(world, bomb, nextX, nextY)
    return world:solidRect(nextX - 4, nextY - 4, nextX + 4, nextY + 4)
end

function ToolSystem:updateBomb(bomb)
    bomb.timer = bomb.timer - 1
    if bomb.timer <= 0 then
        bomb.alive = false
        self:explode(bomb.x, bomb.y)
        return
    end

    if bomb.stuck then return end
    bomb.vy = math.min(8, bomb.vy + 0.6)
    local horizontal = math.floor(math.abs(bomb.vx))
    local xDirection = bomb.vx < 0 and -1 or 1
    for _ = 1, horizontal do
        if bombCollision(self.world, bomb, bomb.x + xDirection, bomb.y) then
            if bomb.sticky then bomb.vx, bomb.vy, bomb.stuck = 0, 0, true
            else bomb.vx = -bomb.vx * 0.5 end
            break
        end
        bomb.x = bomb.x + xDirection
    end
    local vertical = math.floor(math.abs(bomb.vy))
    local yDirection = bomb.vy < 0 and -1 or 1
    for _ = 1, vertical do
        if bombCollision(self.world, bomb, bomb.x, bomb.y + yDirection) then
            if bomb.sticky then
                bomb.vx, bomb.vy, bomb.stuck = 0, 0, true
            elseif yDirection > 0 then
                bomb.vy = math.abs(bomb.vy) > 1 and -bomb.vy * 0.35 or 0
                bomb.vx = bomb.vx * 0.75
            else
                bomb.vy = math.abs(bomb.vy) * 0.5
            end
            break
        end
        bomb.y = bomb.y + yDirection
    end
end

function ToolSystem:deployRope(rope)
    local tileSize = self.world.tileSize
    rope.x = math.floor(rope.x / tileSize) * tileSize + tileSize / 2
    rope.y = math.floor(rope.y / 8 + 0.5) * 8
    rope.vx, rope.vy = 0, 0
    rope.deploying = true
    rope.deployed = true
    rope.deployY = rope.y
    rope.segmentCount = 0
    self.world:set("rope", math.floor(rope.x / tileSize), math.floor(rope.y / tileSize))
end

function ToolSystem:updateRope(rope)
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
            math.floor(nextY / self.world.tileSize))
        return
    end
    if rope.deployed then return end

    rope.vy = rope.vy + 0.6
    local direction = rope.vy < 0 and -1 or 1
    for _ = 1, math.floor(math.abs(rope.vy)) do
        local nextY = rope.y + direction
        if self.world:solidRect(rope.x - 4, nextY - 4, rope.x + 4, nextY + 4) then
            rope.vy = 0
            self:deployRope(rope)
            return
        end
        rope.y = nextY
    end
    if rope.vy >= 0 then self:deployRope(rope) end
end

function ToolSystem:explode(x, y)
    self.world:destroyTerrain(x, y, 24)
    self.explosions[#self.explosions + 1] = { x = x, y = y, age = 0, alive = true }
    if self.explosionSound then self.explosionSound:clone():play() end
    if self.onExplosion then self:onExplosion(x, y, 24) end
end

function ToolSystem:update(player, enemies, items)
    for _, bomb in ipairs(self.bombs) do
        if bomb.alive then self:updateBomb(bomb) end
    end
    for _, rope in ipairs(self.ropes) do
        if rope.alive then self:updateRope(rope) end
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
                        enemy:damage(30)
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
end

function ToolSystem:drawBack()
    if not self.assets then return end
    for _, rope in ipairs(self.ropes) do
        if rope.alive then
            if rope.deployed then
                love.graphics.draw(self.assets.ropeTop, math.floor(rope.x), math.floor(rope.y), 0, 1, 1, 4, 4)
                for _, segmentY in ipairs(rope.segments) do
                    love.graphics.draw(self.assets.rope, math.floor(rope.x), math.floor(segmentY), 0, 1, 1, 4, 4)
                end
            else
                love.graphics.draw(self.assets.ropeEnd, math.floor(rope.x), math.floor(rope.y), 0, 1, 1, 4, 4)
            end
        end
    end
    for _, bomb in ipairs(self.bombs) do
        if bomb.alive then
            local image = self.assets.bomb
            if bomb.timer <= bomb.flashStart then
                image = self.assets.bombArmed[(math.floor(bomb.timer / 2) % 2) + 1]
            end
            love.graphics.draw(image, math.floor(bomb.x), math.floor(bomb.y), 0, 1, 1, 4, 4)
        end
    end
end

function ToolSystem:drawFront()
    if not self.assets then return end
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            local frame = math.min(#self.assets.explosion,
                math.floor(explosion.age * #self.assets.explosion / scaledTicks(10, self.tickRate)) + 1)
            love.graphics.draw(self.assets.explosion[frame], math.floor(explosion.x),
                math.floor(explosion.y), 0, 1, 1, 24, 24)
        end
    end
end

return ToolSystem
