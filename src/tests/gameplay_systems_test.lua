local Creature = require("src.platform.creature")
local Item = require("src.platform.item")
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

    assert(Item.collect("ruby_big", run, player) and run.money == 3000,
        "Treasure must add its original cash value")
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

    local webWorld = World.new(12, 12, 16)
    local webShots = ProjectileSystem.new(webWorld)
    webShots:spawn("web", 80, 80, 0, 0, nil, { life = 0, gravity = 0.2 })
    for _ = 1, 6 do webShots:update() end
    assert(#webShots.webs == 1 and webShots.webs[1].life == 12
        and webWorld:webAtPoint(80, 80) and not webWorld:webAtPoint(70, 80),
        "An expired web ball must finish its creation animation before leaving a web")
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

end

return Test
