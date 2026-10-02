local Definition = require("src.platform.item_traits").carry()
Definition.depth = 101
Definition.lightRadius = 160
Definition.sprite = { group = "Other/Intro", name = "sFlare", size = 8 }
function Definition.update(item, world)
    item.sparkTimer = (item.sparkTimer or 0) + 1
    if world.game and item.sparkTimer % 2 == 1 then
        world.game.effects:add("teleport_spark", item.x, item.y)
    end
end
return Definition
