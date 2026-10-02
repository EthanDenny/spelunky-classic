local PhysicalBody = require("src.platform.physical_body")

local Damsel = {
    creatureConfig = { hp = 4, speed = 1.2, npc = true },
    creatureHalfWidth = 4,
    creatureVerticalBounds = { -12, 0 },
    canContact = false,
    canBeHeld = true,
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

Damsel.depth = 100

return Damsel
