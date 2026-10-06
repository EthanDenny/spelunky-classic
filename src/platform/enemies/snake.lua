-- Snake-only movement and presentation; shared collision lives in enemy.lua.
local Physics = require("src.platform.physical_body")
local Snake = {
    initialTimer = 0,
    initialFacing = 1,
    fallback = "walk",
    mirrorFacing = true,
    animations = {
        walk = { fps = 12, paths = {
            "assets/original/animations/sSnakeWalkL/000.png",
            "assets/original/animations/sSnakeWalkL/001.png",
            "assets/original/animations/sSnakeWalkL/002.png",
            "assets/original/animations/sSnakeWalkL/003.png",
        } },
    },
}

function Snake.initialize(self) self.vx = 2.5 end

local function hasSupport(self, world, direction)
    -- oSnake probes one pixel beyond its 16-pixel sprite on either side.
    local x = self.x + (direction < 0 and -9 or 8)
    return world:solidAtPoint(x, self.y)
end

function Snake.step(self, world)
    local states = self.STATES
    Physics.move(world, self, "x", self.vx)
    Physics.move(world, self, "y", self.vy)
    self.vy = math.min(10, self.vy+0.6)
    if Physics.probe(world, self, "y", 1) then self.vy = 0 end
    if self.state == states.idle then
        if self.timer > 0 then self.timer = self.timer - 1
        else
            self.facing = self.random(0, 1) == 0 and -1 or 1
            self:setState(states.walk)
        end
    elseif self.state == states.walk then
        if Physics.probe(world, self, "x", -1) or Physics.probe(world, self, "x", 1) then
            self.facing = -self.facing
        end
        local leftWall = world:solidAtPoint(self.x - 9, self.y - 16)
        local rightWall = world:solidAtPoint(self.x + 8, self.y - 16)
        local leftSupport = hasSupport(self, world, -1)
        local rightSupport = hasSupport(self, world, 1)
        if (leftWall or not leftSupport) and (rightWall or not rightSupport) then
            self.facing = leftWall and 1 or -1
            self.vx = 0
        else
            local blockedAhead = self.facing < 0 and (leftWall or not leftSupport)
                or self.facing > 0 and (rightWall or not rightSupport)
            if blockedAhead then self.facing = -self.facing end
            self.vx = self.facing
        end
        if self.random(1, 100) == 1 then
            self.vx = 0
            self:setState(states.idle, self.random(20, 50))
        end
    end
    if world:collidesSolid(self, self.x, self.y) then self.y = self.y-2 end
end

function Snake.animation()
    return "walk"
end

function Snake.animationFps(self, animation)
    return self.vx == 0 and 6 or animation.fps
end

Snake.depth = 60

Snake.deathBlood = 3

return Snake
