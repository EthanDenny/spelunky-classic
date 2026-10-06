local ItemBody = require("src.platform.item_body")
local Item = require("src.platform.item")
local Player = require("src.platform.player")
local TrapSystem = require("src.platform.trap_system")
local World = require("src.platform.world")
local Enemy = require("src.platform.enemy")
local Treasure = require("src.platform.treasure")
local ToolSystem = require("src.platform.tool_system")
local Creature = require("src.platform.creature")
local FullLevelPlaytest = require("src.screens.full_level_playtest")
local ItemActions = require("src.platform.item_actions")
local Effects = require("src.platform.effects")

local Test = {}

local function mockPlayer()
    local player = Player.new(64, 80)
    player.state = Player.STATES.standing
    player.facing = -1
    player.vx = 1
    return player
end

function Test.run()
    local function close(actual, expected, message)
        assert(math.abs(actual - expected) < 0.000001,
            string.format("%s: expected %.6f, got %.6f", message, expected, actual))
    end
    local function object(kind, x, y)
        return Item.new({ kind = kind, x = x / 16, y = y / 16 })
    end
    local function step(world, item)
        world.time = world.time + 1
        item:update(world, Player.new(16, 16))
    end
    local cases = {
        { "bomb boxes and jetpacks use heavy carry and throw behavior", function()
            for _, kind in ipairs({ "bomb_box", "jetpack" }) do
                local player = Player.new(72, 80)
                player.facing, player.vx = 1, 2
                local item = object(kind, 72, 80)
                item:pickup(player)
                assert(item.y == 76, kind .. " must sit four pixels above a standing player")
                player:setState(Player.STATES.ducking)
                player.vx = 0
                item:updateHeldPosition(player)
                assert(item.y == 78, kind .. " must sit two pixels above a crouching player")
                player:setState(Player.STATES.standing)
                player.vx = 2
                item:throw(player, { up = true })
                assert(item.vx == 6 and item.vy == -4,
                    kind .. " must use the heavy upward launch velocities")
            end
        end },
        { "upward teleport preserves the pixel offset at the room ceiling", function()
            local player = Player.new(72, 22)
            local teleporter = object("teleporter", 72, 22)
            teleporter:pickup(player)
            local context = { player = player, world = World.new(40, 20, 16),
                effects = Effects.new(17), enemies = {}, heldItem = teleporter,
                sounds = { play = function() end } }
            assert(ItemActions.use(context, teleporter, { up = true }))
            assert(player.x == 72 and player.y == 22 and player.state == "falling",
                "Ceiling-limited teleport must add whole tiles until y >= 16")
        end },
        { "ghosts pursue distant players through terrain at one pixel per tick", function()
            local world = World.new(40, 40, 16)
            world:fill("solid", 4, 4, 3, 3)
            for _, distance in ipairs({ 50, 400 }) do
                local ghost = Creature.new({ kind = "ghost", x = 5, y = 5 },
                    { width = 24, height = 24 })
                local x, y = ghost.x, ghost.y
                local player = Player.new(x + distance * 0.6, y - 8 + distance * 0.8)
                ghost:step(world, player)
                close(ghost.x, x + 0.6, "Ghost horizontal pursuit")
                close(ghost.y, y + 0.8, "Ghost vertical pursuit")
            end
        end },
        { "ghost contact respects protection and cannot be stomped", function()
            local ghost = Creature.new({ kind = "ghost", x = 5, y = 5 },
                { width = 24, height = 24 })
            local player = Player.new(ghost.x, ghost.y - 8)
            player.invincibleTimer = 10
            player.vy = 3
            player:setState(Player.STATES.falling)
            assert(ghost:resolvePlayerContact(player, ghost.y - 24) == "invincible"
                and player.health == 4 and player.vy == 3 and player.invincibleTimer == 10,
                "Protected falling players must pass through ghosts without bouncing")
            player.invincibleTimer = 0
            assert(ghost:resolvePlayerContact(player, ghost.y - 24) == "hurt" and player:isDead(),
                "An unprotected falling player must die on ghost contact, even from above")
        end },
        { "fractional motion follows the global tick", function()
            local world = World.new(20, 20, 16)
            world.time = 1
            local rock = object("rock", 72, 72)
            rock.vx = 0.4
            step(world, rock)
            assert(rock.x == 73, "A 0.4-speed object must pulse on even ticks without carried remainder")
        end },
        { "wall arrival rebounds and separates on the same tick", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 5, 0, 1, 20)
            local rock = object("rock", 72, 72)
            rock.vx = 4
            step(world, rock)
            assert(rock.x == 75 and rock.vx == -2,
                "Reaching a wall exactly must halve velocity and nudge the object away immediately")
        end },
        { "floor arrival bounces immediately", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 6, 20, 1)
            local rock = object("rock", 72, 88)
            rock.vx, rock.vy = 3, 4
            step(world, rock)
            assert(rock.y == 92 and rock.vy == -2, "Exact floor arrival must bounce without waiting another tick")
            close(rock.vx, 0.9, "Landing friction")
        end },
        { "ceiling response observes gravity before rebounding", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 3, 20, 1)
            local rock = object("rock", 72, 68)
            rock.vy = -4
            step(world, rock)
            close(rock.vy, 2.72, "Ceiling rebound factor and gravity order")
        end },
        { "ordinary items fall at the eight-pixel cap", function()
            local world = World.new(20, 20, 16)
            local rock = object("rock", 72, 72)
            rock.vy = 7.9
            step(world, rock)
            assert(rock.vy == 8, "Ordinary items must continue accelerating through six to the eight-pixel cap")
        end },
        { "loose objects pass through player-only platforms", function()
            for _, kind in ipairs({ "rock", "treasure", "bomb" }) do
                local world = World.new(20, 20, 16)
                world:fill("platform", 0, 6, 20, 1)
                local body
                if kind == "treasure" then
                    body = Treasure.new({ kind = "ruby_big", x = 4.5, y = 5.75 })
                elseif kind == "bomb" then
                    body = ToolSystem.new(world):spawnBomb(72, 92, { vy = 4 })
                else body = object(kind, 72, 92) end
                body.vy = 4
                world.time = 1
                if kind == "bomb" then ToolSystem.new(world):updateBomb(body)
                else body:update(world, Player.new(16, 16)) end
                assert(body.y == 96, kind .. " must pass through one-way platforms")
            end
        end },
        { "jar break threshold includes same-tick gravity", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 6, 20, 1)
            world.time = 1
            local jar = object("jar", 72, 87)
            jar.vy = 2.6
            step(world, jar)
            assert(jar.justHit and jar.impactSide == "floor",
                "A jar landing at 2.6 must break when gravity raises its impact velocity above three")
        end },
        { "jar wall hits separate and cancel vertical motion", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 5, 0, 1, 20)
            local jar = object("jar", 72, 72)
            jar.vx, jar.vy = 4, -3
            step(world, jar)
            assert(jar.justHit and jar.x == 75 and jar.vy == 0,
                "A jar's wall response must use its own vertical-stop rule")
        end },
        { "mitt gravity persists for overriding item scripts", function()
            for _, kind in ipairs({ "jar", "skull", "die" }) do
                local world = World.new(40, 20, 16)
                local player = Player.new(72, 72)
                player.equipment.mitt = true
                local item = object(kind, 72, 72)
                item:pickup(player)
                item:throw(player, {}, world)
                step(world, item)
                step(world, item)
                close(item.vy, -0.2, kind .. " mitt trajectory")
                assert(item.gravity == 0.1, kind .. " must retain mitt gravity")
            end
        end },
        { "ordinary mitt throws reset gravity after the first flight tick", function()
            local world = World.new(40, 20, 16)
            local player = Player.new(72, 72)
            player.equipment.mitt = true
            local rock = object("rock", 72, 72)
            rock:pickup(player)
            rock:throw(player, {}, world)
            step(world, rock)
            close(rock.vy, -0.3, "First mitt flight tick")
            step(world, rock)
            close(rock.vy, 0.3, "Ordinary parent resets mitt gravity")
        end },
        { "treasure responds to its previous floor contact without bouncing", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 6, 20, 1)
            local gem = Treasure.new({ kind = "ruby_big", x = 4.5, y = 5.5 })
            gem.vx, gem.vy = 3, 4
            world.time = 1
            gem:update(world)
            assert(gem.y == 92 and gem.vx == 3, "Treasure retains motion on its arrival tick")
            close(gem.vy, 4.6, "Treasure arrival gravity")
            world.time = 2
            gem:update(world)
            assert(gem.vy == 0, "Treasure stops on the next floor-contact tick")
            close(gem.vx, 0.9, "Treasure floor friction")
        end },
        { "crate equipment uses item flight even when it is not for sale", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 6, 20, 1)
            local bag = object("bomb_bag", 72, 86)
            bag.vy = 4
            world.time = 1
            bag:update(world)
            assert(bag.y == 90 and bag.vy == -2, "A released supply uses its oItem bounds and floor bounce")
        end },
        { "enemy impacts use component speeds and retain the object's trajectory", function()
            local game = FullLevelPlaytest.new()
            game.effects = Effects.new(17)
            local enemy = Creature.new({ kind = "caveman", x = 6, y = 5 })
            game.enemies = { enemy }
            local rock = object("rock", enemy.x, enemy.y - 8)
            rock.vx, rock.vy = 1.5, 1.5
            ItemBody.resolveEnemyContacts(rock, nil, game)
            assert(enemy.hp == 3, "Two slow components must not add up to a damaging throw")
            rock.x, rock.vx, rock.vy = enemy.x - 9, 4, 0
            ItemBody.resolveEnemyContacts(rock, nil, game)
            assert(enemy.hp == 3, "The item's outer mask is outside its small source damage rectangle")
            rock.x = enemy.x
            ItemBody.resolveEnemyContacts(rock, nil, game)
            assert(enemy.hp == 2 and rock.vx == 4 and rock.vy == 0,
                "An enemy hit must not manufacture a rebound in the thrown item")
            close(enemy.vx, 1.2, "Thrown-item enemy impulse")
            assert(enemy.vy == -6, "A stunned enemy gets the source vertical impulse")
            enemy = Creature.new({ kind = "caveman", x = 6, y = 5 })
            game.enemies = { enemy }
            local arrow = object("arrow", enemy.x, enemy.y - 8)
            arrow.vx = 4
            ItemBody.resolveEnemyContacts(arrow, nil, game)
            assert(arrow.opened and enemy.hp == 2, "An effective loose-arrow hit consumes the arrow")
            enemy = Creature.new({ kind = "caveman", x = 6, y = 5 })
            game.enemies = { enemy }
            local die = object("die", enemy.x, enemy.y - 8)
            die.vx = 2.5
            ItemBody.resolveEnemyContacts(die, nil, game)
            assert(enemy.hp == 3, "Dice use their own stricter three-pixel damage threshold")
        end },
        { "Down overrides simultaneous Up when throwing", function()
            local player = Player.new(72, 72)
            player.state = Player.STATES.standing
            local rock = object("rock", 72, 72)
            rock:pickup(player)
            rock:throw(player, { up = true, down = true })
            close(rock.vx, 4.8, "Simultaneous Up and Down horizontal drop")
            assert(rock.vy == 0.5, "Down must select the grounded drop after the Up adjustment")
        end },
        { "stuck arrows fall when their wall disappears", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 5, 0, 1, 20)
            local arrow = object("arrow", 72, 72)
            arrow.vx = 14
            step(world, arrow)
            assert(arrow.stuck, "The regression needs an actual high-speed wall stick")
            world.solid = {}
            step(world, arrow)
            assert(not arrow.stuck and arrow.vy == 0.6,
                "A removed supporting wall must release the arrow into gravity")
        end },
        { "bombs use all 120 source fuse ticks", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 10, 20, 1)
            local tools = ToolSystem.new(world, 30)
            local bomb = tools:spawnBomb(72, 120)
            assert(bomb.timer == 120 and bomb.flashStart == 40,
                "The 30 Hz room must retain its 80-tick fuse plus 40-tick flashing alarm")
            for tick = 1, 119 do world.time = tick; tools:updateBomb(bomb) end
            assert(bomb.alive and #tools.explosions == 0, "The bomb must survive its first 119 ticks")
            tools:updateBomb(bomb)
            assert(not bomb.alive and #tools.explosions == 1, "The final fuse tick must detonate")
        end },
        { "flying ropes share fractional item movement and deploy immediately", function()
            local world = World.new(20, 40, 16)
            local tools = ToolSystem.new(world)
            local rope = tools:throwRope(Player.new(72, 320))
            world.time = 1
            tools:updateRope(rope)
            world.time = 2
            tools:updateRope(rope)
            assert(rope.y == 296, "The rope's -11.4 velocity must pulse to twelve pixels on tick two")
            world:fill("solid", 0, 17, 20, 1)
            world.time = 3
            tools:updateRope(rope)
            assert(rope.deployed and #rope.segments == 1,
                "A ceiling rebound must create the hook and first rope segment in the same Step")
        end },
        { "paste bombs release when supporting terrain is destroyed", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 5, 0, 1, 20)
            local tools = ToolSystem.new(world)
            local bomb = tools:spawnBomb(72, 72, { vx = 8, sticky = true })
            world.time = 1
            tools:updateBomb(bomb)
            assert(bomb.stuck, "The regression needs an actual pasted wall contact")
            world.solid = {}
            world.time = 2
            tools:updateBomb(bomb)
            assert(not bomb.stuck and bomb.vy == 0.6, "Paste must not freeze a bomb after its surface disappears")
        end },
        { "un-pasted bombs transfer an item impact without rebounding", function()
            local world = World.new(20, 20, 16)
            local tools = ToolSystem.new(world)
            local enemy = Creature.new({ kind = "caveman", x = 6, y = 5 })
            local bomb = tools:spawnBomb(enemy.x - 4, enemy.y - 8, { vx = 4 })
            world.time = 1
            tools:updateBomb(bomb, { enemy })
            assert(enemy.hp == 2 and enemy.vy == -6 and bomb.vx == 4,
                "An ordinary armed bomb inherits oItem damage and keeps its flight velocity")
            close(enemy.vx, 1.2, "Bomb contact impulse")
        end },
        { "damsels share heavy-object launch and bounce physics", function()
            local world = World.new(20, 20, 16)
            world:fill("solid", 0, 10, 20, 1)
            local player = Player.new(72, 120)
            player.vx = 2
            local damsel = Creature.new({ kind = "damsel", x = 4, y = 5 })
            damsel:pickup(player)
            assert(damsel.x == 76 and damsel.y == 128, "Held damsels must align their source origin to the player")
            damsel:throw(player, {}, world)
            assert(damsel.vx == 6 and damsel.vy == -2 and damsel.y == 124,
                "Damsels use the heavy throw speed and four-pixel release offset")
            damsel.y, damsel.vx, damsel.vy = 156, 2, 4
            world.time = 1
            damsel:step(world, player)
            close(damsel.vx, 0.6, "Thrown damsel floor friction")
            assert(damsel.vy == -2, "A thrown damsel must rebound on the landing tick")
        end },
    }
    local failures = {}
    for _, case in ipairs(cases) do
        local ok, message = pcall(case[2])
        if not ok then failures[#failures + 1] = case[1] .. ": " .. message end
    end
    assert(#failures == 0, table.concat(failures, "\n"))

    assert(Item.isCarryable("rock") and Item.isCarryable("crate")
        and not Item.isCarryable("gold_bars"),
        "Only source carry objects should enter the held-item simulation")
    local player = mockPlayer()
    local rock = Item.new({ kind = "rock", x = 4, y = 5 }, { width = 8, height = 8 })
    assert(rock:pickup(player), "Nearby carry objects must be pickable")
    assert(rock.x == player.x - 4 and rock.y == player.y + 2,
        "Light held objects must use the source's facing and standing offsets")

    player.state = Player.STATES.ducking
    player.vx = 0
    rock:updateHeldPosition(player)
    assert(rock.y == player.y + 4, "Light objects must lower while the player crouches")
    rock:throw(player, { down = true })
    assert(not rock.held and rock.vx == (-8 + player.vx) * 0.6 and rock.vy == 0.5,
        "Down plus attack must gently drop a light object")

    player.state = Player.STATES.standing
    for _, case in ipairs({ { "jar", 0, 4 }, { "skull", 0, 4 },
        { "die", -2, 0 }, { "gold_idol", 0, 2 } }) do
        local held = Item.new({ kind = case[1], x = 4, y = 5 })
        held:pickup(player)
        assert(held.y == player.y + case[2],
            case[1] .. " needs its original standing held offset")
        player.state = Player.STATES.ducking
        held:updateHeldPosition(player)
        assert(held.y == player.y + case[3],
            case[1] .. " needs its original crouched held offset")
        player.state = Player.STATES.standing
    end

    player.state = Player.STATES.standing
    player.facing = 1
    player.vx = 2
    local crate = Item.new({ kind = "crate", x = 4, y = 5 }, { width = 16, height = 16 })
    crate:pickup(player)
    assert(crate.x == player.x + 4 and crate.y == player.y - 4,
        "Heavy held objects must sit above the standing player")
    crate:throw(player, { up = true })
    assert(crate.vx == 6 and crate.vy == -4,
        "Up plus attack must use the source's heavy-object throw velocities")

    local throwWorld = World.new(12, 12, 16)
    throwWorld:set("solid", 4, 5)
    player.x, player.y, player.vx = 64, 80, 0
    local wallRock = Item.new({ kind = "rock", x = 4, y = 5 })
    wallRock:pickup(player)
    wallRock:throw(player, {}, throwWorld)
    assert(wallRock.x == player.x - 4,
        "Throwing beside a wall must move the held object away from that wall")
    throwWorld:remove("solid", 4, 5)
    throwWorld:set("solid", 4, 4)
    local ceilingRock = Item.new({ kind = "rock", x = 4, y = 5 })
    ceilingRock:pickup(player)
    ceilingRock:throw(player, {}, throwWorld)
    assert(ceilingRock.vx == 9 and ceilingRock.vy == 0,
        "Classic flattens a throw under a low ceiling without a pitcher's mitt")
    throwWorld:remove("solid", 4, 4)
    player.equipment.mitt = true
    local mittRock = Item.new({ kind = "rock", x = 4, y = 5 })
    mittRock:pickup(player)
    mittRock:throw(player, {}, throwWorld)
    assert(mittRock.vx == 14 and mittRock.vy == -0.4
        and mittRock.gravity == 0.1,
        "The mitt must add six horizontal speed and reduce thrown-item gravity")
    player.equipment.mitt = false

    local jumpWorld = World.new(12, 12, 16)
    jumpWorld:fill("solid", 0, 5, 12, 1)
    local lockedJumper = Player.new(64, 72)
    lockedJumper.state = Player.STATES.standing
    lockedJumper.cantJumpTimer = 2
    for _ = 1, 3 do lockedJumper:step(jumpWorld, { jump = true }) end
    assert(lockedJumper.state ~= Player.STATES.jumping and lockedJumper.vy >= 0,
        "Holding jump through mattock recovery must not queue an automatic jump")
    lockedJumper:step(jumpWorld, {})
    lockedJumper:step(jumpWorld, { jump = true })
    assert(lockedJumper.vy < 0,
        "Jumping must resume on a fresh press after mattock recovery")

    local pistol = Item.new({ kind = "pistol", x = 4, y = 5 }, { width = 16, height = 8 })
    pistol:pickup(player)
    pistol:dropWeapon(player)
    assert(not pistol.held and pistol.vx == (8 + player.vx) * 0.4 and pistol.vy == 0.5,
        "Down plus attack must use the source's weapon drop velocities")

    local wallWorld = World.new(12, 12, 16)
    wallWorld:fill("solid", 5, 0, 1, 12)
    local thrownJar = Item.new({ kind = "jar", x = 4.5, y = 4.5 },
        { width = 16, height = 16 })
    thrownJar.vx = 8
    thrownJar:update(wallWorld, player)
    assert(thrownJar.justHit,
        "A jar thrown faster than three pixels per step must break on a wall")

    local trapArrow = Item.new({ kind = "arrow", x = 4.5, y = 4.5 })
    trapArrow.vx = 8
    trapArrow:update(wallWorld, player)
    assert(not trapArrow.stuck and trapArrow.vx == -4,
        "A normal-speed arrow must rebound: Classic checks sticking after halving impact speed")
    local overfastArrow = Item.new({ kind = "arrow", x = 4.5, y = 4.5 })
    overfastArrow.vx = 14
    overfastArrow:update(wallWorld, player)
    assert(overfastArrow.stuck and overfastArrow.vx == 0,
        "An arrow still sticks when its post-impact speed exceeds six")

    local restingWorld = World.new(12, 12, 16)
    restingWorld:fill("solid", 0, 6, 12, 1)
    local restingArrow = Item.new({ kind = "arrow", x = 4.5, y = 5.75 })
    restingArrow.vx = 0.000244140625
    restingArrow:update(restingWorld, player)
    assert(restingArrow.vx == 0,
        "A resting item must lose residual horizontal velocity on every grounded tick")
    local fallingArrow = Item.new({ kind = "arrow", x = 4.5, y = 3.5 })
    fallingArrow.vx, fallingArrow.vy = 2, 4
    for _ = 1, 90 do fallingArrow:update(restingWorld, player) end
    assert(fallingArrow.vx == 0 and fallingArrow.vy == 0
        and fallingArrow.arrowAngle == 0 and fallingArrow.y <= 6 * 16 - 4,
        ("A bounced arrow must settle (x=%.3f y=%.3f vx=%.3f vy=%.3f)")
            :format(fallingArrow.x, fallingArrow.y, fallingArrow.vx, fallingArrow.vy))

    local webWorld = World.new(12, 12, 16)
    webWorld:set("web", 5, 5)
    local webRock = Item.new({ kind = "rock", x = 4.5, y = 5.5 })
    webRock.vx = 12
    webRock:update(webWorld, player)
    assert(webRock.x > 72 and webRock.vx == 0 and webRock.vy == 0,
        "A thrown carryable must stop when it enters a web")
    local webGem = Treasure.new({ kind = "ruby_big", x = 4.5, y = 5.5 })
    webGem.vx = 12
    webGem:update(webWorld)
    assert(webGem.x > 72 and webGem.vx == 0 and webGem.vy == 0,
        "Loose treasure must obey the same web collision as a carryable")
    local webTools = ToolSystem.new(webWorld, Player.TICK_RATE)
    local webBomb = webTools:throwBomb(Player.new(72, 88))
    webBomb.vx, webBomb.vy = 12, 0
    local fuse = webBomb.timer
    webTools:updateBomb(webBomb)
    webTools:updateBomb(webBomb)
    assert(webBomb.x > 72 and webBomb.vx == 0 and webBomb.vy == 0
        and webBomb.timer == fuse - 2,
        "A bomb caught in a web must stop moving without pausing its fuse")
    webWorld:remove("web", 5, 5)
    webWorld.dynamicWebs[1] = { x = 80, y = 80 }
    local dynamicWebRock = Item.new({ kind = "rock", x = 5.5, y = 5.5 })
    dynamicWebRock.vx = 8
    dynamicWebRock:update(webWorld, player)
    assert(dynamicWebRock.x == 96 and dynamicWebRock.vx == 0,
        "A placed web must stop carryables after their Step movement")

    for _, direction in ipairs({ -1, 1 }) do
        local trapWorld = World.new(12, 12, 16)
        trapWorld:set("solid", 4, 4)
        local traps = TrapSystem.new(trapWorld, {})
        traps:fireArrow({ x = 64, y = 64, fired = false }, direction)
        traps:updateProjectile(traps.projectiles[1], Player.new(160, 160), {}, {})
        assert(traps.projectiles[1].alive and #traps.projectiles == 1,
            "An arrow must clear its own trap instead of colliding with the firing tile")
    end

    local ceilingWorld = World.new(12, 12, 16)
    ceilingWorld:fill("solid", 0, 3, 12, 1)
    local risingJar = Item.new({ kind = "jar", x = 4.5, y = 4.5 },
        { width = 16, height = 16 })
    risingJar.vy = -9
    risingJar:update(ceilingWorld, player)
    assert(risingJar.justHit,
        "A jar thrown upward faster than three pixels per step must break on a ceiling")

    local floorWorld = World.new(12, 12, 16)
    floorWorld:set("solid", 4, 9)
    for _, kind in ipairs({ "jar", "mattock" }) do
        local item = Item.new({ kind = kind, x = 4.5, y = 8.625 },
            { width = 16, height = kind == "mattock" and 12 or 16 })
        for _ = 1, 12 do item:update(floorWorld, player) end
        assert(item.y == 8 * 16 + 10,
            kind .. " must settle with its six-pixel lower collision bound on the floor")
    end

    local lowCeiling = World.new(12, 12, 16)
    lowCeiling:set("solid", 4, 7)
    for _, kind in ipairs({ "chest", "locked_chest", "crate", "die" }) do
        local item = Item.new({ kind = kind, x = 4.5, y = 8.5 },
            { width = 16, height = 16 })
        item.vy = -2
        item:update(lowCeiling, player)
        assert(item.y < 8 * 16 + 8,
            kind .. " must use Classic's source collision mask below an overhead block")
    end

    local triggerCases = {
        { "enemy", function(_, enemies)
            local snake = Enemy.new("snake", 80, 56, { seed = 11 })
            snake.vx = 1
            enemies[1] = snake
        end },
        { "partially overlapping enemy", function(_, enemies)
            local snake = Enemy.new("snake", 80, 70, { seed = 12 })
            snake.vx = 1
            enemies[1] = snake
        end },
        { "thrown rock", function(_, _, items)
            local thrown = Item.new({ kind = "rock", x = 5, y = 3.5 })
            thrown.vx = 8
            items[1] = thrown
        end },
        { "loose treasure", function(_, _, _, extras)
            local gem = Treasure.new({ kind = "ruby_big", x = 5, y = 3.5 })
            gem.vy = 1
            extras[1] = gem
        end },
        { "thrown bomb", function(world, _, _, extras)
            local tools = ToolSystem.new(world, Player.TICK_RATE)
            local bomb = tools:throwBomb(Player.new(80, 56))
            bomb.x, bomb.y = 80, 56
            extras[1] = bomb
        end },
        { "thrown rope", function(world, _, _, extras)
            local tools = ToolSystem.new(world, Player.TICK_RATE)
            local rope = tools:throwRope(Player.new(80, 56))
            rope.x, rope.y = 80, 56
            extras[1] = rope
        end },
        { "moving push block", function(world)
            world:addDynamicSolid({ kind = "push_block", x = 72, y = 48,
                moveable = true, vx = 1 })
        end },
    }
    for _, case in ipairs(triggerCases) do
        local beamWorld = World.new(14, 9, 16)
        beamWorld:set("solid", 2, 3)
        local trap = TrapSystem.new(beamWorld, { entities = {
            { kind = "arrow_trap_right", x = 2, y = 3 },
        } })
        local enemies, items, extras = {}, {}, {}
        case[2](beamWorld, enemies, items, extras)
        trap:update(Player.new(8, 8), enemies, items, extras)
        assert(trap.traps[1].fired and #trap.projectiles == 1,
            "A moving " .. case[1] .. " must trigger the arrow trap")
    end
    local stillWorld = World.new(14, 9, 16)
    stillWorld:set("solid", 2, 3)
    local stillTrap = TrapSystem.new(stillWorld, { entities = {
        { kind = "arrow_trap_right", x = 2, y = 3 },
    } })
    stillTrap:update(Player.new(8, 8), {
        Enemy.new("snake", 80, 56, { seed = 13 }),
    }, {}, {})
    assert(not stillTrap.traps[1].fired,
        "A motion-sensing arrow trap must ignore an unmoving enemy")
end

return Test
