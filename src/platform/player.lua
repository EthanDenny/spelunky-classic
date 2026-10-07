local SpriteData = require("src.platform.player_sprite_data")
local WhipMask = require("src.platform.whip_mask")
local Ball = require("src.platform.items.ball")
local Cape = require("src.platform.pickups.cape")
local Jetpack = require("src.platform.pickups.jetpack")

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

local SourceMath = require("src.platform.source_math")
local gameMakerRound = SourceMath.roundEven

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
        jumpRearmed = false,
        cantJumpTimer = 0,
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
        attackKind = nil,
        meleeJustStruck = false,
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
        deadBounced = false,
        wallHurt = 0,
        webTimer = 0,
        fallTimer = 0,
        parachuteOpen = false,
        capeOpen = false,
        jetpackFuel = 0,
        jetpackSoundTimer = 0,
        climbSoundTimer = 0,
        climbSoundToggle = false,
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
    self.jumpRearmed = false
    self.cantJumpTimer = 0
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
    self.attackKind = nil
    self.meleeJustStruck = false
    self.whipCracked = false
    self.whipJustCracked = false
    self.whipHits = {}
    self.attackPressedThisStep = false
    self.status = "normal"
    self.stunTimer = 0
    self.deadBounced = false
    self.wallHurt = 0
    self.webTimer = 0
    self.fallTimer = 0
    self.parachuteOpen = false
    self.capeOpen = false
    self.capeFrame = 0
    self.jetpackFuel = 0
    self.jetpackSoundTimer, self.climbSoundTimer, self.climbSoundToggle = 0, 0, false
end

function Player:isDead()
    return self.health <= 0
end

function Player:refreshStatus()
    if self:isDead() then
        self.status = "dead"
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
    if self.sounds then self.sounds:play("die") end
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
    self.stunTimer = 0
    self.deadBounced = cause == "fall"
    self.capeOpen = false
    self.wideCollision = false
    self.collisionTopOffset = -8
    self.status = "dead"
    self:setState(Player.STATES.dead)
    if self.playtestLog then self.playtestLog:record("player_killed", {
        cause = cause, x = self.x, y = self.y, vx = self.vx, vy = self.vy, tick = self.tick,
    }) end
    return true
end

function Player:hurt(sourceX, amount, cause, stunDuration, reaction, impactVx)
    local directImpact = reaction == "bullet" or reaction == "arrow" or reaction == "rock"
    if (self.invincibleTimer > 0 and not directImpact) or self:isDead() then
        if self.playtestLog then self.playtestLog:record("damage_blocked", {
            sourceX = sourceX, amount = amount or 1, cause = cause,
            invincibleTimer = self.invincibleTimer, health = self.health, tick = self.tick,
        }) end
        return false
    end
    local previousHealth = self.health
    if self.sounds then self.sounds:play("hurt") end
    self.health = math.max(0, self.health - (amount or 1))
    if not directImpact then self.invincibleTimer = 30 end
    self.vx = directImpact and impactVx or (self.x < sourceX and -6 or 6)
    if reaction ~= "enemy_contact" then
        self.vy = -4
        self.ax = 0
        self.ay = 0
        self.xRemainder = 0
        self.yRemainder = 0
        self.climbKind = nil
        self.transitionTarget = nil
        self.stunTimer = self.health <= 0 and 0 or (stunDuration or 30)
        self.deadBounced = false
    end
    if self.health <= 0 then
        self:kill(cause, self.vx, self.vy)
    elseif reaction ~= "enemy_contact" then
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

function Player:landHard()
    -- oPlayer1 measures descending steps, not peak speed. A long drop
    -- subtracts life and bounces vertically without horizontal knockback.
    if self.sounds then self.sounds:play("thud")
    elseif self.thudSound then self.thudSound:clone():play() end
    local duration = self.fallTimer
    local damage = duration > 48 and 10 or (duration > 32 and 2 or 1)
    local previousHealth = self.health
    self.health = math.max(0, self.health - damage)
    self.vy = -3
    self.deadBounced = true
    self.fallTimer = 0
    if self.health <= 0 then
        self:kill("fall", self.vx, self.vy)
    else
        self.stunTimer = self.stunTimer + 60
        self:setState(Player.STATES.stunned)
        self:refreshStatus()
    end
    if self.playtestLog then self.playtestLog:record("player_hurt", {
        amount = damage, cause = "fall", healthBefore = previousHealth,
        healthAfter = self.health, x = self.x, y = self.y, tick = self.tick,
        fallTimer = duration,
    }) end
