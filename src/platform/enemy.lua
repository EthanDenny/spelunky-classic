local Enemy = {}
Enemy.__index = Enemy

Enemy.TICK_RATE = 30
Enemy.STATES = {
    idle = "IDLE",
    walk = "WALK",
    hang = "HANG",
    attack = "ATTACK",
    recover = "RECOVER",
    bounce = "BOUNCE",
    dead = "DEAD",
}

local ASSETS = {
    snake = {
        walk = {
            fps = 12,
            paths = {
                "assets/original/animations/sSnakeWalkL/000.png",
                "assets/original/animations/sSnakeWalkL/001.png",
                "assets/original/animations/sSnakeWalkL/002.png",
                "assets/original/animations/sSnakeWalkL/003.png",
            },
        },
    },
    bat = {
        hang = { fps = 0, paths = { "assets/original/entities/bat.png" } },
        left = {
            fps = 15,
            paths = {
                "assets/original/animations/sBatLeft/000.png",
                "assets/original/animations/sBatLeft/001.png",
                "assets/original/animations/sBatLeft/002.png",
            },
        },
        right = {
            fps = 15,
            paths = {
                "assets/original/animations/sBatRight/000.png",
                "assets/original/animations/sBatRight/001.png",
                "assets/original/animations/sBatRight/002.png",
            },
        },
    },
    spider = {
        hang = { fps = 0, paths = { "assets/original/entities/spider.png" } },
        flip = {
            fps = 12,
            paths = {
                "assets/original/animations/sSpiderFlip/000.png",
                "assets/original/animations/sSpiderFlip/001.png",
                "assets/original/animations/sSpiderFlip/002.png",
                "assets/original/animations/sSpiderFlip/003.png",
                "assets/original/animations/sSpiderFlip/004.png",
                "assets/original/animations/sSpiderFlip/005.png",
                "assets/original/animations/sSpiderFlip/006.png",
                "assets/original/animations/sSpiderFlip/007.png",
                "assets/original/animations/sSpiderFlip/008.png",
            },
        },
        bounce = {
            fps = 12,
            paths = {
                "assets/original/animations/sSpider/000.png",
                "assets/original/animations/sSpider/001.png",
                "assets/original/animations/sSpider/002.png",
                "assets/original/animations/sSpider/003.png",
            },
        },
    },
}

local loadedAssets

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

local function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function newRandom(seed)
    local state = math.floor(seed or 1) % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function(minimum, maximum)
        state = (state * 16807) % 2147483647
        local unit = (state - 1) / 2147483646
        return minimum + math.floor(unit * (maximum - minimum + 1))
    end
end

