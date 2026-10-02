local PhysicalBody = require("src.platform.physical_body")

local Damsel = {
    creatureConfig = { hp = 4, speed = 1.2, npc = true },
    creatureHalfWidth = 4,
    creatureVerticalBounds = { -12, 0 },
    canContact = false,
    canBeHeld = true,
    holdWhenHealthy = true,
    stunDuration = 120,
    creatureAnimationPerTick = 0.5,
    -- oDamsel tests status==98 for its live bonus, but THROWN is 2. The
    -- executable Classic code therefore awards eight for both states.
    sacrifice = { favor = 8, deadFavor = 8, rewardOffset = 16 },
}

function Damsel.initializeCreature(self)
    self.heavy = true
    self.gravity = 0.6
    self.physicsOriginY = -8
    self.definition = { hold = { standing = 8, ducking = 10 } }
end

function Damsel.creatureStep(self, world)
    if self.forSale then
        if self.kissTimer and self.kissTimer > 0 then self.kissTimer = self.kissTimer - 1 end
        PhysicalBody.stepItem(world, self)
        PhysicalBody.stopInWeb(world, self)
        return
    end
    self.timer = self.timer - 1
    if self.timer <= 0 then
        self.facing = -self.facing
        self.timer = 90
    end
    self.vx = self.facing * 0.35
    self:groundPhysics(world)
end

function Damsel.stunnedStep(self, world)
    PhysicalBody.stepItem(world, self)
    local web = PhysicalBody.stopInWeb(world, self)
    if web or PhysicalBody.probe(world, self, "y", 1, 2) then
        self.stunned = self.stunned - 1
    end
end

function Damsel.onThrown(self)
    self.state = "stunned"
    self.stunned = 120
end

local Assets = require("src.platform.object_assets")
local sprites = {}
function Damsel.drawCreature(body, renderer)
    if not body.corpse and body.stunned <= 0 then
        renderer:drawEntity({ kind = "damsel", x = body.x / 16,
            y = (body.y - 8) / 16, properties = body.entity.properties })
        return
    end
    local name = body.corpse and "sDamselDieL" or "sDamselStunL"
    local frame = body.corpse and 0 or math.floor(body.animation) % 5
    local key = name .. frame
    sprites[key] = sprites[key] or Assets.image("Character/Damsel", name, frame)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprites[key], math.floor(body.x), math.floor(body.y - 8),
        0, body.facing < 0 and 1 or -1, 1, 8, 8)
end

Damsel.depth = 100

return Damsel
