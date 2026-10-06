local Enemy = require("src.platform.enemy")
local Player = require("src.platform.player")
local World = require("src.platform.world")

local Test = {}

local function flatWorld()
    local world = World.new(20, 14, 16)
    world:fill("solid", 0, 10, 20, 4)
    return world
end

function Test.run(app)
    do
        local world = World.new(16, 14, 16)
        world:fill("solid", 5, 10, 4, 1)
        local snake = Enemy.new("snake", 5 * 16 + 8, 10 * 16,
            { facing = -1, seed = 7 })
        snake.random = function(_, maximum) return maximum end
        snake:setState(Enemy.STATES.walk)
        snake:step(world)
        snake:step(world)
        assert(snake.facing == 1,
            "A patrolling snake must turn before walking off a ledge")

        snake.x = 9 * 16 - snake:getCollisionHalfWidth()
        snake.facing = 1
        snake:step(world)
        assert(snake.facing == -1,
            "A patrolling snake must reverse when it reaches a wall or platform end")
    end

    do
        for _, wallSide in ipairs({ -1, 1 }) do
            local world = World.new(14, 9, 16)
            world:set("solid", 6, 7)
            world:set("solid", wallSide < 0 and 5 or 7, 6)
            local snake = Enemy.new("snake", 6 * 16 + 8, 7 * 16,
                { facing = wallSide, seed = 44 })
            snake.random = function(_, maximum) return maximum end
            snake:setState(Enemy.STATES.walk)
            snake:step(world)
            assert(snake.x == 6 * 16 + 8 and snake.vx == 0
                and snake.facing == -wallSide,
                "A snake between a wall and a drop must stop and face away from the wall")
        end
    end

    do
        local world = flatWorld()
        world:set("solid", 5, 4)
        local bat = Enemy.new("bat", 5 * 16 + 8, 5 * 16 + 16, { seed = 3 })
        local player = Player.new(bat.x, 10 * 16 - 8)
        player.state = Player.STATES.standing
        bat:step(world, player)
        assert(bat.state == Enemy.STATES.attack and bat.justAlerted,
            "A hanging bat must attack a living player below it within 90 pixels")
        local oldY = bat.y
        bat:step(world, player)
        assert(bat.y > oldY,
            "An attacking bat must steer toward a player below it")
    end

    do
        local world = World.new(42, 34, 16)
        world:set("solid", 13, 2)
        local bat = Enemy.new("bat", 229, 62, { seed = 3 })
        local player = Player.new(435, 152)
        player.state = Player.STATES.standing
        bat:setState(Enemy.STATES.attack)
        for _ = 1, 12 do
            bat:step(world, player)
            assert(bat.state == Enemy.STATES.attack and not bat.justAlerted,
                "A bat whose wing hits a ceiling without a solid center perch must not rehang and alert repeatedly")
        end
    end

    do
        local world = flatWorld()
        world:set("solid", 8, 4)
        local spider = Enemy.new("spider", 8 * 16 + 8, 5 * 16 + 16, { seed = 5 })
        local player = Player.new(spider.x, 10 * 16 - 8)
        player.state = Player.STATES.standing
        spider:step(world, player)
        assert(spider.state == Enemy.STATES.recover and spider.justAlerted,
            "A ceiling spider must drop when the player passes directly beneath it")
        local startY = spider.y
        for _ = 1, 45 do spider:step(world, player) end
        assert(spider.y > startY and spider.state ~= Enemy.STATES.hang,
            "A dropped spider must fall and enter its recovery or bouncing behavior")
    end

    do
        local world = World.new(12, 12, 16)
        world:set("solid", 5, 4)
        world:set("solid", 6, 5)
        local spider = Enemy.new("spider", 90, 96, { seed = 5 })
        assert(not world:collidesSolid(spider, spider.x, spider.y),
            "A hanging spider's wings must not collide with the neighboring brick")
        spider:setState(Enemy.STATES.recover)
        assert(world:collidesSolid(spider, spider.x, spider.y),
            "A dropped spider must use its wider active collision mask")
    end

    do
        local world = flatWorld()
        local enemy = Enemy.new("snake", 8 * 16, 10 * 16, { seed = 9 })
        local player = Player.new(enemy.x, 139)
        player.state = Player.STATES.falling
        player.vy = 3
        local result = enemy:resolvePlayerContact(player, 134)
        assert(result == "stomp" and not enemy.alive,
            "A descending player landing from above must stomp a one-HP enemy")
        assert(player.vy < 0 and player.state == Player.STATES.jumping,
            "A successful stomp must bounce the player upward")
    end

    do
        local enemy = Enemy.new("snake", 8 * 16, 10 * 16, { seed = 10 })
        local player = Player.new(enemy.x - 8, 10 * 16 - 8)
        player.state = Player.STATES.standing
        player.spriteName = "sStandLeft"
        local result = enemy:resolvePlayerContact(player, player.y)
        assert(result == "hurt" and player.health == 3 and player.invincibleTimer == 30,
            "Side contact must damage and briefly protect the player")
        assert(player.state == Player.STATES.standing and player.spriteName == "sStandLeft"
            and player.vy == 0 and player.stunTimer == 0 and player.vx < 0,
            "Snake contact must flash and push horizontally without a launch or stun pose")
        assert(enemy:resolvePlayerContact(player, player.y) == "invincible"
            and player.health == 3,
            "Contact during invincibility must not deal repeated damage")
        player:step(flatWorld(), {})
        assert(player.spriteName == "sStandLeft",
            "The player must keep the standing animation after snake contact")
    end

    do
        local viewer = app.screens.enemy_ai
        viewer:enter()
        assert(not viewer.soundEnabled and viewer.scenarios[2].player.whipSound == nil,
            "Scenario playback must start muted")
        viewer:draw()
        viewer:mousepressed(viewer.soundButton.x + 1, viewer.soundButton.y + 1, 1)
        assert(viewer.soundEnabled, "The header button must unmute scenarios")
        viewer:setPage(2)
        assert(viewer.soundEnabled and #viewer.scenarios == 3,
            "The sound setting must carry to the bat page and load its three scenarios")
        viewer:draw()
        viewer:mousepressed(viewer.soundButton.x + 1, viewer.soundButton.y + 1, 1)
        assert(not viewer.soundEnabled, "The header button must mute scenarios again")
        viewer:setPage(1)
        assert(#viewer.scenarios == 4, "The snake page must include the one-block replay")
        local sawTurn, sawContact, sawWhip = false, false, false
        for _ = 1, 300 do
            local patrol = viewer.scenarios[1]
            local previousFacing = patrol.enemy.facing
            viewer:update(1 / Enemy.TICK_RATE)
            assert(patrol.player == nil and patrol.enemy.x < 6 * 16,
                "The player-free patrol must keep the snake clear of its gap")
            if patrol.enemy.facing ~= previousFacing then sawTurn = true end
            local perched = viewer.scenarios[4].enemy
            assert(perched.x == 6 * 16 + 8 and perched.vx == 0,
                "A snake with no safe step on either side must remain still")
            if viewer.scenarios[2].event == "PLAYER HIT" then
                sawContact = true
                local player = viewer.scenarios[2].player
                assert(player.health == 3 and player.stunTimer == 0 and player.vy == 0
                    and player.spriteName == "sStandLeft",
                    "The scripted contact must show damage without changing the player pose")
            end
            if viewer.scenarios[3].event == "WHIP HIT" then
                if not sawWhip then
                    local scenario = viewer.scenarios[3]
                    assert(#scenario.effects.particles == 4,
                        "A lethal snake whip must emit one hit drop and three death drops")
                    for _, particle in ipairs(scenario.effects.particles) do
                        assert(particle.kind == "blood" and particle.age == 1,
                            "Snake blood must enter the live particle simulation")
                    end
                end
                sawWhip = true
            end
        end
        assert(sawTurn and sawContact and sawWhip,
            "Each scripted snake scenario must visibly reach its intended behavior")
        for _, scenario in ipairs(viewer.scenarios) do
            assert(scenario.runs > 1, "Every snake scenario must repeat automatically")
        end
        viewer:setPage(2)
        local sawAlert, sawContact, sawRehang, sawBatWhip = false, false, false, false
        for _ = 1, 100 do
            viewer:update(1 / Enemy.TICK_RATE)
            local ambush, returnToCeiling, whip = unpack(viewer.scenarios)
            if ambush.event == "BAT ALERT" then sawAlert = true end
            if ambush.event == "PLAYER HIT" then
                sawContact = true
                assert(ambush.player.health == 3,
                    "The bat ambush must show one hit before it restarts")
            end
            if returnToCeiling.event == "REHANG" then
                sawRehang = true
                assert(returnToCeiling.player == nil
                    and returnToCeiling.enemy.state == Enemy.STATES.hang,
                    "An untargeted bat must return to its ceiling perch")
            end
            if whip.event == "WHIP HIT" then
                if not sawBatWhip then
                    assert(not whip.enemy.alive and #whip.effects.particles == 4,
                        "Whipping the diving bat must kill it and emit its hit and death blood")
                end
                sawBatWhip = true
            end
        end
        assert(sawAlert and sawContact and sawRehang and sawBatWhip,
            "Each scripted bat scenario must visibly reach its intended behavior")
        for _, scenario in ipairs(viewer.scenarios) do
            assert(scenario.runs > 1, "Every bat scenario must repeat automatically")
        end
        viewer:setPage(5)
        assert(#viewer.scenarios == 3, "The caveman page must have three scenarios")
        viewer:draw()
        local sawPause, sawCharge, sawHit, sawStun, sawRecovery = false, false, false, false, false
        for _ = 1, 260 do
            viewer:update(1 / Enemy.TICK_RATE)
            local patrol, rush, whip = unpack(viewer.scenarios)
            if patrol.enemy.state == Enemy.STATES.idle
                and patrol.enemy.x > patrol.enemy.spawnX then sawPause = true end
            if rush.enemy.state == Enemy.STATES.attack
                and rush.enemy.animationName == "run"
                and rush.enemy.animation >= 2 then sawCharge = true end
            if rush.event == "PLAYER HIT" and rush.player.health == 3 then sawHit = true end
            if whip.enemy.state == Enemy.STATES.stunned
                and whip.enemy.animationName == "stun"
                and whip.enemy.animation >= 2 and whip.enemy.hp == 2 then sawStun = true end
            if sawStun and whip.runs == 1
                and whip.enemy.state ~= Enemy.STATES.stunned then sawRecovery = true end
        end
        assert(sawPause and sawCharge and sawHit and sawStun and sawRecovery,
            "Caveman replays must show a ledge pause, animated charge, contact, animated stun, and recovery")
        for _, scenario in ipairs(viewer.scenarios) do
            assert(scenario.runs > 1, "Every caveman scenario must repeat automatically")
        end
        viewer:setPage(3)
        assert(#viewer.scenarios == 3, "The spider page must have three scenarios")
        viewer:draw()
        local sawDrop, sawFlip, sawFlipEnd, sawBounce, sawSpiderWhip =
            false, false, false, false, false
        for _ = 1, 120 do
            viewer:update(1 / Enemy.TICK_RATE)
            local ambush, lostCeiling, whip = unpack(viewer.scenarios)
            if ambush.event == "SPIDER DROP" then sawDrop = true end
            if ambush.enemy.animationName == "flip"
                and ambush.enemy.animation >= 5 then sawFlip = true end
            if ambush.runs == 1 and sawFlip
                and ambush.enemy.animationName == "bounce" then sawFlipEnd = true end
            assert(not (ambush.runs == 1 and sawFlipEnd
                and ambush.enemy.animationName == "flip"),
                "A dropped spider must not restart its one-time flip while hopping")
            if lostCeiling.enemy.state == Enemy.STATES.bounce then sawBounce = true end
            if whip.event == "WHIP HIT" and not whip.enemy.alive
                and #whip.effects.particles == 4 then sawSpiderWhip = true end
        end
        assert(sawDrop and sawFlip and sawFlipEnd and sawBounce and sawSpiderWhip,
            "Spider replays must show one complete flip, hops, and a whip kill")
        for _, scenario in ipairs(viewer.scenarios) do
            assert(scenario.runs > 1, "Every spider scenario must repeat automatically")
        end

        viewer:setPage(4)
        assert(#viewer.scenarios == 3, "The giant spider page must have three scenarios")
        viewer:draw()
        local sawGiantDrop, sawGiantFlip, sawGiantJump, sawGiantWhip,
            sawWebBall, sawWebCreate, sawWebPlaced =
            false, false, false, false, false, false, false
        for _ = 1, 120 do
            viewer:update(1 / Enemy.TICK_RATE)
            local ambush, whip, web = unpack(viewer.scenarios)
            if ambush.event == "GIANT DROP" then sawGiantDrop = true end
            if ambush.enemy.spriteName == "sGiantSpiderFlip"
                and ambush.enemy.animation >= 2 then sawGiantFlip = true end
            if ambush.enemy.state == "bounce" then sawGiantJump = true end
            if whip.enemy.hp == 9 and whip.enemy.state ~= "hang" then sawGiantWhip = true end
            if web.event == "WEB FIRED" then
                for _, projectile in ipairs(web.projectiles.projectiles) do
                    if projectile.kind == "web" and projectile.phase == "flight" then
                        sawWebBall = true
                    end
                end
            end
            for _, projectile in ipairs(web.projectiles.projectiles) do
                if projectile.kind == "web" and projectile.phase == "create" then
                    sawWebCreate = true
                end
            end
            if web.projectiles.webs and #web.projectiles.webs > 0 then
                sawWebPlaced = true
            end
        end
        assert(sawGiantDrop and sawGiantFlip and sawGiantJump and sawGiantWhip
            and sawWebBall and sawWebCreate and sawWebPlaced,
            "Giant spider replays must show the drop, flip, jump, whip reaction, and a web ball that forms a web")
        for _, scenario in ipairs(viewer.scenarios) do
            assert(scenario.runs > 1, "Every giant spider scenario must repeat automatically")
        end

        viewer:setPage(6)
        assert(#viewer.scenarios == 3, "The skeleton page must have three scenarios")
        viewer:draw()
        local sawBones, sawRise, sawWalk, sawFall, sawShatter, sawSettled =
            false, false, false, false, false, false
        for _ = 1, 120 do
            viewer:update(1 / Enemy.TICK_RATE)
            local rising, ledge, whip = unpack(viewer.scenarios)
            if rising.enemy.state == Enemy.STATES.bones then sawBones = true end
            if rising.enemy.animationName == "rise"
                and rising.enemy.animation >= 2 then sawRise = true end
            if rising.enemy.animationName == "walk"
                and rising.enemy.animation >= 2 then sawWalk = true end
            if ledge.enemy.y > 7 * 16 + 8 then sawFall = true end
            if whip.event == "WHIP HIT" and not whip.enemy.alive then
                local bones, skulls, blood, smoke = 0, 0, 0, 0
                for _, particle in ipairs(whip.effects.particles) do
                    if particle.kind == "bone" then bones = bones + 1 end
                    if particle.kind == "skull" then skulls = skulls + 1 end
                    if particle.kind == "blood" then blood = blood + 1 end
                    if particle.kind == "smoke" then smoke = smoke + 1 end
                end
                if bones == 3 and skulls == 1 and blood == 0 then sawShatter = true end
                if whip.eventTick and whip.tick - whip.eventTick >= 20
                    and bones == 0 and skulls == 0 and smoke > 0 then sawSettled = true end
            end
        end
        assert(sawBones and sawRise and sawWalk and sawFall and sawShatter and sawSettled,
            "Skeleton replays must show awakening, walking, falling, bones smoking, and the skull shattering on impact")
        for _, scenario in ipairs(viewer.scenarios) do
            assert(scenario.runs > 1, "Every skeleton scenario must repeat automatically")
        end

        assert(app.screens.menu.items[2].label == "Scenario Tests",
            "The menu must identify the expanded scenario viewer by its new name")
        viewer:setPage(7)
        assert(#viewer.scenarios == 9, "Rope throws, enemy impacts, and ledge drops must have visible scenarios")
        for _ = 1, 32 do viewer:update(1 / Enemy.TICK_RATE) end
        local blocked, leftCorner, rightCorner, clear, openSky, snakeHit, cavemanHit,
            ledgeDrop, deepShaft =
            unpack(viewer.scenarios)
        assert(blocked.ropesRemaining == 1 and #blocked.tools.ropes == 0
            and blocked.event == "BLOCKED: ROPE KEPT",
            "A one-block headroom scenario must reject the throw without spending a rope")
        assert(leftCorner.tools.ropes[1].deployed and leftCorner.tools.ropes[1].x == 104
            and rightCorner.tools.ropes[1].deployed and rightCorner.tools.ropes[1].x == 120,
            string.format("Offset throws must anchor beside opposite corners (left=%s, right=%s)",
                tostring(leftCorner.tools.ropes[1].x), tostring(rightCorner.tools.ropes[1].x)))
        assert(clear.tools.ropes[1].deployed and #clear.tools.ropes[1].segments > 0,
            "A clear upward throw must unfurl a climbable rope")
        assert(openSky.tools.ropes[1].deployed and openSky.tools.ropes[1].y < 0
            and #openSky.tools.ropes[1].segments > 0,
            "Without a ceiling, the hook must deploy at its apex above the room")
        assert(not snakeHit.enemy.alive and snakeHit.event == "ROPE HIT",
            "The flying rope end must kill a one-health snake")
        assert(cavemanHit.enemy.hp == 2 and cavemanHit.enemy.state == Enemy.STATES.stunned
            and cavemanHit.event == "ROPE HIT",
            "The flying rope end must deal one damage and stun a caveman")
        local ledgeRope = ledgeDrop.tools.ropes[1]
        local longRope = deepShaft.tools.ropes[1]
        assert(ledgeDrop.player.state == Player.STATES.ducking
            and ledgeRope and ledgeRope.deployed and ledgeRope.x > ledgeDrop.player.x
            and #ledgeRope.segments > 0 and not ledgeRope.deploying,
            "Holding down at a ledge must place the rope beside the crouched player and stop at the floor")
        assert(longRope and longRope.deployed and not longRope.deploying
            and #longRope.segments == 16 and deepShaft.event == "ROPE LIMIT: 16 SEGMENTS",
            "A tall shaft must expose Classic's finite 16-segment rope limit")
        assert(deepShaft.world:climbableAtPoint(longRope.x, longRope.segments[16]) == "rope"
            and not deepShaft.world:climbableAtPoint(longRope.x, longRope.segments[16] + 16),
            "The rope must be climbable to its end but not continue down an empty shaft")
        viewer:draw()
        viewer.scrollY = viewer.maxScroll
        viewer:draw()
        for _ = 1, 30 do viewer:update(1 / Enemy.TICK_RATE) end
        assert(#deepShaft.tools.ropes[1].segments == 16,
            "An open shaft must not grow more rope over later ticks")
        viewer:setPage(1)
    end
end

return Test
