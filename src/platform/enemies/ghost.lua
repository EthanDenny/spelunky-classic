local Assets = require("src.platform.object_assets")
local Ghost = {
    creatureConfig = { hp = 1, speed = 1 },
    creatureInsetX = 4, creatureInsetY = 8, creatureHalfWidth = 4,
    creatureVerticalBounds = { -16, 0 }, depth = 0,
}
local counts = { sGhostRight = 4, sGhostLeft = 4, sGhostTurnRight = 7,
    sGhostTurnLeft = 7, sGhostDisappear = 14 }
local sprites = {}
function Ghost.canDamage() return false end
function Ghost.initializeCreature(body)
    body.spriteName, body.animation, body.facing = "sGhostRight", 0, 1
end
function Ghost.stepCreature(body, _, player)
    if body.state == "disappear" then
        body.animation = body.animation + 0.2
        if body.animation >= 14 then body.alive = false body.rescued = true end
        return
    end
    body.animation = body.animation + 0.5
    if body.animation >= counts[body.spriteName] then
        body.animation = 0
        if body.spriteName == "sGhostTurnLeft" then body.spriteName = "sGhostLeft"
        elseif body.spriteName == "sGhostTurnRight" then body.spriteName = "sGhostRight" end
    end
    if not player or player:isDead() then return end
    local dx, dy = player.x-body.x, player.y-(body.y-8)
    local distance = math.sqrt(dx*dx+dy*dy)
    if distance == 0 then body.vx, body.vy = 0, 0 return end
    if dx < 0 and body.spriteName == "sGhostRight" then
        body.spriteName, body.animation = "sGhostTurnLeft", 0
    elseif dx >= 0 and body.spriteName == "sGhostLeft" then
        body.spriteName, body.animation = "sGhostTurnRight", 0
    end
    body.vx, body.vy = dx/distance, dy/distance
    body.x, body.y = body.x+body.vx, body.y+body.vy
end
function Ghost.resolvePlayerContact(body, player, _, game)
    if body.state == "disappear" or player:isDead() or player.invincibleTimer > 0 then return "invincible" end
    player:kill("ghost", 0, 0)
    player.visible, player.invincibleTimer = false, 9999
    body.state, body.spriteName, body.animation = "disappear", "sGhostDisappear", 0
    if game then
        game.sounds:play("die")
        game.sounds:play("ghost")
        for _ = 1, 3 do game.effects:add("bone", player.x, player.y,
            game.effects.random:random(-4,4), -game.effects.random:random(1,3)) end
        local skull = game:spawnEntity("skull", player.x, player.y-2)
        skull.vx, skull.vy = game.effects.random:random(0,3)-game.effects.random:random(0,3), -game.effects.random:random(1,3)
        local held = game.heldItem or game.heldNpc
        if held then held.held, held.vx, held.vy = false, body.facing*2, -4 end
        game.heldItem, game.heldNpc = nil, nil
    end
    return "hurt"
end
function Ghost.drawCreature(body)
    local name = body.spriteName
    sprites[name] = sprites[name] or {}
    local frame = math.floor(body.animation) % counts[name]
    sprites[name][frame] = sprites[name][frame] or Assets.image("Enemies/Ghost", name, frame)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(sprites[name][frame], math.floor(body.x-8), math.floor(body.y-16))
end
return Ghost
