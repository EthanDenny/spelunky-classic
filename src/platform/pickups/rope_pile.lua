local Traits = require("src.platform.item_traits")

local Definition = Traits.supply(2500, "ropes", 3, { 6, -5, 5 })

Definition.depth = 100
Definition.shopOffsetY = 11

Definition.pickupMessage = "YOU GOT 3 MORE ROPES!"
Definition.buyMessage = "EXTRA ROPE FOR $%s."

return Definition
