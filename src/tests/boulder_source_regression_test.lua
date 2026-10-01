local Player = require("src.platform.player")
local TrapSystem = require("src.platform.trap_system")
local World = require("src.platform.world")

local Test = {}

local function boulder(x, y, vx, vy)
    return { x = x, y = y, vx = vx, vy = vy, alive = true, bounced = true }
end

function Test.run()
    local player = Player.new(16, 16)
    local open = World.new(40, 20, 16)
    local traps = TrapSystem.new(open, { entities = {} })
    local falling = boulder(160, 80, 0, 0)
    traps:updateBoulder(falling, player, {})
    assert(falling.y == 80 and falling.vy == 0.6,
        "Classic moves the boulder before adding gravity, so it does not fall on its first tick")

    -- The oMovingSolid pass and oBoulder's own moveTo each consume xVel.
    open.time = 2
    local rolling = boulder(160, 80, 4.5, 0)
    traps:updateBoulder(rolling, player, {})
    assert(rolling.x == 170,
        "An unobstructed Classic boulder moves once in each of its two movement passes")

    local floor = World.new(40, 20, 16)
    floor:fill("solid", 0, 6, 40, 1)
    local floorTraps = TrapSystem.new(floor, { entities = {} })
    local nearStopped = boulder(160, 80, 0.25, 0)
    nearStopped.bounced = false
    floorTraps:updateBoulder(nearStopped, player, {})
    assert(nearStopped.vx == 0 and not nearStopped.bounced,
        "Classic zeros sub-half-pixel speed without launching the boulder again")
    floorTraps:updateBoulder(nearStopped, player, {})
    assert(nearStopped.vx == -4.5 and nearStopped.bounced,
        "Classic launches only when grounded speed is exactly zero")
    local dropping = boulder(160, 76, 0, 4)
    floorTraps:updateBoulder(dropping, player, {})
    assert(dropping.y == 80 and math.abs(dropping.vy + 1.38) < 0.000001,
        "Classic's fast floor impact bounces at 30 percent of post-gravity velocity")

    local wall = World.new(40, 20, 16)
    wall:set("solid", 7, 4)
    local wallTraps = TrapSystem.new(wall, { entities = {} })
    local crusher = boulder(96, 72, 4.5, 0)
    wallTraps:updateBoulder(crusher, player, {})
    assert(not wall:has("solid", 7, 4) and crusher.vx < 4.5,
        "Crushing an ordinary solid must cost the boulder 0.1 horizontal speed")

    local lip = World.new(40, 20, 16)
    lip:set("solid", 7, 5)
    local lipTraps = TrapSystem.new(lip, { entities = {} })
    local skimming = boulder(96, 66, 4.5, 0)
    lipTraps:updateBoulder(skimming, player, {})
    assert(lip:has("solid", 7, 5) and skimming.vx > 0 and skimming.y < 66,
        "A low floor lip is spared and nudges the rolling boulder upward instead of reversing it")

    local movableLip = World.new(40, 20, 16)
    local lipBlock = movableLip:addDynamicSolid({ x = 7 * 16, y = 5 * 16,
        kind = "push_block", moveable = true })
    local movableTraps = TrapSystem.new(movableLip, { entities = {} })
    local skimmingBlock = boulder(96, 66, 4.5, 0)
    movableTraps:updateBoulder(skimmingBlock, player, {})
    assert(lipBlock.alive and skimmingBlock.vx > 0 and skimmingBlock.y < 66,
        "Classic also spares a low moveable-solid lip")

    local ceiling = World.new(40, 20, 16)
    ceiling:set("solid", 10, 2)
    local ceilingTraps = TrapSystem.new(ceiling, { entities = {} })
    local rising = boulder(168, 64, 0, -4)
    ceilingTraps:updateBoulder(rising, player, {})
    assert(math.abs(rising.vy - 2.72) < 0.000001,
        "Classic rebounds from a ceiling at 80 percent after the movement and gravity phases")

    local edge = boulder(33, 80, -2, 0)
    traps:updateBoulder(edge, player, {})
    assert(edge.vx > 0,
        "Classic reverses a boulder that crosses the inner room boundary")

    local nearPlayer = Player.new(177, 80)
    traps:updateBoulder(boulder(160, 80, 0, 0), nearPlayer, {})
    assert(nearPlayer.health > 0,
        "The player is crushed only when their center overlaps the boulder's solid bounds")

    local solidWorld = World.new(40, 20, 16)
    local solidTraps = TrapSystem.new(solidWorld, { entities = {} })
    solidTraps:spawnBoulder({ x = 160, y = 80 })
    local spawned = solidTraps.boulders[1]
    assert(solidWorld:solidAtPoint(160, 80),
        "A spawned Classic boulder is an oSolid collider, even while stationary")
    spawned.vx = 2
    spawned.bounced = true
    solidTraps:updateBoulder(spawned, player, {})
    assert(spawned.x > 160 and solidWorld:solidAtPoint(spawned.x, spawned.y),
        "The boulder collider must move with the sprite without blocking itself")

    solidTraps:spawnBoulder({ x = 198, y = 80 })
    spawned.vx = 4
    solidTraps:updateBoulder(spawned, player, {})
    assert(solidTraps.boulders[2].solid.alive and spawned.vx < 0,
        "A second boulder is invincible solid terrain to the first, not a crushable block")

    local carryWorld = World.new(40, 20, 16)
    local carryTraps = TrapSystem.new(carryWorld, { entities = {} })
    carryTraps:spawnBoulder({ x = 160, y = 80 })
    local carried = Player.new(160, 56)
    carryTraps.boulders[1].vx = 2
    carryTraps.boulders[1].bounced = true
    carryTraps:updateBoulder(carryTraps.boulders[1], carried, {})
    assert(carried.x == 162,
        "Classic's moving-solid pass carries the player standing on a rolling boulder")

    local pushWorld = World.new(40, 20, 16)
    local pushTraps = TrapSystem.new(pushWorld, { entities = {} })
    pushTraps:spawnBoulder({ x = 160, y = 80 })
    local pushed = Player.new(179, 80)
    pushTraps.boulders[1].vx = 2
    pushTraps.boulders[1].bounced = true
    pushTraps:updateBoulder(pushTraps.boulders[1], pushed, {})
    assert(pushed.x == 181 and pushed.health > 0,
        "Classic's moving-solid pass pushes an unobstructed player instead of crushing at contact")
end

return Test
