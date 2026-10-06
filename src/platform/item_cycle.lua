local Bow = require("src.platform.items.bow")
local Rope = require("src.platform.tools.rope")
local Cycle = {}

local function discard(game, item)
    item.alive, item.held, item.visible = false, false, false
    game.heldItem = nil
end

function Cycle.restore(game)
    game.heldItem = nil
    local kind = game.cycleItemKind
    game.cycleItemKind = nil
    if not kind then return end
    local item = game:spawnEntity(kind, game.player.x, game.player.y)
    item.new = false
    item:pickup(game.player, game.run)
    game.heldItem = item
end

local function selectBomb(game)
    local bomb = game.tools:spawnBomb(game.player.x, game.player.y,
        { armed = false, sticky = game.player.equipment.paste })
    bomb:pickup(game.player)
    game.heldItem = bomb
    game.run.bombs = game.run.bombs-1
end

local function selectRope(game)
    game.heldItem = Rope.hold(game.tools, game.player)
    game.run.ropes = game.run.ropes-1
end

function Cycle.select(game)
    local player, item = game.player, game.heldItem
    if player:isDead() or player:isStunned() or player.whipping or game.heldNpc then return false end
    if item and item.kind == "bomb" then
        if item.armed then return false end
        game.run.bombs = game.run.bombs+1
        discard(game, item)
        if game.run.ropes > 0 then selectRope(game) else Cycle.restore(game) end
    elseif item and item.kind == "rope" then
        game.run.ropes = game.run.ropes+1
        discard(game, item)
        Cycle.restore(game)
    elseif item and (item.heavy or require("src.platform.shop").forSale(item)) then
        return false
    else
        if game.run.bombs <= 0 and game.run.ropes <= 0 then return false end
        if item then
            game.cycleItemKind = item.kind
            if item.bowArmed then Bow.updateBow(game, {}) end
            discard(game, item)
        end
        if game.run.bombs > 0 then selectBomb(game) else selectRope(game) end
    end
    return true
end

function Cycle.prepareExit(game)
    local item = game.heldItem
    if not item or (item.kind ~= "bomb" and item.kind ~= "rope") then return end
    if item.kind == "rope" or not item.armed then
        local resource = item.kind == "rope" and "ropes" or "bombs"
        game.run[resource] = game.run[resource]+1
        item.alive = false
    end
    item.held = false
    Cycle.restore(game)
end

return Cycle
