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
        { "treasure stays above a blocked diagonal corner until the gap opens", function()
            for _, treasure in ipairs({
                { "gold_chunk", 2, 2, 100 }, { "gold_bar", 4, 4, 500 },
                { "gold_bars", 7, 8, 1000 }, { "ruby", 2, 2, 400 },
                { "ruby_big", 4, 4, 1600 },
            }) do
                for _, side in ipairs({ -1, 1 }) do
                    local game = fixture()
                    local lowerTile = side == 1 and 5 or 4
                    game.world:set("solid", side == 1 and 4 or 5, 5)
                    game.world:set("solid", lowerTile, 6)
                    game.player.x = 80-side*5
                    local pickup = game:spawnEntity(treasure[1], 80+side*treasure[2], 96-treasure[3])
                    for tick = 1, 20 do
                        game.world.time = tick
                        pickup:update(game.world, game.player)
                        game:checkCollectibles()
                        assert(pickup.alive and game.run.pendingMoney == 0,
                            treasure[1] .. " must not collect through the closed corner, side " .. side)
                    end
                    game.world:remove("solid", lowerTile, 6)
                    for tick = 21, 40 do
                        game.world.time = tick
                        pickup:update(game.world, game.player)
                        game:checkCollectibles()
                    end
                    assert(not pickup.alive and game.run.pendingMoney == treasure[4],
                        treasure[1] .. " must collect once it falls into reach through the opened corner")
                end
            end
        end },
        { "gold collects on its sprite pixels rather than its movement bounds", function()
            for _, gold in ipairs({ { "gold_bar", 114, 500 }, { "gold_bars", 115, 1000 } }) do
                local game = fixture()
                local pickup = game:spawnEntity(gold[1], 80, gold[2])
                game:checkCollectibles()
                assert(pickup.alive and game.run.pendingMoney == 0,
                    gold[1] .. " transparent pixels above the gold must not collect")
                game.player.y = game.player.y+1
                game:checkCollectibles()
                assert(not pickup.alive and game.run.pendingMoney == gold[3],
                    gold[1] .. " first opaque row must still collect")
            end
            local game = fixture()
            game:spawnEntity("gold_bars", 96, 104)
            game:checkCollectibles()
            assert(game.run.pendingMoney == 1000, "The gold pile's leftmost sprite pixel is collectible")
        end },
        { "Kapala collects nine mature droplets rather than enemy deaths", function()
            local game = fixture()
            game.player.equipment.kapala = true
            for _ = 1, 9 do game.effects:add("blood", 80, 104) end
            game.effects:collectBlood(game.player, game.run)
            assert(game.player.health == 4 and game.run.blood == 0)
            for _, blood in ipairs(game.effects.particles) do blood.age = 5 end
            game.effects:collectBlood(game.player, game.run)
            local sparks, hearts = 0, 0
            for _, effect in ipairs(game.effects.particles) do
                if effect.kind == "blood_spark" then sparks = sparks+1 end
                if effect.kind == "heart" then hearts = hearts+1 end
            end
            assert(game.player.health == 5 and game.run.blood == 0 and sparks == 9 and hearts == 1)
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
            assert(not damsel.alive and damsel.held and game.heldNpc == damsel,
                "oExplosion does not release a carried damsel")
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
            assert(not body:damage(2, game.player.x, { kind = "whip", weapon = "machete", phase = "front" })
                and body.hp == 2, "Machete whip collisions retain the caveman's stunned immunity")
        end },
        { "giant spider death releases paste and scattered gems", function()
            local game = fixture()
            local spider = game:spawnEntity("giant_spider", 200, 96)
            spider:damage(100)
            game:simulationStepBody({})
            assert(game.items[1].kind == "paste" and game.items[1].y == 104
                and #game.collectibles >= 1 and #game.collectibles <= 3)
            for _, gem in ipairs(game.collectibles) do
                assert(gem.alive and gem.y == 102 and gem.vy < 0 and gem.pickupDelay > 0)
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
            ghost.x = game.player.x+1
            ghost:step(game.world, game.player, game)
            ghost:resolvePlayerContact(game.player, game.player.y, game)
            assert(game.player:isDead() and game.player.visible == false and not weapon.held
                and not game.heldItem and game.items[2].kind == "skull" and weapon.vx == 2,
                "Ghost turns change sprites, not its source RIGHT-facing drop impulse")
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
        { "enemy activation uses the source sprite anchor and asymmetric viewport bounds", function()
            local game = fixture()
            game.world.activeView = { x = 0, y = 0, width = 100, height = 120 }
            local caveman = game:spawnEntity("caveman", 112, 112)
            caveman.timer, caveman.sightTimer = 20, 5
            caveman:step(game.world, game.player, game)
            assert(caveman.timer == 20 and caveman.sightTimer == 5)
            caveman.x = 111
            caveman:step(game.world, game.player, game)
            assert(caveman.timer == 19)
        end },
        { "gem collection alarms advance while offscreen movement pauses", function()
            local game = fixture()
            game.world.activeView = { x = 0, y = 0, width = 100, height = 120 }
            local gem = game:spawnEntity("ruby_big", 160, 60)
            gem.vx = 4
            for _ = 1, 20 do gem:update(game.world, game.player) end
            assert(gem.pickupDelay == 0 and gem.x == 160)
        end },
        { "traps ignore ghosts and detect the late crouch-to-hang frame", function()
            local game = fixture()
            local entity = { kind = "arrow_trap_right", x = 2, y = 3 }
            game.level.entities = { entity }
            game.world:set("solid", 2, 3, entity)
            game.traps = Traps.new(game.world, game.level)
            local ghost = game:spawnEntity("ghost", 80, 64)
            ghost.vx = 1
            game.traps:update(game.player, { ghost }, {})
            assert(not game.traps.traps[1].fired, "oGhost is not an oEnemy sensor target")
            game.player.x, game.player.y = 80, 56
            game.player.spriteName, game.player.animationFrame = "sDuckToHangL", 7
            game.player.vx, game.player.vy = 0, 0
            game.traps:update(game.player, {}, {})
            assert(game.traps.traps[1].fired)
        end },
        { "lighting uses the lamp anchor and selects the nearest explosion before its frame", function()
            local game = fixture()
            local Lighting = require("src.platform.lighting")
            game.level.entities = { { kind = "lamp", x = 5, y = 6 } }
            game.player.x, game.player.y = 80, 96
            assert(Lighting.darkness(game) == 0)
            game.level.entities = {}
            game.tools.explosions = {
                { x = 100, y = 96, age = 10, alive = true },
                { x = 120, y = 96, age = 3, alive = true },
            }
            assert(math.abs(Lighting.darkness(game)-0.625) < 0.001)
        end },
        { "giant spiders retain front-hit cooldowns and inherited back-whip damage", function()
            local game = fixture()
            local spider = game:spawnEntity("giant_spider", 240, 64)
            spider:step(game.world, game.player, game)
            assert(spider.state ~= "hang")
            assert(not spider:damage(1, 200, { kind = "item", vx = 4, vy = 0 }))
            for _ = 1, 10 do spider:step(game.world, game.player, game) end
            assert(spider:damage(1, 200, { kind = "item", vx = 4, vy = 0 }))
            assert(not spider:damage(1, 200, { kind = "item", vx = 4, vy = 0 }))
            assert(not spider:damage(2, 200, { kind = "whip", phase = "front" }))
            local hp = spider.hp
            assert(spider:damage(2, 200, { kind = "whip", phase = "back" }) and spider.hp == hp-2,
                "oWhipPre inherits damage while oWhip respects the giant's hit cooldown")
        end },
        { "skeleton death drops its skull at the source center", function()
            local game = fixture()
            local skeleton = game:spawnEntity("skeleton", 160, 104)
            skeleton:damage(10)
            skeleton.spec.onDeath(skeleton, game)
            assert(game.items[1].kind == "skull" and game.items[1].y == 96)
        end },
        { "stomps reset fall accumulation and preserve actor-specific bounce", function()
            local game = fixture()
            local caveman = game:spawnEntity("caveman", 160, 112)
            game.player.x, game.player.y, game.player.vy, game.player.fallTimer = 160, 96, 4, 32
            assert(caveman:resolvePlayerContact(game.player, 90, game) == "stomp")
            assert(caveman.hp == 0 and game.player.fallTimer == 0 and game.player.vy == -6)
            local spider = game:spawnEntity("giant_spider", 240, 112)
            spider.state, spider.height = "idle", 32
            game.player.x, game.player.y, game.player.vy, game.player.fallTimer = 240, 96, 4, 0
            assert(spider:resolvePlayerContact(game.player, 90, game) == "stomp")
            assert(math.abs(game.player.vy+6.8) < 0.001)
        end },
        { "only rubble and detritus inherit their source viewport destruction", function()
            local game = fixture()
            game.world.activeView = { x = 0, y = 0, width = 100, height = 120 }
            local rubble = game.effects:add("rubble", 125, 40)
            local spark = game.effects:add("teleport_spark", 125, 40)
            local blood = game.effects:add("blood", 110, 40)
            game.effects:update(game.world)
            local alive = {}
            for _, effect in ipairs(game.effects.particles) do alive[effect] = true end
            assert(alive[rubble] and alive[spark] and not alive[blood])
        end },
        { "skeletons face the player when spawned on either side", function()
            local game = fixture()
            local left = game:spawnEntity("skeleton", 40, 104)
            local right = game:spawnEntity("skeleton", 120, 104)
            assert(left.facing == 1 and right.facing == -1)
        end },
        { "scarabs emit collection sparks and participate in combat", function()
            local game = fixture()
            local collectible = game:spawnEntity("scarab", 80, 104)
            game:checkCollectibles()
            assert(not collectible.alive and #game.effects.particles == 3)
            local target = game:spawnEntity("scarab", game.player.x+16, game.player.y)
            game.player.facing, game.player.whipping, game.player.animationFrame = 1, true, 5
            game:checkWhip()
            assert(not target.alive and #game.effects.particles == 9,
                "A bloodless scarab produces six death sparks and no whip blood")
            local blastTarget = game:spawnEntity("scarab", 240, 64)
            game.tools:explode(240, 64)
            game:simulationStepBody({})
            assert(not blastTarget.alive)
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
