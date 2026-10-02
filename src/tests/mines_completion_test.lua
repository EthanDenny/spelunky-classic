local FullLevel = require("src.screens.full_level_playtest")
local Player = require("src.platform.player")
local Run = require("src.game.run_state")
local World = require("src.platform.world")
local Effects = require("src.platform.effects")
local Traps = require("src.platform.trap_system")
local Projectiles = require("src.platform.projectile_system")
local Exit = require("src.platform.structures.exit")
local Tools = require("src.platform.tool_system")
local Controls = require("src.input.classic_controls")
local Test = {}
local function fixture()
    local game = FullLevel.new({ controls = Controls.fromContents(nil, nil) })
    game.seed, game.run = 17, Run.new(17)
    game.world = World.new(42, 34, 16)
    game.world:fill("solid", 0, 7, 42, 1)
    game.level = { absoluteLevel = 1, entities = {}, tiles = {}, decorations = {} }
    game.world.level = game.level
    game.player = Player.new(80, 104)
    game.player.state = Player.STATES.standing
    game.renderer, game.sounds = { entitySprites = {} }, { play = function() end }
    game.effects = Effects.new(17)
    game.tools = Tools.new(game.world)
    game.projectiles = Projectiles.new(game.world)
    game.traps = Traps.new(game.world, game.level)
    game.world.game, game.tools.game, game.traps.game = game, game, game
    return game
