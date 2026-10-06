local Sensor = {}
Sensor.overlaps = require("src.platform.entity_collision").overlaps

function Sensor.detects(trap, target, player)
    if not target or target.kind == "ghost" or target.alive == false and not target.corpse then return false end
    if target.kind == "bullet" or target.kind == "pellet" or target.kind == "web"
        or target.kind == "explosion" then return false end
    local moving = (target.vx or 0) ~= 0 or (target.vy or 0) ~= 0
        or target == player and target.spriteName == "sDuckToHangL" and (target.animationFrame or 0) > 6
    if not moving then return false end
    -- sRed is opaque only at y=1..14; its image_xscale supplies the cached width.
    return Sensor.overlaps(target, player, trap.beamLeft, trap.y+1, trap.beamRight, trap.y+15)
end

return Sensor
