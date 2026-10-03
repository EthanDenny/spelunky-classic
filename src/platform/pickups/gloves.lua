local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(8000, { 6, -6, 8 })

Definition.depth = 100
Definition.shopOffsetY = 8

function Definition.pickupMessage(game)
    return "YOU GOT CLIMBING GLOVES!" .. (game and game.heldItem and game.heldItem.kind == "web_cannon"
        and "\nYOUR SPIDER SENSE TINGLES!" or "")
end
Definition.buyMessage = "CLIMBING GLOVES FOR $%s."

return Definition