end
function Test.run()
    local cases = {
        { "free supplies collect on contact, paid stock does not", function()
            local game = fixture()
            for _, kind in ipairs({ "bomb_bag", "bomb_box", "rope_pile" }) do
                game:spawnEntity(kind, 80, 104)
            end
            local stock = game:spawnEntity("bomb_box", 80, 104, { forSale = true })
            game:checkCollectibles()
            assert(game.run.bombs == 19 and game.run.ropes == 7 and stock.alive)
        end },
        { "treasure uses creation alarms and counts cash after the delay", function()
            local game = fixture()
            local gold = game:spawnEntity("gold_bar", 80, 104)
            local ruby = game:spawnEntity("ruby_big", 80, 104)
            game:checkCollectibles()
            assert(not gold.alive and ruby.alive and game.run.money == 0,
                "Gold is immediately collectible; newly created gems and cash counting wait")
            for _ = 1, 20 do ruby:update(game.world) end
            game:checkCollectibles()
            for _ = 1, 41 do game.run:update() end
            assert(game.run.money == 100 and game.run.pendingMoney == 2000)
            game.run:flushMoney()
            assert(game.run.money == 2100 and game.run.pendingMoney == 0)
        end },
        { "Kapala collects nine mature droplets rather than enemy deaths", function()
            local game = fixture()
            game.player.equipment.kapala = true
            for _ = 1, 9 do game.effects:add("blood", 80, 104) end
            game.effects:collectBlood(game.player, game.run)
            assert(game.player.health == 4 and game.run.blood == 0)
            for _, blood in ipairs(game.effects.particles) do blood.age = 5 end
            game.effects:collectBlood(game.player, game.run)
            assert(game.player.health == 5 and game.run.blood == 0 and #game.effects.particles == 1 and game.effects.particles[1].kind == "heart")
            for _ = 1, 9 do
                local blood = game.tools.effects:add("blood", 80, 104)
                blood.age = 5
            end
            game:simulationStepBody({})
            assert(game.player.health == 6 and game.run.blood == 0,
                "Blood emitted by tools and explosions must fill the same Kapala")
        end },
        { "scarabs flee nearby players without falling as treasure", function()
            local game = fixture()
            local scarab = game:spawnEntity("scarab", 100, 60)
            scarab.counter = 1
            scarab:update(game.world, game.player)
            assert(scarab.y == 60 and scarab.vx > 0 and scarab.vy < 0)
            assert(math.abs(scarab.vx^2 + scarab.vy^2 - 16) < 0.001)
        end },
        { "smoke and sparks rise steadily while poofs keep their velocity", function()
            local game = fixture()
            local smoke = game.effects:add("smoke", 80, 60)
            local spark = game.effects:add("teleport_spark", 90, 60)
            local poof = game.effects:add("poof", 100, 60, 1, -2)
            for _ = 1, 5 do game.effects:update(game.world) end
            assert(math.abs(smoke.y-59.5)<0.001 and math.abs(spark.y-59.5)<0.001 and poof.y == 50)
        end },
        { "breaking gold bricks and lamp supports releases their contents once", function()
            local game = fixture()
            game.level.tiles[4] = { [6] = { kind = "brick", style = "brick_gold_big" } }
            game.world:set("solid", 5, 3)
            local lamp = { kind = "lamp", x = 5, y = 4 }
            game.level.entities[#game.level.entities+1] = lamp
            game.world:remove("solid", 5, 3)
            require("src.platform.terrain_destruction").update(game)
            assert(#game.collectibles == 4 and game.items[1].kind == "lamp_item" and lamp.destroyed)
            require("src.platform.terrain_destruction").update(game)
            assert(#game.collectibles == 4 and #game.items == 1)
            assert(game.level.tiles[4][6].kind == "empty")
        end },
        { "blasts catch late arrivals, chain bombs, break items and remove webs", function()
            local game = fixture()
            game.player.x = 16
            game.tools:explode(160, 64)
            game.tools:update(game.player, {}, {})
            local skull = game:spawnEntity("skull", 160, 64)
            local bomb = game.tools:spawnBomb(160, 64, { timer = 120 })
            local held = game:spawnEntity("rock", 160, 64)
            held.held, game.heldItem = true, held
            local damsel = game:spawnEntity("damsel", 160, 64)
            damsel.held, game.heldNpc = true, damsel
            game.world:set("web", 10, 4)
            game.tools:update(game.player, game.enemies, game.items)
            assert(not damsel.alive and not damsel.held and not game.heldNpc)
            assert(not skull.alive and bomb.timer >= 4 and bomb.timer <= 8
                and not held.held and not game.heldItem and not game.world:has("web", 10, 4))
        end },
        { "destroying an unfired trap releases its arrow without a blast", function()
            local game = fixture()
            local entity = { kind = "arrow_trap_right", x = 10, y = 4 }
            game.level.entities[#game.level.entities+1] = entity
            game.world:set("solid", 10, 4, entity)
            game.traps = Traps.new(game.world, game.level)
            game.traps.game = game
            game.world:remove("solid", 10, 4)
            game.traps:update(game.player, {}, {})
            assert(#game.items == 1 and game.items[1].kind == "arrow" and not game.traps.traps[1].alive)
        end },
        { "trap sensors detect even very slow treasure motion", function()
            local game = fixture()
            local entity = { kind = "arrow_trap_right", x = 2, y = 3 }
            game.level.entities[#game.level.entities+1] = entity
            game.world:set("solid", 2, 3, entity)
            game.traps = Traps.new(game.world, game.level)
            local gem = game:spawnEntity("ruby_big", 80, 56)
            gem.vy = 0.01
            game.traps:update(game.player, {}, {}, { gem })
            assert(game.traps.traps[1].fired)
        end },
        { "generated cavemen use the source facing and charge rules", function()
            local game = fixture()
            game.player.x = 160
            local caveman = game:spawnEntity("caveman", 80, 112)
            caveman.state, caveman.facing, caveman.sightTimer = "walk", 1, 0
            caveman:step(game.world, game.player, game)
            assert(caveman.state == "attack" and caveman.vx == 3)
        end },
        { "falling enemies impale and lodge without crediting a kill", function()
            local game = fixture()
            game.spikeEntities = { { kind = "spikes", x = 10, y = 6 } }
            local caveman = game:spawnEntity("caveman", 168, 100)
            caveman.vy = 3
            game:simulationStepBody({})
            assert(not caveman.alive and caveman.corpse and caveman.impaled and game.run.kills == 0)
        end },
        { "actors embedded in solid terrain die rather than remain stuck", function()
            local game = fixture()
            game.world:set("solid", 10, 5)
            local body = game:spawnEntity("caveman", 168, 96)
            game:simulationStepBody({})
            assert(not body.alive and not body.corpse and body.hp == 0)
        end },
        { "surviving enemy hits emit collectible blood", function()
            local game = fixture()
            local body = game:spawnEntity("caveman", game.player.x+16, game.player.y+8)
            game.player.facing, game.player.whipping, game.player.animationFrame = 1, true, 5
            game:checkWhip()
            assert(body.alive and body.hp == 2 and body.stunned > 0 and game.run.kills == 0)
            assert(#game.effects.particles == 1 and game.effects.particles[1].kind == "blood")
        end },
        { "giant spider death releases paste and scattered gems", function()
            local game = fixture()
            local spider = game:spawnEntity("giant_spider", 200, 96)
            spider:damage(100)
            game:simulationStepBody({})
            assert(game.items[1].kind == "paste" and #game.collectibles >= 1 and #game.collectibles <= 3)
            for _, gem in ipairs(game.collectibles) do
                assert(gem.alive and gem.vy < 0 and gem.pickupDelay > 0)
            end
            local count = #game.collectibles
            game:simulationStepBody({})
            assert(#game.collectibles == count)
        end },
        { "ghost contact drops equipment and finishes its death animation", function()
            local game = fixture()
            local weapon = game:spawnEntity("shotgun", 80, 104)
            weapon:pickup(game.player)
            game.heldItem = weapon
            local ghost = game:spawnEntity("ghost", 80, 104)
            ghost:resolvePlayerContact(game.player, game.player.y, game)
            assert(game.player:isDead() and game.player.visible == false and not weapon.held
                and not game.heldItem and game.items[2].kind == "skull")
            for _ = 1, 71 do ghost:step(game.world, game.player, game) end
            assert(not ghost.alive)
        end },
        { "ghosts convert big gems but leave small gems alone", function()
            local game = fixture()
            game:spawnEntity("ghost", 160, 64)
            local big = game:spawnEntity("ruby_big", 160, 56)
            local small = game:spawnEntity("ruby", 160, 56)
            game:simulationStepBody({})
            assert(not big.alive and small.alive and game.collectibles[3].kind == "diamond")
        end },
        { "the timed ghost starts at the view edge after the first Mines depth", function()
            local game = fixture()
            game.levelTime = 151
            game:simulationStepBody({})
            assert(not game.ghostSpawned)
            game.levelNumber = 2
            game:simulationStepBody({})
            assert(game.ghostSpawned and #game.enemies == 1)
            local ghost = game.enemies[1]
            assert(ghost.kind == "ghost" and ghost.x == game.cameraX-24)
        end },
        { "dark levels brighten near lamps and during explosions", function()
            local game = fixture()
            assert(require("src.platform.lighting").darkness(game) == 0.9)
            game:spawnEntity("lamp_item", 80, 104)
            assert(require("src.platform.lighting").darkness(game) == 0)
            game.items[1].alive = false
            game.tools:explode(80, 104)
            assert(require("src.platform.lighting").darkness(game) == 0)
        end },
        { "a normal whip pushes a damsel without taking a heart", function()
            local game = fixture()
            local body = game:spawnEntity("damsel", game.player.x+16, game.player.y+8)
            game.player.facing, game.player.whipping, game.player.animationFrame = 1, true, 5
            game:checkWhip()
            assert(body.hp == 4 and body.vy == -2 and body.stunned == 0)
        end },
        { "damsels wait in place and rescue themselves at the door", function()
            local game = fixture()
            game.level.exit = { x = 10, y = 6 }
            local damsel = game:spawnEntity("damsel", 168, 112)
            game:simulationStepBody({})
            assert(damsel.rescued and damsel.state == "exiting" and game.run.damsels == 1
                and game.player.health == 4)
            local bullet = game.projectiles:spawn("bullet", damsel.x-4, damsel.y-8, 4, 0, nil, { damage = 4 })
            game.projectiles:update(game.enemies, game.player, game.items)
            assert(bullet.alive and damsel.hp == 4, "Rescuing damsels let bullets pass through")
            for _ = 1, 34 do game:simulationStepBody({}) end
            assert(not damsel.alive and game.run.damsels == 1)
            local waiting = game:spawnEntity("damsel", 200, 112)
            for _ = 1, 10 do game:simulationStepBody({}) end
            assert(waiting.x == 200 and waiting.vx == 0 and not waiting.rescued)
        end },
        { "exit contact converts idols and the final exit completes after its animation", function()
            local game = fixture()
            game.levelNumber, game.level.exit = 4, { x = 4, y = 6 }
            game.player.x = 72
            local idol = game:spawnEntity("gold_idol", 72, 104)
            idol:pickup(game.player)
            game.heldItem = idol
            Exit.contact(game)
            assert(not idol.alive and not game.heldItem and game.run.pendingMoney == 5000)
            game.player.stunTimer = 10
            assert(not Exit.begin(game))
            game.player.stunTimer = 0
            assert(Exit.begin(game) and not game.completed and game.run.money == 5000)
            for _ = 1, 31 do game:simulationStepBody({}) end
            assert(not game.completed)
            game:simulationStepBody({})
            assert(game.completed)
        end },
    }
    local failures = {}
    for _, case in ipairs(cases) do
        local ok, err = pcall(case[2])
        if not ok then failures[#failures+1] = case[1] .. ": " .. tostring(err) end
    end
    assert(#failures == 0, table.concat(failures, "\n"))
    print("Mines completion checks passed: " .. #cases .. " scenarios")
end
return Test
