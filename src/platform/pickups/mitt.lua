local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(4000, { 6, -6, 8 })

Definition.depth = 100
Definition.shopOffsetY = 8

Definition.pickupMessage = "YOU GOT A PITCHER'S MITT!"
Definition.buyMessage = "PITCHER'S MITT FOR $%s."

return Definition
