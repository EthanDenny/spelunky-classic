local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(8000)

Definition.depth = 100
Definition.shopOffsetY = 10

Definition.pickupMessage = "YOU GOT SPECTACLES!\nYOUR EYESIGHT SEEMS IMPROVED..."
Definition.buyMessage = "SPECTACLES FOR $%s."

return Definition
