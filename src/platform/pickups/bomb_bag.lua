local Traits = require("src.platform.item_traits")

local Definition = Traits.supply(2500, "bombs", 3, { 6, -2, 6 })

Definition.depth = 100
Definition.shopOffsetY = 10

Definition.pickupMessage = "YOU GOT 3 MORE BOMBS!"
Definition.buyMessage = "A BAG OF 3 BOMBS FOR $%s."

return Definition
