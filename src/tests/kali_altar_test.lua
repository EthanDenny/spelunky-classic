local Controls = require("src.input.classic_controls")
local FullLevel = require("src.screens.full_level_playtest")
local World = require("src.platform.world")
local Player = require("src.platform.player")
local RunState = require("src.game.run_state")
local Effects = require("src.platform.effects")
local Tools = require("src.platform.tool_system")
local Traps = require("src.platform.trap_system")
local Projectiles = require("src.platform.projectile_system")

local Test = {}
local function fixture()
    local game = FullLevel.new({ controls = Controls.fromContents(nil, nil) })
    game.seed = 17
    game.world = World.new(42, 34, 16)
    game.world:fill("solid", 0, 7, 42, 1)
    game.level = { width = 42, height = 34, entities = {}, absoluteLevel = 2,
        tiles = {},
        roomPath = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } } }
    game.world.level = game.level
    for y = 1, 34 do
        game.level.tiles[y] = {}
        for x = 1, 42 do game.level.tiles[y][x] = { kind = y == 8 and "brick" or "empty" } end
    end
    game.player = Player.new(64, 104)
    game.player.state = Player.STATES.standing
    game.run = RunState.new(17)
    game.effects = Effects.new(17)
    game.tools = Tools.new(game.world)
    game.traps = Traps.new(game.world, game.level)
    game.projectiles = Projectiles.new(game.world)
    game.renderer = { entitySprites = {} }
    game.sounds = { play = function() end }
    local altar = { kind = "sacrifice_altar", x = 10, y = 6, properties = {} }
    game.level.entities[1] = altar
    game.world:set("solid", 10, 6, altar)
    game.world:set("solid", 11, 6, altar)
    return game, altar
end

local function ticks(game, count)
    for _ = 1, count do game:simulationStepBody({}) end
end

local function sacrificeBody(game, kind, dead, x)
    local body = game:spawnEntity(kind, x or 168, 96)
    body:damage(dead and 100 or 1, body.x - 8, { kind = "bullet" })
    -- Put the damaged body on the altar after its landing; damage and all
    -- subsequent physics, eligibility, rewards and removal use real owners.
    body.x, body.y, body.vx, body.vy = x or 168, 96, 0, 0
    return body
end

