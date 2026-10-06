local ItemBody = require("src.platform.item_body")
local Effects = require("src.platform.effects")
local Enemy = require("src.platform.enemy")
local Creature = require("src.platform.creature")
local FakeBones = require("src.platform.fake_bones")
local Item = require("src.platform.item")
local ItemActions = require("src.platform.item_actions")
local FullLevelPlaytest = require("src.screens.full_level_playtest")
local Player = require("src.platform.player")
local Treasure = require("src.platform.treasure")
local World = require("src.platform.world")
local ToolSystem = require("src.platform.tool_system")
local RunState = require("src.game.run_state")

local Test = {}

local function jarSeedFor(kind, run)
    for seed = 1, 10000 do
        local probe = Item.new({ kind = "jar", x = 0, y = 0 })
        local rewards = probe:open(run, love.math.newRandomGenerator(seed))
        if rewards[1] and rewards[1].kind == kind then return seed end
    end
    error("No jar roll found for " .. kind)
end

function Test.run(app)
    local trappedSeed
    for seed = 1, 100 do
        if love.math.newRandomGenerator(seed):random(1, 12) == 1 then
            trappedSeed = seed
            break
        end
    end
    assert(trappedSeed, "A trapped-chest seed must exist in the test range")
    local chestGame = FullLevelPlaytest.new(app)
    chestGame.world = World.new(12, 12, 16)
    chestGame.tools = ToolSystem.new(chestGame.world, Player.TICK_RATE)
    chestGame.effects = Effects.new(trappedSeed)
    chestGame.run = RunState.new(trappedSeed)
    chestGame.sounds = { play = function() end }
    local chest = Item.new({ kind = "chest", x = 5, y = 5 })
    local chestX, chestY = chest.x, chest.y
    assert(chestGame:openContainer(chest) and chest.opened
        and chest.x == chestX and chest.y == chestY
        and #chestGame.tools.bombs == 1 and chestGame.tools.bombs[1].timer == 40,
        "A trapped chest must stay open in place and arm its bomb for 40 Classic ticks")

    local world = World.new(20, 16, 16)
    world:fill("solid", 0, 12, 20, 4)
    local gem = Treasure.new({ kind = "emerald_big", x = 5, y = 5 }, true)
    local initialY = gem.y
    for _ = 1, 4 do gem:update(world) end
    assert(gem.y > initialY and gem.entity.y == gem.y / 16,
        "A newly released jar gem must fall and update its rendered position")
    assert(gem.pickupDelay == 16, "New treasure must retain the original 20-step pickup delay")

    local effects = Effects.new(123)
    effects:jarBreak(80, 80)
    assert(#effects.particles == 4 and effects.particles[1].kind == "smoke",
        "Jar destruction must create a smoke puff and three rubble pieces")
    effects:blood(80, 80, 1)
    assert(effects.particles[5].kind == "blood", "Enemy blood must create a live particle")
    effects:blood(80, 80, 30)
    local bloodCount = 0
    for _, particle in ipairs(effects.particles) do
        if particle.kind == "blood" then bloodCount = bloodCount + 1 end
    end
    assert(bloodCount == 16, "Source blood creation must respect the 16-detritus limit")
    effects:update(world)
    assert(effects.particles[5].age == 1, "Feedback particles must advance in the simulation")

    do
        local collisionWorld = World.new(12, 12, 16)
        collisionWorld:fill("solid", 0, 10, 12, 2)
        collisionWorld:set("solid", 6, 9)
        collisionWorld:set("solid", 5, 5)
        local blood = Effects.new(7)
        local floorDrop = blood:add("blood", 80, 154, 0, 4)
        local wallDrop = blood:add("blood", 90, 152, 4, 0)
        local ceilingDrop = blood:add("blood", 80, 100, 0, -3)
        local fastDrop = blood:add("blood", 40, 100, 0, 5.9)
        floorDrop.gravity, wallDrop.gravity, ceilingDrop.gravity = 0.2, 0.2, 0.2
        fastDrop.gravity = 0.3
        collisionWorld.time = 1
        blood:update(collisionWorld)
        assert(floorDrop.y == 156 and floorDrop.vy < 0 and floorDrop.life == 20,
            "Blood must stop at the floor, bounce, and cap its remaining life at 20")
        assert(wallDrop.x == 92 and wallDrop.vx == -2,
            "Blood must stop at a wall before reflecting its horizontal velocity")
        assert(ceilingDrop.y == 100 and ceilingDrop.vy > 0,
            "Blood must bounce downward when it reaches a ceiling")
        assert(#blood.particles == 3,
            "Blood exceeding the source's six-pixel fall speed must disappear")

        local skulls = Effects.new(7)
        local skull = skulls:add("skull", 80, 156, 2, 0)
        skull.gravity = 0.6
        skulls:update(collisionWorld)
        assert(#skulls.particles == 1 and skull.vx == 0.6,
            "A gently landing skull must retain only 30 percent of its horizontal speed")
    end

    local screen = app.screens.full_level_playtest
    local jar = Item.new({ kind = "jar", x = 5, y = 5 }, { width = 16, height = 16 })
    jar.x = 81
    local oldCount = #screen.collectibles
    local oldParticles = #screen.effects.particles
    screen:openContainer(jar)
    assert(jar.opened, "Breaking a jar must consume it in the playtest")
    assert(#screen.effects.particles == oldParticles + 4,
        "The playtest's jar-break path must produce its visible fragments")
    -- Classic jars can be empty or contain a creature, so exercise actual
    -- break rolls until a treasure reward appears instead of assuming one.
    for _ = 1, 100 do
        if #screen.collectibles > oldCount then break end
        local nextJar = Item.new({ kind = "jar", x = 5, y = 5 })
        screen:openContainer(nextJar)
    end
    assert(#screen.collectibles > oldCount,
        "Jar break rolls must sometimes release a real collectible")
    local reward = screen.collectibles[#screen.collectibles]
    local delay = reward.kind:match("^gold_") and 0 or 20
    assert(reward.active and reward.pickupDelay == delay,
        "Jar treasure must use its own source collectible alarm")

    local webGame = FullLevelPlaytest.new(app)
    webGame.world = World.new(12, 12, 16)
    webGame.player = Player.new(64, 88)
    webGame.player.facing = 1
    webGame.player.whipping = true
    webGame.player.animationFrame = 5
    local web = { kind = "web", x = 5, y = 5, life = 12 }
    webGame.level = { entities = { web } }
    webGame.world:set("web", 5, 5, web)
    assert(webGame.player:whipOverlapsRectangle(80, 80, 96, 96),
        "The web regression needs an actual whip collision")
    webGame:checkWhip()
    assert(webGame.world:webAtPoint(88, 88) and not web.destroyed,
        "A single ordinary whip must not instantly remove a 12-life web")
    webGame.player.x, webGame.player.y = 88, 104
    webGame.player.attackKind = "machete"
    webGame.player.meleeFacing = 1
    webGame.items = {}
    webGame.enemies = {}
    webGame.sounds = { play = function() end }
    webGame.meleeItem = Item.new({ kind = "machete", x = 4.5, y = 5.5 })
    webGame.meleeItem.held = true
    ItemActions.updateMelee(webGame)
    assert(web.destroyed and not webGame.world:webAtPoint(88, 88),
        "Classic's machete slash must cut a web on contact")

    local collisionGame = FullLevelPlaytest.new(app)
    collisionGame.world = World.new(16, 12, 16)
    collisionGame.level = { entities = {} }
    collisionGame.renderer = app.renderer
    collisionGame.seed = 29
    collisionGame.items = {}
    collisionGame.collectibles = {}
    collisionGame.effects = Effects.new(29)
    collisionGame.run = RunState.new(29)
    collisionGame.sounds = { play = function() end }
    collisionGame.enemies = { Enemy.new("snake", 96, 80, { seed = 29 }) }
    local flyingJar = Item.new({ kind = "jar", x = 5.5, y = 5 })
    flyingJar.vx = 7
    flyingJar.x = 96
    ItemBody.resolveEnemyContacts(flyingJar, nil, collisionGame)
    assert(flyingJar.opened and #collisionGame.effects.particles >= 4,
        "A jar hitting an enemy must smash and emit its break particles")

    collisionGame.enemies = {}
    collisionGame.player = Player.new(96, 80)
    local fallingRock = Item.new({ kind = "rock", x = 6, y = 5 })
    collisionGame.items = { fallingRock }
    fallingRock.vy = 5
    fallingRock.safeTimer = 2
    local health = collisionGame.player.health
    collisionGame:resolveItemPlayerContact(fallingRock)
    assert(collisionGame.player.health == health,
        "A just-thrown object must remain harmless during its safe period")
    fallingRock.safeTimer = 0
    collisionGame:resolveItemPlayerContact(fallingRock)
    assert(collisionGame.player.health == health,
        "Classic ignores vertical rock speed for player damage")
    fallingRock.vx = 5
    collisionGame:resolveItemPlayerContact(fallingRock)
    assert(collisionGame.player.health == health-2,
        "A rock faster than four horizontally still deals two hearts")
    collisionGame.player = Player.new(96, 80)
    local slowRock = Item.new({ kind = "rock", x = 6, y = 5 })
    collisionGame.items = { slowRock }
    slowRock.vy = 3
    collisionGame:resolveItemPlayerContact(slowRock)
    assert(collisionGame.player.health == health,
        "A gently falling object must not damage the player")
    local movingArrow = Item.new({ kind = "arrow", x = 6, y = 5 })
    collisionGame.items = { movingArrow }
    movingArrow.vx = 5
    collisionGame:resolveItemPlayerContact(movingArrow)
    assert(movingArrow.opened and collisionGame.player.health == health - 2,
        "A fast arrow must hurt the player and be consumed on impact")

    local defeated = Enemy.new("snake", screen.player.x + 32, screen.player.y)
    defeated.alive = false
    screen.enemies[#screen.enemies + 1] = defeated
    screen:simulationStep()
    local deathBlood = 0
    for _, particle in ipairs(screen.effects.particles) do
        if particle.kind == "blood" and math.abs(particle.x - defeated.x) < 8
            and math.abs(particle.y - (defeated.y - 8)) < 8 then
            deathBlood = deathBlood + 1
        end
    end
    assert(deathBlood == 3,
        "A dead snake must emit three centered blood particles exactly once")

    local previousEnemies, previousEffects = screen.enemies, screen.effects
    local highTarget = Enemy.new("snake", screen.player.x + 16, screen.player.y - 7)
    local whipTarget = Enemy.new("snake", screen.player.x + 16, screen.player.y + 8)
    screen.enemies = { highTarget, whipTarget }
    screen.effects = Effects.new(41)
    screen.player.facing = 1
    screen.player.whipping = true
    screen.player.animationFrame = 5
    screen.player.whipHits = {}
    screen:checkWhip()
    assert(highTarget.alive,
        "The front whip must miss an enemy above its visible stroke")
    assert(not whipTarget.alive and #screen.effects.particles == 1,
        "A lethal whip must emit the source's single hit drop immediately")
    assert(screen.effects.particles[1].x == whipTarget.x
        and screen.effects.particles[1].y == whipTarget.y - 8,
        "The hit drop must start at the snake sprite's center")
    screen:simulationStep()
    assert(#screen.effects.particles == 4,
        "The same snake must emit three additional death drops")
    screen:simulationStep()
    assert(#screen.effects.particles == 4,
        "A defeated snake must not emit its death drops again")
    screen.player.whipping = false
    screen.enemies, screen.effects = previousEnemies, previousEffects

    local draw = love.graphics.draw
    local bloodySpikesDrawn = false
    local collectSkeleton, skeletonImage = false, nil
    local bloodySpike = { kind = "spikes", x = 2, y = 2, bloody = true }
    screen.level.entities[#screen.level.entities + 1] = bloodySpike
    love.graphics.draw = function(image, ...)
        if image == screen.spikeBloodImage then bloodySpikesDrawn = true end
        if collectSkeleton then skeletonImage = image end
        return draw(image, ...)
    end
    local ok, err = pcall(function()
        screen:drawWorld({ x = 0, y = 0, width = 320, height = 240,
            scale = 1, logicalWidth = 320, logicalHeight = 240 })
        collectSkeleton = true
        local skeleton = Creature.new({ kind = "skeleton", x = 4, y = 5, properties = {} },
            { width = 16, height = 16 })
        skeleton:draw(screen.renderer)
    end)
    love.graphics.draw = draw
    screen.level.entities[#screen.level.entities] = nil
    assert(ok, err)
    assert(skeletonImage and skeletonImage ~= screen.renderer.entitySprites.skeleton.image,
        "Awakened skeletons must draw a skeleton sprite, not the static bones image")
    assert(bloodySpikesDrawn, "Impaling spikes must display the source's blood-stained sprite")

    local player = screen.player
    player.state = "stunned"
    player.stunTimer = 20
    player.vx = -2
    player:updateAnimation(screen.world)
    assert(player.spriteName == "sDieLL",
        "Moving left while stunned must use the source's directional death pose")
    player.vx = 0
    player:updateAnimation(screen.world)
    assert(player.spriteName == "sStunL",
        "The original stun animation must start when horizontal motion stops")

    local awakeningWorld = World.new(12, 12, 16)
    awakeningWorld:fill("solid", 0, 6, 12, 1)
    local bones = FakeBones.new({ kind = "fake_bones", x = 4, y = 5 })
    local observer = Player.new(4 * 16 + 8, 5 * 16 + 8)
    local awoke = false
    for _ = 1, 7 do
        if bones:update(awakeningWorld, observer) then awoke = true end
    end
    assert(awoke and bones.phase == "done",
        "Only nearby fake bones must complete the skeleton-rise animation")

    local priorPlayer, priorSpikes = screen.player, screen.spikeEntities
    local impaled = Player.new(40, 30)
    impaled.vy = 5
    impaled.fallTimer = 5
    impaled.invincibleTimer = 60
    screen.player = impaled
    screen.spikeEntities = { { kind = "spikes", x = 2, y = 2 } }
    local particleCount = #screen.effects.particles
    screen:checkSpikes()
    assert(impaled:isDead() and impaled.vx == 0 and impaled.vy == 0
        and screen.spikeEntities[1].bloody
        and #screen.effects.particles == particleCount + 3,
        "A qualifying spike landing must impale immediately, stain the trap and emit three blood particles")
    local shortDrop = Player.new(40, 30)
    shortDrop.vy = 5
    shortDrop.fallTimer = 4
    screen.player = shortDrop
    screen:checkSpikes()
    assert(shortDrop.health == 4,
        "The original >4-frame threshold must leave a short drop unharmed")
    screen.player, screen.spikeEntities = priorPlayer, priorSpikes

    screen.world = World.new(50, 30, 16)
    screen.player = Player.new(80, 80)
    screen.spikeEntities = {}
    screen.fakeBones = {}
    screen.collectibles = {}
    local target = Creature.new({ kind = "caveman", x = 7, y = 5, properties = {} },
        { width = 16, height = 16 })
    local rock = Item.new({ kind = "rock", x = 7, y = 5 }, { width = 8, height = 8 })
    rock.x, rock.y, rock.vx, rock.vy, rock.safeTimer = target.x - 5, target.y - 8, 5, 0, 10
    screen.enemies = { target }
    screen.items = { rock }
    screen:simulationStepBody({})
    assert(target.hp == 2 and rock.safeTimer > 0,
        "A freshly thrown rock must damage an enemy during its thrower-safe period")

    local impactWorld = World.new(12, 12, 16)
    impactWorld:fill("solid", 5, 0, 1, 12)
    screen.world = impactWorld
    screen.player = Player.new(32, 80)
    screen.enemies = {}
    local wallJar = Item.new({ kind = "jar", x = 4.5, y = 5 },
        { width = 16, height = 16 })
    wallJar.vx = 8
    screen.items = { wallJar }
    screen:simulationStepBody({})
    local smoke, rubble = 0, 0
    for _, particle in ipairs(screen.effects.particles) do
        if math.abs(particle.x - 72) < 8 and math.abs(particle.y - 80) < 8 then
            if particle.kind == "smoke" then smoke = smoke + 1 end
            if particle.kind == "rubble" then rubble = rubble + 1 end
        end
    end
    assert(wallJar.opened and smoke >= 1 and rubble >= 3,
        "A thrown jar hitting a wall must open and emit fragments in the full playtest")

    local potCases = {
        { name = "right wall", x = 72, y = 79, vx = 8, vy = 0,
            solid = { 5, 0, 1, 12 } },
        { name = "left wall", x = 88, y = 79, vx = -8, vy = 0,
            solid = { 4, 0, 1, 12 } },
        { name = "ceiling", x = 390, y = 199, vx = -8.53, vy = -6,
            solid = { 23, 11, 1, 1 } },
        { name = "floor", x = 80, y = 89, vx = 0, vy = 4,
            solid = { 5, 6, 1, 1 } },
        { name = "wall-floor corner", x = 72, y = 89, vx = 8, vy = 4,
            solid = { 5, 0, 1, 12 }, floor = true },
        { name = "push block", x = 72, y = 79, vx = 8, vy = 0,
            block = { x = 80, y = 32, width = 16, height = 64 } },
    }
    for _, kind in ipairs({ "snake", "spider" }) do
        for _, case in ipairs(potCases) do
            local potWorld = World.new(32, 16, 16)
            potWorld:fill("solid", 0, 14, 32, 1)
            if case.solid then potWorld:fill("solid", unpack(case.solid)) end
            if case.floor then potWorld:fill("solid", 0, 6, 32, 1) end
            if case.block then potWorld:addDynamicSolid(case.block) end
            screen.world = potWorld
            screen.player = Player.new(32, 32)
            screen.enemies, screen.collectibles = {}, {}
            screen.effects = Effects.new(jarSeedFor(kind, screen.run))
            local pot = Item.new({ kind = "jar", x = case.x / 16, y = case.y / 16 })
            pot.vx, pot.vy = case.vx, case.vy
            screen.items = { pot }
            pot:update(potWorld, screen.player)
            assert(pot.justHit, "A " .. case.name .. " impact must break the pot")
            screen:processItemImpact(pot)
            assert(pot.opened and #screen.enemies == 1 and screen.enemies[1].kind == kind,
                "A " .. case.name .. "-broken pot must release its rolled " .. kind)
            local enemy = screen.enemies[1]
            assert(enemy.x > 0 and enemy.x < potWorld.width*16
                and enemy.y > 0 and enemy.y < potWorld.height*16,
                "A pot enemy must spawn in the level, not at the removed pot's offscreen location")
            assert(not potWorld:collidesSolid(enemy, enemy.x, enemy.y),
                "A " .. case.name .. "-broken pot must not create a " .. kind .. " inside terrain")
            local moved = false
            for tick = 1, 45 do
                potWorld.time = tick
                local oldX, oldY = enemy.x, enemy.y
                enemy:step(potWorld, screen.player)
                moved = moved or enemy.x ~= oldX or enemy.y ~= oldY
                assert(enemy.alive and not potWorld:collidesSolid(enemy, enemy.x, enemy.y),
                    "A released " .. kind .. " must remain alive and clear of the " .. case.name)
            end
            assert(moved, "A released " .. kind .. " must be able to move after the pot breaks")
        end
    end

    screen.world = World.new(32, 16, 16)
    screen.player = Player.new(144, 90)
    screen.player.facing, screen.player.whipping, screen.player.animationFrame = 1, true, 5
    screen.enemies, screen.collectibles = {}, {}
    screen.effects = Effects.new(jarSeedFor("spider", screen.run))
    local whippedPot = Item.new({ kind = "jar", x = 10, y = 90/16 })
    screen.items = { whippedPot }
    assert(screen.player:whipOverlapsRectangle(156, 84, 164, 96),
        "The unobstructed pot regression must begin with a real whip collision")
    screen:checkWhip()
    assert(whippedPot.opened and #screen.enemies == 1,
        "A real whip hit must smash the pot and release its spider")
    assert(screen.enemies[1].x == 160 and screen.enemies[1].y == 98,
        "An unobstructed pot spider must retain oJar's x-8/y-8 spawn converted to bottom-center")

    local gemWorld = World.new(32, 16, 16)
    gemWorld:set("solid", 23, 11)
    screen.world = gemWorld
    screen.player = Player.new(32, 32)
    screen.enemies = {}
    screen.collectibles = {}
    local gemPot = Item.new({ kind = "jar", x = 391 / 16, y = 199 / 16 })
    gemPot.vx, gemPot.vy = -8.53, -6
    screen.items = { gemPot }
    screen.effects = Effects.new(jarSeedFor("emerald_big", screen.run))
    gemPot:update(gemWorld, screen.player)
    screen:processItemImpact(gemPot)
    assert(gemPot.opened, "A ceiling impact must break the pot")
    assert(#screen.collectibles == 1, "A ceiling-broken pot must be able to release its gem")
    local releasedGem = screen.collectibles[1]
    assert(not gemWorld:collidesSolid(releasedGem, releasedGem.x, releasedGem.y),
        "A pot gem must spawn clear of the ceiling that broke its pot")

    local previousWorld, previousPlayer, previousDeathTimer =
        screen.world, screen.player, screen.deathTimer
    local deathWorld = World.new(12, 12, 16)
    deathWorld:fill("solid", 0, 10, 12, 1)
    screen.world = deathWorld
    screen.player = Player.new(64, 120)
    screen.player:kill("enemy", 2, 3)
    screen.deathTimer = 75
    for _ = 1, 3 do screen:simulationStepBody({ right = true }) end
    assert(screen.player.y > 120 and screen.deathTimer == 72,
        "Full Level Playtest must advance the dead body during its death countdown")
    screen.world, screen.player, screen.deathTimer =
        previousWorld, previousPlayer, previousDeathTimer

end

return Test
