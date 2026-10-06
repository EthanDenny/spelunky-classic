local Simulation = require("src.platform.object_simulation")
local Effects = require("src.platform.effects")
local Enemy = require("src.platform.enemy")
local Creature = require("src.platform.creature")
local Item = require("src.platform.item")
local Player = require("src.platform.player")
local ProjectileSystem = require("src.platform.projectile_system")
local ToolSystem = require("src.platform.tool_system")
local TrapSystem = require("src.platform.trap_system")
local Treasure = require("src.platform.treasure")
local World = require("src.platform.world")
local Depth = require("src.render.classic_depth")
local DepthQueue = require("src.render.depth_queue")
local MineItemScenarios = require("src.screens.mine_item_scenarios")
local KaliScenarios = require("src.screens.kali_scenarios")

local EnemyAI = {}
EnemyAI.__index = EnemyAI

local SIDEBAR_WIDTH = 250
local HEADER_HEIGHT = 90
local FOOTER_HEIGHT = 34
local CARD_MIN_WIDTH = 460
local CARD_HEIGHT = 420
local GAP = 14
local STEP = 1 / Enemy.TICK_RATE

local PAGES = {
    { name = "Snake", scenarios = true },
    { name = "Bat", scenarios = true },
    { name = "Spider", scenarios = true },
    { name = "Giant Spider", scenarios = true },
    { name = "Caveman", scenarios = true },
    { name = "Skeleton", scenarios = true },
    { name = "Ropes", scenarios = true },
    { name = "Bombs", scenarios = true },
    { name = "Boulder & Statue", scenarios = true },
}

