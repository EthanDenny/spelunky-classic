local FullLevel = require("src.screens.full_level_playtest")
local RunState = require("src.game.run_state")
local Player = require("src.platform.player")
local ItemActions = require("src.platform.item_actions")
local Exit = require("src.platform.structures.exit")
local PushBlock = require("src.platform.tiles.push_block")
local Traps = require("src.platform.trap_system")
local Sight = require("src.platform.enemies.enemy_sight")
local Test = {}

function Test.run(app)
    local receipts, stops = {}, {}
    local newSource = love.audio.newSource
    local function observe(source, filename)
        return setmetatable({
            clone = function() return observe(source:clone(), filename) end,
            play = function() receipts[#receipts+1] = filename; return source:play() end,
            stop = function() stops[#stops+1] = filename; return source:stop() end,
        }, { __index = function(_, method)
            return function(_, ...) return source[method](source, ...) end
        end })
    end
    love.audio.newSource = function(path, ...)
        return observe(newSource(path, ...), path:match("([^/]+)%.wav$") or path)
    end
    local failures, count = {}, 0
    local function fixture()
        local game = FullLevel.new(app)
        game:loadAssets()
        game.seed, game.run = 17, RunState.new(17)
        game.level = { width = 42, height = 34, tileSize = 16, seed = 17,
            entrance = { x = 4, y = 6 }, exit = { x = 35, y = 6 }, absoluteLevel = 1,
            tiles = {}, entities = {}, decorations = {}, backdrops = {} }
        for y = 1, 34 do
            game.level.tiles[y] = {}
            for x = 1, 42 do game.level.tiles[y][x] = { kind = y == 8 and "brick" or "empty" } end
        end
        game:buildSimulation()
        receipts, stops = {}, {}
        return game
    end
    local function heard(expected)
        local actual = table.concat(receipts, ",")
        assert(actual == expected, "Expected sounds ["..expected.."], heard ["..actual.."]")
    end
    local function check(name, run)
        count = count+1
        local ok, err = pcall(function() run(fixture()) end)
        if not ok then failures[#failures+1] = name..": "..tostring(err) end
    end
    local function bullet(game, body, damage)
        game.projectiles:spawn("bullet", body.x-12, body.y-8, 12, 0, game.player,
            { damage = damage or 1 })
        game.projectiles:update(game:combatActors(), game.player, game.items)
    end
    local function swing(game, kind, target, stunned)
        local enemy = game:spawnEntity(target, game.player.x+16, game.player.y+8)
        if target == "scarab" then enemy.y = game.player.y end
        local initialHp = enemy.hp
        if stunned then enemy.stunned, enemy.state = 120, "stunned" end
        game.player.facing = 1
        if kind then
            local item = game:spawnEntity(kind, game.player.x, game.player.y)
            item:pickup(game.player, game.run)
            game.heldItem = item
            game:useHeldItem({})
        else game.player:startWhip() end
        for _ = 1, 30 do
            game.player:step(game.world, { suppressWhip = true })
            ItemActions.updateMelee(game)
            game:checkWhip()
            if not stunned and ((enemy.stunned or 0) > 0 or enemy.hp < initialHp or (enemy.cooldown or 0) > 0) then break end
        end
        return enemy
    end
    local ok, err = xpcall(function()
        for _, kind in ipairs({ "snake", "bat", "spider", "skeleton", "caveman", "shopkeeper" }) do
            check(kind.." stomp", function(game)
                local enemy = game:spawnEntity(kind, 160, 112)
                game.player.x, game.player.y, game.player.vy = 160, 99, 6
                game.player.state, game.player.fallTimer = "falling", 1
                if kind == "shopkeeper" then enemy.state = "attack" end
                assert(enemy:resolvePlayerContact(game.player, 90, game) == "stomp", "Fixture must land a stomp")
                heard("hit")
            end)
        end
        for _, weapon in ipairs({ "whip", "machete", "mattock" }) do
            check(weapon.." hit", function(game)
                local enemy = swing(game, weapon ~= "whip" and weapon or nil, "caveman")
                assert(enemy.stunned > 0, "Swing must hit the live caveman")
                heard("whip,hit")
            end)
        end
        check("scarab inherits enemy hit", function(game)
            local scarab = swing(game, nil, "scarab")
            assert(not scarab.alive, "Whip must kill the scarab")
            heard("whip,hit")
        end)
        for _, pickup in ipairs({ { "gold_bar", "coin" }, { "ruby_big", "gem" }, { "bomb_bag", "pickup" } }) do
            check(pickup[1].." pickup", function(game)
                local item = game:spawnEntity(pickup[1], game.player.x, game.player.y)
                for _ = 1, 20 do item:update(game.world, game.player, game) end
                game:checkCollectibles()
                assert(not item.alive, "Player must collect the pickup")
                heard(pickup[2])
            end)
        end
        check("rejected whip", function(game)
            swing(game, nil, "caveman", true)
            heard("whip")
        end)
        check("damsel whip", function(game) swing(game, nil, "damsel"); heard("whip,hit,damsel") end)
        for _, kind in ipairs({ "rock", "arrow", "jar", "skull" }) do
            check(kind.." impact", function(game)
                local enemy = game:spawnEntity("caveman", 160, 112)
                local item = game:spawnEntity(kind, 152, 104)
                item.vx, item.vy, item.safe = 6, 0, false
                item:update(game.world, game.player, game)
                assert(enemy.stunned > 0, "Thrown body must hit the caveman")
                heard((kind == "jar" or kind == "skull") and "hit,break" or "hit")
            end)
        end
        check("damsel bullet", function(game)
            local body = game:spawnEntity("damsel", 160, 112)
            bullet(game, body)
            assert(body.hp == 3, "Bullet must hit damsel")
            heard("damsel")
        end)
        for _, kind in ipairs({ "caveman", "shopkeeper" }) do
            check(kind.." death once", function(game)
                local body = game:spawnEntity(kind, 160, 112)
                bullet(game, body, 30)
                game:simulationStep({})
                game:simulationStep({})
                assert(body.deathCounted, "Death must pass through the gameplay death phase")
                heard("hit,cavemandie")
            end)
        end
        for _, kind in ipairs({ "caveman", "shopkeeper", "damsel" }) do
            check(kind.." crushed corpse", function(game)
                local body = game:spawnEntity(kind, 160, 112)
                bullet(game, body, 30)
                game:simulationStepBody({})
                assert(body.corpse and body.deathCounted, "First hit must leave a counted corpse")
                receipts = {}
                game.world:fill("solid", 8, 4, 7, 3)
                game:simulationStepBody({})
                game:simulationStepBody({})
                assert(not body.corpse, "A crushed corpse must be removed")
                heard(kind == "damsel" and "damsel" or "cavemandie")
            end)
        end
        check("enemy contact hurts once", function(game)
            game:spawnEntity("snake", game.player.x, 112)
            game:simulationStepBody({})
            game:simulationStepBody({})
            assert(game.player.health == 3, "Invincibility must reject the second contact")
            heard("hurt")
        end)
        check("player lethal bullet", function(game)
            game.player.health = 1
            game.projectiles:spawn("bullet", game.player.x-12, game.player.y, 12, 0, {}, { damage = 4 })
            game.projectiles:update({}, game.player, {})
            assert(game.player:isDead(), "Hostile bullet must kill player")
            heard("hurt,die")
        end)
        check("fall death", function(game)
            game.player.health, game.player.fallTimer = 1, 40
            game.player:landHard()
            heard("thud,die")
        end)
        check("spike death", function(game)
            game.player.vy, game.player.fallTimer = 3, 5
            game.spikeEntities = { { kind = "spikes", x = 4, y = 6 } }
            game:checkSpikes()
            assert(game.player:isDead(), "Spikes must impale player")
            heard("thud,die")
        end)
        for _, kind in ipairs({ "snake", "caveman" }) do
            check(kind.." spike silence", function(game)
                local body = game:spawnEntity(kind, 160, 110)
                body.vy = 3
                game.spikeEntities = { { kind = "spikes", x = 10, y = 6 } }
                game:simulationStepBody({})
                assert(not body.alive and body.impaled, "The enemy must be impaled")
                heard(kind == "caveman" and "cavemandie" or "")
            end)
        end
        check("ghost birth and kill", function(game)
            local ghost = game:spawnEntity("ghost", game.player.x, game.player.y)
            ghost:resolvePlayerContact(game.player, game.player.y, game)
            heard("ghost,die,ghost")
        end)
        check("caveman alert", function(game)
            local cave = game:spawnEntity("caveman", 104, 112)
            game.player.x, game.player.y = 76, 96
            cave.facing = -1
            Sight.spawn(game.world, cave)
            for _ = 1, 2 do
                game.world.time = game.world.time+1
                Sight.update(game.world, game.player, game.enemies, game)
            end
            assert(cave.justAlerted, "Sight must alert the caveman: "..tostring(cave.state))
            heard("alert")
        end)
        for _, kind in ipairs({ "crate", "flare_crate", "chest" }) do
            check(kind.." opens", function(game)
                game.effects.random:setSeed(101)
                local item = game:spawnEntity(kind, game.player.x, game.player.y)
                item:pickup(game.player, game.run)
                game.heldItem = item
                assert(game:useHeldItem({ up = true }), "Container action must succeed")
                heard(kind == "chest" and "chestopen" or "pickup")
            end)
        end
        check("exit steps", function(game)
            game.player.x, game.player.y = 568, 104
            assert(Exit.begin(game), "Player must enter the exit")
            heard("steps")
        end)
        check("push and landing", function(game)
            local block = { x = 120, y = 96, width = 16, height = 16, moveable = true, falling = false, vy = 0 }
            game.world.dynamicSolids[1] = block
            assert(game.world:tryPush(game.player, 1, block))
            assert(game.world:tryPush(game.player, 1, block))
            game.world:set("solid", 9, 6)
            block.x = 128
            assert(not game.world:tryPush(game.player, 1, block), "Wall must prevent pushing")
            heard("push")
            block.x, block.y, block.falling, block.vy = 120, 94, true, 3
            PushBlock.update(game.world, block)
            heard("push,thud")
        end)
        check("jetpack delayed after release", function(game)
            local p = game.player
            p.x, p.y, p.state, p.equipment.jetpack, p.jetpackFuel, p.jumpRearmed = 200, 64, "falling", true, 50, true
            p:step(game.world, { jump = true })
            p:step(game.world, {})
            p:step(game.world, {})
            heard("")
            p:step(game.world, {})
            heard("jetpack")
        end)
        check("climb delayed and alternating", function(game)
            game.world:fill("ladder", 4, 1, 1, 6)
            game.player.x, game.player.y, game.player.state = 72, 80, "climbing"
            game.player:step(game.world, { up = true })
            for _ = 1, 7 do game.player:step(game.world, {}) end
            heard("")
            game.player:step(game.world, {})
            heard("climb2")
            game.player:step(game.world, { up = true })
            for _ = 1, 8 do game.player:step(game.world, {}) end
            heard("climb2,climb1")
        end)
        check("arrow trap fires once", function(game)
            local level = { entities = { { kind = "arrow_trap_right", x = 8, y = 5 } } }
            local traps = Traps.new(game.world, level)
            traps:loadAssets()
            traps.sounds = game.sounds
            local target = game:spawnEntity("rock", 160, 84)
            target.vx = 1
            traps:update(game.player, {}, { target })
            traps:update(game.player, {}, { target })
            assert(traps.traps[1].fired and #traps.projectiles == 1, "The rock must trigger one arrow")
            heard("arrowtrap")
        end)
        check("idol trap activation", function(game)
            local traps = Traps.new(game.world, { entities = { { kind = "giant_tiki_head", x = 12, y = 1 } } })
            traps:loadAssets()
            traps.sounds = game.sounds
            traps:triggerIdol(game.player)
            for _ = 1, 100 do traps:update(game.player, {}, {}) end
            assert(#traps.boulders == 1, "The idol trap must release its boulder")
            heard("thump")
        end)
        check("boulder crush", function(game)
            game.world:set("solid", 7, 4)
            game.level.tiles[5][8] = { kind = "brick" }
            game.traps:updateBoulder({ x = 96, y = 72, vx = 4.5, vy = 0, alive = true, bounced = true },
                game.player, {})
            assert(not game.world:has("solid", 7, 4), "Boulder must crush the brick")
            heard("crunch")
        end)
        check("rope impact once", function(game)
            local snake = game:spawnEntity("snake", 72, 80)
            local rope = game.tools:throwRope(game.player, {})
            game.tools:update(game.player, game.enemies, game.items)
            game.tools:update(game.player, game.enemies, game.items)
            assert(not snake.alive and rope.hitEnemies[snake], "The flying rope must hit the snake")
            heard("hit")
        end)
        check("stunned caveman item silent", function(game)
            local cave = game:spawnEntity("caveman", 160, 112)
            cave.stunned, cave.state = 120, "stunned"
            local rock = game:spawnEntity("rock", 152, 104)
            rock.vx = 6
            rock:update(game.world, game.player, game)
            assert(cave.vx > 0, "The rock must transfer momentum to the stunned caveman")
            heard("")
        end)
        check("damsel pot silent hit", function(game)
            local damsel = game:spawnEntity("damsel", 160, 112)
            local pot = game:spawnEntity("jar", 152, 104)
            pot.vx = 6
            pot:update(game.world, game.player, game)
            assert(damsel.hp == 3 and pot.opened, "The pot must hit and break on the damsel")
            heard("break")
        end)
        check("bat alert", function(game)
            local bat = game:spawnEntity("bat", 160, 80)
            bat.state = "HANG"
            game:simulationStepBody({})
            assert(bat.state == "ATTACK", "The unsupported bat must wake")
            heard("bat")
        end)
        check("giant spider conversion", function(game)
            local spider = game:spawnEntity("giant_spider", 160, 80)
            game:simulationStepBody({})
            assert(spider.state ~= "hang", "The unsupported giant spider must drop")
            heard("giantspider")
        end)
        check("giant spider bounce", function(game)
            local spider = game:spawnEntity("giant_spider", 160, 112)
            spider.state, spider.height, spider.vx, spider.vy = "bounce", 32, 0, 0
            game.player.x = 200
            game:simulationStepBody({})
            heard("spiderjump")
        end)
        check("explosion deaths", function(game)
            local snake = game:spawnEntity("snake", 160, 80)
            local skull = game:spawnEntity("skull", 160, 72)
            game.tools:explode(160, 72)
            game.tools:update(game.player, game.enemies, game.items)
            assert(not snake.alive and skull.opened, "Explosion must kill the snake and smash the skull")
            heard("explosion,break")
        end)
        for _, kind in ipairs({ "pistol", "shotgun", "web_cannon", "teleporter" }) do
            check(kind.." use", function(game)
                local item = game:spawnEntity(kind, game.player.x, game.player.y)
                item:pickup(game.player, game.run)
                game.heldItem = item
                game:useHeldItem({})
                heard(kind == "teleporter" and "teleport" or "shotgun")
            end)
        end
        check("damsel throw", function(game)
            local damsel = game:spawnEntity("damsel", game.player.x, game.player.y)
            assert(damsel:pickup(game.player))
            game.heldNpc = damsel
            game:handleActionPressed({})
            assert(not damsel.held, "Throw must release the damsel")
            heard("damsel")
        end)
        check("scenario sounds obey mute", function()
            local viewer = require("src.screens.enemy_ai").new(app)
            viewer:loadAssets()
            viewer:resetPage()
            local scenario = viewer.scenarios[2]
            local function stomp()
                scenario.enemy.x, scenario.enemy.y = 80, 160
                scenario.player.x, scenario.player.y, scenario.player.vy = 80, 147, 6
                assert(scenario.enemy:resolvePlayerContact(scenario.player, 135) == "stomp")
            end
            stomp()
            heard("")
            viewer:resetScenario(scenario)
            viewer:toggleSound()
            stomp()
            heard("hit")
            assert(viewer.sounds:isPlaying("hit"), "Unmuting must play a native voice")
            viewer:toggleSound()
            assert(not viewer.sounds:isPlaying("hit") and stops[#stops] == "hit",
                "Muting must stop the native voice immediately")
        end)
        check("scenario traps obey mute", function()
            local viewer = require("src.screens.enemy_ai").new(app)
            viewer:loadAssets()
            viewer:setPage(9)
            local scenario = viewer.scenarios[1]
            scenario.world:set("solid", 5, 8)
            for _ = 1, 140 do viewer:stepScenario(scenario) end
            assert(not scenario.world:has("solid", 5, 8), "The muted boulder replay must crush its wall")
            heard("")
        end)
        check("bow charge stops on fire", function(game)
            local bow = game:spawnEntity("bow", game.player.x, game.player.y)
            bow:pickup(game.player, game.run)
            game.heldItem = bow
            game:useHeldItem({})
            ItemActions.updateBow(game, {})
            heard("bowpull,arrowtrap")
            assert(table.concat(stops, ",") == "bowpull" and not game.sounds:isPlaying("bowpull"),
                "Firing must stop the real charging voice")
        end)
    end, debug.traceback)
    love.audio.newSource = newSource
    if not ok then error(err) end
    assert(#failures == 0, table.concat(failures, "\n"))
    print("Mines audio: "..count.." native sound-event cases passed")
end
return Test
