local Traits = require("src.platform.item_traits")

local Definition = Traits.money(400)

Definition.depth = 101
Definition.treasureBounds = { 2, -2, 2 }

Definition.sprite = { group = "Items/Treasures", name = "sSapphire", size = 4 }

return Definition
