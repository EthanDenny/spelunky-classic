local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(999999, { 6, -6, 8 })

Definition.depth = 100

Definition.pickupMessage = "YOU GOT THE KAPALA!\nIT THIRSTS FOR BLOOD..."
Definition.buyMessage = "I SHOULDN'T BE SELLING THIS!"

return Definition
