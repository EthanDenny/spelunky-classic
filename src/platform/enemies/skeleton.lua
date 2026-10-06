local Physics = require("src.platform.physical_body")
local Skeleton = {
    initialTimer = 20,
    initialFacing = 1,
    fallback = "idle",
    mirrorFacing = true,
    creatureConfig = { hp = 1, speed = 1.0 },
    creatureInitialTimer = 20,
    creatureAnimationPerTick = 1,
    animations = {
        bones = { fps = 0, paths = { "assets/original/entities/fake_bones.png" } },
        rise = { fps = 15, paths = {
            "assets/original/animations/sSkeletonCreateL/000.png",
            "assets/original/animations/sSkeletonCreateL/001.png",
            "assets/original/animations/sSkeletonCreateL/002.png",
            "assets/original/animations/sSkeletonCreateL/003.png",
            "assets/original/animations/sSkeletonCreateL/004.png",
            "assets/original/animations/sSkeletonCreateL/005.png",
        } },
        idle = { fps = 0, paths = {
            "original-game-reference/source/extracted/spelunky/Sprites/Enemies/Skeleton/sSkeletonLeft.images/image 0.png",
        } },
        walk = { fps = 15, paths = {
            "assets/original/animations/sSkeletonWalkLeft/000.png",
            "assets/original/animations/sSkeletonWalkLeft/001.png",
            "assets/original/animations/sSkeletonWalkLeft/002.png",
            "assets/original/animations/sSkeletonWalkLeft/003.png",
            "assets/original/animations/sSkeletonWalkLeft/004.png",
        } },
    },
}

function Skeleton.initialize(self, options)
    if options.fakeBones then
        self:setState(self.STATES.bones, 0)
    end
end

function Skeleton.step(self, world, player)
    local states = self.STATES
    if self.state == states.bones then
        if player and not player:isDead()
            and math.abs(player.y - (self.y - 8)) < 8
            and math.abs(player.x - self.x) < 64 then
            self:setState(states.rise)
            self.justAlerted = true
        end
        return
    elseif self.state == states.rise then
        if player then self.facing = player.x < self.x and -1 or 1 end
        return
    end
    Physics.move(world, self, "x", self.vx)
    Physics.move(world, self, "y", self.vy)
    self.vy = math.min(10, self.vy+0.6)
    if Physics.probe(world, self, "y", 1) then self.vy = 0 end
    if self.state == states.idle then
        self.vx = 0
        if self.timer > 0 then self.timer = self.timer - 1 end
        if self.timer == 0 then self:setState(states.walk) end
    elseif self.state == states.walk then
        local wedged = Physics.probe(world, self, "x", -1, 4)
            and Physics.probe(world, self, "x", 1, 4)
        if not wedged and (Physics.probe(world, self, "x", -1)
            or Physics.probe(world, self, "x", 1)) then self.facing = -self.facing end
        self.vx = self.facing
    end
    if world:collidesSolid(self, self.x, self.y) then self.y = self.y-2 end
end

function Skeleton.animation(self)
    if self.state == self.STATES.bones or self.state == self.STATES.rise then
        return self.state == self.STATES.bones and "bones" or "rise"
    end
    return self.state == self.STATES.walk and "walk" or "idle"
end

function Skeleton.afterAnimation(self)
    if self.state == self.STATES.rise
        and self.animation >= #Skeleton.animations.rise.paths then
        self:setState(self.STATES.idle, 20)
        self.animationName = "idle"
        self.animation = 0
    end
end

function Skeleton.canContact(self)
    return self.state ~= self.STATES.bones and self.state ~= self.STATES.rise
end

Skeleton.creatureStep = Skeleton.step
function Skeleton.facePlayerOnSpawn(body, player, facing)
    body.facing = facing or (player.x < body.x and -1 or 1)
end

function Skeleton.collisionSprite(self)
    return self.vx == 0 and "sSkeletonLeft" or "sSkeletonWalkLeft",
        self.vx == 0 and 0 or math.floor(self.animation*0.5), self.x-8, self.y-self.height, false
end

function Skeleton.drawCreature(self)
    local sprites = Skeleton.creatureSprites
    if not sprites then
        sprites = { walk = {} }
        local idle = love.graphics.newImage(
            "original-game-reference/source/extracted/spelunky/Sprites/Enemies/Skeleton/sSkeletonLeft.images/image 0.png")
        idle:setFilter("nearest", "nearest")
        sprites.idle = idle
        for index = 0, 4 do
            local image = love.graphics.newImage(string.format(
                "assets/original/animations/sSkeletonWalkLeft/%03d.png", index))
            image:setFilter("nearest", "nearest")
            sprites.walk[#sprites.walk + 1] = image
        end
        Skeleton.creatureSprites = sprites
    end
    local name, frame = Skeleton.collisionSprite(self)
    local image = name == "sSkeletonLeft" and sprites.idle or sprites.walk[frame % #sprites.walk + 1]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(self.x), math.floor(self.y - self.height),
        0, self.facing < 0 and 1 or -1, 1, 8, 0)
end

Skeleton.depth = 60
Skeleton.deathBlood = 0
Skeleton.bloodless = true
function Skeleton.onDeath(body, game)
    if not body.deathDebrisEmitted then
        game.effects:skeletonBreak(body.x, body.y-8, game.items)
        body.deathDebrisEmitted = true
    end
end

return Skeleton
