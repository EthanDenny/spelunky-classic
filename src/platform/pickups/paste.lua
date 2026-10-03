local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(3000, { 6, -2, 6 })

Definition.depth = 100
Definition.shopOffsetY = 10

Definition.pickupMessage = "YOU GOT STICKY BOMBS!"
Definition.buyMessage = "BOMB PASTE FOR $%s."

return Definition
