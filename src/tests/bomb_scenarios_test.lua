local Enemy = require("src.platform.enemy")
local Effects = require("src.platform.effects")
local Player = require("src.platform.player")
local FullLevelPlaytest = require("src.screens.full_level_playtest")
local RunState = require("src.game.run_state")
local ToolSystem = require("src.platform.tool_system")
local World = require("src.platform.world")

local Test = {}

function Test.run(app)
    local collisionWorld = World.new(12, 9, 16)
    collisionWorld:set("solid", 5, 5)
    local collisionEffects = Effects.new(17)
    local flame = collisionEffects:add("flame", 75, 88, 3, 0)
    collisionEffects:update(collisionWorld)
    assert(flame.x <= 76 and flame.vx < 0
        and not collisionWorld:solidRect(flame.x - 4, flame.y - 4,
            flame.x + 4, flame.y + 4),
        "A flame must rebound at a solid wall instead of passing through it")

    local debrisWorld = World.new(12, 9, 16)
    local block = debrisWorld:addDynamicSolid({ kind = "push_block", x = 80, y = 80 })
    local debrisTools = ToolSystem.new(debrisWorld, Player.TICK_RATE)
    debrisTools:explode(88, 88)
    local large, small = 0, 0
    for _, particle in ipairs(debrisTools.effects.particles) do
        if particle.kind == "rubbleLarge" then large = large + 1 end
        if particle.kind == "rubble" then small = small + 1 end
    end
    assert(not block.alive and large == 1 and small == 2,
        "A blast-destroyed movable block must emit one large and two small rubble pieces")

    local protectedWorld = World.new(12, 9, 16)
    protectedWorld:set("solid", 6, 5)
    protectedWorld.level = { tiles = { [6] = { [7] = {
        kind = "brick", properties = { invincible = true },
    } } } }
    local protectedTools = ToolSystem.new(protectedWorld, Player.TICK_RATE)
    protectedTools:explode(104, 88)
    local protectedRubble = 0
    for _, particle in ipairs(protectedTools.effects.particles) do
        if particle.kind == "rubble" or particle.kind == "rubbleLarge" then
            protectedRubble = protectedRubble + 1
        end
    end
    assert(protectedWorld:has("solid", 6, 5) and protectedRubble == 0,
        "An invincible block must remain intact and emit no destruction rubble")

    local skeleton = Enemy.new("skeleton", 88, 88, { seed = 18 })
    local skeletonTools = ToolSystem.new(World.new(12, 9, 16), Player.TICK_RATE)
    skeletonTools:explode(88, 88)
    local skeletonItems = {}
    skeletonTools:update(Player.new(16, 16), { skeleton }, skeletonItems)
    local bones, skulls, blood = 0, 0, 0
    for _, particle in ipairs(skeletonTools.effects.particles) do
        if particle.kind == "bone" then bones = bones + 1 end
        if particle.kind == "skull" then skulls = skulls + 1 end
        if particle.kind == "blood" then blood = blood + 1 end
    end
    for _, item in ipairs(skeletonItems) do if item.kind == "skull" then skulls = skulls+1 end end
    assert(not skeleton.alive and bones == 3 and skulls == 1 and blood == 0,
        "A skeleton killed by a blast must shatter into bones and a skull")

    local survivor = Player.new(88, 88)
    survivor.health = 14
    local survivorTools = ToolSystem.new(World.new(12, 9, 16), Player.TICK_RATE)
    survivorTools:explode(88, 88)
    survivorTools:update(survivor, {}, {})
    assert(survivor.health == 4 and survivor.stunTimer == 100 and survivor.vy == -6,
        "A high-vitality player must survive ten blast damage with the source stun and launch")

    local launchWorld = World.new(14, 9, 16)
    launchWorld:fill("solid", 1, 7, 12, 2)
    local thrower = Player.new(72, 104)
    thrower.facing = -1
    thrower.vx = -2
    local launches = ToolSystem.new(launchWorld, Player.TICK_RATE)
    local normal = launches:throwBomb(thrower)
    local upwardLaunch = launches:throwBomb(thrower, { up = true })
    local groundedDrop = launches:throwBomb(thrower, { down = true })
    thrower.y = 72
    local airborneDrop = launches:throwBomb(thrower, { down = true })
    assert(normal.x == 72 and normal.y == 104 and normal.vx == -10 and normal.vy == -3
        and normal.armed and normal.timer == 120,
        "Classic's left throw must start at the player with facing speed, momentum, and an armed fuse")
    assert(upwardLaunch.vy == -9 and groundedDrop.vx == -1 and groundedDrop.vy == 3
        and airborneDrop.vx == -10 and airborneDrop.vy == 3,
        "Up must lob high; Down must slow a grounded throw but retain airborne speed")
    thrower.whipping = true
    assert(not launches:throwBomb(thrower) and #launches.bombs == 4,
        "A whip must prevent launching or consuming another bomb")

    local pickupGame = FullLevelPlaytest.new(app)
    pickupGame.world = World.new(12, 9, 16)
    pickupGame.player = Player.new(72, 72)
    pickupGame.player.state = Player.STATES.ducking
    pickupGame.tools = ToolSystem.new(pickupGame.world, Player.TICK_RATE)
    pickupGame.run = RunState.new(19)
    pickupGame.sounds = { play = function() end }
    local lit = pickupGame.tools:spawnBomb(72, 76, { timer = 18 })
    assert(pickupGame:pickupNearestItem() and pickupGame.heldItem == lit and lit.held,
        "Down+action must be able to pick up a lit bomb like any other oItem")
    pickupGame.player.x = 88
    pickupGame.tools:update(pickupGame.player, {}, {})
    assert(lit.timer == 17 and lit.x == pickupGame.player.x + pickupGame.player.facing * 4,
        "A held lit bomb must follow the player without pausing its fuse")
    pickupGame:useHeldItem({})
    assert(not lit.held and lit.timer == 17 and pickupGame.heldItem == nil,
        "ACTION must throw the same live bomb without resetting its fuse")

    local viewer = app.screens.enemy_ai
    viewer:setPage(8)
    assert(#viewer.scenarios == 6, "The Bombs page must present launch and blast scenarios")
    viewer:draw()

    local rebound, paste, snake, upward, downward, blocked = unpack(viewer.scenarios)
    assert(rebound.world:has("solid", 8, 5) and paste.world:has("solid", 7, 5)
        and snake.enemy.alive and upward.player.health == 4,
        "Bomb scenarios must begin with intact terrain and living targets")

    for _ = 1, 6 do viewer:update(1 / Enemy.TICK_RATE) end
    assert(upward.tools.bombs[1].y < rebound.tools.bombs[1].y
        and downward.tools.bombs[1].x < rebound.tools.bombs[1].x,
        "Up must launch a higher arc and grounded Down must reduce sideways travel")
    assert(blocked.bombsRemaining == 1 and #blocked.tools.bombs == 0
        and blocked.event == "BLOCKED: BOMB KEPT",
        "Whipping must block a bomb throw without consuming the supply")
    for _ = 7, 20 do viewer:update(1 / Enemy.TICK_RATE) end
    for _, scenario in ipairs(viewer.scenarios) do
        if scenario ~= blocked then
            assert(scenario.bombsRemaining == 0 and #scenario.tools.bombs == 1,
                "Every unblocked replay must spend one bomb and show its thrown object")
        end
    end

    local sawStuck, sawFlash, sawBlast, sawFlames, sawRubble, sawBlood =
        false, false, false, false, false, false
    for _ = 21, 140 do
        viewer:update(1 / Enemy.TICK_RATE)
        local stuckBomb = paste.tools.bombs[1]
        if stuckBomb and stuckBomb.alive and stuckBomb.stuck then sawStuck = true end
        if paste.event == "STUCK AND FLASHING" then sawFlash = true end
        if #rebound.tools.explosions > 0 then sawBlast = true end
        if #paste.tools.explosions > 0 then
            local flames, rubble = 0, 0
            for _, particle in ipairs(paste.tools.effects.particles) do
                if particle.kind == "flame" then flames = flames + 1 end
                if particle.kind == "rubble" or particle.kind == "rubbleLarge" then
                    rubble = rubble + 1
                end
            end
            if flames == 3 then sawFlames = true end
            if rubble >= 3 then sawRubble = true end
        end
        if #snake.tools.explosions > 0 then
            local blood = 0
            for _, particle in ipairs(snake.tools.effects.particles) do
                if particle.kind == "blood" then blood = blood + 1 end
            end
            if blood == 3 then sawBlood = true end
        end
    end

    assert(sawStuck and sawFlash and sawBlast and sawFlames and sawRubble and sawBlood,
        ("Bomb replay effects: stuck=%s flash=%s blast=%s flames=%s rubble=%s blood=%s")
            :format(tostring(sawStuck), tostring(sawFlash), tostring(sawBlast),
                tostring(sawFlames), tostring(sawRubble), tostring(sawBlood)))
    assert(rebound.world:has("solid", 8, 5) and rebound.player.health == 0,
        "An unpasted bomb must rebound from brick and threaten its thrower")
    assert(not paste.world:has("solid", 7, 5) and paste.player.health == 4,
        "A stuck paste bomb must destroy the wall without reaching its distant thrower")
    assert(not snake.enemy.alive and snake.event == "SNAKE BLASTED",
        "The blast must kill the snake on the other side of the wall")

    viewer:draw()
    local sawReset = {}
    for _ = 1, 65 do
        local previousRuns = {}
        for index, scenario in ipairs(viewer.scenarios) do previousRuns[index] = scenario.runs end
        viewer:update(1 / Enemy.TICK_RATE)
        for index, scenario in ipairs(viewer.scenarios) do
            if scenario.runs > previousRuns[index] then
                assert(scenario.player.health == 4 and scenario.bombsRemaining == 1
                    and #scenario.tools.bombs == 0,
                    "Each replay must restore health and bomb supply before the next throw")
                sawReset[index] = true
            end
        end
    end
    for index = 1, #viewer.scenarios do
        assert(sawReset[index], "Every bomb scenario must reset automatically")
    end
    assert(blocked.bombsRemaining == 1 and #blocked.tools.bombs == 0,
        "A blocked throw must keep its bomb after the replay resets")
    viewer:setPage(1)
end

return Test
