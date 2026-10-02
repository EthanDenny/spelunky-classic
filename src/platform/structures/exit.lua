local Definition = { depth = 9000 }

function Definition.isNear(self)
    if not self.level.exit or not self.player then return false end
    local exitX = self.level.exit.x * 16 + 8
    local exitY = self.level.exit.y * 16 + 8
    return math.abs(self.player.x - exitX) <= 11 and math.abs(self.player.y - exitY) <= 15
end


return Definition
