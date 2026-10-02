local DynamicTerrain = require("src.platform.dynamic_terrain")
local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local ToolSystem = require("src.platform.tool_system")
local TrapSystem = require("src.platform.trap_system")
local World = require("src.platform.world")

local Test = {}

local function emptyLevel(width, height)
    local level = { width = width, height = height, tileSize = 16, entities = {}, entrance = { x = 1, y = 1 }, tiles = {} }
    for y = 1, height do
        level.tiles[y] = {}
        for x = 1, width do level.tiles[y][x] = { kind = "empty" } end
    end
    return level
end

function Test.run()
    do
        local level = emptyLevel(8, 6)
        for x = 1, 8 do level.tiles[6][x] = { kind = "brick" } end
        level.tiles[5][4] = { kind = "push_block" }
        local world = GeneratedWorld.fromLevel(level)
        local player = Player.new(3 * 16 - 5, 5 * 16 - 8)
        player.state = Player.STATES.standing
        assert(world:tryPush(player, 1), "A generated push block must accept player pressure")
        for _ = 1, 16 do DynamicTerrain.update(world) end
        local block = world.dynamicSolids[1]
        assert(block.x == 3 * 16 + 1, "Generated push blocks must retain the one-pixel displacement")
    end

    do
        local level = emptyLevel(8, 8)
        for y = 3, 7 do
            for x = 3, 7 do level.tiles[y][x] = { kind = "brick" } end
        end
        local world = GeneratedWorld.fromLevel(level)
        local tools = ToolSystem.new(world, 30)
        tools:explode(5 * 16 + 8, 5 * 16 + 8)
        assert(not world:has("solid", 5, 5), "Bomb explosions must destroy their center tile")
        assert(world:has("solid", 3, 3), "Bomb explosions must not erase distant terrain")
    end

    do
        local level = emptyLevel(12, 5)
        level.entities[1] = { kind = "arrow_trap_right", x = 2, y = 2, properties = {} }
        local world = GeneratedWorld.fromLevel(level)
        local traps = TrapSystem.new(world, level, {})
        local player = Player.new(5 * 16, 2 * 16 + 8)
        player.vx = 1
        traps:update(player, {}, {})
        assert(#traps.projectiles == 1 and traps.projectiles[1].vx == 8,
            "Arrow traps must fire once into a moving target within 96 pixels")
    end

    do
        local level = emptyLevel(5, 5)
        level.tiles[2][3] = { kind = "brick" }
        local world = GeneratedWorld.fromLevel(level)
        local tools = ToolSystem.new(world, 30)
        local player = Player.new(2 * 16 + 8, 2 * 16 + 8)
        assert(not tools:throwRope(player, {}),
            "Upward ropes must not be consumed when the player has no headroom")
    end

    do
        local world = World.new(10, 12, 16)
        local tools = ToolSystem.new(world, 30)
        local player = Player.new(40, 43)
        player.facing = 1
        world:set("solid", 3, 2)
        assert(not tools:throwRope(player, { down = true }) and #tools.ropes == 0,
            "A blocked side placement must not deploy or spend a rope")

        world:remove("solid", 3, 2)
        world:set("solid", 3, 3)
        local outerRope = tools:throwRope(player, { down = true })
        assert(outerRope and outerRope.x == 72,
            "Downward placement must try the far half-cell when the near edge is blocked")
        world:remove("solid", 3, 3)
        local rope = tools:throwRope(player, { down = true })
        assert(rope and rope.deployed and rope.x == 56 and rope.y == 43,
            "Downward rope hooks must snap horizontally but retain the player's pixel height")
        for _ = 1, 12 do tools:update(player, {}, {}) end
        assert(#rope.segments == 12 and world:climbableAtPoint(rope.x, 112) == "rope",
            "Deployed ropes must grow into a climbable body")
        local climber = Player.new(rope.x, 112)
        for _ = 1, 4 do climber:step(world, { up = true }) end
        assert(climber.state == Player.STATES.climbing and climber.climbKind == "rope",
            "The player must be able to grab and climb a deployed rope")
    end

    do
        local level = emptyLevel(10, 10)
        level.area = "mines"
        level.entities[1] = { kind = "giant_tiki_head", x = 5, y = 2, properties = {} }
        local world = GeneratedWorld.fromLevel(level)
        local traps = TrapSystem.new(world, level, {})
        local player = Player.new(5 * 16, 6 * 16)
        traps:triggerIdol(player)
        for _ = 1, 100 do traps:update(player, {}, {}) end
        assert(#traps.boulders == 1, "Mines idols must release their giant-tiki boulder after 100 ticks")
    end
end

return Test
