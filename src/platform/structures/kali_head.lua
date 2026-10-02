local Definition = { depth = 997 }
local Assets = require("src.platform.object_assets")
local hole

function Definition.arm(entity)
    entity.spiderAlarm = 1
end

function Definition.update(game, entity)
    if not entity.spiderAlarm then return end
    entity.spiderAlarm = entity.spiderAlarm - 1
    if entity.spiderAlarm > 0 then return end
    entity.spiderAlarm, entity.opened = nil, true
    for _ = 1, 6 do
        -- oSpider uses a top-left origin; the live body uses bottom-center.
        local spider = game:spawnEntity("spider", entity.x * 16 + 8, entity.y * 16 + 16)
        spider.vx = game.effects.random:random(0, 3) - game.effects.random:random(0, 3)
        spider.vy = -game.effects.random:random(1, 3)
    end
    game.sounds:play("thump")
end

function Definition.draw(renderer, entity)
    if entity.opened then
        hole = hole or Assets.image("Traps", "sGTHHole")
        love.graphics.draw(hole, entity.x * 16 - 16, entity.y * 16 - 16)
        return
    end
    love.graphics.draw(renderer.backdropImages.kali_heads[entity.properties.variant],
        entity.x * 16 - 16, entity.y * 16 - 16)
end

return Definition
