local Traits = require("src.platform.item_traits")

local Definition = Traits.equipment(20000, { 5, -5, 8 })
Definition.heavy = true
Definition.hold = { standing = -4, ducking = -2 }

Definition.depth = 100
Definition.shopOffsetY = 8
Definition.replaces = "cape"

return Definition
