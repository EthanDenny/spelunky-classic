local ArrowTrap = {}

function ArrowTrap.initializeBeam(world, trap, direction)
    local x = trap.x + (direction < 0 and -1 or 16)
    while not world:solidAtPoint(x, trap.y+8) do
        if math.abs(x-trap.x) > 96 then break end
        x = x + direction
    end
    if direction < 0 then
        x = math.min(x, trap.x-16)
        trap.beamLeft, trap.beamRight = x, x+math.ceil((trap.x-1-x)/16)*16
    else
        local distance = math.max(32, x-trap.x-8)
        trap.beamLeft, trap.beamRight = trap.x+16, trap.x+16+math.ceil((distance-16)/16)*16
    end
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
    local originY = trap.y + 8
    if not trap.beamLeft then ArrowTrap.initializeBeam(self.world, trap, direction) end
    local function inBeam(target)
        if not target or target.kind == "ghost" or target.alive == false or target.held or target.deployed
            or target.stuck or target.phase == "create" then return false end
        local solidBody = target.moveable or target.kind == "boulder" and target.width
        local targetX = solidBody and target.x + target.width / 2 or target.x
        local targetY = solidBody and target.y + target.height / 2 or target.y
        local halfWidth = solidBody and target.width / 2
            or target.getCollisionHalfWidth and target:getCollisionHalfWidth()
            or target.radius or 4
        local top, bottom
        if solidBody then
            top, bottom = target.y, target.y + target.height
        elseif target.getVerticalBounds then
            local topOffset, bottomOffset = target:getVerticalBounds()
            top, bottom = target.y + topOffset, target.y + bottomOffset
        else
            local radius = target.radius or 4
            top, bottom = targetY - radius, targetY + radius
        end
        local moving = (target.vx or 0) ~= 0 or (target.vy or 0) ~= 0
            or target == player and target.spriteName == "sDuckToHangL" and (target.animationFrame or 0) > 6
        return targetX+halfWidth > trap.beamLeft and targetX-halfWidth < trap.beamRight
            and bottom > originY-8 and top < originY+8 and moving
    end
    if inBeam(player) then self:fireArrow(trap, direction) return end
    for _, group in ipairs({ enemies or {}, items or {}, movingTargets or {},
        self.world.dynamicSolids, self.projectiles }) do
        for _, target in ipairs(group) do
            if (group ~= self.world.dynamicSolids or target.moveable or target.kind == "boulder") and inBeam(target) then
                self:fireArrow(trap, direction)
                return
            end
        end
    end
end


return ArrowTrap