end

function Player:web(duration)
    self.webTimer = math.max(self.webTimer, duration or 30)
    self:refreshStatus()
end

function Player:isStunned()
    return self.stunTimer > 0 or self.state == Player.STATES.stunned
end

function Player:loadAssets(soundVolume)
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
    self.whipSound = require("src.audio.classic_sounds").load("whip", soundVolume)
    self.thudSound = require("src.audio.classic_sounds").load("thud", soundVolume)
end

function Player:startWhip()
    if self.whipping or self:isDead() or self:isStunned()
        or self.state == Player.STATES.ducking
        or self.state == Player.STATES.duckToHang then
        return false
    end
    self.whipping = true
    self.attackKind = nil
    self.whipCracked = false
    self.whipJustCracked = false
    self.whipHits = {}
    self.spriteName = "sAttackLeft"
    self.animationFrame = 0
    return true
end

function Player:startMelee(kind, speed)
    if not self:startWhip() then return false end
    self.attackKind = kind
    self.meleeSpeed = speed
    return true
end

function Player:getMeleePhase()
    return self.meleeVisualPhase
end

function Player:getWhipPhase()
    if not self.whipping or self.attackKind then return nil end
    if self.animationFrame > 0 and self.animationFrame < 2 then return "back" end
    if self.animationFrame > 4 then return "front" end
    return nil
end

function Player:getWhipHitbox()
    local name, x, y, phase = self:getWhipSprite()
    if not name then return nil end
    local left, top, right, bottom = WhipMask.bounds(name, x, y)
    return left, top, right, bottom, phase
end

function Player:getWhipSprite()
    local phase = self:getWhipPhase()
    if not phase then return nil end
    local name
    if phase == "back" then
        name = self.facing < 0 and "sWhipPreL" or "sWhipPreR"
    else
        name = self.facing < 0 and "sWhipLeft" or "sWhipRight"
    end
    local direction = phase == "back" and -self.facing or self.facing
    return name, math.floor(self.x + direction * 16) - 8,
        math.floor(self.y) - 8, phase
end

function Player:whipOverlapsRectangle(left, top, right, bottom)
    local name, x, y = self:getWhipSprite()
    return name and WhipMask.overlaps(name, x, y, left, top, right, bottom) or false
end

function Player:whipCanHit(target)
    return self.whipping and not self.whipHits[target]
end

function Player:markWhipHit(target)
    self.whipHits[target] = true
end

function Player:updateWhip(input)
    self.whipJustCracked = false
    self.meleeJustStruck = false
    if self.attackPressedThisStep and not input.suppressWhip then self:startWhip() end
    if not self.whipping then return end

    if self.animationFrame > 4 and not self.whipCracked then
        self.whipCracked = true
        if self.attackKind then
            self.meleeJustStruck = true
        else
            self.whipJustCracked = true
            if self.whipSound then self.whipSound:clone():play() end
        end
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
    self.state = state
    if state == Player.STATES.stunned or state == Player.STATES.dead then
        -- oPlayer1 destroys an active oWhip (including weapon slashes) when
        -- stunned or dead, before selecting the body pose for this tick.
        self.whipping, self.attackKind = false, nil
        self.whipJustCracked, self.meleeJustStruck = false, false
        self.meleeVisualPhase, self.meleeStrikeAge = nil, nil
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

function Player:rememberInput(input)
    self.previousInput = {}
    for _, name in ipairs({ "left", "right", "up", "down", "jump", "sprint", "attack" }) do
        self.previousInput[name] = not not input[name]
    end
end

function Player:quantizedPixels(distance)
    return SourceMath.pixels(distance, self.tick)
end

function Player:consumeVerticalPixels(distance)
    return self:quantizedPixels(distance)
end

function Player:collisionProbe(world, axis, direction, distance, kind, topInset)
    distance = distance or 1
    local halfWidth = self:getCollisionHalfWidth()
    local topOffset, bottomOffset = self:getVerticalBounds()
    if axis == "x" then
        local sideX = direction < 0 and self.x - halfWidth - distance
            or self.x + halfWidth + distance - 1
        sideX = gameMakerRound(sideX)
        return world:overlaps(kind or "solid", sideX,
            gameMakerRound(self.y + topOffset + (topInset or 0)),
            sideX + 1, gameMakerRound(self.y + bottomOffset - 1) + 1)
    end
    local sideY = direction < 0 and self.y + topOffset - distance
        or self.y + bottomOffset + distance - 1
    sideY = gameMakerRound(sideY)
    return world:overlaps(kind or "solid", gameMakerRound(self.x - halfWidth), sideY,
        gameMakerRound(self.x + halfWidth - 1) + 1, sideY + 1)
