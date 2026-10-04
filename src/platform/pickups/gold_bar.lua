local Traits = require("src.platform.item_traits")

local Definition = Traits.money(500, "coin")

Definition.depth = 100
-- sGoldBar's automatic rectangular mask excludes its three empty top rows.
Definition.treasurePickupBounds = { -4, -1, 4, 4 }

return Definition
