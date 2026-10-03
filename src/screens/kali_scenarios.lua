-- Replays use the same simulation and draw path as the live Mines.
local FullLevel = require("src.screens.full_level_playtest")
local Kali = require("src.platform.kali")
local RunState = require("src.game.run_state")
local Tools = require("src.platform.tool_system")
local Traps = require("src.platform.trap_system")
local Projectiles = require("src.platform.projectile_system")
local Sounds = require("src.audio.classic_sounds")

local KaliScenarios = {}
local sounds = Sounds.new()
local toolAssets

local CASES = {
    { key = "living_damsel", title = "Living damsel", kind = "damsel",
        description = "A stunned damsel rests on the altar. Kali grants 8 favor." },
    { key = "dead_damsel", title = "Dead damsel", kind = "damsel", dead = true,
        description = "Classic also grants 8 favor for a dead damsel." },
    { key = "living_caveman", title = "Living caveman", kind = "caveman",
        description = "A stationary stunned caveman grants 2 favor." },
    { key = "dead_caveman", title = "Dead caveman", kind = "caveman", dead = true,
        description = "A dead caveman grants 1 favor." },
    { key = "living_shopkeeper", title = "Living shopkeeper", kind = "shopkeeper",
        description = "A stunned shopkeeper grants 12 favor and a first gift." },
    { key = "dead_shopkeeper", title = "Dead shopkeeper", kind = "shopkeeper", dead = true,
        description = "A dead shopkeeper grants 6 favor." },
    { key = "held", title = "Hold, then release", kind = "damsel",
        description = "Holding prevents sacrifice. DOWN + ACTION releases the body after one second." },
    { key = "equipment", title = "First equipment gift", kind = "damsel",
        description = "Reaching 8 favor creates a free equipment pickup on the altar." },
    { key = "kapala", title = "Kapala gift", kind = "damsel", favor = 8, gift = 1,
        description = "Reaching 16 favor creates the free Kapala pickup." },
    { key = "bombs", title = "Full bomb satchel", kind = "damsel", favor = 24, gift = 2,
        description = "Reaching 32 favor fills the player's bomb satchel to 99." },
    { key = "vitality", title = "Vitality reward", kind = "damsel", favor = 40, gift = 3,
        description = "Reaching 48 favor grants 4–8 health, beyond the starting maximum." },
    { key = "devoured", title = "Very angry Kali", kind = "caveman", favor = -8,
        description = "At -8 favor, Kali devours the body without granting favor." },
    { key = "forgiven", title = "Forgiveness", kind = "caveman", favor = -2,
        description = "A living caveman restores -2 favor to zero: Kali forgives." },
    { key = "spiders", title = "First defilement: spiders", punishment = 0,
        description = "A blast breaks the altar. The head opens and releases six spiders." },
    { key = "chain", title = "Second defilement: chain", punishment = 1,
        description = "An altar support breaks. Kali chains a heavy iron ball to the player." },
    { key = "ghost", title = "Third defilement: haunting", punishment = 2,
        description = "Breaking the altar darkens the room and immediately summons a Ghost." },
}

function KaliScenarios.definitions(makeWorld, makePlayer)
    local definitions = {}
    for _, example in ipairs(CASES) do
        local spec = example
        definitions[#definitions+1] = {
            title = spec.title, description = spec.description,
            duration = 210, seed = 217, kaliSetup = spec,
            build = function(assets)
                return makeWorld(), nil, makePlayer(spec.key == "held" and 104 or 48, assets)
            end,
        }
    end
    return { name = "Kali Altar", scenarios = definitions }
end

local function viewport(game)
    local width, height = game.world.width*16, game.world.height*16
    return { x = 0, y = 0, width = width, height = height, scale = 1,
        logicalWidth = width, logicalHeight = height }
end

