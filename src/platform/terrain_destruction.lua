local Definitions = require("src.platform.objects")
local Tiles = require("src.platform.tiles.types")
local Terrain = {}
function Terrain.update(game)
    local events = game.world.destructions or {}
    game.world.destructions = {}
    for _, event in ipairs(events) do
        local x, y = event.pixelX or (event.x+0.5)*16, event.pixelY or (event.y+0.5)*16
        local definition = event.entity and (Definitions[event.entity.kind] or Tiles[event.entity.kind])
            or event.tile and Tiles[event.tile.kind]
        game.effects:terrainBreak(x, y, 16, event.entity or event.tile)
        if definition and definition.onDestroyed then definition.onDestroyed(game, event, x, y) end
        for _, lamp in ipairs(game.level.entities) do
            if (not definition or definition.dropsSupportedLamp)
                and (lamp.kind == "lamp" or lamp.kind == "lamp_red") and not lamp.destroyed
                and lamp.x == event.x and lamp.y == event.y+1 then
                lamp.destroyed = true
                game:spawnEntity(lamp.kind == "lamp_red" and "lamp_red_item" or "lamp_item",
                    lamp.x*16+8, lamp.y*16+12)
            end
        end
    end
end
return Terrain
