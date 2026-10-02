local Caveman = {
    initialTimer = 0,
    initialFacing = 1,
    hp = 3,
    fallback = "idle",
    mirrorFacing = true,
    creatureConfig = { hp = 3, speed = 1.1 },
    canBeHeld = true,
    stunDuration = function(hit) return hit and hit.kind == "bullet" and 20 or 200 end,
    creatureAnimationPerTick = 0.5,
    sacrifice = { favor = 2, deadFavor = 1, rewardOffset = 24 },
    animations = {
        idle = { fps = 0, paths = { "assets/original/entities/caveman.png" } },
        run = { fps = 15, paths = {
            "assets/original/animations/sCavemanRunLeft/000.png",
            "assets/original/animations/sCavemanRunLeft/001.png",
            "assets/original/animations/sCavemanRunLeft/002.png",
            "assets/original/animations/sCavemanRunLeft/003.png",
        } },
        hurt = { fps = 0, paths = {
            "original-game-reference/source/extracted/spelunky/Sprites/Enemies/Caveman/sCavemanDieLL.images/image 0.png",
        } },
        stun = { fps = 15, paths = {
            "assets/original/animations/sCavemanStunL/000.png",
            "assets/original/animations/sCavemanStunL/001.png",
            "assets/original/animations/sCavemanStunL/002.png",
            "assets/original/animations/sCavemanStunL/003.png",
            "assets/original/animations/sCavemanStunL/004.png",
        } },
    },
}

local function canSee(self, world, player)
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

function Caveman.step(self, world, player)
    local states = self.STATES
    if self.state == states.stunned then
        local direction = self.vx < 0 and -1 or self.vx > 0 and 1 or 0
        self.vx = direction * math.max(0, math.abs(self.vx) - 0.1)
        if math.abs(self.vx) < 0.5 then self.vx = 0 end
        local _, landing = self:updateGroundPhysics(world)
        if landing == "floor" or world:groundBelow(self) then
            self.timer = self.timer - 1
            if self.timer <= 0 then self:setState(states.idle, 0) end
        end
        return
    end

    if self.state == states.idle then
        self.vx = 0
        if world:groundBelow(self) then self.timer = self.timer - 1 end
        if self.timer <= 0 then
            self.facing = self.random(0, 1) == 0 and -1 or 1
            self:setState(states.walk)
        end
    elseif self.state == states.walk then
        if world:collidesSolid(self, self.x + self.facing, self.y) then
            self.facing = -self.facing
        end
        local supportX = self.x + (self.facing < 0 and -9 or 8)
        if not world:solidAtPoint(supportX, self.y) then
            self.vx = 0
            self:setState(states.idle, self.random(20, 50))
        else
            self.vx = self.facing * 1.5
            if self.random(1, 100) == 1 then
                self.vx = 0
                self:setState(states.idle, self.random(20, 50))
            end
        end
    elseif self.state == states.attack then
        if world:collidesSolid(self, self.x + self.facing, self.y) then
            self.facing = -self.facing
        end
        self.vx = self.facing * 3
    end

    if self.state == states.idle or self.state == states.walk then
        self.sightTimer = self.sightTimer - 1
        if self.sightTimer <= 0 then
            self.sightTimer = 5
            if canSee(self, world, player) then
                self:setState(states.attack)
                self.vx = self.facing * 3
                self.justAlerted = true
            end
        end
    end
    local hitWall = self:updateGroundPhysics(world)
    if hitWall and self.state == states.attack then self.facing = -self.facing end
end

function Caveman.animation(self)
    if self.state == self.STATES.stunned then
        return self.vx == 0 and "stun" or "hurt"
    end
    return self.vx == 0 and "idle" or "run"
end

function Caveman.animationFps(self, animation, name)
    return self.state == self.STATES.attack and name == "run" and 30 or animation.fps
end

function Caveman.canDamage(body, hit)
    return not hit or hit.kind ~= "whip" or body.stunned <= 0
end

function Caveman.canEnemyDamage(self)
    return self.state ~= self.STATES.stunned
end

function Caveman.onSurviveDamage(self, sourceX, hit)
    self.vx = sourceX and (sourceX < self.x and 2 or -2) or 0
    self.vy = -3
    self:setState(self.STATES.stunned, hit and hit.kind == "bullet" and 20 or 200)
end

function Caveman.canContact(self)
    return self.state ~= self.STATES.stunned
end

function Caveman.onPlayerHit(self, player)
    if player.y < self.y then player.vy = -6 end
end

Caveman.creatureStep = Caveman.step

local Physics = require("src.platform.physical_body")
local Assets = require("src.platform.object_assets")
local sprites = {}
function Caveman.initializeCreature(body)
    body.heavy = true
    body.definition = { hold = { standing = 4, ducking = 6 } }
    body.physicsOriginY = -8
    body.timer, body.facing = 0, 1
end

function Caveman.stunnedStep(body, world)
    Physics.stepItem(world, body)
    if Physics.stopInWeb(world, body) or Physics.probe(world, body, "y", 1) then
        body.stunned = body.stunned - 1
    end
end

function Caveman.onThrown(body)
    body.state = body.corpse and "dead" or "stunned"
end

function Caveman.drawCreature(body, renderer)
    if not body.corpse and not body.held and body.stunned <= 0 then
        local name = body.vx == 0 and "sCavemanLeft" or "sCavemanRunLeft"
        local frame = body.vx == 0 and 0 or math.floor(body.animation*(body.state == "attack" and 2 or 1)) % 4
        local key = name .. frame
        sprites[key] = sprites[key] or Assets.image("Enemies/Caveman", name, frame)
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(sprites[key], math.floor(body.x), math.floor(body.y-16),
            0, body.facing < 0 and 1 or -1, 1, 8, 0)
        return
    end
    local name = body.corpse and (body.held and "sCavemanDHeldL" or "sCavemanDieLL")
        or body.held and "sCavemanHeldL" or "sCavemanStunL"
    local frame = body.corpse and 0 or math.floor(body.animation) % 5
    local key = name .. frame
    sprites[key] = sprites[key] or Assets.image("Enemies/Caveman", name, frame)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprites[key], math.floor(body.x), math.floor(body.y - 16),
        0, body.facing < 0 and 1 or -1, 1, 8, 0)
end

Caveman.depth = 60

Caveman.deathBlood = 0

return Caveman
