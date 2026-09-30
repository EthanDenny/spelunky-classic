local SpriteData = require("src.platform.player_sprite_data")

local Player = {}
Player.__index = Player

Player.TICK_RATE = 30
Player.ATTACK_SPEED = 0.6
Player.ATTACK_FRAMES = 11
Player.STATES = {
    standing = "standing",
    running = "running",
    ducking = "ducking",
    looking = "looking_up",
    climbing = "climbing",
    jumping = "jumping",
    falling = "falling",
    hanging = "hanging",
    duckToHang = "duck_to_hang",
    stunned = "stunned",
    dead = "dead",
}

local function sign(value)
    if value < 0 then return -1 end
    if value > 0 then return 1 end
    return 0
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function approximatelyZero(value)
    return math.abs(value) < 0.1
end

local function gameMakerRound(value)
    local integer = math.floor(value)
    local fraction = value - integer
    if fraction == 0.5 then
        return integer % 2 == 0 and integer or integer + 1
    end
    return math.floor(value + 0.5)
end

function Player.new(x, y)
    return setmetatable({
        x = x,
        y = y,
        spawnX = x,
        spawnY = y,
        vx = 0,
        vy = 0,
        ax = 0,
        ay = 0,
        xRemainder = 0,
        yRemainder = 0,
        tick = 0,
        state = Player.STATES.falling,
        statePrev = Player.STATES.falling,
        statePrevPrev = Player.STATES.falling,
        facing = 1,
        leftHeldSteps = 0,
        rightHeldSteps = 0,
        runHeld = 0,
        pushTimer = 0,
        hangCooldown = 0,
        ladderCooldown = 0,
        dropThroughTimer = 0,
        gravity = 1,
        gravityIntensity = 1,
        jumpTime = 10,
        jumpReleased = false,
        xVelocityLimit = 16,
        yVelocityLimit = 10,
        climbKind = nil,
        climbTileX = nil,
        hangTileX = nil,
        hangTileY = nil,
        transitionTicks = 0,
        transitionTarget = nil,
        currentInput = {},
        previousInput = {},
        spriteName = "sFallLeft",
        animationFrame = 0,
        images = nil,
        wideCollision = false,
        collisionTopOffset = -8,
        maxHealth = 4,
        health = 4,
        invincibleTimer = 0,
        whipping = false,
        whipCracked = false,
        whipJustCracked = false,
        whipHits = {},
        whipImages = nil,
        whipSound = nil,
        thudSound = nil,
        attackPressedThisStep = false,
        equipment = {},
        status = "normal",
        stunTimer = 0,
        burnTimer = 0,
        webTimer = 0,
        fallTimer = 0,
        parachuteOpen = false,
        jetpackFuel = 0,
    }, Player)
end

function Player:reset()
    self.x = self.spawnX
    self.y = self.spawnY
    self.vx = 0
    self.vy = 0
    self.ax = 0
    self.ay = 0
    self.xRemainder = 0
    self.yRemainder = 0
    self.tick = 0
    self.state = Player.STATES.falling
    self.statePrev = Player.STATES.falling
    self.statePrevPrev = Player.STATES.falling
    self.facing = 1
    self.leftHeldSteps = 0
    self.rightHeldSteps = 0
    self.runHeld = 0
    self.pushTimer = 0
    self.hangCooldown = 0
    self.ladderCooldown = 0
    self.dropThroughTimer = 0
    self.gravity = 1
    self.gravityIntensity = 1
    self.jumpTime = 10
    self.jumpReleased = false
    self.xVelocityLimit = 16
    self.yVelocityLimit = 10
    self.climbKind = nil
    self.hangTileX = nil
    self.hangTileY = nil
    self.transitionTicks = 0
    self.transitionTarget = nil
    self.spriteName = "sFallLeft"
    self.animationFrame = 0
    self.wideCollision = false
    self.collisionTopOffset = -8
    self.previousInput = {}
    self.health = self.maxHealth
    self.invincibleTimer = 0
    self.whipping = false
    self.whipCracked = false
    self.whipJustCracked = false
    self.whipHits = {}
    self.attackPressedThisStep = false
    self.status = "normal"
    self.stunTimer = 0
    self.burnTimer = 0
    self.webTimer = 0
    self.fallTimer = 0
    self.parachuteOpen = false
    self.jetpackFuel = 0
end

function Player:isDead()
    return self.health <= 0
end

function Player:refreshStatus()
    if self:isDead() then
        self.status = "dead"
    elseif self.burnTimer > 0 then
        self.status = "burning"
    elseif self.webTimer > 0 then
        self.status = "webbed"
    elseif self.stunTimer > 0 then
        self.status = "stunned"
    else
        self.status = "normal"
    end
    return self.status
end

