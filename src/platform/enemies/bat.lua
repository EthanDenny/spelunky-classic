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

function Bat.step(self, world, player)
    local states = self.STATES
    local playerAlive = player and not player:isDead()
    local dx = playerAlive and player.x - self.x or 0
    local dy = playerAlive and player.y - (self.y - 8) or 0
    local dist = playerAlive and math.sqrt(dx * dx + dy * dy) or math.huge
    if self.state == states.hang then
        self.vx, self.vy = 0, 0
        if not self:hasCeiling(world)
            or (playerAlive and dist < 90 and player.y > self.y) then
            self.justAlerted = true
            self:setState(states.attack)
        end
        return
    end

    if playerAlive and dist < 160 then
        local length = math.max(0.001, dist)
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
        self:setState(states.hang)
        self.vx, self.vy = 0, 0
    elseif verticalHit == "ceiling" and playerAlive and dist < 160 then
        self.vy = 1
    end
end

function Bat.animation(self)
    if self.state == self.STATES.hang then return "hang" end
    return self.facing < 0 and "left" or "right"
end

Bat.depth = 40

return Bat
