local MinesGenerator = require("src.world.mines_generator")
local SpriteData = require("src.world.original_entity_sprites")

local Test = {}

local ENEMIES = {
    bat = true, spider = true, giant_spider = true, snake = true, caveman = true,
    scarab = true,
}

local LOOT = {
    rock = true, jar = true, crate = true, chest = true, damsel = true,
    gold_bar = true, gold_bars = true, emerald_big = true, sapphire_big = true,
    ruby_big = true, bones = true, fake_bones = true,
}

local SPECIAL_RENDERERS = {
    sacrifice_altar = true,
    worshipper = true,
    hidden_sapphire = true,
    hidden_emerald = true,
    hidden_ruby = true,
    hidden_item = true,
}

function Test.run()
    local foundShopkeeper = false
    for depth = 1, 4 do
        local foundEnemy = false
        local foundLoot = false

        for seed = 1, 48 do
            local level = MinesGenerator.generate(seed, { levelNumber = depth })
            local players = 0
            for _, entity in ipairs(level.entities) do
                assert(entity.kind ~= "skeleton",
                    "Generated bone piles must stay inert until fake bones awaken")
                if entity.kind == "player" then players = players + 1 end
                foundEnemy = foundEnemy or ENEMIES[entity.kind] or false
                foundLoot = foundLoot or LOOT[entity.kind] or false
                foundShopkeeper = foundShopkeeper or entity.kind == "shopkeeper"
                assert(SpriteData[entity.kind] or SPECIAL_RENDERERS[entity.kind],
                    "Mines entity has no original sprite mapping: " .. entity.kind)
            end
            assert(players == 1, "Mines must place exactly one player at its entrance")
        end

        assert(foundEnemy, "Mines sample produced no enemies at depth " .. depth)
        assert(foundLoot, "Mines sample produced no visible loot at depth " .. depth)
    end
    assert(foundShopkeeper, "Mines sample produced no shopkeeper")
end

return Test
