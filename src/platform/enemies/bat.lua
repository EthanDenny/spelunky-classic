local Bat = {
    initialState = "HANG",
    initialTimer = 0,
    collisionHalfWidth = 6,
    verticalBounds = { -14, -2 },
    fallback = "hang",
    animations = {
        hang = { fps = 0, paths = { "assets/original/entities/bat.png" } },
        left = { fps = 15, paths = {
            "assets/original/animations/sBatLeft/000.png",
            "assets/original/animations/sBatLeft/001.png",
            "assets/original/animations/sBatLeft/002.png",
        } },
        right = { fps = 15, paths = {
            "assets/original/animations/sBatRight/000.png",
            "assets/original/animations/sBatRight/001.png",
            "assets/original/animations/sBatRight/002.png",
        } },
    },
}

local Physics = require("src.platform.physical_body")

function Bat.step(self, world, player)
    Physics.move(world, self, "x", self.vx)
    Physics.move(world, self, "y", self.vy)
    local target = player and not player:isDead() and not player.swimming
    local dx = target and player.x-self.x or 0
    local dy = target and player.y-(self.y-8) or 0
    local dist = target and math.sqrt(dx*dx+dy*dy) or math.huge
    if self.state == self.STATES.hang then
        if target and ((dist < 90 and player.y > self.y) or not self:hasCeiling(world)) then
            self.justAlerted = true
            self:setState(self.STATES.attack)
        end
        return
    end
    if target and dist < 160 then
        local length = math.max(0.001, dist)
        local vx, vy = dx/length, dy/length
        if (dx > 0 and Physics.probe(world, self, "x", 1))
            or (dx < 0 and Physics.probe(world, self, "x", -1)) then
            vx, vy = 0, dy < 0 and -1 or 1
        end
        if ((dy < 0 and Physics.probe(world, self, "y", -1))
            or (dy > 0 and Physics.probe(world, self, "y", 1)))
            and math.abs(player.x-(self.x-8)) > 8 then
            vx, vy = dx < 0 and -1 or 1, 0
        end
        if world:cellAt("water", self.x, self.y) and vy > 0 then vx, vy = 0, -1 end
        if not world:cellAt("water", self.x-8, self.y-4) or player.y < self.y-16 then
            self.vx, self.vy = vx, vy
        end
        self.facing = dx < 0 and -1 or 1
    elseif self:hasCeiling(world) then self:setState(self.STATES.hang)
    else self.vx, self.vy = 0, -1 end
end

function Bat.animation(self)
    if self.state == self.STATES.hang then return "hang" end
    return self.facing < 0 and "left" or "right"
end

Bat.depth = 40

Bat.deathBlood = 3

return Bat
