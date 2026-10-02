local Head = { depth = 997 }

function Head.update(system, trap)
    if trap.state ~= "armed" then return end
    trap.cooldown = trap.cooldown - 1
    if trap.cooldown <= 0 then
        trap.state = "fired"
        system:spawnBoulder(trap)
        if system.thumpSound then system.thumpSound:clone():play() end
    end
end

function Head.draw(system, trap)
    if trap.state ~= "fired" then return false end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(system.assets.tikiHole, math.floor(trap.x - 16), math.floor(trap.y - 16))
    return true
end

function Head.loadAssets(assets)
    assets.tikiHole = require("src.platform.object_assets").image("Traps", "sGTHHole")
end

function Head.triggerIdol(self, player)
    local nearest, nearestDistance
    for _, trap in ipairs(self.traps) do
        if trap.alive and trap.kind == "giant_tiki_head" then
            local dx, dy = trap.x - player.x, trap.y - 64 - player.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = trap, distance
            end
        end
    end
    if nearest then nearest.state, nearest.cooldown = "armed", 100 end
end

return Head
