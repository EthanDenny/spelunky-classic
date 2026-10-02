local Ghost = {
    creatureConfig = { hp = 999, speed = 0.75, aggressive = true, lethal = true },
    creatureInsetX = 4,
    creatureInsetY = 8,
    creatureHalfWidth = 4,
    creatureVerticalBounds = { -16, 0 },
}

function Ghost.canDamage()
    return false
end

function Ghost.creatureStep(self, world, player)
    if not player then return end
    local dx, dy = player.x - self.x, player.y - self.y
    if dx * dx + dy * dy >= 180 * 180 then return end
    local signX = dx < 0 and -1 or dx > 0 and 1 or 0
    local signY = dy < 0 and -1 or dy > 0 and 1 or 0
    self.facing = dx < 0 and -1 or 1
    self.vx = self.vx * 0.8 + signX * self.config.speed * 0.2
    self.vy = self.vy * 0.8 + signY * self.config.speed * 0.15
    self:moveHorizontal(world, self.vx)
    self:moveVertical(world, self.vy)
end

function Ghost.contactPlayer(self, player)
    player.invincibleTimer = 0
    return player:hurt(self.x, player.health, "ghost") and "hurt" or "invincible"
end

Ghost.depth = 0

return Ghost
