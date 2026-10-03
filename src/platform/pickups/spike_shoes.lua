local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(4000)

Definition.depth = 100
Definition.shopOffsetY = 10

Definition.pickupMessage = "YOU GOT SPIKE SHOES!"
Definition.buyMessage = "SPIKE SHOES FOR $%s."

return Definition
