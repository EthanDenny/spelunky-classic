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
        self:setState(self.STATES.idle, 0)
        self.flipOnDrop = true
    end
end

function Spider.collisionHalfWidth(self)
    return self.state == self.STATES.hang and 4 or 7
end

function Spider.verticalBounds(self)
    if self.state == self.STATES.hang then return -16, -4 end
    return -11, 0
end

local Physics = require("src.platform.physical_body")
local Collision = require("src.platform.entity_collision")

local function hop(self, player, alarm)
    self.vy = -self.random(2, 5)
    local origin = alarm and self.x-8 or self.x
    self.facing = player and player.x < origin and -1 or 1
    self.vx = self.facing*2.5
end

function Spider.alarm(self, world, player)
    local states = self.STATES
    if self.timer > 0 then
        self.timer = self.timer-1
        if self.timer == 0 then
            self:setState(states.bounce)
            if Physics.probe(world, self, "y", 1) then hop(self, player, true) end
        end
    end
end

function Spider.step(self, world, player)
    local states = self.STATES
    if self.state == states.hang then
        if world:solidAtPoint(self.x, self.y-12) then self.hp = 0; return end
        local below = player and player.y > self.y-16 and math.abs(player.x-self.x) < 8
        if not world:solidAtPoint(self.x-8, self.y-32)
            or below and Collision.distance(self, player, player) < 90 then
            self.justAlerted, self.flipOnDrop = true, true
            self:setState(states.idle, 0)
        end
        return
    end
    Physics.move(world, self, "x", self.vx)
    Physics.move(world, self, "y", self.vy)
    self.vy = math.min(10, self.vy+0.2)
    if Physics.probe(world, self, "x", 1) then self.vx = 1 end
    if Physics.probe(world, self, "x", -1) then self.vx = -1 end
    local ground = Physics.probe(world, self, "y", 1)
    if self.state == states.idle then
        self:setState(states.recover, self.random(5, 20))
    elseif self.state == states.recover then
        if ground then self.vx = 0 end
    elseif self.state == states.bounce and player and Collision.distance(self, player, player) < 90 then
        if ground then
            hop(self, player)
            if self.random(1, 4) == 1 then
                self:setState(states.idle)
                self.vx, self.vy = 0, 0
            end
        end
    else self:setState(states.idle) end
    if Physics.probe(world, self, "y", -1) then self.vy = 1 end
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