function Player:kill(cause, vx, vy)
    if self:isDead() and self.state == Player.STATES.dead then return false end
    self.health = 0
    self.invincibleTimer = 0
    self.vx = vx == nil and self.vx or vx
    self.vy = vy == nil and self.vy or vy
    self.ax = 0
    self.ay = 0
    self.xRemainder = 0
    self.yRemainder = 0
    self.climbKind = nil
    self.transitionTarget = nil
    self.whipping = false
    self.stunTimer = 0
    self.status = "dead"
    self:setState(Player.STATES.dead)
    if self.playtestLog then self.playtestLog:record("player_killed", {
        cause = cause, x = self.x, y = self.y, vx = self.vx, vy = self.vy, tick = self.tick,
    }) end
    return true
end

function Player:hurt(sourceX, amount, cause, stunDuration)
    if self.invincibleTimer > 0 or self:isDead() then
        if self.playtestLog then self.playtestLog:record("damage_blocked", {
            sourceX = sourceX, amount = amount or 1, cause = cause,
            invincibleTimer = self.invincibleTimer, health = self.health, tick = self.tick,
        }) end
        return false
    end
    local previousHealth = self.health
    self.health = math.max(0, self.health - (amount or 1))
    self.invincibleTimer = 30
    self.vx = self.x < sourceX and -6 or 6
    self.vy = -4
    self.ax = 0
    self.ay = 0
    self.xRemainder = 0
    self.yRemainder = 0
    self.climbKind = nil
    self.transitionTarget = nil
    self.whipping = false
    self.stunTimer = self.health <= 0 and 0 or (stunDuration or 30)
    if self.health <= 0 then
        self:kill(cause, self.vx, self.vy)
    else
        self:setState(Player.STATES.stunned)
        self:refreshStatus()
    end
    if self.playtestLog then self.playtestLog:record("player_hurt", {
        sourceX = sourceX, amount = amount or 1, cause = cause,
        healthBefore = previousHealth, healthAfter = self.health,
        x = self.x, y = self.y, tick = self.tick,
    }) end
    return true
end

function Player:burn(sourceX)
    if self:isDead() or self.invincibleTimer > 0 then return false end
    -- oMagma/oMagmaMan set burning to 100, stun for 20 steps, and remove
    -- two life. Burning itself is presentation state and does no periodic
    -- damage in oPlayer1's step event.
    self.burnTimer = math.max(self.burnTimer, 100)
    local hurt = self:hurt(sourceX, 2, "burning", 20)
    self:refreshStatus()
    return hurt
end

function Player:landHard()
    -- oPlayer1 measures descending steps, not peak speed. A long drop
    -- subtracts life and bounces vertically without horizontal knockback.
    local duration = self.fallTimer
    local damage = duration > 48 and 10 or (duration > 32 and 2 or 1)
    local previousHealth = self.health
    self.health = math.max(0, self.health - damage)
    self.vy = -3
    self.fallTimer = 0
    if self.health <= 0 then
        self:kill("fall", self.vx, self.vy)
    else
        self.stunTimer = self.stunTimer + 60
        self:setState(Player.STATES.stunned)
        self:refreshStatus()
    end
    if self.thudSound then self.thudSound:clone():play() end
    if self.playtestLog then self.playtestLog:record("player_hurt", {
        amount = damage, cause = "fall", healthBefore = previousHealth,
        healthAfter = self.health, x = self.x, y = self.y, tick = self.tick,
        fallTimer = duration,
    }) end
end

function Player:enterLava()
    if self:isDead() then return false end
    -- oPlayer1: collision_point(x, y+6, oLava) removes 99 life, zeroes
    -- horizontal movement, and leaves a tiny downward velocity.
    self.burnTimer = math.max(self.burnTimer, 100)
    return self:kill("lava", 0, 0.1)
end

function Player:web(duration)
    self.webTimer = math.max(self.webTimer, duration or 30)
    self:refreshStatus()
end

function Player:isStunned()
    return self.stunTimer > 0 or self.state == Player.STATES.stunned
end

