local Player = require("src.platform.player")
local World = require("src.platform.world")

local Test = {}

local function flatWorld()
    local world = World.new(20, 14, 16)
    world:fill("solid", 0, 10, 20, 4)
    return world
end

local function groundedPlayer(world, x)
    local player = Player.new(x or 64, 10 * 16 - 8)
    player:step(world, {})
    assert(player.state == Player.STATES.standing, "Player did not settle onto solid ground")
    return player
end

local function repeatStep(player, world, input, count)
    for _ = 1, count do
        player:step(world, input)
    end
end

local function close(actual, expected, message)
    assert(math.abs(actual - expected) < 0.000001,
        string.format("%s: expected %.6f, got %.6f", message, expected, actual))
end

function Test.run()
    do
        local world = World.makeTestCourse()
        assert(world:has("solid", 12, 12) and world:has("solid", 20, 19),
            "Visible brick ledges in the platform course must be solid terrain")
        assert(not world:has("solid", 15, 12) and not world:has("solid", 15, 17),
            "Solid ledges must leave openings for their ladder tops")
        assert(world:has("ladderTop", 15, 12) and world:has("ladderTop", 15, 17),
            "Only explicit ladder tops should retain one-way platform behavior")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        local startX = player.x
        player:step(world, { right = true })
        player:step(world, { right = true })
        assert(player.x == startX and player.vx == 0,
            "GM8 movement must preserve the original two-step input delay")
        player:step(world, { right = true })
        close(player.vx, 1.8, "First walking acceleration step")
        assert(player.x == startX + 2,
            "GM8 fractional quantization must move 1.8 velocity by two pixels on this tick")
        repeatStep(player, world, { right = true }, 9)
        assert(player.state == Player.STATES.running, "Horizontal input must enter Running")
        assert(player.vx > 0 and player.vx <= 3, "Walk velocity must retain the original 3 px/step cap")

        player:step(world, { right = true, sprint = true })
        assert(player.runHeld == 100, "The dedicated run key must enter the original fast branch immediately")
        assert(player.vx > 4 and player.vx <= 6, "Sprint must accelerate toward the 6 px/step cap")
    end

    do
        local world = flatWorld()
        world:fill("solid", 5, 8, 1, 2)
        local player = groundedPlayer(world, 75)
        repeatStep(player, world, { right = true }, 22)
        assert(player.pushTimer == 20 and player.spriteName ~= "sPushLeft",
            "An ordinary wall must not show stress before twenty sustained timer steps")
        player:step(world, { right = true })
        assert(player.pushTimer == 21 and player.spriteName == "sPushLeft",
            "An ordinary wall must show stress only after the source's greater-than-twenty threshold")

        local moveableWorld = flatWorld()
        moveableWorld:fill("solid", 5, 8, 1, 2)
        moveableWorld:fill("moveableSolid", 5, 8, 1, 2)
        local pushingPlayer = groundedPlayer(moveableWorld, 75)
        pushingPlayer:step(moveableWorld, { right = true })
        assert(pushingPlayer.pushTimer == 11 and pushingPlayer.spriteName ~= "sPushLeft",
            "A movable block must receive the source's ten-point push bonus plus wall pressure")
        pushingPlayer:step(moveableWorld, { right = true })
        assert(pushingPlayer.pushTimer == 22 and pushingPlayer.spriteName == "sPushLeft",
            "A movable block must enter its push animation on the second pressure step")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        local startX = player.x
        repeatStep(player, world, { right = true, sprint = true }, 10)
        assert(player.x == startX + 45 and player.vx == 6,
            "Ten dedicated-run steps must follow the original 0,0,3,6,6... cadence")
    end

    do
        local player = Player.new(0, 0)
        player.tick = 1
        assert(player:quantizedPixels(1.5) == 1,
            "Half-pixel velocity must not advance on an odd global tick")
        player.tick = 2
        assert(player:quantizedPixels(1.5) == 2,
            "Half-pixel velocity must advance on an even global tick")
        player.tick = 5
        assert(player:quantizedPixels(-2.8) == -3,
            "GM8 quantization must use round(1/fraction), not a carried remainder")
        player.tick = 2
        assert(player:quantizedPixels(0.4) == 1,
            "GM8 ties-to-even rounding must turn a 0.4 fraction into a two-tick period")
        player.tick = 3
        assert(player:quantizedPixels(0.4) == 0,
            "The 0.4 fractional pulse must skip odd global ticks")
    end

    do
        local world = flatWorld()
        local longJump = groundedPlayer(world, 48)
        local shortJump = groundedPlayer(world, 96)
        longJump:step(world, { jump = true })
        shortJump:step(world, { jump = true })
        assert(longJump.state == Player.STATES.falling and longJump.vy == -4,
            "The launch step must retain GM8's one-step Falling state and -4 velocity")
        longJump:step(world, { jump = true })
        shortJump:step(world, {})
        close(longJump.vy, -3.9, "Held jump second-step velocity")
        close(shortJump.vy, -3.9, "Release frame must still use the previous gravity intensity")
        repeatStep(longJump, world, { jump = true }, 6)
        repeatStep(shortJump, world, {}, 6)
        assert(longJump.state == Player.STATES.jumping, "Held jump must remain in the rising state")
        assert(longJump.y < shortJump.y, "Ten-step variable gravity must make held jumps higher")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        local startY = player.y
        repeatStep(player, world, { jump = true }, 5)
        assert(player.y == startY - 18,
            "Five held-jump steps must match the original EXE's 18-pixel rise")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        assert(player.spriteName == "sStandLeft", "Grounded player must use the standing sprite")
        world.solid = {}
        player:step(world, {})
        assert(player.state == Player.STATES.falling and player.spriteName == "sStandLeft",
            "The first falling state sample must retain the previous sprite")
        player:step(world, {})
        assert(player.spriteName == "sStandLeft",
            "The second falling state sample must retain the previous sprite")
        player:step(world, {})
        assert(player.spriteName == "sFallLeft",
            "The fall sprite must appear on the third consecutive falling state sample")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        player:step(world, { down = true })
        assert(player.state == Player.STATES.ducking, "Down on solid ground must crouch")
        repeatStep(player, world, { down = true, right = true }, 3)
        assert(player.state == Player.STATES.ducking and player.vx > 0,
            "Horizontal input while crouched must crawl")

        player:reset()
        player.y = 10 * 16 - 8
        player:step(world, {})
        player:step(world, { up = true })
        assert(player.state == Player.STATES.looking, "Up away from ladders must look upward")
    end

    do
        local world = flatWorld()
        local player = Player.new(64, 120)
        player:kill("enemy", 2, 0)
        local unsteeredWorld = flatWorld()
        local unsteered = Player.new(64, 120)
        unsteered:kill("enemy", 2, 0)
        local roseAfterImpact = false
        local showedBounceBody = false
        local showedFallingBody = false
        for _ = 1, 45 do
            player:step(world, { right = true, jump = true })
            unsteered:step(unsteeredWorld, {})
            if player.deadBounced and player.vy < 0 then roseAfterImpact = true end
            if player.spriteName == "sDieLBounce" then showedBounceBody = true end
            if player.spriteName == "sDieLFall" then showedFallingBody = true end
        end
        assert(roseAfterImpact and showedBounceBody and showedFallingBody,
            "A dead player must fall, rebound, and show both tumbling sprites")
        assert(player.x == unsteered.x and player.y == unsteered.y,
            "Movement input must not steer the dead body during its fall and bounce")

        local platformWorld = World.new(12, 14, 16)
        platformWorld:fill("platform", 0, 10, 12, 1)
        local platformBody = Player.new(64, 120)
        platformBody:kill("enemy", 0, 0)
        repeatStep(platformBody, platformWorld, { down = true }, 30)
        assert(platformBody.deadBounced and platformBody.y <= 152,
            "A dead body must bounce on a one-way platform even while Down is held")

        local fatalWorld = flatWorld()
        local fatalFall = groundedPlayer(fatalWorld)
        fatalFall.health = 1
        fatalFall.fallTimer = 17
        fatalFall:step(fatalWorld, { right = true })
        assert(fatalFall:isDead() and fatalFall.deadBounced and fatalFall.vy == 0
            and fatalFall.state == Player.STATES.dead,
            "A fatal long drop must enter the source's grounded corpse response immediately")
    end

    do
        local world = flatWorld()
        world:fill("ladder", 4, 7, 1, 3)
        local player = groundedPlayer(world, 72)
        repeatStep(player, world, { down = true }, 4)
        assert(player.state == Player.STATES.ducking and player.climbKind == nil,
            "Down at a ladder base must crouch, not alternate between crouching and climbing")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        player.facing = -1
        player:step(world, { attack = true })
        assert(player.whipping and player.spriteName == "sAttackLeft"
            and player.animationFrame == 0,
            "Attack press must start the original whip animation on frame zero")
        assert(player:getWhipHitbox() == nil,
            "The original creates the backswing object on the step after attack begins")
        player:step(world, { attack = true })
        local left, top, right, bottom, phase = player:getWhipHitbox()
        assert(phase == "back" and left == player.x + 8 and right == player.x + 18
            and top == player.y - 8 and bottom == player.y + 4,
            "The backswing bounds must follow the original sprite's opaque pixels")

        repeatStep(player, world, { attack = true }, 7)
        left, top, right, bottom, phase = player:getWhipHitbox()
        assert(phase == "front" and left == player.x - 21 and right == player.x - 8
            and top == player.y - 2 and bottom == player.y + 3,
            "After frame four, the front whip bounds must follow its visible stroke")
        assert(not player:whipOverlapsRectangle(player.x - 16, player.y - 1,
                player.x - 15, player.y)
            and player:whipOverlapsRectangle(player.x - 16, player.y,
                player.x - 15, player.y + 1),
            "Transparent holes in the precise front whip mask must not damage targets")

        repeatStep(player, world, { attack = true }, 11)
        assert(not player.whipping,
            "The 11-frame attack at 0.6 frames per step must end instead of looping")
        player:step(world, { attack = true })
        assert(not player.whipping, "Holding attack must not retrigger the whip")
        player:step(world, {})
        player:step(world, { attack = true })
        assert(player.whipping, "Releasing and pressing attack must start another whip")

        player.whipping = false
        player.state = Player.STATES.ducking
        player:step(world, { down = true })
        player:step(world, { down = true, attack = true })
        assert(not player.whipping, "The source does not allow whipping while ducking")
    end

    do
        local world = flatWorld()
        world:fill("ladder", 5, 3, 1, 7)
        local player = groundedPlayer(world, 5 * 16 + 8)
        player:step(world, { up = true })
        assert(player.state == Player.STATES.climbing, "Up at a ladder must enter Climbing")
        local startY = player.y
        repeatStep(player, world, { up = true }, 6)
        assert(player.y < startY, "Climbing input must move along the ladder")
        local climbVelocity = player.vy
        player:step(world, { right = true, jump = true })
        close(player.vx, 3, "Ladder jump horizontal velocity after the retained walking cap")
        close(player.vy, climbVelocity - 3,
            "Ladder jump must retain climb velocity and apply same-step gravity")
        assert(player.state == Player.STATES.jumping,
            "Jumping from a ladder must enter the Jumping state")
        assert(player.ladderCooldown == 5 and player.hangCooldown == 0,
            "Ladder departure must not consume the independent ledge-grab cooldown")
        player:step(world, { up = true })
        assert(player.state ~= Player.STATES.climbing,
            "Ladder departure cooldown must prevent an immediate ladder regrab")
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("rope", 5, 3, 1, 6)
        local player = Player.new(5 * 16 + 8, 5 * 16)
        player.state = Player.STATES.falling
        player:step(world, { up = true })
        assert(player.state == Player.STATES.climbing and player.x == 5 * 16 + 8,
            "Rope climbing must align to the hook at the original body instance's x + 8")
        assert(player.climbKind == "rope", "Rope entry must retain rope animation semantics")
        player.x = player.x - 1
        player:step(world, {})
        assert(player.x == 5 * 16 + 8,
            "Rope climbing must restore the original ladder.x + 8 alignment every step")
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("solid", 5, 8, 4, 1)
        local player = Player.new(5 * 16 - 5, 8 * 16 + 6)
        player.state = Player.STATES.falling
        player.vy = 1
        player:step(world, { right = true })
        assert(player.state == Player.STATES.hanging, "Falling toward a clear ledge must grab it")
        assert(player.facing == 1 and player.vx == 0 and player.vy == 0,
            "A right-side ledge grab must face and hold against the wall")
        player:step(world, { jump = true })
        assert(player.state == Player.STATES.falling and player.vy == -5,
            string.format("Jump while hanging must jump above the ledge (state=%s, vy=%s, x=%s)",
                tostring(player.state), tostring(player.vy), tostring(player.x)))
        assert(player.x == 5 * 16 - 7,
            "Right-facing ledge jumps must preserve the original two-pixel offset")
        player:step(world, { jump = true })
        assert(player.vy == -5 and player.y == 8 * 16 - 2,
            "The first airborne ledge-jump step must retain hanging's zero gravity")
    end

    do
        for _, case in ipairs({
            { name = "left", x = 309, direction = -1, firstTile = 16, lastTile = 18, sprint = true },
            { name = "right", x = 187, direction = 1, firstTile = 12, lastTile = 14 },
        }) do
            local world = World.makeTestCourse()
            local player = Player.new(case.x, 278)
            player.vy = 1
            local toward = { left = case.direction < 0, right = case.direction > 0,
                sprint = case.sprint }
            player:step(world, toward)
            assert(player.state == Player.STATES.hanging and player.y == 280,
                case.name .. " ledge must be reachable before the jump")
            repeatStep(player, world, toward, 4)

            local jumpToward = { left = toward.left, right = toward.right,
                sprint = toward.sprint, jump = true }
            local apex = player.y
            for _ = 1, 22 do
                player:step(world, jumpToward)
                apex = math.min(apex, player.y)
                if player:isGroundState() then break end
            end
            assert(apex <= 260 and player:isGroundState() and player.y == 264
                and player.x >= case.firstTile * 16 and player.x < (case.lastTile + 1) * 16,
                string.format("Holding %s and jump from a hang must clear and land on the ledge (x=%s, y=%s, apex=%s)",
                    case.name, tostring(player.x), tostring(player.y), tostring(apex)))
        end
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("solid", 5, 8, 4, 1)
        local player = Player.new(5 * 16 - 5, 8 * 16 + 6)
        player.state = Player.STATES.falling
        player.vy = 1
        player:step(world, { right = true, jump = true })
        assert(player.state == Player.STATES.falling and player.vy == -5,
            "Jump pressed on a ledge-grab step must immediately jump from that ledge")
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("solid", 5, 8, 4, 1)
        local player = Player.new(9 * 16 - 1, 8 * 16 - 8)
        player.state = Player.STATES.standing
        player:step(world, { right = true, down = true })
        assert(player.state == Player.STATES.duckToHang,
            "Crouching toward a solid platform edge must start Duck To Hang")
        repeatStep(player, world, {}, 12)
        assert(player.state == Player.STATES.hanging and player.facing == -1,
            "Duck To Hang must finish below the edge facing back toward it")
        player:step(world, { down = true, jump = true })
        assert(player.state == Player.STATES.falling and player.hangCooldown == 5,
            "Down plus jump must apply the original five-step ledge cooldown")
        repeatStep(player, world, {}, 5)
        assert(player.hangCooldown == 0,
            "Ledge cooldown assignments must not decrement on their creation step")
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("solid", 5, 8, 1, 1)
        local player = Player.new(5 * 16 - 5, 8 * 16 + 8)
        player.state = Player.STATES.hanging
        player.statePrev = Player.STATES.hanging
        player.statePrevPrev = Player.STATES.hanging
        player.facing = 1
        player.hangTileX = 5
        player.hangTileY = 8
        world.solid["5:8"] = nil
        player:step(world, {})
        assert(player.state == Player.STATES.falling and player.vy == -1,
            "Losing a ledge must apply its upward release impulse in the same step")
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("platform", 4, 8, 5, 1)
        local player = Player.new(6 * 16 + 8, 8 * 16 - 8)
        player.state = Player.STATES.standing
        player:step(world, { down = true })
        assert(player.state == Player.STATES.falling and player.dropThroughTimer > 0,
            "Down alone must drop through a one-way platform")
        assert(player.y > 8 * 16 - 8, "Platform drop must move below its starting height")
    end

    do
        local world = World.new(16, 14, 16)
        world:set("platform", 4, 8)
        local player = Player.new(5 * 16 + 4, 8 * 16 - 8)
        player.state = Player.STATES.falling
        player:step(world, {})
        assert(player:isGroundState(),
            "The leftmost collider pixel must be able to land on a one-pixel platform overlap")
    end

    do
        local world = World.new(16, 14, 16)
        world:fill("platform", 4, 8, 5, 1)
        local player = Player.new(6 * 16 + 8, 8 * 16 - 20)
        player.state = Player.STATES.falling
        player.vy = 4
        repeatStep(player, world, { down = true }, 6)
        assert(player.y > 8 * 16,
            "Holding down while airborne must ignore one-way platforms during movement")
    end

    do
        local world = flatWorld()
        local player = groundedPlayer(world)
        assert(player:hurt(player.x - 10), "The stun regression requires an actual knockback")
        local duration = player.stunTimer
        player:step(world, {})
        assert(player.spriteName == "sDieLR" and player.stunTimer == duration,
            "Source stun must show the rightward knockback pose without advancing its timer")
        local sawStunAnimation = false
        for _ = 1, 40 do
            player:step(world, {})
            if player.spriteName == "sStunL" then
                sawStunAnimation = true
                break
            end
        end
        assert(sawStunAnimation and player.vx == 0 and player.stunTimer < duration,
            "Landing friction must settle knockback so the stun animation can actually play")
    end

    do
        local world = World.makeTestCourse()
        local player = Player.new(248, 190)
        player.state = Player.STATES.falling
        for _ = 1, 30 do
            player:step(world, {})
            if player:isGroundState() or player:isStunned() then break end
        end
        if player:isGroundState() then player:step(world, {}) end
        assert(player.y == 264 and player.health == 4 and player.vx == 0
            and player:isGroundState(),
            "A short drop onto a ladder top must land without damage or sideways knockback")

        local longWorld = World.new(20, 24, 16)
        longWorld:fill("solid", 0, 20, 20, 4)
        local longFall = Player.new(64, 160)
        longFall.state = Player.STATES.falling
        for _ = 1, 40 do
            longFall:step(longWorld, {})
            if longFall:isGroundState() or longFall:isStunned() then break end
        end
        if longFall:isGroundState() then longFall:step(longWorld, {}) end
        assert(longFall.health == 3 and longFall.vx == 0 and longFall.vy < 0
            and longFall:isStunned() and longFall.spriteName == "sStunL",
            "A 17-32-step fall must show the original stun pose while bouncing vertically")
        longFall:step(longWorld, { right = true })
        assert(longFall.x == 64, "A long-fall stun must temporarily block movement input")
        repeatStep(longFall, longWorld, { right = true }, 65)
        assert(longFall.x > 64, "Horizontal movement must return after the fall stun expires")
    end
end

return Test
