-- oFakeBones waits for a nearby player, plays sSkeletonCreateL, then becomes
-- an oSkeleton. Ordinary oBones never activate.
local FakeBones = {}
FakeBones.__index = FakeBones
FakeBones.depth = 900

local frames

local function loadFrames()
    if frames then return frames end
    frames = {}
    for index = 0, 5 do
        local image = love.graphics.newImage(string.format(
            "assets/original/animations/sSkeletonCreateL/%03d.png", index))
        image:setFilter("nearest", "nearest")
        frames[#frames + 1] = image
    end
    return frames
end

function FakeBones.new(entity)
    return setmetatable({
        entity = entity,
        kind = "fake_bones",
        x = entity.x * 16,
        y = entity.y * 16,
        vy = 0,
        phase = "idle",
        frame = 1,
    }, FakeBones)
end

function FakeBones:update(world, player)
    if self.phase == "done" then return false end
    if not world:solidAtPoint(self.x + 8, self.y + 16) then
        self.y = self.y + self.vy
        self.vy = self.vy + 0.2
    end
    if world:solidAtPoint(self.x + 8, self.y + 15) then self.y = self.y - 1 end
    self.entity.y = self.y / 16
    if self.phase == "idle" then
        if math.abs(player.y - (self.y + 8)) < 8
            and math.abs(player.x - (self.x + 8)) < 64 then
            self.phase = "rising"
            self.frame = 1
        end
    else
        self.frame = self.frame + 1
        if self.frame > 6 then
            self.phase = "done"
            return true
        end
    end
    return false
end

function FakeBones:draw(renderer)
    if self.phase == "done" then return end
    if self.phase == "idle" then
        renderer:drawEntity(self.entity)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(loadFrames()[self.frame], math.floor(self.x), math.floor(self.y))
    end
end

return FakeBones
