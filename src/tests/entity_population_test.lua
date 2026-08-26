local MinesGenerator = require("src.world.mines_generator")
local ClassicAreaGenerator = require("src.world.classic_area_generator")
local SpriteData = require("src.world.original_entity_sprites")

local Test = {}

local ENEMIES = {
    bat = true, spider = true, giant_spider = true, snake = true, caveman = true,
    mantrap = true, frog = true, fire_frog = true, zombie = true, vampire = true,
    monkey = true, piranha = true, dead_fish = true, ufo = true, yeti = true,
    scarab = true, hawkman = true, tomb_lord = true,
}

local LOOT = {
    rock = true, jar = true, crate = true, chest = true, damsel = true,
    gold_bar = true, gold_bars = true, emerald_big = true, sapphire_big = true,
    ruby_big = true, bones = true, skeleton = true,
}

local SPECIAL_RENDERERS = {
    sacrifice_altar = true,
    worshipper = true,
    hidden_sapphire = true,
    hidden_emerald = true,
    hidden_ruby = true,
    hidden_item = true,
}

local function generate(area, seed)
    if area == "mines" then return MinesGenerator.generate(seed, { levelNumber = 4 }) end
    return ClassicAreaGenerator.generate(area, seed, { levelNumber = 1 })
end

function Test.run()
    for _, area in ipairs({ "mines", "jungle", "ice", "temple", "olmec" }) do
        local foundEnemy = area == "olmec"
        local foundLoot = false
        local foundShopkeeper = area == "olmec"

        for seed = 1, 48 do
            local level = generate(area, seed)
            local players = 0
            for _, entity in ipairs(level.entities) do
                if entity.kind == "player" then players = players + 1 end
                foundEnemy = foundEnemy or ENEMIES[entity.kind] or false
                foundLoot = foundLoot or LOOT[entity.kind] or false
                foundShopkeeper = foundShopkeeper or entity.kind == "shopkeeper"
                assert(SpriteData[entity.kind] or SPECIAL_RENDERERS[entity.kind],
                    area .. " entity has no original sprite mapping: " .. entity.kind)
            end
            assert(players == 1, area .. " must place exactly one player at its entrance")
        end

        assert(foundEnemy, area .. " sample produced no area enemies")
        assert(foundLoot, area .. " sample produced no visible loot")
        assert(foundShopkeeper, area .. " sample produced no shopkeeper")
    end
end

return Test
