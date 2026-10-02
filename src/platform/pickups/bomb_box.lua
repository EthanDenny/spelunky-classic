local Traits = require("src.platform.item_traits")

local Definition = Traits.supply(10000, "bombs", 12, { 6, -2, 8 })

Definition.depth = 100
Definition.shopOffsetY = 8

return Definition
