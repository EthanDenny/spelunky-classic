local Lighting = {}
function Lighting.darkness(game)
    local distance = 160
    local function light(x, y)
        distance = math.min(distance, math.sqrt((game.player.x-x)^2+(game.player.y-y)^2))
    end
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "lamp" and not entity.destroyed then light(entity.x*16, entity.y*16) end
    end
    for _, item in ipairs(game.items) do
        if item.alive and item.definition.lightRadius then light(item.x, item.y) end
    end
    local nearest, nearestDistance
    for _, explosion in ipairs(game.tools.explosions) do
        if explosion.alive then
            local range = math.sqrt((game.player.x-explosion.x)^2+(game.player.y-explosion.y)^2)
            if not nearestDistance or range < nearestDistance then
                nearest, nearestDistance = explosion, range
            end
        end
    end
    if nearest then
        local frame = nearest.age*0.8
        local expansion = frame <= 3 and -frame*16 or (frame-3)*16
        distance = math.min(distance, nearestDistance+expansion)
    end
    return math.max(0, math.min(0.9, distance/160))
end
return Lighting