end

function Player:moveHorizontal(world, distance)
    local pixels = self:quantizedPixels(distance)
    local direction = sign(pixels)
    local hitWall = false
    for _ = 1, math.abs(pixels) do
        -- moveTo's side probe omits the top five pixels of the collider.
        local hit, hitX, hitY = self:collisionProbe(world, "x", direction, 1, "solid", 5)
        if hit and type(hitX) == "table" and world:tryPush(self, direction, hitX) then
            hit = false
        end
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
        local hit, hitX, hitY = self:collisionProbe(world, "y", direction)
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

function Player:moveWithSlopes(world, ignorePlatforms, blockedTop)
    if not self:isGroundState() or self.vx == 0 then
        self:moveHorizontal(world, self.vx)
        self:moveVertical(world, self.vy, ignorePlatforms)
        return
    end
    local x, y = self.x, self.y
    -- characterStepEvent uses its cached colTop throughout the lift loop.
    local lift = blockedTop and 0 or 5
    self.y = self.y-lift
    local highY = self.y
    local dx = self:quantizedPixels(self.vx)
    local dy = self:quantizedPixels(self.vy+lift)
    self:moveHorizontal(world, self.vx)
    self:moveVertical(world, self.vy+lift, ignorePlatforms)
    local distance = math.sqrt((self.x-x)^2+(self.y-y)^2)
    if distance > math.abs(dx) then
        self.x, self.y = x, highY
        local ratio = math.abs(dx)/distance*0.9
        self:moveHorizontal(world, gameMakerRound(dx*ratio))
        self:moveVertical(world, gameMakerRound(dy*ratio+lift), ignorePlatforms)
    end
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
        -- A ladder body at a solid floor is a crouch, not a climb entry.
        -- Classic's grounded Down-climb exception checks for a ladder top.
        if self:collisionProbe(world, "y", 1)
            and not world:cellAt("ladderTop", self.x, self.y + 9) then
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
    if input.up and not world:climbableAtPoint(self.x, self.y) then
        self.y = tileY * world.tileSize + 14
    end
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
    self.capeOpen = false
    self.jumpRearmed = false
    self.ladderCooldown = 10
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
        if self.climbSoundTimer < 1 then self.climbSoundTimer = 8 end
    elseif input.down then
        if world:climbableAtPoint(self.x, self.y + 8) then
            self.ay = self.ay + 0.6
            if self.climbSoundTimer < 1 then self.climbSoundTimer = 8 end
        else
            self:setState(Player.STATES.falling)
        end
        if self:collisionProbe(world, "y", 1) then
            self.vy = 0
            self.ay = 0
            self:setState(Player.STATES.standing)
        end
    end

    if jumpPressed and not self.whipping then
        self.vx = input.left and -4 or (input.right and 4 or 0)
        self.ay = self.ay - 4
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
    Ball.restrain(self, input)
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
    self.capeOpen = false
    self.jumpRearmed = false
    self.wideCollision = false
    self.collisionTopOffset = -8
    if not self:collisionProbe(world, "x", self.facing, 2) then
        self.hangCooldown = 4
        self.gravity = 1
        self.ay = self.ay - self.gravity
        self:setState(Player.STATES.falling)
    end

    if self.state == Player.STATES.hanging then
        local away = (self.facing == 1 and input.left) or (self.facing == -1 and input.right)
        if jumpPressed and input.down then
            self.hangCooldown = self.equipment.gloves and 10 or 5
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

        if not self:collisionProbe(world, "x", self.facing, 2) then
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
        Ball.restrain(self, input)
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

