local Creature = require("src.platform.creature")
local Item = require("src.platform.item")
local Player = require("src.platform.player")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local World = require("src.platform.world")

local Test = {}

local CREATURES = {
    "caveman", "skeleton", "ghost", "giant_spider", "damsel", "shopkeeper",
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

end

return Test
