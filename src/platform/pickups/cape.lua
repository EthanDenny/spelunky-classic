local Traits = require("src.platform.item_traits")
local Assets = require("src.platform.object_assets")

local Definition = Traits.equipment(12000)

Definition.depth = 100
Definition.shopOffsetY = 10
Definition.replaces = "jetpack"

Definition.pickupMessage = "YOU GOT A CAPE!"
Definition.buyMessage = "A CAPE FOR $%s."

local function wornSprite(player)
    local back = (player.state == "climbing" or player.state == "exiting") and not player.whipping
    if back then return "sCapeBack", 1, 8, true end
    local right = player.facing == 1
    if player.capeOpen then return right and "sCapeUR" or "sCapeUL", 2, 16 end
    if math.abs(player.vx) > 0 then return right and "sCapeRight" or "sCapeLeft", 5, 8 end
    return right and "sCapeDR" or "sCapeDL", 1, 6
end

function Definition.stepWorn(player)
    if player.equipment.cape and player.visible ~= false then
        local _, count = wornSprite(player)
        player.capeFrame = ((player.capeFrame or 0)+1) % count
    else player.capeFrame = 0 end
end

function Definition.submitWorn(queue, player)
    if not player.equipment.cape or player.visible == false then return end
    local name, count, originY, back = wornSprite(player)
    local x, y = player.x, player.y+4
    if not back then
        x, y = player.x+(player.facing == 1 and -4 or 4), player.y-2
    end
    queue:add(back and 0 or 100, function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Assets.frame("Items/Saleable", name, count, player.capeFrame),
            math.floor(x), math.floor(y), 0, 1, 1, 8, originY)
    end)
end

return Definition
