local ArrowTrap = {}

local function clearLine(world, x1, x2, y)
    local direction = x2 < x1 and -4 or 4
    local x = x1
    while (direction < 0 and x > x2) or (direction > 0 and x < x2) do
        if world:solidAtPoint(x, y) then return false end
        x = x + direction
    end
    return true
end

function ArrowTrap.fire(self, trap, direction)
    self.projectiles[#self.projectiles + 1] = {
        kind = "arrow", x = trap.x + (direction > 0 and 18 or -2), y = trap.y + 4,
        vx = direction * 8, vy = 0, direction = direction, alive = true,
        launchTrapX = math.floor(trap.x / self.world.tileSize),
        launchTrapY = math.floor(trap.y / self.world.tileSize),
        clearOfLaunchTrap = false,
    }
    trap.fired = true
    if self.arrowSound then self.arrowSound:clone():play() end
end

function ArrowTrap.update(self, trap, player, enemies, items, movingTargets)
    if trap.fired then return end
    local direction = trap.definition.direction
    local originX, originY = trap.x + 8, trap.y + 8
    local function inBeam(target)
        if not target or target.alive == false or target.held or target.deployed
            or target.stuck or target.phase == "create" then return false end
        local targetX = target.moveable and target.x + target.width / 2 or target.x
        local targetY = target.moveable and target.y + target.height / 2 or target.y
        local halfWidth = target.moveable and target.width / 2
            or target.getCollisionHalfWidth and target:getCollisionHalfWidth()
            or target.radius or 4
        local top, bottom
        if target.moveable then
            top, bottom = target.y, target.y + target.height
        elseif target.getVerticalBounds then
            local topOffset, bottomOffset = target:getVerticalBounds()
            top, bottom = target.y + topOffset, target.y + bottomOffset
        else
            local radius = target.radius or 4
            top, bottom = targetY - radius, targetY + radius
        end
        local near = (targetX - originX) * direction - halfWidth
        local far = near + halfWidth * 2
        local moving = math.abs(target.vx or 0) > 0.05
            or math.abs(target.vy or 0) > 0.05
        return far > 0 and near <= 96 and bottom > originY - 8
            and top < originY + 8
            and moving and clearLine(self.world, originX + direction * 10,
                targetX - direction * halfWidth, originY)
    end
    if inBeam(player) then self:fireArrow(trap, direction) return end
    for _, group in ipairs({ enemies or {}, items or {}, movingTargets or {},
        self.world.dynamicSolids, self.projectiles }) do
        for _, target in ipairs(group) do
            if (group ~= self.world.dynamicSolids or target.moveable) and inBeam(target) then
                self:fireArrow(trap, direction)
                return
            end
        end
    end
end


return ArrowTrap
