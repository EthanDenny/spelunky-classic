local Traits = require("src.platform.item_traits")

local Definition = Traits.money(500, "coin")

Definition.depth = 100
Definition.treasureBounds = { 4, -4, 4 }

Definition.sprite = { group = "Items/Treasures", name = "sGoldNugget", size = 8 }

return Definition
