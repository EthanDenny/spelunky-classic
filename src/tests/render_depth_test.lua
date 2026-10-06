local Depth = require("src.render.classic_depth")
local DepthQueue = require("src.render.depth_queue")
local Enemy = require("src.platform.enemy")
local MinesGenerator = require("src.world.mines_generator")
local RunState = require("src.game.run_state")
local Item = require("src.platform.item")
local Player = require("src.platform.player")

local Test = {}

local function assertDarkLighting(app)
    local game = require("src.screens.full_level_playtest").new(app)
    game:loadAssets()
    game:generateLevel(17)
    game.player.x, game.player.y, game.player.visible = 400, 300, false
    game.enemies, game.items, game.collectibles, game.hiddenEntities = {}, {}, {}, {}
    game.fakeBones, game.level.entities, game.level.decorations, game.level.backdrops = {}, {}, {}, {}
    game.tools.bombs, game.tools.ropes, game.tools.explosions = {}, {}, {}
    game.traps.traps = {}
    -- A uniform visible field makes tint and circle boundaries independent of
    -- the cave texture's naturally black pixels. The world render path is live.
    function game:drawBackground()
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 0, 0, self.world.width*16, self.world.height*16)
    end
    for _, row in ipairs(game.level.tiles) do
        for x in ipairs(row) do row[x] = { kind = "empty" } end
    end
    local logicalMask
    for _, scale in ipairs({ 1, 2, 3 }) do
        local view = { x = 7, y = 9, width = 320*scale, height = 240*scale,
            scale = scale, logicalWidth = 320, logicalHeight = 240 }
        local canvas = love.graphics.newCanvas(view.width+14, view.height+18)
        local function render(dark)
            game.level.dark = dark
            love.graphics.push("all")
            love.graphics.origin()
            love.graphics.setScissor()
            love.graphics.setCanvas({ canvas, stencil = true })
            love.graphics.clear(0.3, 0.4, 0.5, 1)
            game:drawWorld(view)
            love.graphics.pop()
            return canvas:newImageData()
        end
        local function pixel(image, x, y)
            return image:getPixel(view.x+x*scale, view.y+y*scale)
        end
        local function lit(actual, x, y, tint)
            local r, g, b = pixel(actual, x, y)
            assert(math.abs(r-0.6*tint) < 0.01 and math.abs(g-0.4*tint) < 0.01
                and math.abs(b-0.2) < 0.01, "Dark-level light circles must retain the source blue tint")
        end
        local function black(actual, x, y)
            local r, g, b = pixel(actual, x, y)
            assert(r == 0 and g == 0 and b == 0, "Terrain outside light circles must be black")
        end
        local dark = render(true)
        if scale == 1 then
            logicalMask = dark
        else
            for y = 0, 239 do
                for x = 0, 319 do
                    local er, eg, eb = logicalMask:getPixel(7+x, 9+y)
                    for dy = 0, scale-1 do
                        for dx = 0, scale-1 do
                            local r, g, b = dark:getPixel(view.x+x*scale+dx, view.y+y*scale+dy)
                            assert(math.abs(r-er) < 0.01 and math.abs(g-eg) < 0.01
                                and math.abs(b-eb) < 0.01,
                                "Dark light boundaries must enlarge whole 320x240 pixels at every scale")
                        end
                    end
                end
            end
        end
        -- oScreen: radius 96-64*0.9 = 38.4, centered on the player.
        lit(dark, 160, 120, 0.1)
        lit(dark, 197, 120, 0.1)
        black(dark, 200, 120)
        game.player.equipment.spectacles = true
        black(render(true), 200, 120)
        game.level.entities = { { kind = "lamp", x = 35, y = 19 } }
        dark = render(true)
        lit(dark, 234, 132, 0.1) -- lamp center (x+8,y+8), radius 96
        black(dark, 230, 132)
        game.level.entities = { { kind = "lamp", x = 25, y = 18.75 } }
        dark = render(true)
        lit(dark, 160, 30, 1) -- nearby lamp expands the player's radius to 96
        black(dark, 160, 20)
        local r, g, b = dark:getPixel(0, 0)
        assert(math.abs(r-0.3) < 0.01 and math.abs(g-0.4) < 0.01 and math.abs(b-0.5) < 0.01,
            "Darkness must stay inside the scaled camera viewport")
        game.level.entities = { { kind = "arrow_trap_left_lit", x = 15, y = 18.75 } }
        dark = render(true)
        lit(dark, 8, 98, 0.1) -- source trap circle: center +8,+8, radius 32
        black(dark, 8, 92)
        game.level.entities = { { kind = "lamp_red", x = 25, y = 18.75 } }
        dark = render(true)
        r, g, b = pixel(dark, 125, 120)
        assert(math.abs(r-0.6) < 0.01 and math.abs(g-0.4*24/255) < 0.01
            and math.abs(b-0.2*24/255) < 0.01, "Nearby hanging red lamps must tint the source light mask red")
        r, g, b = pixel(dark, 160, 30)
        assert(math.abs(r-0.6) < 0.01 and math.abs(g-0.4*24/255) < 0.01
            and math.abs(b-0.2*24/255) < 0.01, "Hanging red lamps must retain the full 96-pixel circle")
        game.level.entities = {}
        local redLamp = game:spawnEntity("lamp_red_item", 400, 300)
        dark = render(true)
        r, g, b = pixel(dark, 125, 120)
        assert(math.abs(r-0.6) < 0.01 and math.abs(g-0.4*24/255) < 0.01
            and math.abs(b-0.2*24/255) < 0.01, "Dropped red lamps must tint the player's existing light circle")
        black(dark, 200, 120) -- oLampRedItem does not inherit oLampItem's extra circle
        redLamp.alive = false
        game.items = {}
        for _, source in ipairs({
            { "lamp_item", 240, 304, 0, 26, 22 },
            { "flare", 240, 300, 0, 26, 22 },
            { "scarab", 272, 300, 32, 105, 101 },
            { "ghost", 264, 300, 32, 58, 52 },
        }) do
            local body = game:spawnEntity(source[1], source[2], source[3])
            dark = render(true)
            lit(dark, source[4], source[5], 0.1)
            black(dark, source[4], source[6])
            body.alive = false
            black(render(true), source[4], source[5])
            game.items, game.collectibles, game.enemies = {}, {}, {}
        end
        game.tools:explode(240, 300)
        dark = render(true)
        lit(dark, 0, 26, 0.1)
        black(dark, 0, 22)
        game.tools.explosions[1].alive = false
        black(render(true), 0, 26)
        game.tools.explosions = {}
        canvas:release()
    end
