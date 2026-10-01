local Depth = require("src.render.classic_depth")
local DepthQueue = require("src.render.depth_queue")
local Enemy = require("src.platform.enemy")
local MinesGenerator = require("src.world.mines_generator")
local MinesVariants = require("src.world.mines_variants")
local RunState = require("src.game.run_state")

local Test = {}

local function before(order, a, b)
    local positions = {}
    for index, label in ipairs(order) do
        if not positions[label] then positions[label] = index end
    end
    assert(positions[a] and positions[b] and positions[a] < positions[b],
        a .. " must draw behind " .. b)
end

function Test.run(app)
    -- Classic's observable overlaps: backdrop/door/ladder/web/spikes/terrain,
    -- ground enemy/player/air enemy/lip/effects/held object.
    local queue = DepthQueue.new()
    local order = {}
    for _, object in ipairs({
        { "held", Depth.HELD_ITEM }, { "snake", Depth.entity("snake") },
        { "terrain", Depth.TERRAIN }, { "lip", Depth.CAVE_LIP },
        { "player", Depth.PLAYER }, { "web", Depth.entity("web") },
        { "ladder", Depth.tile("ladder") }, { "spikes", Depth.entity("spikes") },
        { "bat", Depth.entity("bat") }, { "entrance", Depth.entity("entrance") },
        { "effects", Depth.EFFECT },
    }) do
        local label = object[1]
        queue:add(object[2], function() order[#order + 1] = label end)
    end
    queue:draw()
    local expected = "entrance,ladder,web,spikes,terrain,snake,player,bat,lip,effects,held"
    assert(table.concat(order, ",") == expected, "Classic draw-depth ordering changed")
    assert(Depth.entity("bomb") == 99 and Depth.entity("bomb", "armed") == 49
        and Depth.entity("bomb", "sticky") == 1,
        "Bombs must change draw depth as they arm or stick")
    assert(Depth.heldItem({ state = "climbing", equipment = { jetpack = true } }) == 51
        and Depth.heldItem({ state = "standing", equipment = {} }) == 0,
        "The held object must move behind a jetpack climber")
    assert(Depth.entity("player", "exiting") == 999,
        "The player must move behind terrain while exiting")
    assert(Depth.entity("shop_sign") == 110 and Depth.entity("scarab") == 40,
        "Room-generated signs and scarabs must use their object depths")
    local okUnknown = pcall(Depth.entity, "unmapped_mines_object")
    assert(not okUnknown, "New visible Mines kinds need a checked source depth")
    for seed = 1, 8 do
        for levelNumber = 1, 4 do
            local level = MinesGenerator.generate(seed * 1297, { levelNumber = levelNumber })
            MinesVariants.apply(level, RunState.new(seed))
            for _, row in ipairs(level.tiles) do
                for _, tile in ipairs(row) do Depth.tile(tile.kind) end
            end
            for _, entity in ipairs(level.entities) do
                if not entity.kind:match("^hidden_") then Depth.entity(entity.kind) end
            end
        end
    end

    local renderer = app.screens.world_generation
    local originalEntity, originalTile, originalBackdrop =
        renderer.drawEntity, renderer.drawTile, renderer.drawBackdrops
    local previewOrder = {}
    renderer.drawEntity = function(_, entity) previewOrder[#previewOrder + 1] = entity.kind end
    renderer.drawTile = function(_, tile) previewOrder[#previewOrder + 1] = tile.kind end
    renderer.drawBackdrops = function() previewOrder[#previewOrder + 1] = "backdrop" end
    local previewOk, previewError = pcall(function()
        local mini = {
            width = 3, height = 1, decorations = {}, backdrops = {},
            tiles = { {
                { kind = "brick" }, { kind = "smooth_brick" }, { kind = "ladder" },
            } },
            entities = {
                { kind = "rock" }, { kind = "ruby_big" }, { kind = "web" },
                { kind = "kali_head" }, { kind = "entrance" }, { kind = "shop_sign" },
                { kind = "player" },
            },
        }
        local preview = DepthQueue.new()
        renderer:submitLevel(preview, mini)
        preview:draw()
    end)
    renderer.drawEntity, renderer.drawTile, renderer.drawBackdrops =
        originalEntity, originalTile, originalBackdrop
    assert(previewOk, previewError)
    before(previewOrder, "backdrop", "entrance")
    before(previewOrder, "entrance", "ladder")
    before(previewOrder, "ladder", "kali_head")
    before(previewOrder, "kali_head", "web")
    before(previewOrder, "web", "shop_sign")
    before(previewOrder, "shop_sign", "smooth_brick")
    before(previewOrder, "smooth_brick", "ruby_big")
    before(previewOrder, "ruby_big", "brick")
    before(previewOrder, "rock", "brick") -- deliberate equal-depth terrain occlusion
    before(previewOrder, "brick", "player")

    local tools = app.screens.full_level_playtest.tools
    local oldBombs, oldRopes, oldDrawBomb, oldDrawRope, oldDrawExplosions =
        tools.bombs, tools.ropes, tools.drawBomb, tools.drawRope, tools.drawExplosions
    local toolOrder = {}
    tools.bombs = {
        { alive = true, timer = 80, flashStart = 20, label = "loose" },
        { alive = true, armed = true, timer = 10, flashStart = 20, label = "armed" },
        { alive = true, timer = 80, flashStart = 20, sticky = true, label = "sticky" },
    }
    tools.ropes = {
        { alive = true, deployed = true, label = "rope" },
        { alive = true, deployed = false, label = "rope_throw" },
    }
    tools.drawBomb = function(_, bomb) toolOrder[#toolOrder + 1] = bomb.label end
    tools.drawRope = function(_, rope) toolOrder[#toolOrder + 1] = rope.label end
    tools.drawExplosions = function() toolOrder[#toolOrder + 1] = "explosion" end
    local toolOk, toolError = pcall(function()
        local toolQueue = DepthQueue.new()
        toolQueue:add(Depth.TERRAIN, function() toolOrder[#toolOrder + 1] = "terrain" end)
        toolQueue:add(Depth.PLAYER, function() toolOrder[#toolOrder + 1] = "player" end)
        toolQueue:add(Depth.CAVE_LIP, function() toolOrder[#toolOrder + 1] = "lip" end)
        tools:submit(toolQueue)
        toolQueue:draw()
    end)
    tools.bombs, tools.ropes, tools.drawBomb, tools.drawRope, tools.drawExplosions =
        oldBombs, oldRopes, oldDrawBomb, oldDrawRope, oldDrawExplosions
    assert(toolOk, toolError)
    before(toolOrder, "rope", "terrain")
    before(toolOrder, "terrain", "rope_throw")
    before(toolOrder, "terrain", "loose")
    before(toolOrder, "loose", "player")
    before(toolOrder, "player", "armed")
    before(toolOrder, "lip", "sticky")

    local screen = app.screens.full_level_playtest
    local snake = Enemy.new("snake", screen.player.x + 32, screen.player.y)
    local bat = Enemy.new("bat", screen.player.x + 48, screen.player.y)
    local oldEnemies = screen.enemies
    local oldSnakeDraw, oldBatDraw = snake.draw, bat.draw
    local oldPlayerDraw, oldEffectsDraw = screen.player.drawBody, screen.effects.draw
    local oldGraphicsDraw = love.graphics.draw
    local oldInvincibleTimer = screen.player.invincibleTimer
    local liveOrder = {}
    screen.enemies = { snake, bat }
    snake.draw = function() liveOrder[#liveOrder + 1] = "snake" end
    bat.draw = function() liveOrder[#liveOrder + 1] = "bat" end
    screen.player.drawBody = function(self, ...)
        liveOrder[#liveOrder + 1] = "player"
        return oldPlayerDraw(self, ...)
    end
    screen.effects.draw = function(self, ...)
        liveOrder[#liveOrder + 1] = "effects"
        return oldEffectsDraw(self, ...)
    end
    love.graphics.draw = function(image, ...)
        if image == renderer.images.bg_cave_top then liveOrder[#liveOrder + 1] = "lip" end
        return oldGraphicsDraw(image, ...)
    end
    local liveOk, liveError = pcall(function()
        screen.player.invincibleTimer = 0
        screen:drawWorld({ x = 0, y = 0, width = 320, height = 240,
            scale = 1, logicalWidth = 320, logicalHeight = 240 })
    end)
    screen.enemies = oldEnemies
    snake.draw, bat.draw = oldSnakeDraw, oldBatDraw
    screen.player.drawBody, screen.effects.draw = oldPlayerDraw, oldEffectsDraw
    screen.player.invincibleTimer = oldInvincibleTimer
    love.graphics.draw = oldGraphicsDraw
    assert(liveOk, liveError)
    before(liveOrder, "snake", "player")
    before(liveOrder, "player", "bat")
    before(liveOrder, "bat", "lip")
    before(liveOrder, "lip", "effects")
end

return Test
