local Traits = require("src.platform.item_traits")

local jarLoot = {
    { odds = 3, kind = "gold_chunk" }, { odds = 6, kind = "gold_nugget" },
    { odds = 12, kind = "emerald_big" }, { odds = 12, kind = "sapphire_big" },
    { odds = 12, kind = "ruby_big" }, { odds = 6, kind = "spider" },
    { odds = 12, kind = "snake" },
}

local Definition = Traits.carry({ flight = "fragile", bounds = { 4, -6, 6 }, hold = { standing = 0, ducking = 4 },
    breakOnImpact = { wall = 3, ceiling = 3, floor = 3, effect = "jar" },
    container = { mode = "chain", rolls = jarLoot,
        message = "JAR SMASHED", effect = "jar" } })

Definition.depth = 100

Definition.breakWhenEmbedded = true
Definition.breakOnBullet = true

return Definition