function Player:updateDuckToHang(world)
    self.transitionTicks = self.transitionTicks - 1
    if self.transitionTicks <= 0 and self.transitionTarget then
        local target = self.transitionTarget
        self.transitionTarget = nil
        local y = gameMakerRound((target.y + 16) / 8) * 8
        local kind, tileX = world:climbableAtPoint(target.x + target.direction * 8, y)
        if kind then
            self.x = tileX * world.tileSize + world.tileSize / 2
            self.y = y
            self.climbKind = kind
            self.climbTileX = tileX
            self.ax, self.ay = 0, 0
            self.state = Player.STATES.climbing
            return
        end
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
    local colLeft = self:collisionProbe(world, "x", -1)
    local colRight = self:collisionProbe(world, "x", 1)
    local colMoveableLeft = self:collisionProbe(world, "x", -1, 1, "moveableSolid")
    local colMoveableRight = self:collisionProbe(world, "x", 1, 1, "moveableSolid")
    local colTop = self:collisionProbe(world, "y", -1)
    local colBottom = self:collisionProbe(world, "y", 1)
    local colPlatformBottom = self.dropThroughTimer == 0
        and world:platformLanding(self, self.y, self.y + 1) ~= nil
    local colPlatform = world:overlapsPlayer("platform", self, self.x, self.y)
        or world:overlapsPlayer("ladderTop", self, self.x, self.y)

    local runKey = input.sprint or (input.attack and not self.whipping)

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
        elseif (self.rightHeldSteps > 2 or colMoveableLeft)
            and (self.facing == 1 or approximatelyZero(self.vx)) then
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
        self.jumpRearmed = true
        if self.equipment.gloves then self.hangCooldown = 5 end
    end

    if colTop and self.state == Player.STATES.jumping then
        self.vy = math.abs(self.vy * 0.3)
    end
    if (colLeft and self.facing == -1) or (colRight and self.facing == 1) then
        self.vx = 0
    end

    if jumpReleased and self:isAirState() then
        self.jumpRearmed = true
    elseif self:isGroundState() then
        self.jumpRearmed = false
        self.capeOpen = false
    end

    if jumpPressed and world:webAtPoint(self.x, self.y) then
        world:damageWebAtPoint(self.x, self.y)
        self.ay = self.ay - 4
        self.vy = self.vy - 3
        self.ax = self.ax + self.vx / 2
        self.state = Player.STATES.jumping
        self.jumpReleased = false
        self.jumpTime = 0
    elseif self.equipment.cape and jumpPressed and self.jumpRearmed and self:isAirState() then
        self.capeOpen = not self.capeOpen
    elseif self.equipment.jetpack and input.jump and self.jumpRearmed
        and self:isAirState() and self.jetpackFuel > 0 then
        self.ay = self.ay - 2
        self.vy = -1
        self.jetpackFuel = self.jetpackFuel - 1
        if self.jetpackSoundTimer < 1 then self.jetpackSoundTimer = 3 end
        self.state = Player.STATES.jumping
        self.jumpReleased = false
        self.jumpTime = 0
        self.gravity = 0
    elseif self:isGroundState() and jumpPressed and self.fallTimer == 0 then
        self.ay = self.ay - 4
        if self.equipment.spring_shoes then self.ay = self.ay * 1.5 end
        if math.abs(self.vx) > 3 then
            self.ax = self.ax + self.vx * 2
        else
            self.ax = self.ax + self.vx / 2
        end
        self.state = Player.STATES.falling
        self.jumpReleased = false
        self.jumpTime = 0
        self.pushTimer = 0
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

    if input.down and self:isGroundState() and not self.whipping then
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

    if self.hangCooldown == 0 and self.y > 16 and self.state == Player.STATES.falling
        and require("src.platform.items.arrow").hangAt(world, self.x, self.y) then
        self.vy, self.ay, self.gravity = 0, 0, 0
        self:setState(Player.STATES.hanging)
        self:updateHanging(world, input, jumpPressed)
        return
    end

    if not colTop and self.hangCooldown == 0 and self.y > 16 and self:isAirState()
        and direction ~= 0 and ((direction < 0 and colLeft) or (direction > 0 and colRight)) then
        local ledge = world:ledgeFor(self, direction, self.equipment.gloves and self.vy > 0)
        if ledge then
            self:beginHang(ledge)
            self:updateHanging(world, input, jumpPressed)
            return
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

    -- Classic tests the player's origin, then damps the accelerated velocity.
    if world:webAtPoint(self.x, self.y) then
        xFriction, yFriction = 0.2, 0.2
        self.fallTimer = 0
    end
    if self.parachuteOpen or self.capeOpen then yFriction = 0.5 end

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
    self.ax = clamp(self.ax, -9, 9)
    self.ay = clamp(self.ay, -6, 6)
    self.vx = (self.vx + self.ax) * xFriction
    self.vy = (self.vy + self.ay) * yFriction
    self.ax = 0
    self.ay = 0
    Ball.restrain(self, input)
    self.vx = clamp(self.vx, -self.xVelocityLimit, self.xVelocityLimit)
    self.vy = clamp(self.vy, -self.yVelocityLimit, self.yVelocityLimit)
    if approximatelyZero(self.vx) then self.vx = 0 end
    if approximatelyZero(self.vy) then self.vy = 0 end

    self:moveWithSlopes(world, input.down, colTop)

