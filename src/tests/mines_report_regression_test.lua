local Item = require("src.platform.item")
local Player = require("src.platform.player")
local World = require("src.platform.world")
local GeneratedWorld = require("src.platform.generated_world")
local TrapSystem = require("src.platform.trap_system")
local ProjectileSystem = require("src.platform.projectile_system")
local FakeBones = require("src.platform.fake_bones")
local Effects = require("src.platform.effects")
local DepthQueue = require("src.render.depth_queue")

local Test = {}

function Test.run(app)
    local floor = World.new(12, 12, 16)
    floor:fill("solid", 0, 8, 12, 1)
    local player = Player.new(32, 80)
    local idol = Item.new({ kind = "gold_idol", x = 4, y = 7.75 })
    assert(idol:getCollisionHalfWidth() == 4
        and select(2, idol:getVerticalBounds()) == 4,
        "The idol must use Classic's four-pixel collision bounds")
    for _ = 1, 30 do idol:update(floor, player) end
    assert(idol.y == 124 and idol.vy == 0,
        "An idol dropped on a floor must settle without an endless bounce")

    local skullWorld = World.new(12, 12, 16)
    skullWorld:fill("solid", 5, 0, 1, 12)
    local skull = Item.new({ kind = "skull", x = 4.5, y = 4.5 })
    skull.vx = 8
    skull:update(skullWorld, player)
    assert(skull.justHit, "A thrown skull must break on a fast wall impact")
    local skullEffects = Effects.new(17)
    skullEffects:skullBreak(skull.x, skull.y)
    assert(#skullEffects.particles >= 2
        and skullEffects.particles[1].kind == "smoke"
        and skullEffects.particles[2].kind == "bone",
        "A smashed skull must produce the original smoke and bone fragments")
    local bone = skullEffects.particles[2]
    local initialVy = bone.vy
    skullEffects:update(skullWorld)
    assert(bone.vy > initialVy,
        "Bone fragments from a smashed skull must fall without crashing the next simulation tick")

    local level = { width = 12, height = 12, tileSize = 16, entities = {
        { kind = "giant_tiki_head", x = 5, y = 5 },
        { kind = "spikes", x = 7, y = 3 },
    }, tiles = {} }
    for y = 1, 12 do
        level.tiles[y] = {}
        for x = 1, 12 do level.tiles[y][x] = { kind = "empty" } end
    end
    local boulderWorld = GeneratedWorld.fromLevel(level)
    assert(not boulderWorld:has("solid", 5, 5),
        "Classic's tiki head is decorative and must not trap its own boulder")
    boulderWorld:set("solid", 7, 4)
    level.tiles[5][8] = { kind = "brick" }
    local traps = TrapSystem.new(boulderWorld, level)
    local boulder = { x = 96, y = 72, vx = 4.5, vy = 0, alive = true, bounced = true }
    traps:updateBoulder(boulder, Player.new(16, 16), {})
    assert(not boulderWorld:has("solid", 7, 4),
        "A moving boulder must crush a destructible brick in its path")
    local crushedSpikes = level.entities[2]
    assert(crushedSpikes.destroyed,
        "Crushing a brick must remove the spikes attached directly above it")
    local movingSupportWorld = World.new(12, 12, 16)
    local movingSpikes = { kind = "spikes", x = 7, y = 3 }
    movingSupportWorld.level = { entities = { movingSpikes } }
    local movingBlock = movingSupportWorld:addDynamicSolid({
        x = 7 * 16, y = 4 * 16, kind = "push_block", moveable = true,
    })
    local movingSupportTraps = TrapSystem.new(movingSupportWorld, { entities = {} })
    movingSupportTraps:updateBoulder({ x = 96, y = 72, vx = 4.5, vy = 0,
        alive = true, bounced = true }, Player.new(16, 16), {})
    assert(not movingBlock.alive and movingSpikes.destroyed,
        "A boulder must also remove spikes above a crushed push block")
    boulderWorld:set("solid", 8, 4)
    level.tiles[5][9] = { kind = "brick", properties = { invincible = true } }
    boulder.x, boulder.vx = 112, 4.5
    traps:updateBoulder(boulder, Player.new(16, 16), {})
    assert(boulderWorld:has("solid", 8, 4) and boulder.vx < 0,
        "The boulder must rebound from an invincible wall without deleting it")
    traps:loadAssets()
    traps.traps[1].state = "fired"
    traps.boulders = { boulder }
    local drawn, originalDraw = {}, love.graphics.draw
    love.graphics.draw = function(image, ...)
        drawn[#drawn + 1] = image
        return originalDraw(image, ...)
    end
    local drawOk, drawError = pcall(function()
        local queue = DepthQueue.new()
        traps:submit(queue)
        queue:draw()
    end)
    love.graphics.draw = originalDraw
    assert(drawOk, drawError)
    assert(drawn[1] == traps.assets.tikiHole and drawn[2] ~= traps.assets.boulder,
        "A fired tiki head must show its hole while the moving boulder rotates")

    local arrowWorld = World.new(12, 12, 16)
    arrowWorld:fill("solid", 5, 0, 1, 12)
    local arrowTraps = TrapSystem.new(arrowWorld, { entities = {} })
    local trapArrow = { kind = "arrow", x = 74, y = 72, vx = 8, vy = 0,
        direction = 1, alive = true }
    local trapItems = {}
    arrowTraps:updateProjectile(trapArrow, Player.new(16, 16), {}, trapItems)
    assert(#trapItems == 1 and trapItems[1].kind == "arrow",
        "A trap arrow must become a persistent physical item after hitting terrain")
    assert(not arrowWorld:collidesSolid(trapItems[1], trapItems[1].x, trapItems[1].y),
        "A trap arrow must become physical outside the wall so it can rebound")
    assert(trapItems[1].vx == -4 and trapItems[1].gravity == 0.6 and trapItems[1].safeTimer == 0,
        "The wall rebound must preserve oItem's reversed velocity and leave the trap arrow unsafe")
    local bow = ProjectileSystem.new(arrowWorld)
    local bowArrow = bow:spawn("arrow", 74, 72, 10, 0, player,
        { damage = 2, gravity = 0.12, radius = 3, life = 90 })
    local bowItems = {}
    bow:update({}, player, bowItems)
    assert(not bowArrow.alive and #bowItems == 1 and bowItems[1].kind == "arrow",
        "A bow arrow must become a persistent physical item after hitting terrain")
    assert(not arrowWorld:collidesSolid(bowItems[1], bowItems[1].x, bowItems[1].y),
        "A bow arrow must become physical outside the wall so it can rebound")
    local idleArrow = ProjectileSystem.new(World.new(12, 12, 16))
    local arrowInFlight = idleArrow:spawn("arrow", 48, 48, 0, 0, player,
        { life = 1, gravity = 0 })
    idleArrow:update({}, player)
    idleArrow:update({}, player)
    assert(arrowInFlight.alive,
        "Arrows must not disappear when an arbitrary projectile lifetime expires")

    local screen = app.screens.full_level_playtest
    if screen and screen.player and screen.world then
        local priorPlayer, priorSpikes = screen.player, screen.spikeEntities
        local spikePlayer = Player.new(crushedSpikes.x * 16 + 8, crushedSpikes.y * 16 + 8)
        spikePlayer.vy, spikePlayer.fallTimer = 3, 5
        screen.player, screen.spikeEntities = spikePlayer, { crushedSpikes }
        screen:checkSpikes()
        screen.player, screen.spikeEntities = priorPlayer, priorSpikes
        assert(not spikePlayer:isDead(),
            "A destroyed spike must no longer impale the player")

        local heard, originalSounds = {}, screen.sounds
        screen.sounds = { play = function(_, cue) heard[#heard + 1] = cue end }
        for _, sample in ipairs({
            { kind = "gold_bar", cue = "coin" },
            { kind = "ruby_big", cue = "gem" },
            { kind = "bomb_bag", cue = "pickup" },
        }) do
            screen.items, screen.collectibles = {}, {}
            screen:spawnEntity(sample.kind, screen.player.x, screen.player.y)
            if sample.kind ~= "bomb_bag" then screen.collectibles[1].pickupDelay = 0 end
            screen:checkCollectibles()
            if sample.kind == "bomb_bag" then screen:pickupNearestItem() end
            assert(heard[#heard] == sample.cue,
                "Mines treasure and supplies must play their Classic pickup sound")
        end
        screen.sounds = originalSounds

        local bones = FakeBones.new({ kind = "fake_bones", x = 4, y = 5 })
        bones.phase, bones.frame = "rising", 6
        screen.fakeBones = { bones }
        local spawnEntity = screen.spawnEntity
        local skeletonSpawn
        screen.spawnEntity = function(self, kind, x, y, properties)
            if kind == "skeleton" then skeletonSpawn = { x = x, y = y } end
            return spawnEntity(self, kind, x, y, properties)
        end
        screen:simulationStep()
        screen.spawnEntity = nil
        assert(skeletonSpawn and skeletonSpawn.x == bones.x + 8
            and skeletonSpawn.y == bones.y + 16,
            "The awakened skeleton must inherit the bones' top-left origin, not spawn inside a block")
        screen:buildSimulation()
    end
end

return Test
