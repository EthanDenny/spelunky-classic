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
        assert(world:tryPush(player, 1), "A clear push block must begin moving")
        for _ = 1, 16 do DynamicTerrain.update(world, player) end
        local block = world.dynamicSolids[1]
        assert(block.x == 4 * 16, "Push blocks must travel exactly one tile per push")
    end

    do
        local world = World.new(20, 14, 16)
        world:fill("solid", 0, 10, 20, 4)
        local player = Player.new(88, 152)
        local block = world:addDynamicSolid({
            x = 80, y = 96, width = 16, height = 16,
            kind = "falling", falling = true, vy = 0,
        })
        for _ = 1, 20 do DynamicTerrain.update(world, player) end
        assert(player.health == 4 and block.alive and block.y == 128,
            "A falling oMovingSolid must stop before pushing the player into the floor")
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
        local level = emptyLevel(10, 10)
        level.area = "mines"
        level.entities[1] = { kind = "giant_tiki_head", x = 5, y = 2, properties = {} }
        local world = GeneratedWorld.fromLevel(level)
        local traps = TrapSystem.new(world, level, {})
        local player = Player.new(5 * 16, 6 * 16)
        traps:triggerIdol(player, "mines")
        for _ = 1, 100 do traps:update(player, {}, {}) end
        assert(#traps.boulders == 1, "Mines idols must release their giant-tiki boulder after 100 ticks")
    end
end

return Test
