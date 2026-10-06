local Definition = { depth = 9000 }
function Definition.isNear(game)
    if not game.level.exit or not game.player then return false end
    local x, y = game.level.exit.x*16, game.level.exit.y*16
    return game.player.x >= x and game.player.x < x+16
        and game.player.y >= y and game.player.y < y+16
end
function Definition.contact(game)
    if not Definition.isNear(game) or game.player:isDead() then return end
    local held = game.heldItem
    if held and held.kind == "gold_idol" then
        game.run:queueMoney(5000)
        if game.recordLoot then game:recordLoot(held.kind, 5000) end
        held.alive, held.held, held.visible, held.opened = false, false, false, true
        game.heldItem = nil
        game.sounds:play("coin")
    end
    local body = game.heldNpc
    if body and body.kind == "damsel" and body.alive then
        require("src.platform.enemies.damsel").rescue(body, game)
    end
end
function Definition.prepare(game)
    Definition.contact(game)
    require("src.platform.item_cycle").prepareExit(game)
    if game.heldItem and game.heldItem.heavy then
        game.heldItem.held = false
        game.heldItem = nil
    end
    if game.heldItem then
        local item = game.heldItem
        if item.kind ~= "bomb" then game:captureHeldItem() end
        item.held = false
        if item.kind ~= "bomb" then item.alive, item.visible, item.opened = false, false, true end
        game.heldItem = nil
    end
    if game.heldNpc then
        game.heldNpc.held = false
        game.heldNpc = nil
    end
    game.run:flushMoney()
end
function Definition.begin(game)
    local player = game.player
    if game.exiting or game.completed or not Definition.isNear(game)
        or player:isDead() or player:isStunned() or player.whipping
        or not game.world:groundBelow(player) then return false end
    Definition.prepare(game)
    game.exiting = 0
    player.invincibleTimer = 999
    player.state, player.vx, player.vy = "exiting", 0, 0
    player.x, player.y = game.level.exit.x*16+8, game.level.exit.y*16+8
    return true
end
local frames
function Definition.drawPlayer(game)
    local Assets = require("src.platform.object_assets")
    frames = frames or {}
    local frame = math.min(15, math.floor(game.exiting*0.5))
    frames[frame] = frames[frame] or Assets.image("Character/Main Dude", "sPExit", frame)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(frames[frame], math.floor(game.player.x), math.floor(game.player.y), 0,
        game.player.facing == 1 and -1 or 1, 1, 8, 8)
    require("src.platform.pickups.jetpack").drawWorn(game.player, true)
end
return Definition
