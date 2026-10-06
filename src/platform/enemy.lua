-- Shared 30 Hz body and contact rules. Kind-specific AI, masks, damage
-- reactions, and animations live in src/platform/enemies/<kind>.lua.
local Types = require("src.platform.enemies.types")

local ActorBody = require("src.platform.actor_body")
local Enemy = {}
Enemy.__index = Enemy

Enemy.TICK_RATE = 30
Enemy.STATES = {
    idle = "IDLE", walk = "WALK", hang = "HANG", attack = "ATTACK",
    recover = "RECOVER", bounce = "BOUNCE", stunned = "STUNNED",
    bones = "BONES", rise = "RISE", dead = "DEAD",
}

local loadedAssets

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
    for kind, spec in pairs(Types) do
        if spec.animations then
            loadedAssets[kind] = {}
            for name, animation in pairs(spec.animations) do
                local frames = {}
                for _, path in ipairs(animation.paths) do
                    local image = love.graphics.newImage(path)
                    image:setFilter("nearest", "nearest")
                    frames[#frames + 1] = image
                end
                loadedAssets[kind][name] = { fps = animation.fps, frames = frames }
            end
        end
    end
    return loadedAssets
end

function Enemy.new(kind, x, y, options)
    options = options or {}
    local spec = Types[kind]
    assert(spec and spec.animations, "Unknown enemy kind: " .. tostring(kind))
    local enemy = setmetatable({
        kind = kind,
        spec = spec,
        x = x,
        y = y,
        spawnX = x,
        spawnY = y,
        vx = 0,
        vy = 0,
        xRemainder = 0,
        yRemainder = 0,
        facing = options.facing or spec.initialFacing or -1,
        state = spec.initialState or Enemy.STATES.idle,
        timer = spec.initialTimer or 0,
        gravity = spec.gravity or 0.6,
        terminalVelocity = 10,
        dropThroughTimer = 0,
        hp = spec.hp or 1,
        alive = true,
        animation = 0,
        animationName = nil,
        random = newRandom(options.seed or (x * 31 + y * 17 + #kind)),
        justAlerted = false,
        sightTimer = 0,
    }, Enemy)
    if spec.initialize then spec.initialize(enemy, options) end
    return enemy
end

function Enemy:getCollisionHalfWidth()
    local width = self.spec.collisionHalfWidth
    if type(width) == "function" then return width(self) end
    return width or 6
end

function Enemy:getVerticalBounds()
    local bounds = self.spec.verticalBounds
    if type(bounds) == "function" then return bounds(self) end
    if bounds then return bounds[1], bounds[2] end
    return -16, 0
end

Enemy.getBounds = ActorBody.bounds

function Enemy:setState(state, timer)
    self.state = state
    if timer ~= nil then self.timer = timer end
end

function Enemy:moveHorizontal(world, amount)
    return ActorBody.moveHorizontal(self, world, amount, true)
end

function Enemy:moveVertical(world, amount, usePlatforms)
    return ActorBody.moveVertical(self, world, amount, usePlatforms, true)
end

function Enemy:hasCeiling(world)
    return world:solidAtPoint(self.x, self.y - 17)
end

function Enemy:updateGroundPhysics(world)
    local hitWall = self:moveHorizontal(world, self.vx)
    local verticalHit = self:moveVertical(world, self.vy, false)
    if hitWall then self.vx = 0 end
    if verticalHit == "floor" then self.vy = 0 end
    if verticalHit == "ceiling" then self.vy = math.max(1, math.abs(self.vy)) end
    if verticalHit ~= "floor" then self.vy = math.min(self.terminalVelocity, self.vy+self.gravity) end
    return hitWall, verticalHit
end

function Enemy:updateAnimation()
    local name = self.spec.animation(self)
    if name ~= self.animationName then
        self.animationName = name
        self.animation = 0
    else
        local animation = self.spec.animations[name]
        local fps = self.spec.animationFps and self.spec.animationFps(self, animation, name)
            or animation.fps
        self.animation = self.animation + fps / Enemy.TICK_RATE
    end
    if self.spec.afterAnimation then self.spec.afterAnimation(self) end
end

function Enemy:step(world, player)
    if not self.alive then return end
    if not require("src.platform.activity").enemy(world, self) then return end
    self.justAlerted = false
    self.spec.step(self, world, player)
    if self.hp <= 0 or world:solidAtPoint(self.x, self.y-8) then
        self.hp, self.alive, self.state = 0, false, Enemy.STATES.dead
    end
    self:updateAnimation()
end

Enemy.overlapsRectangle = ActorBody.overlapsRectangle
Enemy.overlapsPlayer = ActorBody.overlapsPlayer

function Enemy:damage(amount, sourceX, hit)
    if not self.alive or self.spec.canEnemyDamage
        and not self.spec.canEnemyDamage(self) and (not hit or (hit.kind ~= "bullet" and hit.kind ~= "explosion")) then return false end
    self.hp = self.hp - (amount or 1)
    if self.hp <= 0 then
        self.alive = false
        self.vx, self.vy = 0, 0
        self:setState(Enemy.STATES.dead)
    elseif self.spec.onSurviveDamage then
        self.spec.onSurviveDamage(self, sourceX, hit)
    end
    if self.alive and hit then
        self.vx, self.vy = hit.vx or self.vx, hit.vy or self.vy
    end
    return true
end

function Enemy:resolvePlayerContact(player, previousPlayerY)
    if not self.alive or not self:overlapsPlayer(player) then return nil end
    if self.spec.canContact and not self.spec.canContact(self) then return nil end

    local _, playerBottom = player:getVerticalBounds()
    local _, enemyTop = self:getBounds()
    local previousBottom = previousPlayerY + playerBottom
    if player.vy > 0 and player.y < self.y and previousBottom <= enemyTop + 3 then
        return ActorBody.stomp(self, player, false, true)
    end

    -- oEnemy contact flashes and pushes horizontally, without a stun pose.
    if player:hurt(self.x, 1, self.kind, nil, "enemy_contact") then
        if self.spec.onPlayerHit then self.spec.onPlayerHit(self, player) end
        return "hurt"
    end
    return "invincible"
end

function Enemy:draw()
    local assets = loadedAssets or Enemy.loadAssets()
    local animation = assets[self.kind][self.animationName or self.spec.fallback]
    local index = (math.floor(self.animation) % #animation.frames) + 1
    local image = animation.frames[index]
    local scaleX = 1
    local drawX = math.floor(self.x - 8)
    if self.spec.mirrorFacing and self.facing > 0 then
        scaleX = -1
        drawX = math.floor(self.x + 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, drawX, math.floor(self.y - 16), 0, scaleX, 1)
end

return Enemy
