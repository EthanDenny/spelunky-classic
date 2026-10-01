local Effects = require("src.platform.effects")
local Enemy = require("src.platform.enemy")
local Creature = require("src.platform.creature")
local FakeBones = require("src.platform.fake_bones")
local Item = require("src.platform.item")
local Player = require("src.platform.player")
local Treasure = require("src.platform.treasure")
local World = require("src.platform.world")

local Test = {}

function Test.run(app)
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
    jar.x = 81 -- the current jar reward table yields an emerald at this location
    local oldCount = #screen.collectibles
    local oldParticles = #screen.effects.particles
    screen:openContainer(jar)
    assert(jar.opened and #screen.collectibles == oldCount + 1,
        "Breaking a jar must create an actual collectible in the playtest")
    assert(#screen.effects.particles == oldParticles + 4,
        "The playtest's jar-break path must produce its visible fragments")
    local reward = screen.collectibles[#screen.collectibles]
    assert(reward.active and reward.pickupDelay == 20,
        "The jar reward must enter loose-treasure physics before collection")

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

    assert(#screen.level.decorations > 0, "The draw-order probe needs cave-top decorations")
    local draw = love.graphics.draw
    local drawPlayer = screen.player.drawBody
    local playerDrawn, decorationAfterPlayer, bloodySpikesDrawn = false, false, false
    local collectSkeleton, skeletonImage = false, nil
    local bloodySpike = { kind = "spikes", x = 2, y = 2, bloody = true }
    screen.level.entities[#screen.level.entities + 1] = bloodySpike
    love.graphics.draw = function(image, ...)
        if image == screen.renderer.images.bg_cave_top and playerDrawn then
            decorationAfterPlayer = true
        end
        if image == screen.spikeBloodImage then bloodySpikesDrawn = true end
        if collectSkeleton then skeletonImage = image end
        return draw(image, ...)
    end
    screen.player.drawBody = function(self, ...)
        playerDrawn = true
        return drawPlayer(self, ...)
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
    screen.player.drawBody = nil
    screen.level.entities[#screen.level.entities] = nil
    assert(ok, err)
    assert(decorationAfterPlayer,
        "Cave-top tile decorations must draw in front of the player (depth 3 versus 50)")
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
        { name = "wall", x = 72, y = 79, vx = 8, vy = 0,
            solid = { 5, 0, 1, 12 } },
        { name = "ceiling", x = 390, y = 199, vx = -8.53, vy = -6,
            solid = { 23, 11, 1, 1 } },
        { name = "floor", x = 80, y = 89, vx = 0, vy = 4,
            solid = { 5, 6, 1, 1 } },
    }
    for _, case in ipairs(potCases) do
        local potWorld = World.new(32, 16, 16)
        potWorld:fill("solid", unpack(case.solid))
        screen.world = potWorld
        screen.player = Player.new(32, 32)
        screen.enemies = {}
        local pot = Item.new({ kind = "jar", x = case.x / 16, y = case.y / 16 })
        pot.vx, pot.vy = case.vx, case.vy
        screen.items = { pot }
        screen:simulationStepBody({})
        assert(pot.opened and #screen.enemies == 1
            and screen.enemies[1].kind == "snake",
            "A " .. case.name .. "-broken pot must release its snake")
        local snake = screen.enemies[1]
        assert(not potWorld:collidesSolid(snake, snake.x, snake.y),
            "A " .. case.name .. "-broken pot must not create a snake inside terrain")
    end

    local gemWorld = World.new(32, 16, 16)
    gemWorld:set("solid", 23, 11)
    screen.world = gemWorld
    screen.player = Player.new(32, 32)
    screen.enemies = {}
    screen.collectibles = {}
    local gemPot = Item.new({ kind = "jar", x = 391 / 16, y = 199 / 16 })
    gemPot.vx, gemPot.vy = -8.53, -6
    screen.items = { gemPot }
    screen:simulationStepBody({})
    assert(gemPot.opened and #screen.collectibles == 1,
        "A ceiling-broken pot must release its gem")
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
