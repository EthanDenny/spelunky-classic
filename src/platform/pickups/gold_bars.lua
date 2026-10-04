local Traits = require("src.platform.item_traits")

local Definition = Traits.money(1000, "coin")

Definition.depth = 100
Definition.treasureBounds = { 7, -8, 8 }
-- sGoldBars has a wider, shallower sprite mask than setCollisionBounds.
Definition.treasurePickupBounds = { -8, -2, 8, 8 }

return Definition
