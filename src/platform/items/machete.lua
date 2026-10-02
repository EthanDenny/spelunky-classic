local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "melee", price = 7000,
    melee = { damage = 2, strike = "slash", canSwingInAir = true,
        playerSpeed = 1, strikeSpeed = 1 } })

Definition.depth = 101
Definition.shopOffsetY = 12

Definition.melee.keeperWhipDamage = Definition.melee.damage
Definition.melee.cutsWebs = true

Definition.leftSprite = { group = "Items/Saleable", name = "sMacheteLeft" }

return Definition
