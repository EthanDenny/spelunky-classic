local Traits = require("src.platform.item_traits")

local Definition = Traits.money(4000, "coin")

Definition.depth = 40
Definition.hp = 1
Definition.bloodless = true
Definition.deathBlood = 0
Definition.treasureAnchor = { 8, 8 }
Definition.treasureBounds = { 4, -4, 4 }
function Definition.updateTreasure(body, world, player)
    local Physics = require("src.platform.physical_body")
    body.counter = body.counter or love.math.random(10, 30)
    local vx, vy = body.vx, body.vy
    if Physics.move(world, body, "x", vx) then body.vx = -vx end
    if Physics.move(world, body, "y", vy) then body.vy = -vy end
    if world:solidAtPoint(body.x, body.y) then
        body:damage(999)
        return
    end
    local function slow(value)
        if value > 0 then value = value-0.5 elseif value < 0 then value = value+0.5 end
        return math.abs(value) < 1 and 0 or value
    end
    body.vx, body.vy = slow(body.vx), slow(body.vy)
    if body.vx == 0 and body.vy == 0 then body.counter = body.counter - 1 end
    if body.counter <= 0 and math.abs(body.vx) < 1 and math.abs(body.vy) < 1 then
        local angle = love.math.random() * math.pi * 2
        if player and (player.x-body.x)^2 + (player.y-body.y)^2 < 64^2 then
            angle = math.atan2(body.y-player.y, body.x-player.x)
        end
        body.vx, body.vy = math.cos(angle)*4, math.sin(angle)*4
        body.counter = love.math.random(10, 30)
    end
end

function Definition.onCollected(body, game)
    local random = game.effects.random
    for _ = 1, 3 do
        game.effects:add("teleport_spark", body.x-2+random:random(0,4), body.y-2+random:random(0,4))
    end
end

function Definition.onDeath(body, game)
    local random = game.effects.random
    for _ = 1, 3 do
        game.effects:add("teleport_spark", body.x-6+random:random(0,14),
            body.y-6+random:random(0,14), 0, random:random(1,3))
    end
    Definition.onCollected(body, game)
end

return Definition