function Player:loadAssets()
    if self.images then return end
    self.images = {}
    for name, data in pairs(SpriteData) do
        local frames = {}
        for _, path in ipairs(data.frames) do
            local image = love.graphics.newImage(path)
            image:setFilter("nearest", "nearest")
            frames[#frames + 1] = image
        end
        self.images[name] = { data = data, frames = frames }
    end
    self.whipImages = {}
    for _, name in ipairs({ "sWhipLeft", "sWhipRight", "sWhipPreL", "sWhipPreR" }) do
        local image = love.graphics.newImage("assets/original/platform/whip/" .. name .. ".png")
        image:setFilter("nearest", "nearest")
        self.whipImages[name] = image
    end
    self.whipSound = love.audio.newSource("original-game-reference/sound/whip.wav", "static")
    self.thudSound = love.audio.newSource("original-game-reference/sound/thud.wav", "static")
end

function Player:startWhip()
    if self.whipping or self:isDead()
        or self.state == Player.STATES.ducking
        or self.state == Player.STATES.duckToHang then
        return false
    end
    self.whipping = true
    self.whipCracked = false
    self.whipJustCracked = false
    self.whipHits = {}
    self.spriteName = "sAttackLeft"
    self.animationFrame = 0
    return true
end

function Player:getWhipPhase()
    if not self.whipping then return nil end
    if self.animationFrame < 2 then return "back" end
    if self.animationFrame > 4 then return "front" end
    return nil
end

function Player:getWhipHitbox()
    local phase = self:getWhipPhase()
    if not phase then return nil end
    local direction = phase == "back" and -self.facing or self.facing
    local centerX = self.x + direction * 16
    return centerX - 8, self.y - 8, centerX + 8, self.y + 8, phase
end

function Player:whipCanHit(target)
    return self.whipping and not self.whipHits[target]
end

function Player:markWhipHit(target)
    self.whipHits[target] = true
end

function Player:updateWhip(input)
    self.whipJustCracked = false
    if self.attackPressedThisStep and not input.suppressWhip then self:startWhip() end
    if not self.whipping then return end

    if self.animationFrame > 4 and not self.whipCracked then
        self.whipCracked = true
        self.whipJustCracked = true
        if self.whipSound then self.whipSound:clone():play() end
    end

    if self.animationFrame >= Player.ATTACK_FRAMES then
        self.whipping = false
    end
end

function Player:getCollisionHalfWidth()
    return self.wideCollision and 8 or 5
end

function Player:getVerticalBounds()
    return self.collisionTopOffset, 8
end

function Player:isGroundState()
    return self.state == Player.STATES.standing
        or self.state == Player.STATES.running
        or self.state == Player.STATES.ducking
        or self.state == Player.STATES.looking
end

function Player:isAirState()
    return self.state == Player.STATES.jumping or self.state == Player.STATES.falling
end

function Player:setState(state)
    if self.state ~= state then
        self.state = state
    end
end

function Player:pressed(input, name)
    if input[name .. "Pressed"] ~= nil then
        return input[name .. "Pressed"]
    end
    return input[name] and not self.previousInput[name]
end

function Player:released(input, name)
    if input[name .. "Released"] ~= nil then
        return input[name .. "Released"]
    end
    return not input[name] and self.previousInput[name]
end

function Player:quantizedPixels(distance)
    local magnitude = math.abs(distance)
    local pixels = math.floor(magnitude)
    local fraction = magnitude - pixels
    if fraction ~= 0 then
        local period = gameMakerRound(1 / fraction)
        if period ~= 0 and self.tick % period == 0 then
            pixels = pixels + 1
        end
    end
    return pixels * sign(distance)
end

function Player:consumeVerticalPixels(distance)
    return self:quantizedPixels(distance)
end

function Player:moveHorizontal(world, distance)
    local pixels = self:quantizedPixels(distance)
    local direction = sign(pixels)
    local hitWall = false
    for _ = 1, math.abs(pixels) do
        local hit, hitX, hitY = world:collidesSolid(self, self.x + direction, self.y)
        if hit then
            if self.playtestLog then self.playtestLog:record("collision", {
                axis = "horizontal", x = self.x + direction, y = self.y,
                cellX = type(hitX) == "number" and hitX or nil,
                cellY = hitY, dynamicKind = type(hitX) == "table" and hitX.kind or nil,
                tick = self.tick,
            }) end
            self.xRemainder = 0
            hitWall = true
            break
        end
        self.x = self.x + direction
    end
    return hitWall
end

function Player:moveVertical(world, distance, ignorePlatforms)
    local pixels = self:quantizedPixels(distance)
    local direction = sign(pixels)
    local landed = false
    local hitCeiling = false
    for _ = 1, math.abs(pixels) do
        local nextY = self.y + direction
        local hit, hitX, hitY = world:collidesSolid(self, self.x, nextY)
        if hit then
            if self.playtestLog then self.playtestLog:record("collision", {
                axis = "vertical", x = self.x, y = nextY,
                cellX = type(hitX) == "number" and hitX or nil,
                cellY = hitY, dynamicKind = type(hitX) == "table" and hitX.kind or nil,
                tick = self.tick,
            }) end
            self.yRemainder = 0
            if direction > 0 then landed = true else hitCeiling = true end
            break
        end
        if direction > 0 and not ignorePlatforms then
            local platformY = world:platformLanding(self, self.y, nextY)
            if platformY then
                if self.playtestLog then self.playtestLog:record("collision", {
                    axis = "platform", x = self.x, y = platformY, tick = self.tick,
                }) end
                self.y = platformY
                self.yRemainder = 0
                landed = true
                break
            end
        end
        self.y = nextY
    end
    return landed, hitCeiling
end

function Player:enterClimb(world, input)
    if self.ladderCooldown > 0 then
        return false
    end

    local kind, tileX, tileY
    if input.up then
        kind, tileX, tileY = world:climbableAtPoint(self.x, self.y - 8)
        if not kind then
            kind, tileX, tileY = world:climbableAtPoint(self.x, self.y)
        end
    elseif input.down then
        if not self:isGroundState() then
            return false
        end
        kind, tileX, tileY = world:climbableAtPoint(self.x, self.y + 8)
        if not kind then
            kind, tileX, tileY = world:climbableAtPoint(self.x, self.y + 16)
        end
        if not kind then
            kind, tileX, tileY = world:climbableAtPoint(self.x, self.y)
        end
    end
    if not kind then
        return false
    end

    -- The original platform engine treats oRope as an oLadder child and
    -- centers every climber at ladder.x + 8. Rope body instances are placed
    -- eight pixels left of their hook, so this aligns the player to the hook.
    local centerX = tileX * world.tileSize + world.tileSize / 2
    if math.abs(self.x - centerX) >= 4 then
        return false
    end
    self.x = centerX
    self.vx = 0
    self.vy = 0
    self.ax = 0
    self.ay = 0
    self.xRemainder = 0
    self.yRemainder = 0
    self.climbKind = kind
    self.climbTileX = tileX
    self.wideCollision = false
    self.collisionTopOffset = -8
    self:setState(Player.STATES.climbing)
    return true
end

function Player:updateClimbing(world, input, jumpPressed)
    self.gravity = 1
    self.wideCollision = false
    self.collisionTopOffset = -8
    local kind, tileX = world:climbableAtPoint(self.x, self.y)
    if kind then
        self.x = tileX * world.tileSize + world.tileSize / 2
    end
    if input.left ~= input.right then
        self.facing = input.left and -1 or 1
    end

    if input.up and world:climbableAtPoint(self.x, self.y - 8) then
        self.ay = self.ay - 0.6
    elseif input.down then
        if world:climbableAtPoint(self.x, self.y + 8) then
            self.ay = self.ay + 0.6
        else
            self:setState(Player.STATES.falling)
        end
        if world:collidesSolid(self, self.x, self.y + 1) then
            self.vy = 0
            self.ay = 0
            self:setState(Player.STATES.standing)
        end
    end

    if jumpPressed then
        self.vx = input.left and -4 or (input.right and 4 or 0)
        self.ay = self.ay - (self.equipment.spring_shoes and 6 or 4)
        self.climbKind = nil
        self.ladderCooldown = 5
        self.jumpTime = 0
        self.jumpReleased = false
        self:setState(Player.STATES.jumping)
    end

    if self:isAirState() then
        self.ay = self.ay + self.gravityIntensity
    end
    if self.jumpTime < 10 then
        self.jumpTime = self.jumpTime + 1
    end
    if not input.jump then
        self.jumpReleased = true
    end
    if self.jumpReleased then
        self.jumpTime = 10
    end
    self.gravityIntensity = self.jumpTime / 10 * self.gravity

    if self.vy < 0 and self:isAirState() then
        self:setState(Player.STATES.jumping)
    elseif self.vy > 0 and self:isAirState() then
        self:setState(Player.STATES.falling)
    end
    self.collisionTopOffset = self.vy > 0 and self:isAirState() and -6 or -8

    local xFriction = self.state == Player.STATES.climbing and 0.6
        or (self:isAirState() and 0.8 or 0.6)
    local yFriction = self.state == Player.STATES.climbing and 0.6 or 1

    self.ax = clamp(self.ax, -9, 9)
    self.ay = clamp(self.ay, -6, 6)
    self.vx = (self.vx + self.ax) * xFriction
    self.vy = (self.vy + self.ay) * yFriction
    self.ax = 0
    self.ay = 0
    self.vx = clamp(self.vx, -self.xVelocityLimit, self.xVelocityLimit)
    self.vy = clamp(self.vy, -self.yVelocityLimit, self.yVelocityLimit)
    if approximatelyZero(self.vx) then self.vx = 0 end
    if approximatelyZero(self.vy) then self.vy = 0 end

    self:moveHorizontal(world, self.vx)
    self:moveVertical(world, self.vy, input.down)

    if self.state ~= Player.STATES.climbing then
        self.climbKind = nil
    end
end

function Player:beginHang(ledge)
    self.x = ledge.x
    self.y = ledge.y
    self.vx = 0
    self.vy = 0
    self.ax = 0
    self.ay = 0
    self.xRemainder = 0
    self.yRemainder = 0
    self.facing = ledge.direction
    self.gravity = 0
    self.hangTileX = ledge.tileX
    self.hangTileY = ledge.tileY
    self:setState(Player.STATES.hanging)
end

function Player:updateHanging(world, input, jumpPressed)
    self.wideCollision = false
    self.collisionTopOffset = -8
    if not self.hangTileX or not world:has("solid", self.hangTileX, self.hangTileY) then
        self.hangCooldown = 4
        self.gravity = 1
        self.ay = self.ay - self.gravity
        self:setState(Player.STATES.falling)
    end

    if self.state == Player.STATES.hanging then
        local away = (self.facing == 1 and input.left) or (self.facing == -1 and input.right)
        if jumpPressed and input.down then
            self.hangCooldown = 5
            self.gravity = 1
            self.ay = self.ay - self.gravity
            self:setState(Player.STATES.falling)
        elseif jumpPressed and away then
            self.hangCooldown = 3
            self.gravity = 1
            self.ay = self.ay - self.gravity
            self:setState(Player.STATES.falling)
        elseif jumpPressed then
            self.hangCooldown = 3
            self.gravity = 1
            self.ay = self.ay - 4
            -- Spelunky 1.1 checks ledge support again after this offset.
            self.x = self.x - self.facing * 2
            self:setState(Player.STATES.jumping)
        end

        local halfWidth = self:getCollisionHalfWidth()
        local topOffset, bottomOffset = self:getVerticalBounds()
        -- isCollisionLeft(2) probes lb-2; isCollisionRight(2) probes rb+2-1.
        local sideX = self.facing < 0 and self.x - halfWidth - 2
            or self.x + halfWidth + 1
        if not world:overlaps("solid", sideX, self.y + topOffset,
            sideX + 1, self.y + bottomOffset) then
            self.gravity = 1
            self:setState(Player.STATES.falling)
            self.ay = self.ay - self.gravity
            self.hangCooldown = 4
        end
    end

    -- The original variable-jump calculation observes grav == 0 on every
    -- completed hanging step. Preserve that zero for the first airborne step
    -- instead of carrying normal falling gravity into a ledge jump.
    if self.state == Player.STATES.hanging then
        self.gravityIntensity = 0
    end

    if self.state ~= Player.STATES.hanging then
        self.vx = (self.vx + self.ax) * 0.8
        self.vy = self.vy + self.ay
        self.ax = 0
        self.ay = 0
        self.vx = clamp(self.vx, -self.xVelocityLimit, self.xVelocityLimit)
        self.vy = clamp(self.vy, -self.yVelocityLimit, self.yVelocityLimit)
        if approximatelyZero(self.vx) then self.vx = 0 end
        if approximatelyZero(self.vy) then self.vy = 0 end
        self:moveHorizontal(world, self.vx)
        self:moveVertical(world, self.vy)
    end
end

function Player:edgeTransition(world, direction)
    if not world:solidAtPoint(self.x, self.y + 9) then
        return false
    end
    local aheadX = self.x + direction
    if world:solidAtPoint(aheadX, self.y + 9) then
        return false
    end

    self.transitionTarget = { x = self.x, y = self.y, direction = direction }
    self.transitionTicks = 12
    self.vx = 0
    self.vy = 0
    self.xRemainder = 0
    self.yRemainder = 0
    self:setState(Player.STATES.duckToHang)
    return true
end

function Player:updateDuckToHang()
    self.transitionTicks = self.transitionTicks - 1
    if self.transitionTicks <= 0 and self.transitionTarget then
        local target = self.transitionTarget
        self.transitionTarget = nil
        local y = math.floor((target.y + 16) / 8 + 0.5) * 8
        if target.direction < 0 then
            local x = target.x - 5
            self:beginHang({
                x = x,
                y = y,
                direction = 1,
                tileX = math.floor((x + 6) / 16),
                tileY = math.floor((y - 5) / 16),
            })
        else
            local x = target.x + 6
            self:beginHang({
                x = x,
                y = y,
                direction = -1,
                tileX = math.floor((x - 6) / 16),
                tileY = math.floor((y - 5) / 16),
            })
        end
    end
end

function Player:updateNormal(world, input, jumpPressed, jumpReleased)
    self.gravity = 1
    local colLeft = world:collidesSolid(self, self.x - 1, self.y)
    local colRight = world:collidesSolid(self, self.x + 1, self.y)
    local colMoveableLeft = world:overlapsPlayer("moveableSolid", self, self.x - 1, self.y)
    local colMoveableRight = world:overlapsPlayer("moveableSolid", self, self.x + 1, self.y)
    local colTop = world:collidesSolid(self, self.x, self.y - 1)
    local colBottom = world:collidesSolid(self, self.x, self.y + 1)
    local colPlatformBottom = self.dropThroughTimer == 0
        and world:platformLanding(self, self.y, self.y + 1) ~= nil
    local colPlatform = world:overlapsPlayer("platform", self, self.x, self.y)

    local runKey = not not input.sprint

    local direction = 0
    if input.left ~= input.right then
        direction = input.left and -1 or 1
    end

    if self:released(input, "left") and approximatelyZero(self.vx) then
        self.ax = self.ax - 0.5
    end
    if self:released(input, "right") and approximatelyZero(self.vx) then
        self.ax = self.ax + 0.5
    end

    if input.left and not input.right then
        if colMoveableLeft then
            if self:isGroundState() and self.state ~= Player.STATES.ducking then
                self.ax = self.ax - 1
                self.pushTimer = self.pushTimer + 10
            end
        elseif self.leftHeldSteps > 2 and (self.facing == -1 or approximatelyZero(self.vx)) then
            self.ax = self.ax - 3
        end
        self.facing = -1
    end

    if input.right and not input.left then
        if colMoveableRight then
            if self:isGroundState() and self.state ~= Player.STATES.ducking then
                self.ax = self.ax + 1
                self.pushTimer = self.pushTimer + 10
            end
        elseif self.rightHeldSteps > 2 and (self.facing == 1 or approximatelyZero(self.vx)) then
            self.ax = self.ax + 3
        end
        self.facing = 1
    end

    if self:isAirState() then
        self.ay = self.ay + self.gravityIntensity
    end

    if (colBottom or colPlatformBottom) and self:isAirState() and self.vy >= 0 then
        if not colPlatform or colBottom then
            self.vy = 0
            self.ay = 0
            self:setState(Player.STATES.running)
        end
    end
    if (colBottom or colPlatformBottom) and not colPlatform then
        self.vy = 0
    end

    if not colBottom and (not colPlatformBottom or colPlatform) and self:isGroundState() then
        self:setState(Player.STATES.falling)
        self.ay = self.ay + self.gravity
    end

    if colTop and self.state == Player.STATES.jumping then
        self.vy = math.abs(self.vy * 0.3)
    end
    if (colLeft and self.facing == -1) or (colRight and self.facing == 1) then
        self.vx = 0
    end

    if jumpReleased and self:isAirState() then
        self.jumpReleased = true
    elseif self:isGroundState() then
        self.jumpReleased = false
    end

    if self:isGroundState() and jumpPressed then
        self.ay = self.ay - 4
        if math.abs(self.vx) > 3 then
            self.ax = self.ax + self.vx * 2
        else
            self.ax = self.ax + self.vx / 2
        end
        self.state = Player.STATES.falling
        self.jumpReleased = false
        self.jumpTime = 0
    end

    if self.jumpTime < 10 then
        self.jumpTime = self.jumpTime + 1
    end
    if not input.jump then
        self.jumpReleased = true
    end
    if self.jumpReleased then
        self.jumpTime = 10
    end
    self.gravityIntensity = self.jumpTime / 10 * self.gravity

    if input.up and self:isGroundState() and not world:climbableAtPoint(self.x, self.y) then
        if self.vx == 0 and self.ax == 0 then
            self.state = Player.STATES.looking
        end
    elseif not input.up and self.state == Player.STATES.looking then
        self.state = Player.STATES.standing
    end

    if input.down and self:isGroundState() then
        if colBottom then
            self.state = Player.STATES.ducking
        elseif colPlatformBottom then
            if self:enterClimb(world, input) then
                return
            else
                self.y = self.y + 1
                self.state = Player.STATES.falling
                self.ay = self.ay + self.gravity
                self.dropThroughTimer = 1
            end
        end
    elseif not input.down and self.state == Player.STATES.ducking then
        self.state = Player.STATES.standing
        self.vx = 0
        self.ax = 0
    end

    if self.vx == 0 and self.ax == 0 and self.state == Player.STATES.running then
        self.state = Player.STATES.standing
    end
    if self.ax ~= 0 and self.state == Player.STATES.standing then
        self.state = Player.STATES.running
    end
    if self.vy < 0 and self:isAirState() then
        self.state = Player.STATES.jumping
    elseif self.vy > 0 and self:isAirState() then
        self.state = Player.STATES.falling
    end
    self.collisionTopOffset = self.vy > 0 and self:isAirState() and -6 or -8
    self.wideCollision = false

    if not colTop and self.hangCooldown == 0 and self.y > 16 and self:isAirState()
        and direction ~= 0 and ((direction < 0 and colLeft) or (direction > 0 and colRight)) then
        local ledge = world:ledgeFor(self, direction)
        if ledge then
            self:beginHang(ledge)
            self:updateHanging(world, input, jumpPressed)
            return
        elseif self.equipment.gloves then
            self.vy = math.min(0, self.vy)
            self.ay = 0
            if jumpPressed then
                self.vx = -direction * 5
                self.vy = -5
                self.facing = -direction
                self.hangCooldown = 5
            end
        end
    end

    if self:enterClimb(world, input) then
        return
    end

    local xFriction
    local yFriction = 1
    if runKey and self:isGroundState() and self.runHeld >= 10 then
        if input.left then
            self.vx = self.vx - 0.1
        elseif input.right then
            self.vx = self.vx + 0.1
        end
        self.xVelocityLimit = 6
        xFriction = 0.98
    elseif self.state == Player.STATES.ducking then
        if self.vx < 2 and self.vx > -2 then
            xFriction = 0.2
            self.xVelocityLimit = 3
        elseif input.left and input.downToRun then
            self.vx = self.vx - 0.1
            self.xVelocityLimit = 6
            xFriction = 0.98
        elseif input.right and input.downToRun then
            self.vx = self.vx + 0.1
            self.xVelocityLimit = 6
            xFriction = 0.98
        else
            self.vx = self.vx * 0.8
            if self.vx < 0.5 then self.vx = 0 end
            xFriction = 0.2
            self.xVelocityLimit = 3
        end
    elseif self:isAirState() then
        xFriction = 0.8
    else
        xFriction = 0.6
    end

    if self:isGroundState() and not input.jump and not input.down and not runKey then
        self.xVelocityLimit = 3
    end

    if self:isGroundState() then
        if self.state == Player.STATES.running and direction < 0 and colLeft then
            self.pushTimer = self.pushTimer + 1
        elseif self.state == Player.STATES.running and direction > 0 and colRight then
            self.pushTimer = self.pushTimer + 1
        else
            self.pushTimer = 0
        end

        if self.state == Player.STATES.ducking and math.abs(self.vx) < 3
            and direction ~= 0 and self:edgeTransition(world, direction) then
            return
        end
    end

    self.pushTimer = math.min(self.pushTimer, 100)
    if self:isGroundState() and self.pushTimer > 20 and direction ~= 0 then
        world:tryPush(self, direction)
    end
    self.ax = clamp(self.ax, -9, 9)
    self.ay = clamp(self.ay, -6, 6)
    self.vx = (self.vx + self.ax) * xFriction
    self.vy = (self.vy + self.ay) * yFriction
    self.ax = 0
    self.ay = 0
    self.vx = clamp(self.vx, -self.xVelocityLimit, self.xVelocityLimit)
    self.vy = clamp(self.vy, -self.yVelocityLimit, self.yVelocityLimit)
    if approximatelyZero(self.vx) then self.vx = 0 end
    if approximatelyZero(self.vy) then self.vy = 0 end

    self:moveHorizontal(world, self.vx)
    self:moveVertical(world, self.vy, input.down)

end

function Player:selectSprite(world)
    local sprite
    local speed = 0
    if self.whipping then
        sprite = "sAttackLeft"
        speed = Player.ATTACK_SPEED * Player.TICK_RATE
    elseif self.state == Player.STATES.running then
        sprite = self.currentInput.up and "sLookRunL" or "sRunLeft"
        speed = math.min(30, (math.abs(self.vx) * 0.1 + 0.1) * 30)
    elseif self.state == Player.STATES.ducking then
        if self.vx == 0 then
            sprite = "sDuckLeft"
        elseif math.abs(self.vx) < 3 then
            sprite = "sCrawlLeft"
            speed = 24
        else
            sprite = "sRunLeft"
        end
    elseif self.state == Player.STATES.looking then
        sprite = math.abs(self.vx) > 0.15 and "sLookRunL" or "sLookLeft"
        speed = math.min(30, (math.abs(self.vx) * 0.1 + 0.1) * 30)
    elseif self.state == Player.STATES.jumping then
        sprite = "sJumpLeft"
    elseif self.state == Player.STATES.falling then
        if self.statePrev == Player.STATES.falling
            and self.statePrevPrev == Player.STATES.falling then
            sprite = "sFallLeft"
        else
            sprite = self.spriteName
        end
    elseif self.state == Player.STATES.stunned then
        sprite = self.vx == 0 and "sStunL" or "sFallLeft"
        speed = 0.4 * Player.TICK_RATE
    elseif self.state == Player.STATES.dead then
        sprite = "sFallLeft"
    elseif self.state == Player.STATES.hanging then
        sprite = "sHangLeft"
    elseif self.state == Player.STATES.climbing then
        if self.climbKind == "rope" then
            sprite = self.currentInput.down and "sClimbUp3" or "sClimbUp2"
        else
            sprite = "sClimbUp"
        end
        speed = math.min(30, math.sqrt(self.vx * self.vx + self.vy * self.vy) * 0.4 * 30)
    elseif self.state == Player.STATES.duckToHang then
        sprite = "sDuckToHangL"
        speed = 24
    else
        local supportX = self.x - 2
        if world and not world:solidAtPoint(supportX, self.y + 9) then
            sprite = "sWhoaLeft"
            speed = 18
        else
            sprite = "sStandLeft"
        end
    end
    -- characterSprite.gml applies stress after the normal ground/air/hang
    -- choice, but climbing and duck-to-hang override it later in that script.
    if not self.whipping and self.pushTimer > 20
        and self.state ~= Player.STATES.climbing
        and self.state ~= Player.STATES.duckToHang then
        sprite = "sPushLeft"
        speed = math.min(30, (math.abs(self.vx) * 0.1 + 0.1) * 30)
    end
    return sprite or self.spriteName, speed
end

function Player:updateAnimation(world)
    local sprite, fps = self:selectSprite(world)
    if self.spriteName ~= sprite then
        self.spriteName = sprite
        self.animationFrame = 0
    elseif fps > 0 then
        self.animationFrame = self.animationFrame + fps / Player.TICK_RATE
    end
end

function Player:step(world, input)
    input = input or {}
    world.time = (world.time or 0) + 1
    self.tick = world.time
    self.currentInput = input
    local jumpPressed = self:pressed(input, "jump")
    local jumpReleased = self:released(input, "jump")
    self.attackPressedThisStep = self:pressed(input, "attack")

    self.leftHeldSteps = input.left and self.leftHeldSteps + 1 or 0
    self.rightHeldSteps = input.right and self.rightHeldSteps + 1 or 0
    if input.sprint then
        self.runHeld = 100
    end
    if not input.sprint or (not input.left and not input.right) then
        self.runHeld = 0
    end

    local wasHanging = self.state == Player.STATES.hanging
    local decrementHangCooldown = self.hangCooldown > 0
    if wasHanging and decrementHangCooldown then
        self.hangCooldown = self.hangCooldown - 1
    end
    if self.ladderCooldown > 0 then self.ladderCooldown = self.ladderCooldown - 1 end
    if self.dropThroughTimer > 0 then self.dropThroughTimer = self.dropThroughTimer - 1 end
    if self.invincibleTimer > 0 then self.invincibleTimer = self.invincibleTimer - 1 end

    if self.burnTimer > 0 then
        self.burnTimer = self.burnTimer - 1
    end
    if self.webTimer > 0 then self.webTimer = self.webTimer - 1 end
    self:refreshStatus()

    if self.vy > 0 and self.state ~= Player.STATES.climbing then
        self.fallTimer = self.fallTimer + 1
    elseif self:isGroundState() then
        if self.fallTimer > 16 and not self.parachuteOpen then self:landHard() end
        self.fallTimer = 0
    else
        self.fallTimer = 0
    end

    if self:isDead() then
        self.state = Player.STATES.dead
        self:updateAnimation(world)
        return
    end

    if self.stunTimer > 0 then
        self.stunTimer = self.stunTimer - 1
        self.vy = math.min(self.yVelocityLimit, self.vy + 0.6)
        if self.webTimer > 0 then
            self.vx = self.vx * 0.5
            self.vy = self.vy * 0.5
        end
        if self:moveHorizontal(world, self.vx) then self.vx = -self.vx * 0.25 end
        local landed = self:moveVertical(world, self.vy, false)
        if landed then
            self.vy = 0
            self.vx = self.vx * 0.75
        end
        if self.stunTimer == 0 then
            self:setState(landed and Player.STATES.standing or Player.STATES.falling)
            self:refreshStatus()
        end
        self:updateAnimation(world)
        self:updateWhip({})
        return
    end

    if self.state == Player.STATES.hanging then
        self:updateHanging(world, input, jumpPressed)
    elseif self.state == Player.STATES.climbing then
        self:updateClimbing(world, input, jumpPressed)
    elseif self.state == Player.STATES.duckToHang then
        self:updateDuckToHang()
    else
        self:updateNormal(world, input, jumpPressed, jumpReleased)
    end

    if self.equipment.jetpack and input.jump and self:isAirState() and self.jumpTime >= 10 then
        self.vy = math.max(-4, self.vy - 1.25)
        self.jetpackFuel = self.jetpackFuel + 1
    elseif self.vy > 0 and self:isAirState() then
        if self.equipment.cape and input.jump then
            self.vy = math.min(self.vy, 2)
            self.fallTimer = 0
        end
        if self.equipment.parachute and self.vy >= 7 then
            self.parachuteOpen = true
            self.vy = math.min(self.vy, 2)
            self.fallTimer = 0
        end
    end

    if self:isGroundState() and self.parachuteOpen then
        self.equipment.parachute = false
        self.parachuteOpen = false
        self.fallTimer = 0
    end

    if not wasHanging and decrementHangCooldown then
        self.hangCooldown = self.hangCooldown - 1
    end

    self:updateAnimation(world)
    self:updateWhip(input)
    self.statePrevPrev = self.statePrev
    self.statePrev = self.state
    self.wideCollision = math.abs(self.vx) >= 4 and self:isGroundState()
    self.collisionTopOffset = -8
    self.previousInput = {
        left = not not input.left,
        right = not not input.right,
        up = not not input.up,
        down = not not input.down,
        jump = not not input.jump,
        sprint = not not input.sprint,
        attack = not not input.attack,
    }
end

function Player:getAnimationFrame()
    local sprite = assert(self.images and self.images[self.spriteName],
        "Player sprite assets are not loaded: " .. tostring(self.spriteName))
    local index = (math.floor(self.animationFrame) % #sprite.frames) + 1
    return sprite, sprite.frames[index]
end

function Player:draw()
    local sprite, image = self:getAnimationFrame()
    local scaleX = self.facing == -1 and 1 or -1
    love.graphics.setColor(1, 1, 1, 1)
    local phase = self:getWhipPhase()
    if phase == "back" then
        local name = self.facing < 0 and "sWhipPreL" or "sWhipPreR"
        local whip = self.whipImages and self.whipImages[name]
        local whipX = self.x - self.facing * 16
        if whip then love.graphics.draw(whip, math.floor(whipX), math.floor(self.y), 0, 1, 1, 8, 8) end
    end
    love.graphics.draw(image, math.floor(self.x), math.floor(self.y), 0,
        scaleX, 1, sprite.data.originX, sprite.data.originY)
    if phase == "front" then
        local name = self.facing < 0 and "sWhipLeft" or "sWhipRight"
        local whip = self.whipImages and self.whipImages[name]
        local whipX = self.x + self.facing * 16
        if whip then love.graphics.draw(whip, math.floor(whipX), math.floor(self.y), 0, 1, 1, 8, 8) end
    end
end

return Player
