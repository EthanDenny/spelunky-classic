-- Construct and register placed entities or bodies released during play.
local Enemy = require("src.platform.enemy")
local Creature = require("src.platform.creature")
local Item = require("src.platform.item")
local Treasure = require("src.platform.treasure")
local dynamicEnemies = { snake = true, bat = true, spider = true }
local Factory = {}

local function category(kind, placed)
    if not placed and Item.isCarryable(kind) then return "items" end
    if dynamicEnemies[kind] or Creature.supports(kind) then return "enemies" end
    if Item.isCarryable(kind) then return "items" end
    if Item.isCollectible(kind) then return "collectibles" end
end

function Factory.create(game, entity, options)
    local group = category(entity.kind, options.placed)
    if not group then return nil end
    local metadata
    if group == "items" or group == "enemies" and not dynamicEnemies[entity.kind] then
        local sprite = game.renderer.entitySprites[entity.kind]
        metadata = sprite and sprite.metadata
    end
    local body
    if group == "items" then body = Item.new(entity, metadata)
    elseif group == "collectibles" then body = Treasure.new(entity, not options.placed, game)
    elseif dynamicEnemies[entity.kind] then
        body = Enemy.new(entity.kind, options.x or entity.x*16+8, options.y or entity.y*16+16,
            { seed = options.seed or game.seed+#game.enemies, hanging = options.placed and entity.kind ~= "snake" or false })
    else
        body = Creature.new(entity, metadata, {
            seed = options.seed or game.seed+#game.enemies,
            angry = options.placed and entity.kind == "shopkeeper" and game.run.shopkeeperAnger > 0,
        })
    end
    if not options.placed then
        body.x, body.y = options.x, options.y
        if group == "collectibles" then body:syncEntity() end
    end
    if body.spec and body.spec.facePlayerOnSpawn then
        body.spec.facePlayerOnSpawn(body, game.player, entity.properties and entity.properties.facing)
    end
    body.sounds = game.sounds
    if body.spec and body.spec.createSound and game.sounds then game.sounds:play(body.spec.createSound) end
    game[group][#game[group]+1] = body
    return body
end

return Factory
