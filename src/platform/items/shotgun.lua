local Traits = require("src.platform.item_traits")

local Definition = Traits.carry({ action = "gun", price = 15000, gun = {
    projectile = "bullet", count = 6, minSpeed = 6, maxSpeed = 8,
    verticalSpread = 1, damage = 4,
    recoil = 3, cooldown = 40,
} })

Definition.depth = 101
Definition.shopOffsetY = 12

Definition.leftSprite = { group = "Items/Weapons", name = "sShotgunLeft" }

return Definition