function Enemy.loadAssets()
    if loadedAssets then return loadedAssets end
    loadedAssets = {}
    for kind, animations in pairs(ASSETS) do
        loadedAssets[kind] = {}
        for name, animation in pairs(animations) do
            local frames = {}
            for _, path in ipairs(animation.paths) do
                local image = love.graphics.newImage(path)
                image:setFilter("nearest", "nearest")
                frames[#frames + 1] = image
            end
            loadedAssets[kind][name] = { fps = animation.fps, frames = frames }
        end
    end
    return loadedAssets
end

function Enemy.new(kind, x, y, options)
    options = options or {}
    assert(ASSETS[kind], "Unknown enemy kind: " .. tostring(kind))

    local state = Enemy.STATES.idle
    local timer = 15
    local gravity = 0.6
    if kind == "bat" or (kind == "spider" and options.hanging ~= false) then
        state = Enemy.STATES.hang
        timer = 0
    elseif kind == "spider" then
        state = Enemy.STATES.recover
        timer = 8
        gravity = 0.2
    end

    return setmetatable({
        kind = kind,
        x = x,
        y = y,
        spawnX = x,
        spawnY = y,
        vx = 0,
        vy = 0,
        xRemainder = 0,
        yRemainder = 0,
        facing = options.facing or -1,
        state = state,
        timer = timer,
        gravity = kind == "spider" and 0.2 or gravity,
        terminalVelocity = 10,
        dropThroughTimer = 0,
        hp = 1,
        alive = true,
        animation = 0,
        animationName = nil,
        random = newRandom(options.seed or (x * 31 + y * 17 + #kind)),
        justAlerted = false,
    }, Enemy)
end

function Enemy:getCollisionHalfWidth()
    if self.kind == "bat" then return 6 end
    if self.kind == "spider" then return 7 end
    return 6
end

function Enemy:getVerticalBounds()
    if self.kind == "bat" then return -14, -2 end
    if self.kind == "spider" then return -11, 0 end
    return -16, 0
end

function Enemy:getBounds(x, y)
    local halfWidth = self:getCollisionHalfWidth()
    local topOffset, bottomOffset = self:getVerticalBounds()
    return (x or self.x) - halfWidth, (y or self.y) + topOffset,
        (x or self.x) + halfWidth, (y or self.y) + bottomOffset
end

function Enemy:setState(state, timer)
    if self.state ~= state then
        self.state = state
        self.animation = 0
    end
    if timer ~= nil then self.timer = timer end
end

function Enemy:consumeHorizontalPixels(distanceToMove)
    self.xRemainder = self.xRemainder + distanceToMove
    local pixels = math.floor(math.abs(self.xRemainder)) * sign(self.xRemainder)
    self.xRemainder = self.xRemainder - pixels
    return pixels
end

function Enemy:consumeVerticalPixels(distanceToMove)
    self.yRemainder = self.yRemainder + distanceToMove
    local pixels = math.floor(math.abs(self.yRemainder)) * sign(self.yRemainder)
    self.yRemainder = self.yRemainder - pixels
    return pixels
end

function Enemy:moveHorizontal(world, amount)
    local pixels = self:consumeHorizontalPixels(amount)
    local direction = sign(pixels)
    for _ = 1, math.abs(pixels) do
        if world:collidesSolid(self, self.x + direction, self.y) then
            self.xRemainder = 0
            return true
        end
        self.x = self.x + direction
    end
    return false
end

function Enemy:moveVertical(world, amount, usePlatforms)
    local pixels = self:consumeVerticalPixels(amount)
    local direction = sign(pixels)
    for _ = 1, math.abs(pixels) do
        local nextY = self.y + direction
        if world:collidesSolid(self, self.x, nextY) then
            self.yRemainder = 0
            return direction > 0 and "floor" or "ceiling"
        end
        if direction > 0 and usePlatforms then
            local platformY = world:platformLanding(self, self.y, nextY)
            if platformY then
                self.y = platformY
                self.yRemainder = 0
                return "floor"
            end
        end
        self.y = nextY
    end
end

function Enemy:hasCeiling(world)
    return world:solidAtPoint(self.x, self.y - 17)
end

function Enemy:hasSupportAhead(world, direction)
    local halfWidth = self:getCollisionHalfWidth()
    local _, bottomOffset = self:getVerticalBounds()
    local x = self.x + direction * (halfWidth + 2)
    local y = self.y + bottomOffset + 1
    local tileX = math.floor(x / world.tileSize)
    local tileY = math.floor(y / world.tileSize)
    return world:has("solid", tileX, tileY)
        or world:has("platform", tileX, tileY)
        or world:has("ladderTop", tileX, tileY)
end

function Enemy:updateGroundPhysics(world)
    self.vy = math.min(self.terminalVelocity, self.vy + self.gravity)
    local hitWall = self:moveHorizontal(world, self.vx)
    local verticalHit = self:moveVertical(world, self.vy, true)
    if hitWall then self.vx = 0 end
    if verticalHit == "floor" then self.vy = 0 end
    if verticalHit == "ceiling" then self.vy = math.max(1, math.abs(self.vy)) end
    return hitWall, verticalHit
end

function Enemy:updateSnake(world)
    local onGround = world:groundBelow(self) ~= nil
    if self.state == Enemy.STATES.idle then
        self.vx = 0
        self.timer = self.timer - 1
        if self.timer <= 0 then
            self.facing = self.random(0, 1) == 0 and -1 or 1
            self:setState(Enemy.STATES.walk)
        end
    elseif self.state == Enemy.STATES.walk then
        local wallAhead = world:collidesSolid(self, self.x + self.facing, self.y)
        if onGround and (wallAhead or not self:hasSupportAhead(world, self.facing)) then
            self.facing = -self.facing
        end
        self.vx = self.facing
        if self.random(1, 100) == 1 then
            self.vx = 0
            self:setState(Enemy.STATES.idle, self.random(20, 50))
        end
    end

    local hitWall = self:updateGroundPhysics(world)
    if hitWall and self.state == Enemy.STATES.walk then
        self.facing = -self.facing
    end
end

function Enemy:updateBat(world, player)
    local playerAlive = player and not player:isDead()
    local dist = playerAlive and distance(self.x, self.y - 8, player.x, player.y) or math.huge
    if self.state == Enemy.STATES.hang then
        self.vx, self.vy = 0, 0
        if not self:hasCeiling(world)
            or (playerAlive and dist < 90 and player.y > self.y) then
            self.justAlerted = true
            self:setState(Enemy.STATES.attack)
        end
        return
    end

    if playerAlive and dist < 160 then
        local dx = player.x - self.x
        local dy = player.y - (self.y - 8)
        local length = math.max(0.001, math.sqrt(dx * dx + dy * dy))
        self.vx = dx / length
        self.vy = dy / length
        self.facing = dx < 0 and -1 or 1
    else
        self.vx, self.vy = 0, -1
    end

    local hitWall = self:moveHorizontal(world, self.vx)
    local verticalHit = self:moveVertical(world, self.vy, false)
    if hitWall then self.vx = 0 end
    if verticalHit == "floor" then self.vy = -1 end
    if verticalHit == "ceiling" then
        if not playerAlive or dist >= 160 then
            self:setState(Enemy.STATES.hang)
            self.vx, self.vy = 0, 0
        else
            self.vy = 1
        end
    end
end

function Enemy:spiderHop(player)
    self:setState(Enemy.STATES.bounce)
    self.vy = -self.random(2, 5)
    self.facing = player and player.x < self.x and -1 or 1
    self.vx = self.facing * 2.5
end

function Enemy:updateSpider(world, player)
    local playerAlive = player and not player:isDead()
    local dist = playerAlive and distance(self.x, self.y - 6, player.x, player.y) or math.huge

    if self.state == Enemy.STATES.hang then
        self.vx, self.vy = 0, 0
        local directlyBelow = playerAlive and player.y > self.y and math.abs(player.x - self.x) < 8
        if not self:hasCeiling(world) or (directlyBelow and dist < 90) then
            self.justAlerted = true
            self:setState(Enemy.STATES.recover, self.random(5, 20))
        end
        return
    end

    self.timer = math.max(0, self.timer - 1)
    local _, verticalHit = self:updateGroundPhysics(world)
    local grounded = verticalHit == "floor" or world:groundBelow(self) ~= nil

    if self.state == Enemy.STATES.recover then
        if grounded then self.vx = 0 end
        if grounded and self.timer <= 0 then self:spiderHop(player) end
    elseif self.state == Enemy.STATES.bounce and grounded then
        if playerAlive and dist < 90 and self.random(1, 4) ~= 1 then
            self:spiderHop(player)
        else
            self.vx, self.vy = 0, 0
            self:setState(Enemy.STATES.recover, self.random(5, 20))
        end
    end
end

function Enemy:updateAnimation()
    local name
    if self.kind == "snake" then
        name = "walk"
    elseif self.kind == "bat" then
        if self.state == Enemy.STATES.hang then name = "hang"
        else name = self.facing < 0 and "left" or "right" end
    elseif self.state == Enemy.STATES.hang then
        name = "hang"
    elseif self.state == Enemy.STATES.recover and self.timer > 0 then
        name = "flip"
    else
        name = "bounce"
    end

    if name ~= self.animationName then
        self.animationName = name
        self.animation = 0
    else
        local animation = ASSETS[self.kind][name]
        self.animation = self.animation + animation.fps / Enemy.TICK_RATE
    end
end

function Enemy:step(world, player)
    if not self.alive then return end
    self.justAlerted = false
    if self.kind == "snake" then
        self:updateSnake(world)
    elseif self.kind == "bat" then
        self:updateBat(world, player)
    else
        self:updateSpider(world, player)
    end
    self:updateAnimation()
end

function Enemy:overlapsRectangle(left, top, right, bottom)
    local myLeft, myTop, myRight, myBottom = self:getBounds()
    return left < myRight and right > myLeft and top < myBottom and bottom > myTop
end

function Enemy:overlapsPlayer(player)
    local halfWidth = player:getCollisionHalfWidth()
    local topOffset, bottomOffset = player:getVerticalBounds()
    return self:overlapsRectangle(player.x - halfWidth, player.y + topOffset,
        player.x + halfWidth, player.y + bottomOffset)
end

function Enemy:damage(amount)
    if not self.alive then return false end
    self.hp = self.hp - (amount or 1)
    if self.hp <= 0 then
        self.alive = false
        self.vx, self.vy = 0, 0
        self:setState(Enemy.STATES.dead)
    end
    return true
end

function Enemy:resolvePlayerContact(player, previousPlayerY)
    if not self.alive or not self:overlapsPlayer(player) then return nil end

    local _, playerBottom = player:getVerticalBounds()
    local _, enemyTop = self:getBounds()
    local previousBottom = previousPlayerY + playerBottom
    if player.vy > 0 and player.y < self.y and previousBottom <= enemyTop + 3 then
        self:damage(1)
        player.vy = -6 - 0.2 * player.vy
        player.jumpTime = 10
        player.jumpReleased = true
        player:setState("jumping")
        return "stomp"
    end

    if player:hurt(self.x) then return "hurt" end
    return "invincible"
end

function Enemy:draw()
    local assets = loadedAssets or Enemy.loadAssets()
    local animation = assets[self.kind][self.animationName or (self.kind == "snake" and "walk" or "hang")]
    local index = (math.floor(self.animation) % #animation.frames) + 1
    local image = animation.frames[index]
    local scaleX = 1
    local drawX = math.floor(self.x - 8)
    if self.kind == "snake" and self.facing > 0 then
        scaleX = -1
        drawX = math.floor(self.x + 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, drawX, math.floor(self.y - 16), 0, scaleX, 1)
end

return Enemy
