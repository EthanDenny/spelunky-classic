local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ unlocks = "locked_chest" })

Definition.depth = 101

Definition.leftSprite = { group = "Items/Saleable", name = "sKeyLeft", originY = 6 }

return Definition
