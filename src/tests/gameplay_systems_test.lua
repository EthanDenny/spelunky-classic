local Creature = require("src.platform.creature")
local DepthQueue = require("src.render.depth_queue")
local Item = require("src.platform.item")
local ItemActions = require("src.platform.item_actions")
local Player = require("src.platform.player")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local World = require("src.platform.world")

local Test = {}

local CREATURES = {
    "caveman", "skeleton", "ghost", "giant_spider", "damsel", "shopkeeper",
}

function Test.run(app)
    local run = RunState.new(1234)
    local player = Player.new(64, 64)
    run.money = 1000
    run.bombs = 7
    run.equipment.jetpack = true
    run:applyToPlayer(player)
    assert(player.health == 4 and player.equipment.jetpack,
        "Run state must restore health and equipment")
    player.health = 2
    run:capturePlayer(player)
    assert(run.health == 2 and run.bombs == 7, "Run resources must survive player capture")

    assert(Item.collect("ruby_big", run, player) and run.money == 2600,
        "Treasure must add its original cash value")
    assert(Item.price("shotgun", 1) == 15000 and Item.price("shotgun", 3) == 16500
        and Item.price("bow", 2) == 1000,
        "Shop prices must use the Classic Create cost and post-level-two markup")
    Item.collect("spring_shoes", run, player)
    assert(run.equipment.spring_shoes and player.equipment.spring_shoes,
        "Equipment pickup must affect both the run and live player")
    Item.collect("bomb_bag", run, player)
    assert(run.bombs == 10, "Bomb bags must add three bombs")

    for _, kind in ipairs(CREATURES) do
        assert(Creature.supports(kind), "Missing live creature implementation for " .. kind)
    end

    local edgeWorld = World.new(12, 12, 16)
    edgeWorld:set("solid", 6, 5)
    local damsel = Creature.new({ kind = "damsel", x = 91 / 16, y = 5.5 },
        { width = 16, height = 16, originX = 8, originY = 8 })
    assert(not edgeWorld:collidesSolid(damsel, damsel.x, damsel.y),
        "The damsel's four-pixel side mask must clear a neighboring brick")
    local ghost = Creature.new({ kind = "ghost", x = 5, y = 5 },
        { width = 24, height = 24, originX = 0, originY = 0 })
    assert(not edgeWorld:collidesSolid(ghost, ghost.x, ghost.y),
        "The ghost's small offset mask must clear a neighboring brick")
    local overhead = World.new(12, 12, 16)
    overhead:set("solid", 5, 4)
    for _, kind in ipairs({ "caveman", "skeleton", "shopkeeper" }) do
        local creature = Creature.new({ kind = kind, x = 5, y = 5 },
            { width = 16, height = 16, originX = 0, originY = 0 })
        assert(overhead:collidesSolid(creature, creature.x, creature.y - 1),
            kind .. " must meet the ceiling with Classic's full-height collision mask")
    end

    local world = World.new(20, 20, 16)
    world:fill("solid", 0, 10, 20, 1)
    local target = Creature.new({ kind = "caveman", x = 6, y = 9, properties = {} },
        { width = 16, height = 16, originX = 0, originY = 0 })
    local projectiles = ProjectileSystem.new(world)
    projectiles:spawn("bullet", target.x - 12, target.y - 8, 12, 0, player,
        { damage = 2, life = 5 })
    projectiles:update({ target }, player)
    assert(target.hp == 1, "Projectile damage must reach live enemies")

    local shots = ProjectileSystem.new(World.new(40, 12, 16))
    local gunner = Player.new(80, 80)
    gunner.state = Player.STATES.standing
    gunner.facing = 1
    shots:fireGun(Item.new({ kind = "pistol", x = 5, y = 5 }).definition.gun,
        gunner, gunner, love.math.newRandomGenerator(17))
    assert(#shots.projectiles == 1 and shots.projectiles[1].x == 88
        and shots.projectiles[1].y == 78 and #shots.flashes == 1
        and shots.flashes[1].x == 88 and shots.flashes[1].y == 81,
        "A pistol must spawn its bullet and separate muzzle flash at Classic's offsets")
    local drawing = {}
    local originalDraw = love.graphics.draw
    love.graphics.draw = function(image, ...)
        drawing[#drawing + 1] = image
        return originalDraw(image, ...)
    end
    local drawnOk, drawnError = pcall(function()
        shots:drawOne(shots.projectiles[1])
        assert(#drawing == 1 and drawing[1]:getWidth() == 8,
            "A bullet must render its original eight-pixel sprite")
        local queue = DepthQueue.new()
        shots:submit(queue)
        queue:draw()
        local firstFlash = drawing[2]
        assert(firstFlash and #drawing == 3,
            "The muzzle flash and bullet must both render after a shot")
        shots:update()
        shots:update()
        drawing = {}
        queue = DepthQueue.new()
        shots:submit(queue)
        queue:draw()
        assert(drawing[1] ~= firstFlash,
            "The Classic muzzle flash must advance frames while the bullet travels")
    end)
    love.graphics.draw = originalDraw
    assert(drawnOk, drawnError)
    for _ = 1, 13 do shots:update() end
    assert(shots.projectiles[1].alive and #shots.flashes == 0,
        "Bullet travel must not expire with the ten-frame muzzle flash")

    local impactWorld = World.new(12, 12, 16)
    impactWorld:set("solid", 5, 5)
    local impactShots = ProjectileSystem.new(impactWorld)
    local impacts = {}
    impactShots.onImpact = function(kind) impacts[#impacts + 1] = kind end
    impactShots:spawn("bullet", 70, 88, 12, 0, gunner, { damage = 4 })
    impactShots:update()
    assert(impacts[1] == "solid" and not impactShots.projectiles[1].alive,
        "Bullet impact must produce feedback and remove the shot")
    local jarShots = ProjectileSystem.new(World.new(12, 12, 16))
    local jar = Item.new({ kind = "jar", x = 5, y = 5 })
    jarShots.onHitItem = function(item) item.opened = true end
    local jarBullet = jarShots:spawn("bullet", 70, 80, 12, 0, gunner,
        { damage = 4 })
    jarShots:update({}, gunner, { jar })
    assert(jar.opened and jarBullet.alive,
        "A bullet must break a jar without being consumed by it")
    local victim = Player.new(80, 80)
    victim.health, victim.maxHealth, victim.invincibleTimer = 8, 8, 10
    local hostileShots = ProjectileSystem.new(World.new(12, 12, 16))
    hostileShots:spawn("bullet", 70, 80, 12, 0, gunner, { damage = 4 })
    hostileShots:update({}, victim)
    assert(victim.health == 4 and victim.vx == 12 and victim.vy == -4
        and victim.stunTimer == 20 and victim.invincibleTimer == 10,
        "Classic bullet contact must deal four hearts and impart its own velocity even during invincibility")

    local archer = Player.new(80, 80)
    local bow = Item.new({ kind = "bow", x = 5, y = 5 })
    bow:pickup(archer, run)
    local recovered = Item.new({ kind = "arrow", x = 5, y = 5 })
    local pickupCues = {}
    local arrowContext = { heldItem = bow, player = archer, items = { recovered },
        run = run, sounds = { play = function(_, cue) pickupCues[#pickupCues + 1] = cue end } }
    local priorArrows = run.arrows
    assert(ItemActions.recoverArrows(arrowContext) and run.arrows == priorArrows + 1
        and recovered.opened and pickupCues[1] == "pickup",
        "Holding a bow must recover a nearby slow, unstuck arrow")
    recovered.opened, recovered.stuck = false, true
    recovered.x, recovered.y = archer.x, archer.y
    assert(not ItemActions.recoverArrows(arrowContext) and run.arrows == priorArrows + 1,
        "A stuck arrow must not be recovered by the bow")

    local webWorld = World.new(12, 12, 16)
    local webShots = ProjectileSystem.new(webWorld)
    webShots:spawn("web", 80, 80, 0, 0, nil, { life = 0, gravity = 0.2 })
    for _ = 1, 6 do webShots:update() end
    assert(#webShots.webs == 1 and webShots.webs[1].life == 12
        and webWorld:webAtPoint(80, 80) and not webWorld:webAtPoint(70, 80),
        "An expired web ball must finish its creation animation before leaving a web")
    for _ = 1, 600 do webShots:update() end
    assert(#webShots.webs == 1 and webShots.webs[1].life == 12
        and webWorld:webAtPoint(80, 80),
        "An intact web must persist until damaged or marked dying")
    webShots.webs[1].dying = true
    webShots:update()
    assert(webShots.webs[1].life < 12,
        "A dying web must lose life as in Classic's oWeb Step event")
    local itemWebWorld = World.new(12, 12, 16)
    local itemWebShots = ProjectileSystem.new(itemWebWorld)
    local rock = Item.new({ kind = "rock", x = 5, y = 5 })
    itemWebShots:spawn("web", rock.x - 4, rock.y, 4, 0, nil,
        { life = 20, gravity = 0.2, radius = 4 })
    itemWebShots:update({}, nil, { rock })
    assert(itemWebShots.projectiles[1].phase == "create"
        and itemWebShots.projectiles[1].vx == 0,
        "A web ball must form a web when it hits a loose item")
    local waterWebWorld = World.new(12, 12, 16)
    waterWebWorld:set("water", 5, 5)
    local waterWebShots = ProjectileSystem.new(waterWebWorld)
    waterWebShots:spawn("web", 80, 80, 0, 0, nil,
        { life = 20, gravity = 0.2, radius = 4 })
    waterWebShots:update()
    assert(waterWebShots.projectiles[1].phase == "create",
        "A web ball must form a web on water")
    for _ = 1, 560 do webShots:update() end
    assert(#webShots.webs == 0 and not webWorld:webAtPoint(80, 80),
        "The source web must fade away and release its collision area")
    local airborneWeb = ProjectileSystem.new(World.new(12, 12, 16))
    airborneWeb:spawn("web", player.x, player.y, 0, 0, nil,
        { life = 10, gravity = 0.2, radius = 4 })
    airborneWeb:update({}, player)
    assert(player.webTimer == 0 and airborneWeb.projectiles[1].phase == "flight",
        "The flying ball must not web a character before it forms oWeb")

    -- oGiantSpiderHang stays inverted under a ceiling, then converts to the
    -- 32x32 oGiantSpider and plays its flip frames when the player passes below.
    local ceilingWorld = World.new(20, 16, 16)
    ceilingWorld:fill("solid", 8, 4, 2, 1)
    ceilingWorld:fill("solid", 0, 12, 20, 1)
    local giant = Creature.new({ kind = "giant_spider", x = 8, y = 5, properties = {} },
        { width = 32, height = 16, originX = 0, originY = 0 }, { seed = 17 })
    local observer = Player.new(giant.x, giant.y + 48)
    local renderer = app.screens.world_generation
    renderer:loadAssets()
    local images = {}
    local originalDraw = love.graphics.draw
    love.graphics.draw = function(image, x, y, ...)
        images[#images + 1] = { image = image, x = x, y = y }
        return originalDraw(image, x, y, ...)
    end
    local ok, err = pcall(function()
        local distantPlayer = Player.new(16, giant.y + 48)
        giant:step(ceilingWorld, distantPlayer)
        giant:draw(renderer)
        assert(#images == 1 and images[1].image:getHeight() == 16,
            "A giant spider must stay upside down until triggered under its ceiling")
        giant:step(ceilingWorld, observer)
        giant:draw(renderer)
        assert(#images == 2 and images[2].image:getHeight() == 32,
            "Triggering the hanging spider must draw the upright 32-pixel flip sprite")
        assert(images[1].x == images[2].x and images[1].y == images[2].y,
            "The hanging and flipped sprites must keep the same top-left position")
        local firstFlipFrame = images[2].image
        for _ = 1, 4 do giant:step(ceilingWorld, observer) end
        giant:draw(renderer)
        assert(images[#images].image ~= firstFlipFrame,
            "The giant spider's flip animation must advance visible frames")
    end)
    love.graphics.draw = originalDraw
    assert(ok, err)

    -- The active head has its own contact event; the hanging head inherits
    -- oEnemy's lighter contact reaction.
    local active = Creature.new({ kind = "giant_spider", x = 8, y = 5, properties = {} },
        { width = 32, height = 16 }, { seed = 19 })
    active.state = "idle"
    active.height = 32
    active.y = active.y + 16
    local side = Player.new(active.x + 12, active.y - 8)
    side:setState(Player.STATES.standing)
    assert(active:resolvePlayerContact(side, side.y) == "hurt"
        and side.health == 2 and side.vx == 6 and side.vy == 0
        and side.stunTimer == 0 and side.state == Player.STATES.standing,
        "An active giant spider's side hit must take two hearts and push sideways without launching or stunning")
    local innerLeft = Player.new(active.x - 12, active.y - 8)
    innerLeft:setState(Player.STATES.standing)
    assert(active:resolvePlayerContact(innerLeft, innerLeft.y) == "hurt"
        and innerLeft.vx == 6,
        "Classic giant-spider knockback compares with the sprite's left edge, not its center")
    local outerEdge = Player.new(active.x + 18, active.y - 8)
    outerEdge:setState(Player.STATES.standing)
    assert(active:resolvePlayerContact(outerEdge, outerEdge.y) == nil
        and outerEdge.health == 4,
        "The active spider's contact event ignores player centers beyond its 16-pixel range")

    local hanging = Creature.new({ kind = "giant_spider", x = 8, y = 5, properties = {} },
        { width = 32, height = 16 }, { seed = 20 })
    local below = Player.new(hanging.x, hanging.y - 8)
    below:setState(Player.STATES.standing)
    assert(hanging:resolvePlayerContact(below, below.y) == "hurt"
        and below.health == 3 and below.vx == 6 and below.vy == 0
        and below.stunTimer == 0 and below.state == Player.STATES.standing,
        "A hanging giant spider must use ordinary enemy contact: one heart and horizontal push only")

end

return Test