function KaliScenarios.reset(scenario, renderer, viewer)
    local spec = scenario.definition.kaliSetup
    if not spec then return end
    local game = FullLevel.new(viewer.app)
    game.seed, game.world, game.player = 217, scenario.world, scenario.player
    local world = game.world
    local altar = { kind = "sacrifice_altar", x = 6, y = 6, properties = {} }
    local head = { kind = "kali_head", x = 7, y = 2, properties = { variant = 1 } }
    game.level = { width = world.width, height = world.height, tileSize = 16,
        absoluteLevel = 1, entities = { altar, head }, tiles = {}, decorations = {},
        backdrops = { { kind = "kali_body", x = 5, y = 3 } } }
    -- Copy the room's collision terrain into the live renderer's tile grid.
    for y = 0, world.height-1 do
        game.level.tiles[y+1] = {}
        for x = 0, world.width-1 do
            game.level.tiles[y+1][x+1] = { kind = world:has("solid", x, y) and "brick" or "empty" }
        end
    end
    world.level, world.game = game.level, game
    world:set("solid", 6, 6, altar)
    world:set("solid", 7, 6, altar)
    game.run = RunState.new(game.seed)
    game.run.favor, game.run.kaliGift, game.run.kaliPunish = spec.favor or 0, spec.gift or 0, spec.punishment or 0
    game.renderer, game.effects = renderer, scenario.effects
    game.tools, game.traps = Tools.new(world), Traps.new(world, game.level)
    game.projectiles = Projectiles.new(world)
    game.tools.game, game.traps.game = game, game
    if not toolAssets then
        game.tools:loadAssets()
        toolAssets = game.tools.assets
    end
    game.tools.assets = toolAssets
    game.tools.explosionSound = nil
    game.sounds = { play = function(_, cue)
        if viewer.soundEnabled then sounds:play(cue) end
    end }
    game:configureProjectiles()
    game.getViewport = viewport
    game.cameraWidth, game.cameraHeight = world.width*16, world.height*16
    scenario.kaliGame, scenario.altar = game, altar
    if game.run.kaliPunish >= 2 then Kali.attachBall(game) end
    if spec.kind then
        local body = game:spawnEntity(spec.kind, 104, 96)
        body:damage(spec.dead and 100 or 1, body.x-8, { kind = spec.kind == "shopkeeper" and "bullet" or "whip" })
        body.x, body.y, body.vx, body.vy = 104, 96, 0, 0
        scenario.body = body
        if spec.key == "held" then
            game.player.y = 88
            assert(body:pickup(game.player), "The held Kali replay needs a carryable body")
            game.heldNpc = body
        end
    end
end

function KaliScenarios.step(scenario, viewer)
    local game = scenario.kaliGame
    local spec = scenario.definition.kaliSetup
    local input = {}
    if spec.key == "held" and scenario.tick == 35 then input = { down = true, attack = true } end
    if scenario.tick == 30 and spec.punishment ~= nil then
        if spec.key == "chain" then game.world:remove("solid", 7, 7)
        else
            game.tools:explode(120, 104)
            viewer:playScenarioSound("explosion")
        end
    end
    if spec.key == "chain" and scenario.tick > 30 and scenario.tick < 90 then input.right = true end
    -- Keep the final death frame visible until replay, rather than generating
    -- a new random level inside this small scenario room.
    if not game.player:isDead() then game:simulationStepBody(input) end
    if game.run.kaliPunish > (spec.punishment or 0) then
        scenario.event = spec.key == "spiders" and "6 SPIDERS"
            or spec.key == "chain" and "BALL & CHAIN" or "DARK + GHOST"
    elseif scenario.body and scenario.body.sacrificed then
        scenario.event = spec.key == "devoured" and "DEVOURED"
            or spec.key == "forgiven" and "FORGIVEN"
            or game.run.kaliGift > (spec.gift or 0) and "GIFT GRANTED" or "SACRIFICED"
    elseif game.heldNpc then scenario.event = "HELD: NO FAVOR"
    elseif spec.key == "held" then scenario.event = "RELEASED" end
end

function KaliScenarios.draw(scenario, x, y, width, height, font)
    local game = scenario.kaliGame
    local worldWidth, worldHeight = game.world.width*16, game.world.height*16
    local scale = math.max(1, math.min(2, math.floor(width/worldWidth), math.floor(height/worldHeight)))
    local clipX, clipY, clipWidth, clipHeight = love.graphics.getScissor()
    -- drawWorld establishes its own scissor; preserve the grid's scroll clip
    -- with a stencil so cards cannot paint over the header or footer.
    love.graphics.stencil(function() love.graphics.rectangle("fill", x, y, width, height) end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    local viewport = { x = math.floor(x+(width-worldWidth*scale)/2),
        y = math.floor(y+(height-worldHeight*scale)/2), width = worldWidth*scale,
        height = worldHeight*scale, scale = scale,
        logicalWidth = worldWidth, logicalHeight = worldHeight }
    game:drawWorld(viewport)
    game:drawGameplayMessages(viewport)
    love.graphics.setStencilTest()
    love.graphics.setScissor(clipX, clipY, clipWidth, clipHeight)
end

return KaliScenarios
