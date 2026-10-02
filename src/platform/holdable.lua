local Holdable = {}

function Holdable.pickup(item, player)
    if item.held then return false end
    item.held = true
    item.stuck = false
    item.vx, item.vy = 0, 0
    item.xRemainder, item.yRemainder = 0, 0
    Holdable.position(item, player)
    return true
end

function Holdable.position(item, player)
    item.x = player.x + player.facing * 4
    item.facing = player.facing
    local crouched = player.state == "ducking" and math.abs(player.vx) < 2
    local hold = item.definition.hold
    item.y = player.y + (crouched and hold.ducking or hold.standing)
end

function Holdable.throw(item, player, input, world)
    input = input or {}
    item.held = false
    item.stuck = false
    item.facing = player.facing
    item.safeTimer = 10
    item.vx = player.facing * (item.heavy and 4 or 8) + player.vx
    item.vy = item.heavy and -2 or -3
    if world and world:solidAtPoint(player.x + player.facing * 8, player.y) then
        item.x = item.x - player.facing * 8
    end
    if input.up then
        item.vy = item.heavy and -4 or -9
    end
    if input.down then
        if player:isGroundState() then
            item.y = item.y - 2
            item.vx = item.vx * 0.6
            item.vy = 0.5
        else
            item.vy = 3
        end
    end
    if not input.down and not (player.equipment and player.equipment.mitt)
        and world and world:solidAtPoint(player.x + player.facing * 8, player.y - 10) then
        item.vy = 0
        item.vx = item.vx + player.facing
    end
    local ducking = player.state == "ducking" and math.abs(player.vx) < 3
    if player.equipment and player.equipment.mitt and not ducking then
        item.vx = item.vx + (item.vx < 0 and -6 or 6)
        if not input.up and not input.down then item.vy = -0.4
        elseif input.down then item.vy = 6 end
        item.gravity = 0.1
    end
end

function Holdable.dropWeapon(item, player)
    item.held = false
    item.bowArmed = false
    item.bowStrength = 0
    item.safeTimer = 10
    item.vx = (player.facing * (item.heavy and 4 or 8) + player.vx) * 0.4
    item.vy = 0.5
    -- The held sprite keeps its last position when dropped.
end

function Holdable.dropFromHurt(item, player)
    item.held = false
    item.bowArmed = false
    item.bowStrength = 0
    item.safeTimer = 10
    item.vx, item.vy = player.vx, -6
end

return Holdable
