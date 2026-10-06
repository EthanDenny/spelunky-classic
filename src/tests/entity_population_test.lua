local MinesGenerator = require("src.world.mines_generator")
local EntityGenerator = require("src.world.entity_generator")
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
    kali_head = true,
    worshipper = true,
    hidden_sapphire = true,
    hidden_emerald = true,
    hidden_ruby = true,
    hidden_item = true,
}

local function assertAltarDoesNotFaceArrowTrap()
    local level = {
        width = 42,
        height = 34,
        levelNumber = 1,
        startRoomX = 0,
        startRoomY = 0,
        roomPath = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
        entrance = { x = 1, y = 1 },
        entities = { { kind = "altar_left", x = 12, y = 10 } },
        tiles = {},
    }
    for y = 1, level.height do
        level.tiles[y] = {}
        for x = 1, level.width do level.tiles[y][x] = { kind = "empty" } end
    end
    level.tiles[11][10] = { kind = "brick" }
    level.tiles[11][11] = { kind = "block" }
    local rng = { integer = function(_, minimum) return minimum end }
    EntityGenerator.populate(level, rng)
    for _, entity in ipairs(level.entities) do
        assert(entity.kind ~= "arrow_trap_right",
            "Arrow trap must not face the solid idol altar")
    end
end

local function assertCrowdedProgressionPlacement()
    -- No ordinary chest location clears the entrance radius, and the only
    -- treasure is buried. The exit must still receive a usable chest and key.
    local level = {
        width = 5, height = 5, levelNumber = 4,
        startRoomX = 0, startRoomY = 0,
        roomPath = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
        entrance = { x = 2, y = 1 }, exit = { x = 2, y = 3 },
        entities = {
            { kind = "ruby_big", x = 1.5, y = 1.5 },
            { kind = "entrance", x = 2, y = 1 },
            { kind = "exit", x = 2, y = 3 },
        }, tiles = {},
    }
    for y = 1, level.height do
        level.tiles[y] = {}
        for x = 1, level.width do level.tiles[y][x] = { kind = "empty" } end
    end
    level.tiles[2][2] = { kind = "brick" }
    level.tiles[5][3] = { kind = "brick" }
    local rng = { integer = function(_, _, maximum) return maximum end }
    EntityGenerator.populate(level, rng)
    local chests, keys = 0, 0
    for _, entity in ipairs(level.entities) do
        if entity.kind == "locked_chest" or entity.kind == "key" then
            assert(entity.x == 2.5 and entity.y == 3.5,
                "Fallback progression items must occupy the clear exit cell")
            if entity.kind == "locked_chest" then chests = chests + 1
            else keys = keys + 1 end
        end
    end
    assert(chests == 1 and keys == 1,
        "A crowded level without exposed treasure must still generate the Udjat pair")
    assert(level.entities[1].kind == "ruby_big", "A buried gem must not become an inaccessible key")
end

function Test.run()
    assertAltarDoesNotFaceArrowTrap()
    assertCrowdedProgressionPlacement()
    local lamps, scarabs, litTraps = 0, 0, 0
    for seed = 1, 48 do
        local level = MinesGenerator.generate(seed, { levelNumber = 1, forceDark = true })
        assert(level.dark, "The lighting playtest must be able to generate dark 1-1")
        local world = require("src.platform.generated_world").fromLevel(level)
        local entrance, crate = level.entrance
        for _, entity in ipairs(level.entities) do
            if entity.kind == "flare_crate" then
                assert(not crate, "Dark levels get one entrance flare crate")
                crate = entity
            elseif entity.kind == "lamp" or entity.kind == "scarab" then
                local parentY = entity.y-1
                local roomX, roomY = math.floor((entity.x-1)/10), math.floor((parentY-2)/8)
                assert(level.symbols[entity.y+1][entity.x+1] == "l" or parentY > 1 and parentY < level.height-4
                    and (roomX ~= level.startRoomX or roomY ~= level.startRoomY),
                    "Dark ceiling spawns must obey the source top, bottom and entrance-room exclusions")
                if entity.kind == "lamp" then lamps = lamps+1 else scarabs = scarabs+1 end
            elseif entity.kind == "arrow_trap_left_lit" or entity.kind == "arrow_trap_right_lit" then
                litTraps = litTraps+1
            else
                assert(entity.kind ~= "arrow_trap_left" and entity.kind ~= "arrow_trap_right",
                    "Dark Mines must generate lit arrow traps")
            end
        end
        local x, y = entrance.x*16, entrance.y*16
        local offset = not world:solidAtPoint(x-16, y) and -16
            or not world:solidAtPoint(x+16, y) and 16 or 0
        assert(crate and crate.x*16 == x+offset+8 and crate.y*16 == y+8,
            "The flare crate uses the first clear entrance side, falling back to the entrance itself")
    end
    assert(lamps > 0 and scarabs > 0 and litTraps > 0, "Dark fixtures must exercise all dark Mines spawns")
    local foundShopkeeper = false
    local foundKissingShop, foundWildDamsel = false, false
    for depth = 1, 4 do
        local foundEnemy = false
        local foundLoot = false

        for seed = 1, 48 do
            local level = MinesGenerator.generate(seed, { levelNumber = depth })
            local players = 0
            local kissingShop, damsels, shopDamsels = false, 0, 0
            for _, entity in ipairs(level.entities) do
                assert(entity.kind ~= "skeleton",
                    "Generated bone piles must stay inert until fake bones awaken")
                if entity.kind == "player" then players = players + 1 end
                foundEnemy = foundEnemy or ENEMIES[entity.kind] or false
                foundLoot = foundLoot or LOOT[entity.kind] or false
                foundShopkeeper = foundShopkeeper or entity.kind == "shopkeeper"
                if entity.kind == "shopkeeper" and entity.properties.shopType == "Kissing" then
                    kissingShop = true
                elseif entity.kind == "damsel" then
                    damsels = damsels + 1
                    if entity.properties.forSale then shopDamsels = shopDamsels + 1
                    else foundWildDamsel = true end
                end
                assert(SpriteData[entity.kind] or SPECIAL_RENDERERS[entity.kind],
                    "Mines entity has no original sprite mapping: " .. entity.kind)
            end
            assert(players == 1, "Mines must place exactly one player at its entrance")
            if kissingShop then
                foundKissingShop = true
                assert(damsels == 1 and shopDamsels == 1,
                    "Kissing-shop levels must have only the shop's damsel (seed " .. seed .. ")")
            end
        end

        assert(foundEnemy, "Mines sample produced no enemies at depth " .. depth)
        assert(foundLoot, "Mines sample produced no visible loot at depth " .. depth)
    end
    assert(foundShopkeeper, "Mines sample produced no shopkeeper")
    assert(foundKissingShop, "Mines sample must exercise kissing shops")
    assert(foundWildDamsel, "Levels without kissing shops must still generate wild damsels")
end

return Test
