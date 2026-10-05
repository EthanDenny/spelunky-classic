local Definition = require("src.platform.item_traits").carry({ heavy = true,
    gravity = 0.2, bounds = { 6, 0, 8 }, action = "open", container = { mode = "flare_crate", effect = "smoke" } })
local Assets = require("src.platform.object_assets")
Definition.depth, Definition.lightRadius = 900, 160
Definition.sprite = { group = "Items/Other", name = "sFlareCrate", size = 16 }
function Definition.container.roll(random)
    local flares = {}
    for _ = 1, 3 do
        flares[#flares+1] = { kind = "flare", vx = random:random(0,3)-random:random(0,3),
            vy = -random:random(1,3) }
    end
    return flares
end
function Definition.update(item, world)
    item.spriteFrame = (item.spriteFrame or 0)+0.2
    item.sparkTimer = (item.sparkTimer or 0)+1
    if world.game and item.sparkTimer % 2 == 1 then
        local random = world.game.effects.random
        world.game.effects:add("teleport_spark", item.x+random:random(0,3)-random:random(0,3),
            item.y-4+random:random(0,3)-random:random(0,3))
    end
end
function Definition.itemImage(_, item)
    return Assets.frame("Items/Other", "sFlareCrate", 3, item.spriteFrame)
end
function Definition.entityImage(_, tick)
    return Assets.frame("Items/Other", "sFlareCrate", 3, (tick or 0)*0.2)
end
function Definition.collisionSprite(item)
    return "sFlareCrate", item.spriteFrame or 0, item.x, item.y, false
end
return Definition
