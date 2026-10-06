local Traits = require("src.platform.item_traits")
local Assets = require("src.platform.object_assets")

local Definition = Traits.equipment(20000, { 5, -5, 8 })
Definition.heavy = true
Definition.hold = { standing = -4, ducking = -2 }

Definition.depth = 100
Definition.shopOffsetY = 8
Definition.replaces = "cape"

function Definition.update(item, _, player)
    if player and player.visible == false then
        item.alive, item.visible, item.opened = false, false, true
    end
end

Definition.pickupMessage = "YOU GOT A JETPACK!"
Definition.buyMessage = "JETPACK FOR $%s."

function Definition.drawWorn(player, afterBody)
    if not player.equipment.jetpack then return end
    local back = (player.state == "climbing" or player.state == "exiting") and not player.whipping
    if back ~= afterBody then return end
    local name = back and "sJetpackBack" or player.facing == 1 and "sJetpackRight" or "sJetpackLeft"
    local x, y = player.x, player.y
    if not back then x, y = x+(player.facing == 1 and -4 or 4), y-1 end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Assets.frame("Items/Saleable", name, 1, 0), math.floor(x), math.floor(y), 0, 1, 1, 8, 8)
end

return Definition
