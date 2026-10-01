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
    stunned = "STUNNED",
    bones = "BONES",
    rise = "RISE",
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
    caveman = {
        idle = { fps = 0, paths = { "assets/original/entities/caveman.png" } },
        run = {
            fps = 15,
            paths = {
                "assets/original/animations/sCavemanRunLeft/000.png",
                "assets/original/animations/sCavemanRunLeft/001.png",
                "assets/original/animations/sCavemanRunLeft/002.png",
                "assets/original/animations/sCavemanRunLeft/003.png",
            },
        },
        hurt = { fps = 0, paths = {
            "original-game-reference/source/extracted/spelunky/Sprites/Enemies/Caveman/sCavemanDieLL.images/image 0.png",
        } },
        stun = {
            fps = 15,
            paths = {
                "assets/original/animations/sCavemanStunL/000.png",
                "assets/original/animations/sCavemanStunL/001.png",
                "assets/original/animations/sCavemanStunL/002.png",
                "assets/original/animations/sCavemanStunL/003.png",
                "assets/original/animations/sCavemanStunL/004.png",
            },
        },
    },
    skeleton = {
        bones = { fps = 0, paths = { "assets/original/entities/fake_bones.png" } },
        rise = {
            fps = 15,
            paths = {
                "assets/original/animations/sSkeletonCreateL/000.png",
                "assets/original/animations/sSkeletonCreateL/001.png",
                "assets/original/animations/sSkeletonCreateL/002.png",
                "assets/original/animations/sSkeletonCreateL/003.png",
                "assets/original/animations/sSkeletonCreateL/004.png",
                "assets/original/animations/sSkeletonCreateL/005.png",
            },
        },
        idle = { fps = 0, paths = {
            "original-game-reference/source/extracted/spelunky/Sprites/Enemies/Skeleton/sSkeletonLeft.images/image 0.png",
        } },
        walk = {
            fps = 15,
            paths = {
                "assets/original/animations/sSkeletonWalkLeft/000.png",
                "assets/original/animations/sSkeletonWalkLeft/001.png",
                "assets/original/animations/sSkeletonWalkLeft/002.png",
                "assets/original/animations/sSkeletonWalkLeft/003.png",
                "assets/original/animations/sSkeletonWalkLeft/004.png",
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
    local timer = kind == "caveman" and 0 or kind == "skeleton" and 20 or 15
    if kind == "skeleton" and options.fakeBones then
        state = Enemy.STATES.bones
        timer = 0
    end
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
        facing = options.facing or ((kind == "caveman" or kind == "skeleton") and 1 or -1),
        state = state,
        timer = timer,
        gravity = kind == "spider" and 0.2 or gravity,
        terminalVelocity = 10,
        dropThroughTimer = 0,
        hp = kind == "caveman" and 3 or 1,
        alive = true,
        animation = 0,
        animationName = nil,
        random = newRandom(options.seed or (x * 31 + y * 17 + #kind)),
        justAlerted = false,
        sightTimer = 0,
    }, Enemy)
end

function Enemy:getCollisionHalfWidth()
    if self.kind == "bat" then return 6 end
    if self.kind == "spider" then
        return self.state == Enemy.STATES.hang and 4 or 7
    end
    return 6
end

function Enemy:getVerticalBounds()
    if self.kind == "bat" then return -14, -2 end
    if self.kind == "spider" then
        if self.state == Enemy.STATES.hang then return -16, -4 end
        return -11, 0
    end
    return -16, 0
end

function Enemy:getBounds(x, y)
    local halfWidth = self:getCollisionHalfWidth()
    local topOffset, bottomOffset = self:getVerticalBounds()
    return (x or self.x) - halfWidth, (y or self.y) + topOffset,
        (x or self.x) + halfWidth, (y or self.y) + bottomOffset
end

function Enemy:setState(state, timer)
    self.state = state
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

function Enemy:hasSnakeSupport(world, direction)
    -- oSnake probes one pixel beyond its 16-pixel sprite on either side.
    local x = self.x + (direction < 0 and -9 or 8)
    return world:solidAtPoint(x, self.y)
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
        -- oSnake checks the sprite's top corners for walls in its no-exit rule.
        local leftWall = world:solidAtPoint(self.x - 9, self.y - 16)
        local rightWall = world:solidAtPoint(self.x + 8, self.y - 16)
        local leftSupport = self:hasSnakeSupport(world, -1)
        local rightSupport = self:hasSnakeSupport(world, 1)
        if (leftWall or not leftSupport) and (rightWall or not rightSupport) then
            -- The original holds position when both directions are blocked.
            self.facing = leftWall and 1 or -1
            self.vx = 0
        else
            local blockedAhead = self.facing < 0 and (leftWall or not leftSupport)
                or self.facing > 0 and (rightWall or not rightSupport)
            if onGround and blockedAhead then
                self.facing = -self.facing
            end
            self.vx = self.facing
        end
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

function Enemy:canCavemanSee(world, player)
    if not player or player:isDead() then return false end
    local dx = player.x - self.x
    if dx * self.facing <= 0 or math.abs(dx) >= 100
        or math.abs(player.y - self.y) > 16 then return false end
    for offset = 4, math.abs(dx) - 4, 4 do
        if world:solidAtPoint(self.x + self.facing * offset, self.y - 8) then
            return false
        end
    end
    return true
end

function Enemy:updateCaveman(world, player)
    if self.state == Enemy.STATES.stunned then
        self.vx = sign(self.vx) * math.max(0, math.abs(self.vx) - 0.1)
        if math.abs(self.vx) < 0.5 then self.vx = 0 end
        local _, landing = self:updateGroundPhysics(world)
        if landing == "floor" or world:groundBelow(self) then
            self.timer = self.timer - 1
            if self.timer <= 0 then self:setState(Enemy.STATES.idle, 0) end
        end
        return
    end

    if self.state == Enemy.STATES.idle then
        self.vx = 0
        if world:groundBelow(self) then self.timer = self.timer - 1 end
        if self.timer <= 0 then
            self.facing = self.random(0, 1) == 0 and -1 or 1
            self:setState(Enemy.STATES.walk)
        end
    elseif self.state == Enemy.STATES.walk then
        if world:collidesSolid(self, self.x + self.facing, self.y) then
            self.facing = -self.facing
        end
        local supportX = self.x + (self.facing < 0 and -9 or 8)
        if not world:solidAtPoint(supportX, self.y) then
            self.vx = 0
            self:setState(Enemy.STATES.idle, self.random(20, 50))
        else
            self.vx = self.facing * 1.5
            if self.random(1, 100) == 1 then
                self.vx = 0
                self:setState(Enemy.STATES.idle, self.random(20, 50))
            end
        end
    elseif self.state == Enemy.STATES.attack then
        if world:collidesSolid(self, self.x + self.facing, self.y) then
            self.facing = -self.facing
        end
        self.vx = self.facing * 3
    end

    if self.state == Enemy.STATES.idle or self.state == Enemy.STATES.walk then
        self.sightTimer = self.sightTimer - 1
        if self.sightTimer <= 0 then
            self.sightTimer = 5
            if self:canCavemanSee(world, player) then
                self:setState(Enemy.STATES.attack)
                self.vx = self.facing * 3
                self.justAlerted = true
            end
        end
    end
    local hitWall = self:updateGroundPhysics(world)
    if hitWall and self.state == Enemy.STATES.attack then
        self.facing = -self.facing
    end
end

function Enemy:updateSkeleton(world, player)
    if self.state == Enemy.STATES.bones then
        if player and not player:isDead()
            and math.abs(player.y - (self.y - 8)) < 8
            and math.abs(player.x - self.x) < 64 then
            self:setState(Enemy.STATES.rise)
            self.justAlerted = true
        end
        return
    elseif self.state == Enemy.STATES.rise then
        if player then self.facing = player.x < self.x and -1 or 1 end
        return
    elseif self.state == Enemy.STATES.idle then
        self.vx = 0
        if self.timer > 0 then self.timer = self.timer - 1 end
        if self.timer == 0 then self:setState(Enemy.STATES.walk) end
    elseif self.state == Enemy.STATES.walk then
        local leftWall = world:collidesSolid(self, self.x - 1, self.y)
        local rightWall = world:collidesSolid(self, self.x + 1, self.y)
        if leftWall ~= rightWall then self.facing = -self.facing end
        self.vx = self.facing
    end
    self:updateGroundPhysics(world)
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
    if (not playerAlive or dist >= 160) and self:hasCeiling(world) then
        self:setState(Enemy.STATES.hang)
        self.vx, self.vy = 0, 0
    elseif verticalHit == "ceiling" and playerAlive and dist < 160 then
        self.vy = 1
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
            self.flipOnDrop = true
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
    elseif self.kind == "caveman" then
        if self.state == Enemy.STATES.stunned then
            name = self.vx == 0 and "stun" or "hurt"
        else
            name = self.vx == 0 and "idle" or "run"
        end
    elseif self.kind == "skeleton" then
        if self.state == Enemy.STATES.bones or self.state == Enemy.STATES.rise then
            name = self.state == Enemy.STATES.bones and "bones" or "rise"
        else
            name = self.state == Enemy.STATES.walk and "walk" or "idle"
        end
    elseif self.kind == "bat" then
        if self.state == Enemy.STATES.hang then name = "hang"
        else name = self.facing < 0 and "left" or "right" end
    elseif self.state == Enemy.STATES.hang then
        name = "hang"
    elseif self.flipOnDrop then
        name = "flip"
    else
        name = "bounce"
    end

    if name ~= self.animationName then
        self.animationName = name
        self.animation = 0
    else
        local animation = ASSETS[self.kind][name]
        local fps = self.kind == "snake" and self.vx == 0 and 6
            or self.kind == "caveman" and self.state == Enemy.STATES.attack
                and name == "run" and 30
            or animation.fps
        self.animation = self.animation + fps / Enemy.TICK_RATE
    end
    if self.kind == "spider" and self.flipOnDrop
        and self.animation >= #ASSETS.spider.flip.paths then
        self.flipOnDrop = false
        self.animationName = "bounce"
        self.animation = 0
    end
    if self.kind == "skeleton" and self.state == Enemy.STATES.rise
        and self.animation >= #ASSETS.skeleton.rise.paths then
        self:setState(Enemy.STATES.idle, 20)
        self.animationName = "idle"
        self.animation = 0
    end
end

function Enemy:step(world, player)
    if not self.alive then return end
    self.justAlerted = false
    if self.kind == "snake" then
        self:updateSnake(world)
    elseif self.kind == "caveman" then
        self:updateCaveman(world, player)
    elseif self.kind == "skeleton" then
        self:updateSkeleton(world, player)
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

function Enemy:damage(amount, sourceX)
    if not self.alive then return false end
    if self.kind == "caveman" and self.state == Enemy.STATES.stunned then return false end
    self.hp = self.hp - (amount or 1)
    if self.hp <= 0 then
        self.alive = false
        self.vx, self.vy = 0, 0
        self:setState(Enemy.STATES.dead)
    elseif self.kind == "caveman" then
        self.vx = sourceX and (sourceX < self.x and 2 or -2) or 0
        self.vy = -3
        self:setState(Enemy.STATES.stunned, 200)
    end
    return true
end

function Enemy:resolvePlayerContact(player, previousPlayerY)
    if not self.alive or not self:overlapsPlayer(player) then return nil end
    if self.kind == "skeleton"
        and (self.state == Enemy.STATES.bones or self.state == Enemy.STATES.rise) then return nil end
    if self.kind == "caveman" and self.state == Enemy.STATES.stunned then return nil end

    local _, playerBottom = player:getVerticalBounds()
    local _, enemyTop = self:getBounds()
    local previousBottom = previousPlayerY + playerBottom
    if player.vy > 0 and player.y < self.y and previousBottom <= enemyTop + 3 then
        self:damage(1, player.x)
        player.vy = -6 - 0.2 * player.vy
        player.jumpTime = 10
        player.jumpReleased = true
        player:setState("jumping")
        return "stomp"
    end

    -- oEnemy contact flashes the player and gives a brief horizontal push;
    -- it does not launch or stun them.
    if player:hurt(self.x, 1, self.kind, nil, "enemy_contact") then
        if self.kind == "caveman" and player.y < self.y then player.vy = -6 end
        return "hurt"
    end
    return "invincible"
end

function Enemy:draw()
    local assets = loadedAssets or Enemy.loadAssets()
    local fallback = self.kind == "snake" and "walk"
        or self.kind == "caveman" and "idle" or "hang"
    if self.kind == "skeleton" then fallback = "idle" end
    local animation = assets[self.kind][self.animationName or fallback]
    local index = (math.floor(self.animation) % #animation.frames) + 1
    local image = animation.frames[index]
    local scaleX = 1
    local drawX = math.floor(self.x - 8)
    if (self.kind == "snake" or self.kind == "caveman" or self.kind == "skeleton")
        and self.facing > 0 then
        scaleX = -1
        drawX = math.floor(self.x + 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, drawX, math.floor(self.y - 16), 0, scaleX, 1)
end

return Enemy
