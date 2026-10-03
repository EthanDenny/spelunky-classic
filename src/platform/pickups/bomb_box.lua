local Traits = require("src.platform.item_traits")

local Definition = Traits.supply(10000, "bombs", 12, { 6, -2, 8 })
Definition.heavy = true
Definition.hold = { standing = -4, ducking = -2 }

Definition.depth = 100
Definition.shopOffsetY = 8

Definition.pickupMessage = "YOU GOT 12 MORE BOMBS!"
Definition.buyMessage = "A BOX OF 12 BOMBS FOR $%s."

return Definition
