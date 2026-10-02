local Traits = require("src.platform.item_traits")

local Definition = Traits.supply(2500, "bombs", 3, { 6, -2, 6 })

Definition.depth = 100
Definition.shopOffsetY = 10

return Definition
