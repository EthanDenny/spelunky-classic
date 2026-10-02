local Ghost = {
    creatureConfig = { hp = 1, speed = 1 },
    creatureInsetX = 4,
    creatureInsetY = 8,
    creatureHalfWidth = 4,
    creatureVerticalBounds = { -16, 0 },
}

function Ghost.canDamage()
    return false
end

function Ghost.creatureStep(self, _, player)
    if not player then return end
    -- oGhost targets its 16-pixel collision mask's center and moves directly.
    local dx, dy = player.x - self.x, player.y - (self.y - 8)
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance == 0 then self.vx, self.vy = 0, 0 return end
    self.facing = dx < 0 and -1 or 1
    self.vx, self.vy = dx / distance, dy / distance
    self.x, self.y = self.x + self.vx, self.y + self.vy
end

function Ghost.resolvePlayerContact(self, player)
    return player:hurt(self.x, player.health, "ghost") and "hurt" or "invincible"
end

Ghost.depth = 0

return Ghost
