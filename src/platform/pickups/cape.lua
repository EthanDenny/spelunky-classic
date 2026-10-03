local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(12000)

Definition.depth = 100
Definition.shopOffsetY = 10
Definition.replaces = "jetpack"

Definition.pickupMessage = "YOU GOT A CAPE!"
Definition.buyMessage = "A CAPE FOR $%s."

return Definition
