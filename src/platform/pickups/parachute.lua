local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(2000)

Definition.depth = 100
Definition.shopOffsetY = 10

Definition.pickupMessage = "YOU GOT A PARACHUTE!\nIT WILL DEPLOY AUTOMATICALLY."
Definition.buyMessage = "A PARACHUTE FOR $%s."

return Definition