end

function Player:selectSprite(world)
    local sprite
    local speed = 0
    if self.whipping then
        sprite = "sAttackLeft"
        speed = (self.attackKind and self.meleeSpeed or Player.ATTACK_SPEED)
            * Player.TICK_RATE
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
        if self.vx == 0 then
            sprite = "sStunL"
            speed = 0.4 * Player.TICK_RATE
        elseif self.deadBounced then
            sprite = self.vy < 0 and "sDieLBounce" or "sDieLFall"
        else
            sprite = self.vx < 0 and "sDieLL" or "sDieLR"
        end
    elseif self.state == Player.STATES.dead then
        if self.vx == 0 then
            sprite = "sDieL"
        elseif self.deadBounced then
            sprite = self.vy < 0 and "sDieLBounce" or "sDieLFall"
        else
            sprite = self.vx < 0 and "sDieLL" or "sDieLR"
        end
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

function Player:updateBody(world)
    -- oPlayer1 applies gravity and contact response before moveTo. Once the
    -- body has touched ground, bounced switches its gravity from 0.6 to 1.
    self.vy = self.vy + (self.deadBounced and 1 or 0.6)
    if self.vy < 0 and self:collisionProbe(world, "y", -1) then
        self.vy = -self.vy * 0.8
    end
    if self:collisionProbe(world, "x", -1)
        or self:collisionProbe(world, "x", 1) then
        self.vx = -self.vx * 0.5
    end
    if self:collisionProbe(world, "y", 1)
        or world:platformLanding(self, self.y, self.y + 1) then
        self.vy = self.vy > 1 and -self.vy * 0.5 or 0
        self.vx = math.abs(self.vx) < 0.1 and 0 or self.vx * 0.3
        self.deadBounced = true
    end
    Ball.restrain(self, self.currentInput or {})
    self.vx = clamp(self.vx, -10, 10)
    self.xVelocityLimit = 10
    self.vy = clamp(self.vy, -self.yVelocityLimit, self.yVelocityLimit)
    self:moveHorizontal(world, self.vx)
    self:moveVertical(world, self.vy, false)
    -- oPlayer1's thrown-body impact takes a heart directly, independently of
    -- contact invulnerability, and consumes the keeper's single wallHurt charge.
    if (self.wallHurt or 0) > 0 and (self:collisionProbe(world, "x", -1)
        or self:collisionProbe(world, "x", 1) or self:collisionProbe(world, "y", 1)) then
        if self.sounds then self.sounds:play("hurt") end
        self.wallHurt = self.wallHurt - 1
        self.health = math.max(0, self.health - 1)
        if self.health == 0 then self:kill("shopkeeper", self.vx, self.vy) end
    end
end

function Player:updateSoundAlarms()
    if self.jetpackSoundTimer > 0 then
        self.jetpackSoundTimer = self.jetpackSoundTimer-1
        if self.jetpackSoundTimer == 0 and self.sounds then self.sounds:play("jetpack") end
    end
    if self.climbSoundTimer > 0 then
        self.climbSoundTimer = self.climbSoundTimer-1
        if self.climbSoundTimer == 0 then
            if self.sounds then self.sounds:play(self.climbSoundToggle and "climb1" or "climb2") end
            self.climbSoundToggle = not self.climbSoundToggle
        end
    end
end

