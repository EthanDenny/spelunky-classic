local Collision = require("src.platform.entity_collision")
local Sight = {}

function Sight.collisionSprite(body)
    return "sSight", 0, body.x, body.y, false
end

function Sight.spawn(world, caveman)
    world.enemySights = world.enemySights or {}
    world.enemySights[#world.enemySights+1] = {
        kind = "enemy_sight", definition = Sight, x = caveman.x-8, y = caveman.y-16,
        vx = caveman.facing*10, born = world.time, alive = true,
    }
end

function Sight.update(world, player, actors, game)
    for index = #(world.enemySights or {}), 1, -1 do
        local ray = world.enemySights[index]
        if ray.born ~= world.time then
            ray.x = ray.x+ray.vx
            if Collision.solid(world, ray, player) then table.remove(world.enemySights, index)
            elseif player and Collision.touching(ray, player, player) then
                -- oEnemySight alerts every nearby caveman; its owner is unused.
                for _, actor in ipairs(actors) do
                    if actor.kind == "caveman" and actor.alive and not actor.corpse
                        and (actor.stunned or 0) == 0 and actor.state ~= actor.STATES.stunned
                        and Collision.distance(actor, player, player) < 100 then
                        actor:setState(actor.STATES.attack)
                        actor.justAlerted = true
                        if game then game.sounds:play("alert") end
                    end
                end
            end
        end
    end
end

return Sight