end

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
            for _, row in ipairs(level.tiles) do
                for _, tile in ipairs(row) do Depth.tile(tile.kind) end
            end
            for _, entity in ipairs(level.entities) do
                if not entity.kind:match("^hidden_") then Depth.entity(entity.kind) end
            end
        end
    end

    local renderer = app.renderer
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

    do
        local game = require("src.screens.full_level_playtest").new(app)
        game.renderer = renderer
        game:generateLevel(17)
        game:spawnEntity("flare", 80, 80)
        game:spawnEntity("lamp_item", 96, 80)
        game:spawnEntity("diamond", 112, 80)
        game:spawnEntity("ghost", 144, 96)
        game.effects:add("teleport_spark", 120, 80)
        game.effects:add("blood_spark", 128, 80)
        local entityDraw, tileDraw, itemDraw = renderer.drawEntity, renderer.drawTile, renderer.drawItem
        local order = {}
        local particleDraw = game.effects.drawParticle
        game.effects.drawParticle = function(self, particle, ...)
            order[#order+1] = particle.kind
            return particleDraw(self, particle, ...)
        end
        renderer.drawEntity = function(self, entity)
            order[#order+1] = entity.kind
            return entityDraw(self, entity)
        end
        renderer.drawItem = function(self, item, ...)
            order[#order+1] = item.kind
            return itemDraw(self, item, ...)
        end
        renderer.drawTile = function(self, tile, ...)
            order[#order+1] = tile.kind
            return tileDraw(self, tile, ...)
        end
        local ok, err = pcall(function()
            local view = { x = 0, y = 0, width = 320, height = 240,
                scale = 1, logicalWidth = 320, logicalHeight = 240 }
            game:drawWorld(view)
            before(order, "flare", "brick")
            before(order, "lamp_item", "brick")
            before(order, "diamond", "brick")
            before(order, "brick", "blood_spark")
            game.player.equipment.spectacles = true
            order = {}
            game:drawWorld(view)
            before(order, "brick", "flare")
            before(order, "brick", "lamp_item")
            before(order, "brick", "diamond")
            game.exiting, game.player.state = 16, "exiting"
            game:drawWorld(view)
        end)
        renderer.drawEntity, renderer.drawTile, renderer.drawItem = entityDraw, tileDraw, itemDraw
        game.effects.drawParticle = particleDraw
        assert(ok, err)
    end

    local heldImages, heldAngles = {}, {}
    local drawImage = love.graphics.draw
    love.graphics.draw = function(image, ...)
        heldImages[#heldImages + 1] = image
        local args = { ... }
        heldAngles[#heldAngles + 1] = args[3]
        return drawImage(image, ...)
    end
    local heldOk, heldError = pcall(function()
        for _, kind in ipairs({ "mattock", "machete", "pistol", "shotgun",
            "bow", "web_cannon", "key" }) do
            local item = { kind = kind, x = 80, y = 80, facing = -1 }
            heldImages = {}
            renderer:drawItem(item)
            assert(heldImages[1] == renderer.entitySprites[kind .. "_left"].image,
                "A left-facing held " .. kind .. " must use its original left sprite")
            heldImages = {}
            renderer:drawItem(item, 1)
            assert(heldImages[1] == renderer.entitySprites[kind].image,
                "Turning right must restore the original right sprite for " .. kind)
        end
        assert(renderer.entitySprites.key_left.metadata.originY == 6,
            "The original left key sprite has a different origin from the right sprite")
        local bow = { kind = "bow", x = 80, y = 80, facing = 1,
            held = true, bowStrength = 10 }
        heldImages = {}
        renderer:drawItem(bow)
        assert(heldImages[1] == renderer.itemAnimationSprites.bowRight[4],
            "A fully drawn bow must display its fourth Classic frame")
        local chest = { kind = "chest", x = 80, y = 80, opened = true }
        heldImages = {}
        renderer:drawItem(chest)
        assert(heldImages[1] == renderer.itemAnimationSprites.chestOpen,
            "An opened chest must show the open sprite instead of disappearing")
        local die = { kind = "die", x = 80, y = 80, diceValue = 5,
            diceRolling = false }
        heldImages = {}
        renderer:drawItem(die)
        assert(heldImages[1] == renderer.itemAnimationSprites.diceFaces[5],
            "A settled die must show the rolled face")
        die.diceRolling, die.diceAge = true, 5
        heldImages = {}
        renderer:drawItem(die)
        assert(heldImages[1] == renderer.itemAnimationSprites.diceRoll[6],
            "A moving die must show a rolling frame")
        local arrow = { kind = "arrow", x = 80, y = 80, held = true,
            arrowAngle = -math.pi / 2, facing = 1, vx = 0, vy = 0 }
        heldAngles = {}
        renderer:drawItem(arrow, 1)
        assert(heldAngles[1] == 0,
            "A held arrow must point horizontally even if it was picked up mid-flight")
        local swinger = Player.new(80, 80)
        swinger.facing = 1
        swinger.meleeFacing = -1
        swinger.meleeVisualPhase = "front"
        swinger.meleeStrikeAge = 0
        heldImages = {}
        renderer:drawMeleeSwing(swinger, Item.new({ kind = "machete", x = 5, y = 5 }))
        assert(heldImages[1] == renderer.meleeSprites.sSlashLeft[1],
            "Turning mid-swing must not flip an already spawned slash")
    end)
    love.graphics.draw = drawImage
    assert(heldOk, heldError)
    assertDarkLighting(app)
end

return Test
