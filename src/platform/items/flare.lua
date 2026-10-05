local Definition = require("src.platform.item_traits").carry()
Definition.depth = 30
Definition.lightRadius = 160
Definition.sprite = { group = "Other/Intro", name = "sFlare", size = 8 }
function Definition.update(item, world)
    item.spriteFrame = (item.spriteFrame or 0)+0.3
    item.sparkTimer = (item.sparkTimer or 0) + 1
    if world.game and item.sparkTimer % 2 == 1 then
        world.game.effects:add("teleport_spark", item.x+world.game.effects.random:random(0,3)-world.game.effects.random:random(0,3),
            item.y+world.game.effects.random:random(0,3)-world.game.effects.random:random(0,3))
    end
end
function Definition.itemImage(_, item)
    return require("src.platform.object_assets").frame("Other/Intro", "sFlare", 2, item.spriteFrame)
end
function Definition.collisionSprite(item)
    return "sFlare", item.spriteFrame or 0, item.x, item.y, false
end
return Definition
