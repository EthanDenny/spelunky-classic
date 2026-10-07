local Traits = require("src.platform.item_traits")

local Definition = Traits.money(4000, "coin")

Definition.depth = 40
Definition.hp = 1
Definition.deferDeath = true
Definition.bloodless = true
Definition.deathBlood = 0
Definition.treasureAnchor = { 8, 8 }
Definition.treasureBounds = { 4, -4, 4 }
Definition.animationSpeed = 0.5
local function random(body, minimum, maximum)
    if body.game then return body.game.effects.random:random(minimum, maximum) end
    return love.math.random(minimum, maximum)
end

function Definition.initializeTreasure(body)
    body.counter = body.entity.counter or random(body, 10, 30)
end

function Definition.collisionSprite(body)
    return "sScarab", body.animation, body.x-8, body.y-8, false
end

function Definition.entityImage(entity)
    return require("src.platform.object_assets").frame("Items/Treasures", "sScarab", 3, entity.animation or 0)
end

function Definition.updateTreasure(body, world, player)
    local Physics = require("src.platform.physical_body")
    Physics.move(world, body, "x", body.vx)
    Physics.move(world, body, "y", body.vy)
    if world:solidAtPoint(body.x, body.y) then
        body.hp = -999
    end
    if body.hp < 1 then
        body.alive = false
        Definition.onDeath(body, body.game)
    end
    -- oScarab continues its Step after instance_destroy, including rand calls.
    local function slow(value)
        if value > 0 then value = value-0.5 elseif value < 0 then value = value+0.5 end
        return math.abs(value) < 1 and 0 or value
    end
    body.vx, body.vy = slow(body.vx), slow(body.vy)
    if body.vx == 0 and body.vy == 0 and body.counter > 0 then body.counter = body.counter - 1 end
    if body.counter == 0 and body.vx < 1 and body.vy < 1 then
        local angle
        if player and (player.x-body.x)^2 + (player.y-body.y)^2 < 64^2 then
            angle = math.atan2(body.y-player.y, body.x-player.x)
        else angle = -math.rad(random(body, 0, 360)) end
        body.vx, body.vy = math.cos(angle)*4, math.sin(angle)*4
        body.counter = random(body, 10, 30)
    end
    if Physics.probe(world, body, "x", 1) and body.vx > 0 then body.vx = -body.vx end
    if Physics.probe(world, body, "x", -1) and body.vx < 0 then body.vx = -body.vx end
    if Physics.probe(world, body, "y", -1) and body.vy < 0 then body.vy = -body.vy end
    if Physics.probe(world, body, "y", 1) and body.vy > 0 then body.vy = -body.vy end
end

local function destroySparks(game, x, y)
    local random = game.effects.random
    for _ = 1, 3 do
        game.effects:add("teleport_spark", x+random:random(0,4), y+random:random(0,4))
    end
end

function Definition.onCollected(_, game)
    destroySparks(game, game.player.x+6, game.player.y+6)
end

function Definition.onDeath(body, game)
    local random = game.effects.random
    for _ = 1, 3 do
        game.effects:add("teleport_spark", body.x-6+random:random(0,14),
            body.y-6+random:random(0,14), 0, random:random(1,3))
    end
    destroySparks(game, body.x-2, body.y-2)
end

return Definition
