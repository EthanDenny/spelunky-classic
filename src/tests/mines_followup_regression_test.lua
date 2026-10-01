local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local Treasure = require("src.platform.treasure")
local TrapSystem = require("src.platform.trap_system")
local World = require("src.platform.world")
local DepthQueue = require("src.render.depth_queue")

local Test = {}

local function level()
    local result = { width = 12, height = 12, tileSize = 16,
        tiles = {}, entities = {}, decorations = {}, backdrops = {} }
    for y = 1, 12 do
        result.tiles[y] = {}
        for x = 1, 12 do result.tiles[y][x] = { kind = "empty" } end
    end
    return result
end

function Test.run(app)
    local openWorld = World.new(12, 12, 16)
    local gem = Treasure.new({ kind = "emerald_big", x = 4.5, y = 4.5 }, false)
    gem:update(openWorld)
    gem:update(openWorld)
    gem:update(openWorld)
    assert(gem.y > 72, "Generated gems must start active and fall in empty space")

    local floor = World.new(12, 12, 16)
    floor:set("solid", 4, 6)
    local settled = Treasure.new({ kind = "ruby_big", x = 4.5, y = 5.75 }, true)
    for _ = 1, 8 do settled:update(floor) end
    floor:remove("solid", 4, 6)
    local before = settled.y
    for _ = 1, 4 do settled:update(floor) end
    assert(settled.y > before, "A gem must fall when its supporting tile is destroyed")

    local barsFloor = World.new(12, 12, 16)
    barsFloor:set("solid", 4, 9)
    local bars = Treasure.new({ kind = "gold_bars", x = 4.5, y = 8.5 }, false)
    for _ = 1, 12 do bars:update(barsFloor) end
    assert(bars.y == 8 * 16 + 8,
        "Gold bars must rest on top of a brick instead of sinking four pixels into it")

    local boulderWorld = World.new(12, 12, 16)
    local traps = TrapSystem.new(boulderWorld, { entities = {} })
    local boulder = { x = 80, y = 80, vx = 0.5, vy = 0, alive = true, bounced = true }
    local player = Player.new(16, 16)
    traps:updateBoulder(boulder, player, {})
    traps:updateBoulder(boulder, player, {})
    assert(boulder.x > 80,
        "A slowly rolling boulder must keep fractional movement instead of spinning in place")
    local runway = World.new(12, 12, 16)
    runway:fill("solid", 0, 6, 12, 1)
    local rolling = TrapSystem.new(runway, { entities = {} })
    local supportedBoulder = { x = 80, y = 80, vx = 4.5, vy = 0,
        alive = true, bounced = true }
    rolling:updateBoulder(supportedBoulder, player, {})
    assert(supportedBoulder.vx < 4.5,
        "A grounded boulder must apply Classic's 0.99 rolling friction every tick")

    local scene = level()
    scene.tiles[7][5] = { kind = "brick" }
    scene.decorations[1] = { kind = "cave_top", x = 4, y = 5, variant = 1 }
    local altar = { kind = "altar_left", x = 6, y = 6 }
    scene.entities[1] = altar
    local world = GeneratedWorld.fromLevel(scene)
    world:destroyTerrain(4 * 16 + 8, 6 * 16 + 8, 0)
    assert(#scene.decorations == 0,
        "Destroyed terrain must remove the cave lip attached above that tile")
    world:destroyTerrain(6 * 16 + 8, 6 * 16 + 8, 0)
    assert(not world:has("solid", 6, 6), "The boulder must remove an altar's collision cell")
    local renderer = app.screens.world_generation
    renderer:loadAssets()
    local drawn = {}
    local drawEntity = renderer.drawEntity
    renderer.drawEntity = function(_, entity) drawn[#drawn + 1] = entity.kind end
    local ok, err = pcall(function()
        local queue = DepthQueue.new()
        renderer:submitLevel(queue, scene)
        queue:draw()
    end)
    renderer.drawEntity = drawEntity
    assert(ok, err)
    assert(#drawn == 0,
        "An altar face must disappear when the boulder destroys its solid object")
end

return Test
