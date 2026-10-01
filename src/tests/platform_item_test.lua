local Item = require("src.platform.item")
local Player = require("src.platform.player")
local TrapSystem = require("src.platform.trap_system")
local World = require("src.platform.world")

local Test = {}

local function mockPlayer()
    local player = Player.new(64, 80)
    player.state = Player.STATES.standing
    player.facing = -1
    player.vx = 1
    return player
end

function Test.run()
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
    player.facing = 1
    player.vx = 2
    local crate = Item.new({ kind = "crate", x = 4, y = 5 }, { width = 16, height = 16 })
    crate:pickup(player)
    assert(crate.x == player.x + 4 and crate.y == player.y - 4,
        "Heavy held objects must sit above the standing player")
    crate:throw(player, { up = true })
    assert(crate.vx == 6 and crate.vy == -4,
        "Up plus attack must use the source's heavy-object throw velocities")

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
end

return Test
