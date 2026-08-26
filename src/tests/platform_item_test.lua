local Item = require("src.platform.item")
local Player = require("src.platform.player")

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
    assert(Item.rendersBehindTerrain("rock") and Item.rendersBehindTerrain("gold_bars")
        and not Item.rendersBehindTerrain("snake"),
        "Loose oItem descendants must render behind terrain without moving enemies there")

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
end

return Test
