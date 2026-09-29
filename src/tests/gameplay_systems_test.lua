local Creature = require("src.platform.creature")
local Item = require("src.platform.item")
local Player = require("src.platform.player")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local SpecialGeneration = require("src.world.special_generation")
local World = require("src.platform.world")

local Test = {}

local CREATURES = {
    "caveman", "skeleton", "zombie", "hawkman", "yeti", "frog", "fire_frog",
    "vampire", "ufo", "piranha", "dead_fish", "monkey", "mantrap",
    "alien", "ghost", "magma_man", "jaws", "yeti_king",
    "giant_spider", "tomb_lord", "alien_boss", "olmec", "damsel", "shopkeeper",
    "worshipper", "tunnel_man",
}

function Test.run()
    local run = RunState.new(1234)
    local player = Player.new(64, 64)
    run.money = 1000
    run.bombs = 7
    run.equipment.jetpack = true
    run:applyToPlayer(player)
    assert(player.health == 4 and player.equipment.jetpack,
        "Run state must restore health and equipment")
    player.health = 2
    run:capturePlayer(player)
    assert(run.health == 2 and run.bombs == 7, "Run resources must survive player capture")

    assert(Item.collect("ruby_big", run, player) and run.money == 3000,
        "Treasure must add its original cash value")
    Item.collect("spring_shoes", run, player)
    assert(run.equipment.spring_shoes and player.equipment.spring_shoes,
        "Equipment pickup must affect both the run and live player")
    Item.collect("bomb_bag", run, player)
    assert(run.bombs == 10, "Bomb bags must add three bombs")

    for _, kind in ipairs(CREATURES) do
        assert(Creature.supports(kind), "Missing live creature implementation for " .. kind)
    end

    local world = World.new(20, 20, 16)
    world:fill("solid", 0, 10, 20, 1)
    local target = Creature.new({ kind = "caveman", x = 6, y = 9, properties = {} },
        { width = 16, height = 16, originX = 0, originY = 0 })
    local projectiles = ProjectileSystem.new(world)
    projectiles:spawn("bullet", target.x - 12, target.y - 8, 12, 0, player,
        { damage = 2, life = 5 })
    projectiles:update({ target }, player)
    assert(target.hp == 1, "Projectile damage must reach live enemies")

    local interiorKinds = { "black_market", "city_of_gold", "alien_craft", "yeti_lair", "moai" }
    for _, kind in ipairs(interiorKinds) do
        local level = SpecialGeneration.interior(kind, 99)
        assert(level.special == kind and level.entrance and level.exit,
            "Special interior is not playable: " .. kind)
        assert(#level.entities >= 3, "Special interior is empty: " .. kind)
        if kind == "black_market" then
            local expected = {
                { 2, 4, 4, 2 }, { 2, 4, 4, 2 }, { 2, 4, 5, 4 }, { 3, 1, 1, 3 },
            }
            for y = 1, 4 do for x = 1, 4 do
                assert(level.roomPath[y][x] == expected[y][x],
                    "Black Market room path differs from scrLevelGen.gml")
            end end
        elseif kind == "city_of_gold" then
            assert(level.cityOfGold, "City of Gold generation flag was lost")
        elseif kind == "alien_craft" then
            assert(level.alienCraft, "Alien Craft room strip was not generated")
        elseif kind == "yeti_lair" then
            assert(level.yetiLair, "Yeti Lair generation flag was lost")
        end
    end

    local probe = {
        area = "jungle", seed = 1234, absoluteLevel = run.blackMarketLevel,
        levelNumber = run.blackMarketLevel - 4, width = 12, height = 12,
        entities = {}, tiles = {},
    }
    for y = 0, 11 do
        probe.tiles[y + 1] = {}
        for x = 0, 11 do
            probe.tiles[y + 1][x + 1] = { kind = y == 10 and "solid" or "empty" }
        end
    end
    run.equipment.udjat_eye = true
    SpecialGeneration.apply(probe, run)
    assert(probe.blackMarket and #probe.specialEntrances == 1,
        "Udjat Eye must reveal the run's Black Market entrance")
end

return Test
