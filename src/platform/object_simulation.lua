-- Reusable phases; screens retain their own phase order and responses.
local Simulation = {}

function Simulation.prepareAction(game, input, pressed, includeNpc)
    local container = pressed and input.up and game:containerAtPlayer()
    if game.heldItem or (includeNpc and game.heldNpc) or container then input.suppressWhip = true end
    return container
end

function Simulation.whipContact(player, enemy)
    local name, x, y = player:getWhipSprite()
    if not name or not (enemy.alive or enemy.corpse) or enemy.kind == "ghost" or not player:whipCanHit(enemy)
        or not require("src.platform.whip_mask").touching(name, x, y, enemy) then return false end
    player:markWhipHit(enemy)
    return true
end

function Simulation.stepItems(game, afterStep, onlyClosed)
    for _, item in ipairs(game.items) do
        if not onlyClosed or not item.opened then
            item:update(game.world, game.player, game)
            if afterStep then afterStep(item) end
        end
    end
end

function Simulation.stepCollectibles(game, player)
    for _, item in ipairs(game.collectibles) do item:update(game.world, player) end
end

return Simulation
