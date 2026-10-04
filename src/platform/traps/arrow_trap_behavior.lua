local ArrowTrap = {}
local Sensor = require("src.platform.traps.arrow_trap_sensor")

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
    local arrow = require("src.platform.item").new({ kind = "arrow",
        x = (trap.x + (direction > 0 and 18 or -2))/16, y = (trap.y+4)/16 })
    arrow.vx, arrow.direction, arrow.facing = direction*8, direction, direction
    self.projectiles[#self.projectiles+1] = arrow
    trap.fired = true
    if self.arrowSound then self.arrowSound:clone():play() end
end

function ArrowTrap.update(self, trap, player, enemies, items, movingTargets)
    if trap.fired then return end
    local direction = trap.definition.direction
    if not trap.beamLeft then ArrowTrap.initializeBeam(self.world, trap, direction) end
    if Sensor.detects(trap, player, player) then self:fireArrow(trap, direction) return end
    for _, group in ipairs({ enemies or {}, items or {}, movingTargets or {},
        self.world.dynamicSolids, self.boulders, self.projectiles }) do
        for _, target in ipairs(group) do
            if (group ~= self.world.dynamicSolids or target.moveable) and Sensor.detects(trap, target, player) then
                self:fireArrow(trap, direction)
                return
            end
        end
    end
end


return ArrowTrap
