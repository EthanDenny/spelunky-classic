local Pixels = require("src.platform.source_math").pixels
local Body = {}

function Body.bounds(self, x, y)
    local half = self:getCollisionHalfWidth()
    local top, bottom = self:getVerticalBounds()
    return (x or self.x)-half, (y or self.y)+top, (x or self.x)+half, (y or self.y)+bottom
end

function Body.overlapsRectangle(self, left, top, right, bottom)
    local a, b, c, d = self:getBounds()
    return left < c and right > a and top < d and bottom > b
end

function Body.overlapsPlayer(self, player)
    local half = player:getCollisionHalfWidth()
    local top, bottom = player:getVerticalBounds()
    return self:overlapsRectangle(player.x-half, player.y+top, player.x+half, player.y+bottom)
end

function Body.moveHorizontal(self, world, amount, clearRemainder)
    local pixels = Pixels(amount, world.time)
    local direction = pixels < 0 and -1 or pixels > 0 and 1 or 0
    for _ = 1, math.abs(pixels) do
        if world:collidesSolid(self, self.x+direction, self.y) then
            if clearRemainder then self.xRemainder = 0 end
            return true
        end
        self.x = self.x+direction
    end
    return false
end

function Body.moveVertical(self, world, amount, usePlatforms, clearRemainder)
    local pixels = Pixels(amount, world.time)
    local direction = pixels < 0 and -1 or pixels > 0 and 1 or 0
    for _ = 1, math.abs(pixels) do
        local nextY = self.y+direction
        if world:collidesSolid(self, self.x, nextY) then
            if clearRemainder then self.yRemainder = 0 end
            return direction > 0 and "floor" or "ceiling"
        end
        if direction > 0 and usePlatforms then
            local platformY = world:platformLanding(self, self.y, nextY)
            if platformY then
                self.y = platformY
                if clearRemainder then self.yRemainder = 0 end
                return "floor"
            end
        end
        self.y = nextY
    end
end

function Body.playHit(self, hit)
    if self.sounds and hit and (hit.kind == "whip" or hit.kind == "stomp") then
        self.sounds:play("hit")
    end
end

function Body.stomp(self, player, fixedBounce, rearmJump)
    self:damage((math.floor((player.fallTimer or 0)/16)+1)
        * (player.equipment and player.equipment.spike_shoes and 3 or 1), player.x, { kind = "stomp" })
    player.vy = fixedBounce and -6 or -6-0.2*player.vy
    player.fallTimer = 0
    if rearmJump then player.jumpTime, player.jumpReleased = 10, true end
    player:setState("jumping")
    return "stomp"
end

return Body
