local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(5000)

Definition.depth = 100
Definition.shopOffsetY = 10

Definition.pickupMessage = "YOU GOT SPRING SHOES!\nYOU FEEL BOUNCY."
Definition.buyMessage = "SPRINGY SHOES FOR $%s."

return Definition