local function stepMovement(self, world, input)
    input = input or {}
    local rawInput = input
    local jumpRestricted = self.cantJumpTimer > 0
    if jumpRestricted then
        self.cantJumpTimer = self.cantJumpTimer - 1
        local restricted = {}
        for key, value in pairs(input) do restricted[key] = value end
        restricted.jump = false
        input = restricted
    end
    world.time = (world.time or 0) + 1
    self.tick = world.time
    self:updateSoundAlarms()
    self.currentInput = input
    local jumpPressed = self:pressed(input, "jump")
    local jumpReleased = self:released(input, "jump")
    if jumpRestricted then jumpPressed, jumpReleased = false, false end
    self.attackPressedThisStep = self:pressed(input, "attack")

    local wasHanging = self.state == Player.STATES.hanging
    local decrementHangCooldown = self.hangCooldown > 0
    if wasHanging and decrementHangCooldown then
        self.hangCooldown = self.hangCooldown - 1
    end
    if self.ladderCooldown > 0 then self.ladderCooldown = self.ladderCooldown - 1 end
    if self.dropThroughTimer > 0 then self.dropThroughTimer = self.dropThroughTimer - 1 end
    if self.invincibleTimer > 0 then self.invincibleTimer = self.invincibleTimer - 1 end

    if self.webTimer > 0 then self.webTimer = self.webTimer - 1 end
    self:refreshStatus()

    if self:isDead() then
        self:setState(Player.STATES.dead)
        self:updateBody(world)
        self:updateAnimation(world)
        self:rememberInput(rawInput)
        return
    end

    -- Count down the previous frame's stationary stun pose before movement.
    if self.stunTimer > 0 and self.spriteName == "sStunL" then
        self.stunTimer = self.stunTimer - 1
        if self.stunTimer == 0 then
            self:setState(world:groundBelow(self) and Player.STATES.standing or Player.STATES.falling)
            self:refreshStatus()
        end
    end

    if self.equipment.jetpack and self:isGroundState() then self.jetpackFuel = 50 end
    if self.parachuteOpen or self.capeOpen then self.fallTimer = 0 end
    if self.vy > 0 and self.state ~= Player.STATES.climbing then
        self.fallTimer = self.fallTimer + 1
        if self.equipment.parachute and not self:isStunned() and self.fallTimer > 14
            and not world:solidAtPoint(self.x, self.y + 32) then
            self.parachuteOpen = true
            self.equipment.parachute = false
            self.fallTimer = 0
        end
    elseif self:isGroundState() then
        if self.fallTimer > 16 and not self.parachuteOpen then self:landHard() end
        self.fallTimer = 0
    else
        self.fallTimer = 0
    end
    if self.vy <= 0 or self.state == Player.STATES.climbing then
        self.parachuteOpen = false
    end

    -- A long drop can turn fatal during the fall-timer check above. It must
    -- enter the same body-physics path on this tick, not normal controls.
    if self:isDead() then
        self:setState(Player.STATES.dead)
        self:updateBody(world)
        self:updateAnimation(world)
        self:rememberInput(rawInput)
        return
    end

    if self.stunTimer > 0 then
        self:updateBody(world)
        self:updateAnimation(world)
        self:rememberInput(rawInput)
        return
    end

    if self.state ~= Player.STATES.duckToHang then
        self.leftHeldSteps = input.left and self.leftHeldSteps + 1 or 0
        self.rightHeldSteps = input.right and self.rightHeldSteps + 1 or 0
        if input.sprint then self.runHeld = 100 end
        if input.attack and not self.whipping then self.runHeld = self.runHeld + 1 end
        if (not input.sprint and (not input.attack or self.whipping))
            or (not input.left and not input.right) then
            self.runHeld = 0
        end
    end

    if self.state == Player.STATES.hanging then
        self:updateHanging(world, input, jumpPressed)
    elseif self.state == Player.STATES.climbing then
        self:updateClimbing(world, input, jumpPressed)
    elseif self.state == Player.STATES.duckToHang then
        self:updateDuckToHang(world)
    else
        self:updateNormal(world, input, jumpPressed, jumpReleased)
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
    self:rememberInput(rawInput)
end

function Player:step(world, input)
    stepMovement(self, world, input)
    Cape.stepWorn(self)
end

function Player:getAnimationFrame()
    local sprite = assert(self.images and self.images[self.spriteName],
        "Player sprite assets are not loaded: " .. tostring(self.spriteName))
    local index = (math.floor(self.animationFrame) % #sprite.frames) + 1
    return sprite, sprite.frames[index]
end

function Player:drawWhip()
    local name, x, y = self:getWhipSprite()
    local whip = name and self.whipImages and self.whipImages[name]
    if not whip then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(whip, x + 8, y + 8, 0, 1, 1, 8, 8)
end

function Player:drawBody()
    local sprite, image = self:getAnimationFrame()
    local scaleX = self.facing == -1 and 1 or -1
    Jetpack.drawWorn(self, false)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(self.x), math.floor(self.y), 0,
        scaleX, 1, sprite.data.originX, sprite.data.originY)
    Jetpack.drawWorn(self, true)
end

function Player:draw()
    if self:getWhipPhase() == "back" then self:drawWhip() end
    self:drawBody()
    if self:getWhipPhase() == "front" then self:drawWhip() end
end

function Player.drawDepth(state)
    if state == "exiting" or state == "lava" then return 999 end
    return 50
end

return Player
