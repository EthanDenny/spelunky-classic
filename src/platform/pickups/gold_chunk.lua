local Traits = require("src.platform.item_traits")

local Definition = Traits.money(100, "coin")

Definition.depth = 100
Definition.treasureBounds = { 2, -2, 2 }

Definition.sprite = { group = "Items/Treasures", name = "sGoldChunk", size = 4 }

return Definition