local COLORS = {
    background = { 0.045, 0.04, 0.035 },
    panel = { 0.095, 0.08, 0.065 },
    panelDark = { 0.065, 0.057, 0.049 },
    card = { 0.12, 0.102, 0.082 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    accent = { 0.72, 0.18, 0.10 },
    selectedText = { 1, 0.94, 0.78 },
    success = { 0.40, 0.76, 0.42 },
    danger = { 0.95, 0.28, 0.16 },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function makeWorld(gap)
    local world = World.new(14, 9, 16)
    world:fill("solid", 0, 0, 14, 1)
    world:fill("solid", 0, 1, 1, 8)
    world:fill("solid", 13, 1, 1, 8)
    world:fill("solid", 1, 7, 12, 2)
    if gap then
        for y = 7, 8 do
            world:remove("solid", 6, y)
            world:remove("solid", 7, y)
        end
    end
    return world
end

local function makePlayer(x, assets)
    local player = Player.new(x, 7 * 16 - 8)
    player.state = Player.STATES.standing
    player.spriteName = "sStandLeft"
    player.facing = 1
    if assets then
        player.images = assets.images
        player.whipImages = assets.whipImages
    else
        player:loadAssets()
    end
    return player
end

local function makeGiantSpider(tileX, tileY, seed)
    return Creature.new({ kind = "giant_spider", x = tileX, y = tileY, properties = {} },
        { width = 32, height = 16 }, { seed = seed })
end

local SNAKE_SCENARIOS = {
    {
        title = "Patrol and gap",
        description = "No player. The snake patrols and turns before the gap.",
        duration = 180,
        seed = 11,
        build = function()
            local world = makeWorld(true)
            local snake = Enemy.new("snake", 4 * 16 + 8, 7 * 16, { facing = 1, seed = 11 })
            snake:setState(Enemy.STATES.walk)
            return world, snake
        end,
    },
    {
        title = "Contact",
        description = "The snake starts walking toward a player in a short corridor.",
        duration = 150,
        seed = 22,
        build = function(assets)
            local world = makeWorld()
            world:fill("solid", 2, 5, 1, 2)
            world:fill("solid", 10, 5, 1, 2)
            local snake = Enemy.new("snake", 3 * 16 + 8, 7 * 16, { facing = 1, seed = 22 })
            snake:setState(Enemy.STATES.walk)
            -- Keep this run directed at the player. Random idle pauses appear
            -- in the patrol demonstration.
            snake.random = function(_, maximum) return maximum end
            return world, snake, makePlayer(7 * 16 + 8, assets)
        end,
    },
    {
        title = "Whip an idle snake",
        description = "The player waits, then whips while the snake is idling.",
        duration = 95,
        attackTick = 18,
        seed = 67, -- keeps this short replay's blood in the source's midrange gravity rolls
        build = function(assets)
            local world = makeWorld()
            local snake = Enemy.new("snake", 6 * 16, 7 * 16, { facing = -1, seed = 33 })
            snake:setState(Enemy.STATES.idle, 110)
            snake.vx = 0
            return world, snake, makePlayer(4 * 16 + 8, assets)
        end,
    },
    {
        title = "Blocked on one block",
        description = "No safe step: speed is zero, but the original WALK sprite still animates slowly.",
        duration = 120,
        seed = 44,
        build = function()
            local world = makeWorld()
            for x = 1, 12 do
                if x ~= 6 then
                    world:remove("solid", x, 7)
                    world:remove("solid", x, 8)
                end
            end
            local snake = Enemy.new("snake", 6 * 16 + 8, 7 * 16, { facing = -1, seed = 44 })
            snake:setState(Enemy.STATES.idle, 0)
            snake.vx = 0
            return world, snake
        end,
    },
}

local BAT_SCENARIOS = {
    {
        title = "Hanging ambush",
        description = "A player approaches beneath a hanging bat, drawing it into pursuit.",
        duration = 150,
        eventDuration = 25,
        seed = 41,
        input = function(tick) return { right = tick <= 30 } end,
        build = function(assets)
            local world = makeWorld()
            world:set("solid", 7, 2)
            local bat = Enemy.new("bat", 7 * 16 + 8, 4 * 16, { seed = 41 })
            return world, bat, makePlayer(2 * 16 + 8, assets)
        end,
    },
    {
        title = "Return to ceiling",
        description = "With no player nearby, the bat rises and hangs from the ceiling again.",
        duration = 100,
        seed = 42,
        build = function()
            local world = makeWorld()
            world:set("solid", 6, 2)
            local bat = Enemy.new("bat", 6 * 16 + 8, 6 * 16, { seed = 42 })
            bat:setState(Enemy.STATES.attack)
            return world, bat
        end,
    },
    {
        title = "Whip a diving bat",
        description = "The bat leaves its perch as the player times a whip into its dive.",
        duration = 95,
        attackTick = 13,
        seed = 43,
        build = function(assets)
            local world = makeWorld()
            world:set("solid", 5, 4)
            local bat = Enemy.new("bat", 5 * 16, 6 * 16, { seed = 43 })
            return world, bat, makePlayer(2 * 16 + 8, assets)
        end,
    },
}

local CAVEMAN_SCENARIOS = {
    {
        title = "Patrol and ledge",
        description = "The caveman runs, stops at a gap, and resumes after an idle pause.",
        duration = 180,
        seed = 51,
        build = function()
            local world = makeWorld(true)
            local caveman = Enemy.new("caveman", 4 * 16 + 8, 7 * 16,
                { facing = 1, seed = 51 })
            caveman:setState(Enemy.STATES.walk)
            return world, caveman
        end,
    },
    {
        title = "Spot and rush",
        description = "A player enters its line of sight; the caveman charges toward them.",
        duration = 110,
        eventDuration = 45,
        seed = 52,
        build = function(assets)
            local world = makeWorld()
            local caveman = Enemy.new("caveman", 3 * 16 + 8, 7 * 16,
                { facing = 1, seed = 52 })
            caveman:setState(Enemy.STATES.walk)
            return world, caveman, makePlayer(8 * 16 + 8, assets)
        end,
    },
    {
        title = "Whip and recovery",
        description = "One whip stuns the three-health caveman; it later gets back up.",
        duration = 260,
        eventDuration = 235,
        attackTick = 18,
        seed = 53,
        build = function(assets)
            local world = makeWorld()
            local caveman = Enemy.new("caveman", 6 * 16, 7 * 16,
                { facing = 1, seed = 53 })
            caveman:setState(Enemy.STATES.idle, 110)
            caveman.vx = 0
            return world, caveman, makePlayer(4 * 16 + 8, assets)
        end,
    },
}

local SPIDER_SCENARIOS = {
    {
        title = "Hanging ambush",
        description = "A player below the spider triggers its drop, flip, and hops.",
        duration = 135,
        seed = 61,
        build = function(assets)
            local world = makeWorld()
            world:set("solid", 6, 2)
            local spider = Enemy.new("spider", 6 * 16 + 8, 4 * 16, { seed = 61 })
            return world, spider, makePlayer(spider.x, assets)
        end,
    },
    {
        title = "Lost ceiling",
        description = "Without a ceiling, the spider drops and hops toward a nearby player.",
        duration = 115,
        seed = 62,
        build = function()
            local world = makeWorld()
            local spider = Enemy.new("spider", 6 * 16 + 8, 4 * 16, { seed = 62 })
            return world, spider, makePlayer(spider.x)
        end,
    },
    {
        title = "Whip a hanging spider",
        description = "The player whips the spider before it leaves its perch.",
        duration = 90,
        eventDuration = 35,
        attackTick = 18,
        seed = 63,
        build = function(assets)
            local world = makeWorld()
            world:set("solid", 5, 5)
            local spider = Enemy.new("spider", 6 * 16, 7 * 16, { seed = 63 })
            return world, spider, makePlayer(4 * 16 + 8, assets)
        end,
    },
}

local GIANT_SPIDER_SCENARIOS = {
    {
        title = "Giant ambush",
        description = "The giant spider flips from the ceiling and jumps toward the player.",
        duration = 155,
        seed = 71,
        build = function(assets)
            local world = makeWorld()
            world:fill("solid", 6, 2, 2, 1)
            local spider = makeGiantSpider(6, 3, 71)
            return world, spider, makePlayer(spider.x, assets)
        end,
    },
    {
        title = "Whip the giant",
        description = "A whip hit wounds the hanging giant and makes it drop.",
        duration = 120,
        eventDuration = 55,
        attackTick = 18,
        seed = 72,
        build = function(assets)
            local world = makeWorld()
            world:fill("solid", 5, 5, 2, 1)
            world:remove("solid", 5, 7)
            world:remove("solid", 6, 7)
            local spider = makeGiantSpider(5, 6, 72)
            return world, spider, makePlayer(4 * 16 + 8, assets)
        end,
    },
    {
        title = "Web squirt",
        description = "The giant lobs a web ball; its impact forms a fading web.",
        duration = 110,
        eventDuration = 80,
        projectiles = true,
        seed = 73,
        build = function()
            local world = makeWorld()
            local spider = makeGiantSpider(6, 5, 73)
            spider.y = 7 * 16
            spider.height = 32
            spider.state = "idle"
            spider.spriteName = "sGiantSpider"
            spider.squirtTimer = 0
            return world, spider
        end,
    },
}

local SKELETON_SCENARIOS = {
    {
        title = "Bones awaken",
        description = "A nearby player wakes fake bones; the skeleton forms, waits, then walks.",
        duration = 115,
        seed = 81,
        input = function(tick) return { right = tick <= 15 } end,
        build = function(assets)
            local world = makeWorld()
            local skeleton = Enemy.new("skeleton", 6 * 16 + 8, 7 * 16,
                { fakeBones = true, seed = 81 })
            return world, skeleton, makePlayer(1 * 16 + 8, assets)
        end,
    },
    {
        title = "No ledge sense",
        description = "Unlike a snake, the walking skeleton continues over a gap.",
        duration = 95,
        seed = 82,
        build = function()
            local world = makeWorld(true)
            world:fill("solid", 6, 8, 2, 1)
            local skeleton = Enemy.new("skeleton", 4 * 16 + 8, 7 * 16,
                { facing = 1, seed = 82 })
            skeleton:setState(Enemy.STATES.walk)
            return world, skeleton
        end,
    },
    {
        title = "Whip and shatter",
        description = "One whip breaks the skeleton into animated bones and a skull.",
        duration = 90,
        eventDuration = 45,
        attackTick = 18,
        seed = 32, -- source-valid bone rolls with modest horizontal spread
        build = function(assets)
            local world = makeWorld()
            local skeleton = Enemy.new("skeleton", 6 * 16, 7 * 16,
                { facing = -1, seed = 83 })
            skeleton:setState(Enemy.STATES.idle, 110)
            return world, skeleton, makePlayer(4 * 16 + 8, assets)
        end,
    },
}

local function ropeWorld(withCeiling)
    local world = makeWorld()
    if not withCeiling then
        for x = 1, 12 do world:remove("solid", x, 0) end
    end
    return world
end

local function ledgeShaft(height)
    local world = World.new(14, height, 16)
    world:fill("solid", 0, 0, 14, 1)
    world:fill("solid", 0, 1, 1, height - 1)
    world:fill("solid", 13, 1, 1, height - 1)
    world:fill("solid", 1, height - 2, 12, 2)
    world:fill("solid", 1, 7, 6, 1)
    return world
end

local ROPE_SCENARIOS = {
    {
        title = "One-block headroom",
        description = "The block directly over the player prevents the throw; no rope is spent.",
        duration = 75, throwTick = 5, rope = true, seed = 91,
        build = function(assets)
            local world = ropeWorld(true)
            world:set("solid", 4, 5)
            return world, nil, makePlayer(4 * 16 + 8, assets)
        end,
    },
    {
        title = "Left corner, odd offset",
        description = "A throw from x=109 grazes the brick corner and anchors on its left side.",
        duration = 80, throwTick = 5, rope = true, seed = 92,
        build = function(assets)
            local world = ropeWorld(true)
            world:set("solid", 7, 3)
            return world, nil, makePlayer(6 * 16 + 13, assets)
        end,
    },
    {
        title = "Right corner, odd offset",
        description = "A throw from x=115 grazes the opposite corner and anchors on its right side.",
        duration = 80, throwTick = 5, rope = true, seed = 93,
        build = function(assets)
            local world = ropeWorld(true)
            world:set("solid", 6, 3)
            return world, nil, makePlayer(7 * 16 + 3, assets)
        end,
    },
    {
        title = "Clear upward throw",
        description = "With open headroom, the rope reaches the ceiling and unfurls downward.",
        duration = 85, throwTick = 5, rope = true, seed = 94,
        build = function(assets)
            return ropeWorld(true), nil, makePlayer(6 * 16 + 8, assets)
        end,
    },
    {
        title = "No ceiling overhead",
        description = "The hook reaches its apex above the room, then the body grows back into view.",
        duration = 85, throwTick = 5, rope = true, seed = 95,
        build = function(assets)
            return ropeWorld(false), nil, makePlayer(6 * 16 + 8, assets)
        end,
    },
    {
        title = "Rope hits a snake",
        description = "The rising rope end kills the snake; its deployed body remains climbable.",
        duration = 85, throwTick = 5, rope = true, seed = 96,
        build = function(assets)
            local world = ropeWorld(true)
            local snake = Enemy.new("snake", 6 * 16 + 8, 88, { seed = 96 })
            snake:setState(Enemy.STATES.idle, 90)
            snake.vx = 0
            return world, snake, makePlayer(snake.x, assets)
        end,
    },
    {
        title = "Rope stuns a caveman",
        description = "The rising rope end deals one damage and stuns a three-health caveman.",
        duration = 85, throwTick = 5, rope = true, seed = 97,
        build = function(assets)
            local world = ropeWorld(true)
            local caveman = Enemy.new("caveman", 6 * 16 + 8, 88, { seed = 97 })
            caveman:setState(Enemy.STATES.idle, 90)
            caveman.vx = 0
            return world, caveman, makePlayer(caveman.x, assets)
        end,
    },
    {
        title = "Crouched ledge drop",
        description = "Hold down at the ledge, then deploy beside the player; the rope stops at the shaft floor.",
        duration = 90, throwTick = 5, rope = true, seed = 98,
        input = function() return { down = true } end,
        build = function(assets)
            return ledgeShaft(16), nil, makePlayer(6 * 16 + 8, assets)
        end,
    },
    {
        title = "Deep shaft: finite rope",
        description = "The floor is 30 tiles down. The rope stops after 16 eight-pixel segments, not at the floor.",
        duration = 100, throwTick = 5, rope = true, ropeLimit = true, seed = 99,
        input = function() return { down = true } end,
        build = function(assets)
            return ledgeShaft(30), nil, makePlayer(6 * 16 + 8, assets)
        end,
    },
}

local BOMB_SCENARIOS = {
    {
        title = "Wall rebound",
        description = "An unpasted bomb rebounds from brick and blasts the nearby thrower.",
        duration = 160, throwTick = 5, bomb = true, seed = 101,
        build = function(assets)
            local world = makeWorld()
            world:fill("solid", 8, 5, 1, 2)
            return world, nil, makePlayer(4 * 16 + 8, assets)
        end,
    },
    {
        title = "Paste sticks to a wall",
        description = "With paste, the bomb stays on the wall until its fuse explodes.",
        duration = 160, throwTick = 5, bomb = true, seed = 102,
        build = function(assets)
            local world = makeWorld()
            world:fill("solid", 7, 5, 1, 2)
            local player = makePlayer(4 * 16 + 8, assets)
            player.equipment.paste = true
            return world, nil, player
        end,
    },
    {
        title = "Blast catches a snake",
        description = "The wall catches a paste bomb; its blast reaches the snake beyond it.",
        duration = 160, throwTick = 5, bomb = true, seed = 103,
        build = function(assets)
            local world = makeWorld()
            world:fill("solid", 7, 5, 1, 2)
            local snake = Enemy.new("snake", 8 * 16 + 8, 7 * 16, { seed = 103 })
            snake:setState(Enemy.STATES.idle, 160)
            snake.vx = 0
            local player = makePlayer(4 * 16 + 8, assets)
            player.equipment.paste = true
            return world, snake, player
        end,
    },
    {
        title = "Upward lob",
        description = "Holding up launches the bomb steeply toward the ceiling.",
        duration = 160, throwTick = 5, bomb = true, seed = 104,
        input = function(tick) return { up = tick == 5 } end,
        build = function(assets)
            local world = makeWorld()
            return world, nil, makePlayer(4 * 16 + 8, assets)
        end,
    },
    {
        title = "Grounded drop",
        description = "Holding down drops the bomb with little sideways speed.",
        duration = 160, throwTick = 5, bomb = true, seed = 105,
        input = function(tick) return { down = tick == 5 } end,
        build = function(assets)
            return makeWorld(), nil, makePlayer(4 * 16 + 8, assets)
        end,
    },
    {
        title = "Whip blocks the throw",
        description = "A bomb press during a whip leaves the bomb supply untouched.",
        duration = 75, throwTick = 5, attackTick = 4, bomb = true, seed = 106,
        build = function(assets)
            return makeWorld(), nil, makePlayer(4 * 16 + 8, assets)
        end,
    },
}

local function boulderWorld()
    local world = World.new(14, 12, 16)
    world:fill("solid", 0, 0, 14, 1)
    world:fill("solid", 0, 1, 1, 11)
    world:fill("solid", 13, 1, 1, 11)
    world:fill("solid", 1, 10, 12, 2)
    return world
end

local function boulderPlayer(assets)
    local player = makePlayer(3 * 16 + 8, assets)
    player.y = 10 * 16 - 8
    return player
end

local BOULDER_STATUE_SCENARIOS = {
    {
        title = "Fall, bounce, roll",
        description = "A released boulder falls, bounces, then rolls toward the player's side.",
        duration = 155, eventDuration = 155, boulderTick = 5,
        build = function(assets)
            return boulderWorld(), nil, boulderPlayer(assets),
                { entities = {} }, { x = 9 * 16, y = 5 * 16 }
        end,
    },
    {
        title = "Break the wall",
        description = "The rolling boulder smashes ordinary brick; the room boundary holds.",
        duration = 155, eventDuration = 155, boulderTick = 5,
        build = function(assets)
            local world = boulderWorld()
            world:set("solid", 5, 8)
            return world, nil, boulderPlayer(assets),
                { entities = {} }, { x = 9 * 16, y = 5 * 16 }
        end,
    },
    {
        title = "Crush a push block",
        description = "A rolling boulder destroys a movable block in its path.",
        duration = 155, eventDuration = 155, boulderTick = 5, targetKind = "block",
        build = function(assets)
            local world = boulderWorld()
            local block = world:addDynamicSolid({ kind = "push_block", x = 5 * 16,
                y = 9 * 16, moveable = true })
            return world, nil, boulderPlayer(assets),
                { entities = {} }, { x = 9 * 16, y = 5 * 16 }, block
        end,
    },
    {
        title = "Crush a snake",
        description = "The boulder runs over a grounded snake before reaching the player.",
        duration = 155, eventDuration = 155, boulderTick = 5,
        build = function(assets)
            local snake = Enemy.new("snake", 6 * 16 + 8, 10 * 16, { seed = 107 })
            snake:setState(Enemy.STATES.idle, 150)
            snake.vx = 0
            return boulderWorld(), snake, boulderPlayer(assets),
                { entities = {} }, { x = 9 * 16, y = 5 * 16 }
        end,
    },
    {
        title = "Ruby meets the boulder",
        description = "Loose treasure responds to the boulder's solid body; it is not destroyed.",
        duration = 155, eventDuration = 155, boulderTick = 5, targetKind = "treasure",
        build = function(assets)
            local ruby = Treasure.new({ kind = "ruby_big", x = 6.5,
                y = 9.75, properties = {} })
            return boulderWorld(), nil, boulderPlayer(assets),
                { entities = {} }, { x = 9 * 16, y = 5 * 16 }, ruby
        end,
    },
    {
        title = "Idol arms the statue",
        description = "Taking the idol starts the head's 100-step alarm. Its face opens and releases a boulder.",
        duration = 190, eventDuration = 190, idolTick = 5, statue = true,
        build = function(assets)
            local world = boulderWorld()
            local head = { kind = "giant_tiki_head", x = 9, y = 4.75 }
            return world, nil, boulderPlayer(assets),
                { entities = { head } }
        end,
    },
    {
        title = "Untouched idol",
        description = "Without an idol pickup, the complete statue stays closed and no boulder appears.",
        duration = 190, eventDuration = 190, statue = true,
        build = function(assets)
            local world = boulderWorld()
            local head = { kind = "giant_tiki_head", x = 9, y = 4.75 }
            return world, nil, boulderPlayer(assets),
                { entities = { head } }
        end,
    },
}

local SCENARIOS = {
    Snake = SNAKE_SCENARIOS,
    Bat = BAT_SCENARIOS,
    Spider = SPIDER_SCENARIOS,
    ["Giant Spider"] = GIANT_SPIDER_SCENARIOS,
    Caveman = CAVEMAN_SCENARIOS,
    Skeleton = SKELETON_SCENARIOS,
    Ropes = ROPE_SCENARIOS,
    Bombs = BOMB_SCENARIOS,
    ["Boulder & Statue"] = BOULDER_STATUE_SCENARIOS,
}
for _, page in ipairs(MineItemScenarios.definitions(makeWorld, makePlayer)) do
    PAGES[#PAGES + 1] = { name = page.name, scenarios = true }
    SCENARIOS[page.name] = page.scenarios
end

local kaliPage = KaliScenarios.definitions(makeWorld, makePlayer)
PAGES[#PAGES+1] = { name = kaliPage.name, scenarios = true }
SCENARIOS[kaliPage.name] = kaliPage.scenarios

function EnemyAI.new(app)
    return setmetatable({
        app = app,
        pageIndex = 1,
        scenarios = {},
        images = {},
        sounds = {},
        accumulator = 0,
        scrollY = 0,
        sidebarScrollY = 0,
        maxScroll = 0,
        paused = false,
        soundEnabled = false,
        pageRows = {},
    }, EnemyAI)
end

function EnemyAI:loadAssets()
    if self.images.brick then return end
    self.images.brick = loadImage("assets/original/mines/brick.png")
    self.images.brickAlt = loadImage("assets/original/mines/brick_alt.png")
    self.images.background = loadImage("assets/original/mines/bg_cave.png")
    self.images.background:setWrap("repeat", "repeat")
    self.images.tikiHead = loadImage("assets/original/entities/giant_tiki_head.png")
    self.images.idol = loadImage("assets/original/mines/gold_idol.png")
    self.images.ruby = loadImage("assets/original/mines/ruby_big.png")
    self.images.block = loadImage("assets/original/mines/block.png")
    self.images.tikiBody = loadImage("original-game-reference/source/extracted/spelunky/Backgrounds/bgTiki.png")
    self.images.tikiArms = loadImage("original-game-reference/source/extracted/spelunky/Backgrounds/bgTikiArms.png")
    self.tikiArmLeft = love.graphics.newQuad(0, 16, 16, 16, self.images.tikiArms:getDimensions())
    self.tikiArmRight = love.graphics.newQuad(0, 0, 16, 16, self.images.tikiArms:getDimensions())
    self.backgroundQuad = love.graphics.newQuad(0, 0, 14 * 16, 9 * 16,
        self.images.background:getDimensions())
    self.sounds.hit = love.audio.newSource("original-game-reference/sound/hit.wav", "static")
    self.sounds.hurt = love.audio.newSource("original-game-reference/sound/hurt.wav", "static")
    self.sounds.bat = love.audio.newSource("original-game-reference/sound/bat.wav", "static")
    self.sounds.alert = love.audio.newSource("original-game-reference/sound/alert.wav", "static")
    self.sounds.spider = love.audio.newSource("original-game-reference/sound/spiderjump.wav", "static")
    self.sounds.giant = love.audio.newSource("original-game-reference/sound/gspiderjump.wav", "static")
    self.sounds.throw = love.audio.newSource("original-game-reference/sound/throw.wav", "static")
    self.sounds.explosion = love.audio.newSource("original-game-reference/sound/explosion.wav", "static")
    Enemy.loadAssets()
    Effects.loadAssets()
    self.itemRenderer = self.app.renderer
    self.itemRenderer:loadAssets()
end

function EnemyAI:playScenarioSound(name)
    if not self.soundEnabled then return end
    local source = self.sounds[name]
    if source then
        source:stop()
        source:play()
    end
end

function EnemyAI:resetScenario(scenario)
    scenario.world, scenario.enemy, scenario.player, scenario.level, scenario.boulderOrigin,
        scenario.target =
        scenario.definition.build(self.playerAssets)
    scenario.block = scenario.definition.targetKind == "block" and scenario.target or nil
    scenario.treasure = scenario.definition.targetKind == "treasure" and scenario.target or nil
    scenario.backgroundQuad = scenario.world.height ~= 9 and love.graphics.newQuad(0, 0,
        scenario.world.width * 16, scenario.world.height * 16,
        self.images.background:getDimensions()) or self.backgroundQuad
    scenario.hadBrick = scenario.world:has("solid", 5, 8)
    scenario.idol = scenario.definition.statue and Item.new({
        kind = "gold_idol", x = (scenario.player.x + 16) / 16,
        y = scenario.player.y / 16,
    }) or nil
    scenario.tools = nil
    scenario.traps = nil
    if scenario.level then
        scenario.traps = TrapSystem.new(scenario.world, scenario.level, {
            drawEntity = function(_, entity)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.images.tikiHead,
                    math.floor(entity.x * 16 - 16), math.floor(entity.y * 16 - 16))
            end,
        })
        if self.trapAssets then
            scenario.traps.assets = self.trapAssets
        else
            scenario.traps:loadAssets()
            self.trapAssets = scenario.traps.assets
        end
    end
    if scenario.definition.rope or scenario.definition.bomb then
        scenario.tools = ToolSystem.new(scenario.world, Player.TICK_RATE)
        if self.toolAssets then
            scenario.tools.assets = self.toolAssets
        else
            scenario.tools:loadAssets()
            self.toolAssets = scenario.tools.assets
        end
        scenario.tools.explosionSound = nil
        if scenario.definition.rope then
            scenario.ropesRemaining = 1
            scenario.tools.onRopeHit = function(_, target)
                scenario.event = "ROPE HIT"
                scenario.eventTick = scenario.tick
                scenario.effects:blood(target.x, target.y - 8,
                    target.alive and 1 or (target.kind == "snake" and 4 or 1))
                self:playScenarioSound("hit")
            end
        else
            scenario.bombsRemaining = 1
            scenario.tools.onExplosion = function()
                self:playScenarioSound("explosion")
            end
        end
    end
    scenario.effects = Effects.new(scenario.definition.seed)
    MineItemScenarios.reset(scenario, self.itemRenderer, self)
    KaliScenarios.reset(scenario, self.itemRenderer, self)
    scenario.projectiles = scenario.definition.projectiles
        and ProjectileSystem.new(scenario.world)
        or scenario.itemGame and scenario.itemGame.projectiles or nil
    if scenario.player and not self.playerAssets then
        self.playerAssets = {
            images = scenario.player.images,
            whipImages = scenario.player.whipImages,
        }
        self.sounds.whip = scenario.player.whipSound
    end
    if scenario.player then
        -- Scenario playback owns audio, so muting can stop every active sound.
        scenario.player.whipSound = nil
        scenario.player.thudSound = nil
    end
    scenario.tick = 0
    scenario.event = nil
    scenario.eventTick = nil
    scenario.runs = (scenario.runs or 0) + 1
end

function EnemyAI:resetPage()
    self.scenarios = {}
    local definitions = SCENARIOS[PAGES[self.pageIndex].name]
    if definitions then
        for _, definition in ipairs(definitions) do
            local scenario = { definition = definition }
            self:resetScenario(scenario)
            self.scenarios[#self.scenarios + 1] = scenario
        end
    end
    self.accumulator = 0
end

function EnemyAI:enter()
    self:loadAssets()
    self:resetPage()
end

function EnemyAI:setPage(index)
    self.pageIndex = ((index - 1) % #PAGES) + 1
    local available = love.graphics.getHeight()-168
    local top = (self.pageIndex-1)*36
    self.sidebarScrollY = clamp(self.sidebarScrollY, math.max(0, top+32-available), top)
    self.scrollY = 0
    self.paused = false
    self:resetPage()
end

function EnemyAI:toggleSound()
    self.soundEnabled = not self.soundEnabled
    if not self.soundEnabled then
        for _, source in pairs(self.sounds) do source:stop() end
    end
end

function EnemyAI:stepScenario(scenario)
    local definition = scenario.definition
    scenario.tick = scenario.tick + 1
    if scenario.kaliGame then
        KaliScenarios.step(scenario, self)
        if scenario.tick >= definition.duration then self:resetScenario(scenario) end
        return
    end
    local player = scenario.player
    local enemy = scenario.enemy
    local previousPlayerY = player and player.y

    if player then
        local input = definition.input and definition.input(scenario.tick) or {}
        input.attack = input.attack or scenario.tick == definition.attackTick
        MineItemScenarios.prepare(scenario, input)
        player:step(scenario.world, input)
        if player.whipJustCracked then self:playScenarioSound("whip") end
        if definition.bomb and scenario.tick == definition.throwTick then
            if scenario.tools:throwBomb(player, input) then
                scenario.bombsRemaining = scenario.bombsRemaining - 1
                scenario.event = "BOMB THROWN"
                self:playScenarioSound("throw")
            else
                scenario.event = "BLOCKED: BOMB KEPT"
            end
        elseif definition.rope and scenario.tick == definition.throwTick then
            if scenario.tools:throwRope(player, input) then
                scenario.ropesRemaining = scenario.ropesRemaining - 1
                scenario.event = "ROPE THROWN"
                self:playScenarioSound("throw")
            else
                scenario.event = "BLOCKED: ROPE KEPT"
            end
        end
    else
        scenario.world.time = (scenario.world.time or 0) + 1
    end

    if enemy and enemy.alive then
        local previousState = enemy.state
        local previousProjectiles = scenario.projectiles and #scenario.projectiles.projectiles or 0
        enemy:step(scenario.world, player, { projectiles = scenario.projectiles })
        require("src.platform.enemies.enemy_sight").update(scenario.world, player, { enemy })
        if enemy.justAlerted then
            if enemy.kind == "caveman" then
                scenario.event = "CAVEMAN ALERT"
                self:playScenarioSound("alert")
            elseif enemy.kind == "spider" then
                scenario.event = "SPIDER DROP"
            elseif enemy.kind == "skeleton" then
                scenario.event = "BONES STIR"
            else
                scenario.event = "BAT ALERT"
                self:playScenarioSound("bat")
            end
        elseif enemy.kind == "giant_spider" and previousState == "hang"
            and enemy.state ~= "hang" then
            scenario.event = "GIANT DROP"
            self:playScenarioSound("giant")
        elseif enemy.kind == "bat" and previousState ~= Enemy.STATES.hang
            and enemy.state == Enemy.STATES.hang then
            scenario.event = "REHANG"
            scenario.eventTick = scenario.tick
        end
        if (enemy.kind == "spider" or enemy.kind == "giant_spider")
            and enemy.state ~= previousState
            and (enemy.state == Enemy.STATES.bounce or enemy.state == "bounce") then
            self:playScenarioSound(enemy.kind == "spider" and "spider" or "giant")
        end
        if scenario.projectiles and #scenario.projectiles.projectiles > previousProjectiles then
            scenario.event = "WEB FIRED"
            scenario.eventTick = scenario.tick
        end
        if player then
            if Simulation.whipContact(player, enemy) then
                local _, whipX = player:getWhipSprite()
                enemy:damage(1, whipX+8, { kind = "whip", phase = player:getWhipPhase() })
                if enemy.kind ~= "skeleton" then
                    scenario.effects:blood(enemy.x, enemy.y - 8, 1)
                end
                scenario.event = "WHIP HIT"
                scenario.eventTick = scenario.tick
                self:playScenarioSound("hit")
            end
            if enemy.alive and enemy:resolvePlayerContact(player, previousPlayerY) == "hurt" then
                scenario.event = "PLAYER HIT"
                scenario.eventTick = scenario.eventTick or scenario.tick
                if enemy.kind == "caveman" then
                    scenario.effects:blood(player.x, player.y - 8, 1)
                end
                self:playScenarioSound("hurt")
            end
        end
        if not enemy.alive then
            if enemy.kind == "skeleton" then
                scenario.effects:skeletonBreak(enemy.x, enemy.y - 8)
            else
                scenario.effects:blood(enemy.x, enemy.y - 8,
                    enemy.kind == "giant_spider" and 4 or 3)
            end
        end
    end

    if scenario.tools then
        local explosionCount = #scenario.tools.explosions
        scenario.tools:update(player, enemy and { enemy } or {}, {})
        if definition.bomb then
            local bomb = scenario.tools.bombs[1]
            if enemy and not enemy.alive and scenario.event == "WALL BLASTED" then
                scenario.event = "SNAKE BLASTED"
                scenario.eventTick = scenario.tick
            elseif #scenario.tools.explosions > explosionCount then
                scenario.event = player.health == 0 and "PLAYER BLASTED"
                    or enemy and not enemy.alive and "SNAKE BLASTED" or "WALL BLASTED"
                scenario.eventTick = scenario.tick
            elseif bomb and bomb.alive and bomb.timer <= bomb.flashStart then
                scenario.event = bomb.stuck and "STUCK AND FLASHING" or "BOMB FLASHING"
            elseif bomb and bomb.alive and bomb.stuck then
                scenario.event = "BOMB STUCK"
            end
        end
        local rope = scenario.tools.ropes[1]
        if rope and rope.deployed and scenario.event == "ROPE THROWN" then
            scenario.event = "ROPE ANCHORED"
        end
        if rope and definition.ropeLimit and rope.deployed and not rope.deploying then
            scenario.event = "ROPE LIMIT: 16 SEGMENTS"
        end
    end
    if scenario.traps then
        if scenario.tick == definition.idolTick then
            if scenario.idol:pickup(player) then scenario.traps:triggerIdol(player) end
            scenario.event = "IDOL TAKEN: HEAD ARMED"
            scenario.eventTick = scenario.tick
        end
        if scenario.idol and scenario.idol.held then scenario.idol:updateHeldPosition(player) end
        if scenario.tick == definition.boulderTick then
            scenario.traps:spawnBoulder(scenario.boulderOrigin)
            scenario.event = "BOULDER RELEASED"
            scenario.eventTick = scenario.tick
        end
        local bouldersBefore = #scenario.traps.boulders
        local enemyWasAlive = enemy and enemy.alive
        local blockWasAlive = scenario.block and scenario.block.alive
        scenario.traps:update(player, enemy and { enemy } or {}, {})
        if scenario.treasure then scenario.treasure:update(scenario.world) end
        if #scenario.traps.boulders > bouldersBefore then
            scenario.event = "STATUE OPENED: BOULDER"
            scenario.eventTick = scenario.tick
        elseif enemyWasAlive and not enemy.alive then
            scenario.effects:blood(enemy.x, enemy.y - 8, 3)
            scenario.event = "SNAKE CRUSHED"
            scenario.eventTick = scenario.tick
        elseif blockWasAlive and not scenario.block.alive then
            scenario.event = "PUSH BLOCK CRUSHED"
            scenario.eventTick = scenario.tick
        elseif scenario.hadBrick and definition.boulderTick and scenario.tick > definition.boulderTick
            and scenario.world:has("solid", 5, 8) == false then
            scenario.event = "BRICK CRUSHED"
            scenario.eventTick = scenario.tick
        end
    end
    if scenario.projectiles then
        local itemGame = scenario.itemGame
        scenario.projectiles:update(itemGame and itemGame.enemies or {}, player,
            itemGame and itemGame.items or nil)
    end
    MineItemScenarios.step(scenario, scenario.itemInput)
    scenario.effects:update(scenario.world)

    if scenario.tick >= definition.duration
        or (scenario.eventTick and scenario.tick - scenario.eventTick >= (definition.eventDuration or 35)) then
        self:resetScenario(scenario)
    end
end

function EnemyAI:update(dt)
    if self.paused then return end
    self.accumulator = math.min(self.accumulator + dt, STEP * 5)
    while self.accumulator >= STEP do
        local log = self.app.playtestLog
        local before = log and log.capture(self)
        if log then log:tickStart("enemy_ai", {}, before) end
        for _, scenario in ipairs(self.scenarios) do
            self:stepScenario(scenario)
        end
        if log then log:tick("enemy_ai", {}, before, self) end
        self.accumulator = self.accumulator - STEP
    end
end

function EnemyAI:keypressed(key, _, isRepeat)
    if isRepeat then return end
    if key == "left" or key == "a" then
        self:setPage(self.pageIndex - 1)
    elseif key == "right" or key == "d" then
        self:setPage(self.pageIndex + 1)
    elseif key == "up" or key == "w" then
        self.scrollY = clamp(self.scrollY - 80, 0, self.maxScroll)
    elseif key == "down" or key == "s" then
        self.scrollY = clamp(self.scrollY + 80, 0, self.maxScroll)
    elseif key == "pageup" then
        self.scrollY = clamp(self.scrollY - 500, 0, self.maxScroll)
    elseif key == "pagedown" then
        self.scrollY = clamp(self.scrollY + 500, 0, self.maxScroll)
    elseif key == "r" then
        self:resetPage()
    elseif key == "space" then
        self.paused = not self.paused
    elseif key == "m" then
        self:toggleSound()
    end
end

function EnemyAI:wheelmoved(_, y)
    if love.mouse.getX() < SIDEBAR_WIDTH then
        self.sidebarScrollY = clamp(self.sidebarScrollY-y*72, 0,
            math.max(0, #PAGES*36-(love.graphics.getHeight()-168)))
    else
        self.scrollY = clamp(self.scrollY-y*72, 0, self.maxScroll)
    end
end

local function contains(rect, x, y)
    return rect and x >= rect.x and x <= rect.x + rect.width
        and y >= rect.y and y <= rect.y + rect.height
end

function EnemyAI:mousepressed(x, y, button)
    if button ~= 1 then return end
    if contains(self.soundButton, x, y) then
        self:toggleSound()
    elseif contains(self.restartButton, x, y) then
        self:resetPage()
    elseif contains(self.pauseButton, x, y) then
        self.paused = not self.paused
    else
        for _, row in ipairs(self.pageRows) do
            if contains(row, x, y) then
                self:setPage(row.index)
                return
            end
        end
    end
end

function EnemyAI:getGridLayout()
    local width, height = love.graphics.getDimensions()
    local contentX = SIDEBAR_WIDTH + GAP
    local contentWidth = width - contentX - GAP
    local columns = math.max(1, math.floor((contentWidth + GAP) / (CARD_MIN_WIDTH + GAP)))
    local cardWidth = math.floor((contentWidth - GAP * (columns - 1)) / columns)
    local rows = math.ceil(#self.scenarios / columns)
    local viewportHeight = height - HEADER_HEIGHT - FOOTER_HEIGHT
    local contentHeight = rows * CARD_HEIGHT + math.max(0, rows - 1) * GAP + GAP * 2
    return {
        x = contentX, width = contentWidth, columns = columns, cardWidth = cardWidth,
        y = HEADER_HEIGHT, height = viewportHeight, contentHeight = contentHeight,
    }
end

function EnemyAI:drawSidebar(height)
    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, SIDEBAR_WIDTH, height)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", SIDEBAR_WIDTH - 1, 0, 1, height)
    love.graphics.setFont(self.app.fonts.body)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("SCENARIO TESTS", 16, 17)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print(string.format("%d TEST PAGES", #PAGES), 16, 47)

    self.pageRows = {}
    local clipX, clipY, clipWidth, clipHeight = love.graphics.getScissor()
    love.graphics.setScissor(0, 78, SIDEBAR_WIDTH, height-168)
    for index, enemy in ipairs(PAGES) do
        local row = { index = index, x = 8, y = 78 + (index - 1) * 36-self.sidebarScrollY,
            width = SIDEBAR_WIDTH - 16, height = 32 }
        if row.y >= 78 and row.y+row.height <= height-90 then
            self.pageRows[#self.pageRows + 1] = row
        end
        local selected = index == self.pageIndex
        if selected then
            love.graphics.setColor(COLORS.accent)
            love.graphics.rectangle("fill", row.x, row.y, row.width, row.height, 3, 3)
        end
        love.graphics.setFont(self.app.fonts.small)
        love.graphics.setColor(selected and COLORS.selectedText or COLORS.text)
        love.graphics.print(string.format("%02d", index), row.x + 9, row.y + 7)
        love.graphics.print(enemy.name, row.x + 43, row.y + 7)
        if not enemy.scenarios then
            love.graphics.setColor(COLORS.muted)
            love.graphics.printf("—", row.x, row.y + 7, row.width - 9, "right")
        end
    end
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.setScissor(clipX, clipY, clipWidth, clipHeight)
    love.graphics.printf("SCENARIOS LOOP AUTOMATICALLY", 14, height - 74,
        SIDEBAR_WIDTH - 28, "left")
end

function EnemyAI:drawButton(rect, label)
    love.graphics.setColor(COLORS.accent)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 4, 4)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.selectedText)
    love.graphics.printf(label, rect.x, rect.y + 8, rect.width, "center")
end

function EnemyAI:drawHeader(width)
    local enemy = PAGES[self.pageIndex]
    love.graphics.setColor(COLORS.panelDark)
    love.graphics.rectangle("fill", SIDEBAR_WIDTH, 0, width - SIDEBAR_WIDTH, HEADER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", SIDEBAR_WIDTH, HEADER_HEIGHT - 1,
        width - SIDEBAR_WIDTH, 1)
    love.graphics.setFont(self.app.fonts.title)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(enemy.name, SIDEBAR_WIDTH + GAP, 6)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print(enemy.scenarios and string.format("%d SCRIPTED SCENARIOS  •  30 STEPS/S", #self.scenarios)
        or "SCENARIOS COMING SOON", SIDEBAR_WIDTH + GAP + 2, 59)
    self.soundButton = { x = width - 118, y = 25, width = 104, height = 34 }
    self:drawButton(self.soundButton, self.soundEnabled and "MUTE" or "UNMUTE")
    if enemy.scenarios then
        self.restartButton = { x = width - 318, y = 25, width = 88, height = 34 }
        self.pauseButton = { x = width - 218, y = 25, width = 94, height = 34 }
        self:drawButton(self.restartButton, "RESTART")
        self:drawButton(self.pauseButton, self.paused and "RESUME" or "PAUSE")
    else
        self.restartButton, self.pauseButton = nil, nil
    end
end

function EnemyAI:drawScenarioWorld(scenario, x, y, width)
    local previewX, previewY = x + 12, y + 76
    local previewWidth, previewHeight = width - 24, 294
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", previewX, previewY, previewWidth, previewHeight, 3, 3)
    if scenario.kaliGame then
        KaliScenarios.draw(scenario, previewX, previewY, previewWidth, previewHeight, self.app.fonts.small)
        return
    end
    local worldWidth = scenario.world.width * 16
    local worldHeight = scenario.world.height * 16
    local scale = math.max(1, math.min(2, math.floor(previewWidth / worldWidth),
        math.floor(previewHeight / worldHeight)))
    local drawX = math.floor(previewX + (previewWidth - worldWidth * scale) / 2)
    local drawY = worldHeight * scale > previewHeight and previewY
        or math.floor(previewY + (previewHeight - worldHeight * scale) / 2)
    local clipX, clipY, clipWidth, clipHeight = love.graphics.getScissor()
    local left = math.max(previewX, clipX or previewX)
    local top = math.max(previewY, clipY or previewY)
    local right = math.min(previewX + previewWidth,
        clipX and clipX + clipWidth or previewX + previewWidth)
    local bottom = math.min(previewY + previewHeight,
        clipY and clipY + clipHeight or previewY + previewHeight)
    love.graphics.setScissor(left, top, math.max(0, right - left), math.max(0, bottom - top))
    love.graphics.push()
    love.graphics.translate(drawX, drawY)
    love.graphics.scale(scale)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.images.background, scenario.backgroundQuad, 0, 0)
    local queue = DepthQueue.new()
    if scenario.level and #scenario.level.entities > 0 then
        queue:add(Depth.BACKDROP, function()
            local head = scenario.level.entities[1]
            local x, y = (head.x - 1) * 16, (head.y + 1.25) * 16
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.images.tikiBody, x, y)
            love.graphics.draw(self.images.tikiArms, self.tikiArmLeft, x - 16, y)
            love.graphics.draw(self.images.tikiArms, self.tikiArmRight, x + 32, y)
        end)
    end
    queue:add(Depth.TERRAIN, function()
        scenario.world:each("solid", function(tileX, tileY)
            local image = (tileX * 17 + tileY * 31) % 7 == 0
                and self.images.brickAlt or self.images.brick
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, tileX * 16, tileY * 16)
        end)
    end)
    if scenario.block and scenario.block.alive then
        queue:add(Depth.tile("push_block"), function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.images.block, scenario.block.x, scenario.block.y)
        end)
    end
    if scenario.player then
        require("src.platform.pickups.cape").submitWorn(queue, scenario.player)
        if scenario.player.invincibleTimer == 0
            or math.floor(scenario.player.invincibleTimer / 2) % 2 == 1 then
            queue:add(Depth.PLAYER, function() scenario.player:drawBody() end)
            if scenario.player:getWhipPhase() then
                queue:add(Depth.EFFECT, function() scenario.player:drawWhip() end)
            end
        end
    end
    if scenario.tools then scenario.tools:submit(queue) end
    if scenario.idol then
        queue:add(scenario.idol.held and Depth.heldItem(scenario.player)
            or Depth.entity("gold_idol"), function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.images.idol, math.floor(scenario.idol.x - 8),
                math.floor(scenario.idol.y - 12))
        end)
    end
    if scenario.treasure and scenario.treasure.alive then
        queue:add(Depth.entity("ruby_big"), function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.images.ruby, math.floor(scenario.treasure.x - 4),
                math.floor(scenario.treasure.y - 4))
        end)
    end
    if scenario.traps then scenario.traps:submit(queue) end
    if scenario.enemy and scenario.enemy.alive then
        queue:add(Depth.entity(scenario.enemy.kind), function() scenario.enemy:draw() end)
    end
    if scenario.projectiles then scenario.projectiles:submit(queue) end
    MineItemScenarios.submit(queue, scenario, self.itemRenderer)
    queue:add(Depth.EFFECT, function() scenario.effects:draw() end)
    queue:draw()
    if scenario.enemy and scenario.enemy.alive then
        love.graphics.setFont(self.app.fonts.small)
        love.graphics.setColor(COLORS.text)
        love.graphics.print(scenario.enemy.state, scenario.enemy.x - 12,
            scenario.enemy.y - 29, 0, 0.5, 0.5)
    end
    love.graphics.pop()
    love.graphics.setScissor(clipX, clipY, clipWidth, clipHeight)
end

function EnemyAI:drawCard(scenario, x, y, width)
    local definition = scenario.definition
    love.graphics.setColor(COLORS.card)
    love.graphics.rectangle("fill", x, y, width, CARD_HEIGHT, 5, 5)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1,
        CARD_HEIGHT - 1, 5, 5)
    love.graphics.setFont(self.app.fonts.body)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(definition.title, x + 12, y + 9)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(definition.description, x + 12, y + 38, width - 24, "left")
    self:drawScenarioWorld(scenario, x, y, width)
    love.graphics.setColor(scenario.event == "PLAYER HIT" and COLORS.danger
        or scenario.event and COLORS.success or COLORS.text)
    love.graphics.print(scenario.event or (scenario.enemy and scenario.enemy.state)
        or "READY", x + 12, y + 385)
    if scenario.player then
        love.graphics.setColor(COLORS.text)
        local status = scenario.kaliGame and string.format("FAVOR %d · HP %d",
            scenario.kaliGame.run.favor, scenario.player.health) or definition.bomb
            and string.format("HP %d/%d  BOMBS %d", scenario.player.health,
                scenario.player.maxHealth, scenario.bombsRemaining)
            or string.format("HEALTH %d/%d", scenario.player.health, scenario.player.maxHealth)
        love.graphics.printf(status, x + width / 3, y + 385, width / 3, "center")
    end
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(string.format("RUN %02d  •  %d/%d", scenario.runs,
        scenario.tick, definition.duration), x + 12, y + 385, width - 24, "right")
end

function EnemyAI:drawGrid(width, height)
    local layout = self:getGridLayout()
    self.maxScroll = math.max(0, layout.contentHeight - layout.height)
    self.scrollY = clamp(self.scrollY, 0, self.maxScroll)
    if #self.scenarios == 0 then
        love.graphics.setFont(self.app.fonts.body)
        love.graphics.setColor(COLORS.muted)
        love.graphics.printf("Scripted scenarios for " .. PAGES[self.pageIndex].name
            .. " are coming soon.", layout.x, height / 2 - 15,
            layout.width, "center")
        return
    end
    love.graphics.setScissor(layout.x, layout.y, layout.width, layout.height)
    for index, scenario in ipairs(self.scenarios) do
        local column = (index - 1) % layout.columns
        local row = math.floor((index - 1) / layout.columns)
        local x = layout.x + column * (layout.cardWidth + GAP)
        local y = layout.y + GAP + row * (CARD_HEIGHT + GAP) - self.scrollY
        if y + CARD_HEIGHT >= layout.y and y <= layout.y + layout.height then
            self:drawCard(scenario, x, y, layout.cardWidth)
        end
    end
    love.graphics.setScissor()
    if self.maxScroll > 0 then
        local trackHeight = layout.height - 8
        local thumbHeight = math.max(32, trackHeight * layout.height / layout.contentHeight)
        local thumbY = layout.y + 4 + (trackHeight - thumbHeight) * self.scrollY / self.maxScroll
        love.graphics.setColor(COLORS.border)
        love.graphics.rectangle("fill", width - 5, layout.y + 4, 3, trackHeight, 2, 2)
        love.graphics.setColor(COLORS.text)
        love.graphics.rectangle("fill", width - 5, thumbY, 3, thumbHeight, 2, 2)
    end
end

function EnemyAI:drawFooter(width, height)
    love.graphics.setColor(COLORS.panelDark)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, 1)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.printf("A/D OR ←/→  PAGE     W/S OR WHEEL  SCROLL     SPACE  PAUSE     R  RESTART     M  SOUND     ESC  MENU",
        10, height - 25, width - 20, "center")
end

function EnemyAI:draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(COLORS.background)
    self:drawHeader(width)
    self:drawGrid(width, height)
    self:drawSidebar(height)
    self:drawFooter(width, height)
end

return EnemyAI
