local Spider = {
    initialState = "HANG",
    initialTimer = 0,
    gravity = 0.2,
    fallback = "hang",
    animations = {
        hang = { fps = 0, paths = { "assets/original/entities/spider.png" } },
        flip = { fps = 12, paths = {
            "assets/original/animations/sSpiderFlip/000.png",
            "assets/original/animations/sSpiderFlip/001.png",
            "assets/original/animations/sSpiderFlip/002.png",
            "assets/original/animations/sSpiderFlip/003.png",
            "assets/original/animations/sSpiderFlip/004.png",
            "assets/original/animations/sSpiderFlip/005.png",
            "assets/original/animations/sSpiderFlip/006.png",
            "assets/original/animations/sSpiderFlip/007.png",
            "assets/original/animations/sSpiderFlip/008.png",
        } },
        bounce = { fps = 12, paths = {
            "assets/original/animations/sSpider/000.png",
            "assets/original/animations/sSpider/001.png",
            "assets/original/animations/sSpider/002.png",
            "assets/original/animations/sSpider/003.png",
        } },
    },
}

function Spider.initialize(self, options)
    if options.hanging == false then
        self:setState(self.STATES.recover, 8)
    end
end

function Spider.collisionHalfWidth(self)
    return self.state == self.STATES.hang and 4 or 7
end

function Spider.verticalBounds(self)
    if self.state == self.STATES.hang then return -16, -4 end
    return -11, 0
end

local function hop(self, player)
    self:setState(self.STATES.bounce)
    self.vy = -self.random(2, 5)
    self.facing = player and player.x < self.x and -1 or 1
    self.vx = self.facing * 2.5
end

function Spider.step(self, world, player)
    local states = self.STATES
    local playerAlive = player and not player:isDead()
    local dx = playerAlive and player.x - self.x or 0
    local dy = playerAlive and player.y - (self.y - 6) or 0
    local dist = playerAlive and math.sqrt(dx * dx + dy * dy) or math.huge
    if self.state == states.hang then
        self.vx, self.vy = 0, 0
        local directlyBelow = playerAlive and player.y > self.y and math.abs(dx) < 8
        if not self:hasCeiling(world) or (directlyBelow and dist < 90) then
            self.justAlerted = true
            self.flipOnDrop = true
            self:setState(states.recover, self.random(5, 20))
        end
        return
    end

    self.timer = math.max(0, self.timer - 1)
    local _, verticalHit = self:updateGroundPhysics(world)
    local grounded = verticalHit == "floor" or world:groundBelow(self) ~= nil
    if self.state == states.recover then
        if grounded then self.vx = 0 end
        if grounded and self.timer <= 0 then hop(self, player) end
    elseif self.state == states.bounce and grounded then
        if playerAlive and dist < 90 and self.random(1, 4) ~= 1 then
            hop(self, player)
        else
            self.vx, self.vy = 0, 0
            self:setState(states.recover, self.random(5, 20))
        end
    end
end

function Spider.animation(self)
    if self.state == self.STATES.hang then return "hang" end
    return self.flipOnDrop and "flip" or "bounce"
end

function Spider.afterAnimation(self)
    if self.flipOnDrop and self.animation >= #Spider.animations.flip.paths then
        self.flipOnDrop = false
        self.animationName = "bounce"
        self.animation = 0
    end
end

Spider.depth = 40

Spider.deathBlood = 3

return Spider