function Test.run(app)
    local cases = {
        { "stationary bodies are consumed after twenty countdown ticks", function()
            for _, example in ipairs({ { "caveman", false, 2 }, { "caveman", true, 1 },
                { "shopkeeper", false, 12 }, { "shopkeeper", true, 6 },
                { "damsel", false, 8 }, { "damsel", true, 8 } }) do
                local game = fixture()
                local body = sacrificeBody(game, example[1], example[2], 184)
                ticks(game, 20)
                assert(game.run.favor == 0, "No early sacrifice on tick twenty")
                ticks(game, 1)
                assert(game.run.favor == example[3] and not body.alive
                    and not body.corpse, example[1] .. " must give its source favor and disappear")
                assert(game.run.kills == (example[2] and 1 or 0),
                    "A living sacrifice must not count as a combat kill")
                ticks(game, 30)
                assert(game.run.favor == example[3], "A consumed body cannot score twice")
            end
        end },
        { "holding resets sacrifice progress and healthy actors and items are excluded", function()
            local game = fixture()
            local body = sacrificeBody(game, "damsel", false)
            ticks(game, 10)
            game.player.x, game.player.y = body.x - 4, body.y - 8
            game.player.state = Player.STATES.ducking
            game:handleActionPressed({ down = true, attack = true })
            assert(game.heldNpc == body, "The damaged body must be picked up through ACTION")
            ticks(game, 25)
            assert(game.run.favor == 0 and body.alive, "Held bodies must never sacrifice")
            body:throw(game.player, { down = true }, game.world)
            game.heldNpc = nil
            game.player.x, game.player.y = 64, 104
            body.x, body.y, body.vx, body.vy = 168, 96, 0, 0
            ticks(game, 20)
            assert(game.run.favor == 0, "Picking up must restart the countdown")
            ticks(game, 1)
            assert(game.run.favor == 8, "Dropped living damsels can be sacrificed")
            local moving = fixture()
            local movingBody = sacrificeBody(moving, "damsel", false)
            ticks(moving, 10)
            movingBody.vx = 1
            for _ = 1, 10 do
                if movingBody.vx == 0 then break end
                ticks(moving, 1)
            end
            assert(movingBody.vx == 0, "The thrown body must finish sliding before this countdown")
            ticks(moving, 20)
            assert(moving.run.favor == 0, "Motion must discard the previous partial countdown")
            ticks(moving, 1)
            assert(moving.run.favor == 8, "A moving body must become eligible after settling")
            local ignored = fixture()
            local rock = ignored:spawnEntity("rock", 184, 92)
            local healthy = ignored:spawnEntity("shopkeeper", 168, 96)
            ticks(ignored, 30)
            assert(ignored.run.favor == 0 and rock.alive and healthy.alive,
                "Loose items and healthy walking actors are not sacrifices")
        end },
        { "gifts are free world pickups and favor thresholds retain their order", function()
            local game = fixture()
            game.run.favor = 8
            sacrificeBody(game, "damsel", true)
            ticks(game, 21)
            local gift = game.items[1]
            assert(game.run.kaliGift == 2 and gift and gift.kind == "kapala"
                and not gift.properties.forSale and not game.run.equipment.kapala,
                "Sixteen favor must create a free Kapala to collect")
            game.run.favor = 24
            sacrificeBody(game, "damsel", true)
            ticks(game, 21)
            assert(game.run.bombs == 99 and game.run.kaliGift == 3,
                "Thirty-two favor fills the bomb satchel")
            game.run.favor = 40
            sacrificeBody(game, "damsel", true)
            local health = game.player.health
            ticks(game, 21)
            assert(game.run.kaliGift == 4 and game.player.health >= health + 4
                and game.player.health <= health + 8, "Forty-eight favor grants uncapped vitality")
            health = game.player.health
            sacrificeBody(game, "caveman", true)
            ticks(game, 21)
            assert(game.run.kaliGift == 4 and game.player.health == health,
                "Vitality must not repeat until the next sixteen favor milestone")
        end },
        { "severe anger devours sacrifices while lesser anger can be forgiven", function()
            for _, favor in ipairs({ -8, -2 }) do
                local game = fixture()
                game.run.favor = favor
                local body = sacrificeBody(game, "caveman", false)
                ticks(game, 21)
                assert(game.run.favor == (favor == -8 and -8 or 0) and body.sacrificed
                    and game.run:currentMessage().text:find(favor == -8 and "DEVOURS" or "FORGIVEN"),
                    "Very angry Kali refuses favor; lesser anger permits recovery")
            end
        end },
        { "the first gift skips owned equipment and has useful fallbacks", function()
            for _, expected in ipairs({ "compass", "jetpack", "bomb_box" }) do
                local game = fixture()
                for _, kind in ipairs({ "cape", "gloves", "spectacles", "mitt",
                    "spring_shoes", "spike_shoes", "paste" }) do game.player.equipment[kind] = true end
                game.player.equipment.compass = expected ~= "compass"
                game.player.equipment.jetpack = expected == "bomb_box"
                sacrificeBody(game, "damsel", true)
                ticks(game, 21)
                local gift = game.items[1]
                assert(game.run.kaliGift == 1 and gift and gift.kind == expected
                    and gift.properties.cost == 0 and gift.properties.forSale == false,
                    "The first gift must select " .. expected .. " when the other equipment is owned")
                sacrificeBody(game, "caveman", true)
                ticks(game, 21)
                assert(#game.items == 1, "Favor between thresholds must not repeat equipment gifts")
            end
        end },
        { "a full satchel receives vitality and a threshold jump skips lower gifts", function()
            local game = fixture()
            game.run.favor, game.run.kaliGift, game.run.bombs = 24, 2, 80
            sacrificeBody(game, "damsel", true)
            ticks(game, 21)
            assert(game.run.bombs == 80 and game.run.kaliGift == 3
                and game.player.health >= 8 and game.player.health <= 12,
                "Eighty bombs must switch the thirty-two favor gift to vitality")
            local jumped = fixture()
            jumped.run.favor = 26
            sacrificeBody(jumped, "shopkeeper", true)
            ticks(jumped, 21)
            assert(jumped.run.bombs == 99 and jumped.run.kaliGift == 3,
                "A jump to thirty-two must give the bomb reward")
            for _, item in ipairs(jumped.items) do
                assert(not require("src.platform.item").isEquipment(item.kind),
                    "A jump to thirty-two must skip the lower equipment gifts")
            end
        end },
        { "dead bodies stay carryable and healthy enemies cannot be grabbed", function()
            for _, kind in ipairs({ "caveman", "shopkeeper", "damsel" }) do
                local game = fixture()
                local body = sacrificeBody(game, kind, true)
                game.player.x, game.player.y = body.x, body.y - 8
                game:simulationStepBody({ down = true, attack = true })
                assert(game.heldNpc == body and body.corpse and not body.alive,
                    "ACTION must pick up a dead " .. kind)
                ticks(game, 25)
                assert(body.held and game.run.favor == 0, "A held corpse cannot be consumed")
                body:draw(app.screens.world_generation)
                game:handleActionPressed({ down = true, attack = true })
                assert(not game.heldNpc and not body.held and body.corpse,
                    "ACTION must release a corpse without resurrecting it")
            end
            local game = fixture()
            local body = game:spawnEntity("caveman", game.player.x, game.player.y)
            game.player.state = Player.STATES.ducking
            game:handleActionPressed({ down = true, attack = true })
            assert(not game.heldNpc and body.alive, "Healthy cavemen cannot be picked up")
        end },
        { "altar destruction penalizes once, removes all altars and activates every head", function()
            local game, altar = fixture()
            local second = { kind = "sacrifice_altar", x = 20, y = 6, properties = {} }
            game.level.entities[2] = second
            game.world:set("solid", 20, 6, second)
            game.world:set("solid", 21, 6, second)
            game.level.entities[3] = { kind = "kali_head", x = 11, y = 4, properties = { variant = 1 } }
            game.level.entities[4] = { kind = "kali_head", x = 21, y = 4, properties = { variant = 3 } }
            game.tools:explode(184, 104)
            ticks(game, 2)
            assert(altar.destroyed and second.destroyed and game.run.favor == -16
                and game.run.kaliPunish == 1 and #game.enemies == 12,
                "Either half's destruction must cause one penalty and six spiders per head")
            ticks(game, 1)
            assert(game.run.kaliPunish == 1, "Destroyed altars must not punish on subsequent ticks")
            app.screens.world_generation:drawEntity(game.level.entities[3])
            game.effects:draw()
        end },
        { "support collapse escalates to ball and chain then darkness and a ghost", function()
            local game = fixture()
            game.run.kaliPunish = 1
            game.world:remove("solid", 11, 7)
            ticks(game, 1)
            assert(game.run.kaliPunish == 2 and game.items[1] and game.items[1].kind == "ball",
                "Removing support beneath either altar half must attach the iron ball")
            local ball = game.items[1]
            ball.x, ball.y, ball.vx, ball.vy = 20, 107, 0, 0
            game.player.x, game.player.y, game.player.vx = 64, 104, 3
            game:simulationStepBody({ right = true })
            assert(game.player.vx == 0 and ball.vx > 0,
                "The chain must restrain the player and pull the ball")
            local cursed = fixture()
            cursed.run.kaliPunish = game.run.kaliPunish
            cursed.world:remove("solid", 10, 6)
            ticks(cursed, 1)
            assert(cursed.level.dark and cursed.ghostSpawned and cursed.enemies[1]
                and cursed.enemies[1].kind == "ghost" and cursed.run.kaliPunish == 3,
                "The third destruction must darken the level and immediately summon a ghost")
            local alreadyDark = fixture()
            alreadyDark.run.kaliPunish = 3
            alreadyDark.level.dark, alreadyDark.ghostSpawned = true, true
            alreadyDark:spawnEntity("ghost", -32, 120)
            alreadyDark.level.entities[#alreadyDark.level.entities + 1] = {
                kind = "kali_head", x = 11, y = 4, properties = { variant = 2 } }
            alreadyDark.world:remove("solid", 10, 6)
            ticks(alreadyDark, 2)
            assert(#alreadyDark.enemies == 7 and alreadyDark.run.kaliPunish == 4,
                "An already haunted dark level must get six spiders instead of a second ghost")
        end },
        { "exits retain Kali progress and chains while dropping corpses", function()
            local game = FullLevel.new(app)
            game.renderer = app.screens.world_generation
            game:generateLevel(17)
            game.run.favor, game.run.kaliGift, game.run.kaliPunish = 16, 2, 2
            local body = game:spawnEntity("damsel", game.player.x, game.player.y)
            body:damage(100)
            assert(body:pickup(game.player), "The transition begins with a dead held damsel")
            game.heldNpc = body
            game:advanceLevel()
            assert(game.run.favor == 16 and game.run.kaliGift == 2 and game.run.kaliPunish == 2
                and not game.heldNpc and body.corpse and not body.held
                and game.run.damsels == 0 and game.player.ball and #game.chains == 4,
                "An exit must preserve Kali progress and the punishment without rescuing or reviving a corpse")
            local ball = game.player.ball
            assert(ball:pickup(game.player), "The iron ball remains a heavy carryable item")
            game.heldItem = ball
            game:generateLevel(18)
            local balls = 0
            for _, item in ipairs(game.items) do if item.kind == "ball" then balls = balls + 1 end end
            assert(balls == 1 and game.player.ball == game.heldItem and #game.chains == 4,
                "Carrying the iron ball through an exit must not duplicate it")
            game.heldItem:throw(game.player, {}, game.world)
            game.heldItem = nil
            local teleporter = game:spawnEntity("teleporter", game.player.x, game.player.y)
            teleporter:pickup(game.player)
            game.heldItem = teleporter
            local x = game.player.x
            game:handleActionPressed({ attack = true })
            assert(game.player.x ~= x and game.player.ball.x == game.player.x
                and game.player.ball.y == game.player.y,
                "Teleportation must move the punished player's ball too")
            app.screens.world_generation:drawItem(game.player.ball)
            local queue = require("src.render.depth_queue").new()
            require("src.platform.kali").submit(game, queue)
            queue:draw()
            game.run = nil
            game.heldItem, game.heldNpc = nil, nil
            game:generateLevel(17)
            assert(game.run.kaliPunish == 0 and game.run.kaliGift == 0 and game.run.favor == 0
                and not game.player.ball and #game.chains == 0, "A fresh run must reset Kali's progress")
        end },
        { "offscreen enemy sacrifices pause with their inherited Step event", function()
            local game = fixture()
            local body = sacrificeBody(game, "caveman", false, 184)
            game.world.activeView = { x = 0, y = 0, width = 100, height = 120 }
            local Kali = require("src.platform.kali")
            for _ = 1, 30 do Kali.update(game) end
            assert(body.alive and game.run.favor == 0)
            game.world.activeView = nil
            for _ = 1, 21 do Kali.update(game) end
            assert(not body.alive and game.run.favor == 2)
        end },
    }
    local failures = {}
    for _, case in ipairs(cases) do
        local ok, err = pcall(case[2])
        if not ok then failures[#failures + 1] = case[1] .. ": " .. tostring(err) end
    end
    assert(#failures == 0, table.concat(failures, "\n"))
    print("Kali altar tests passed (" .. #cases .. " scenarios)")
end

return Test
