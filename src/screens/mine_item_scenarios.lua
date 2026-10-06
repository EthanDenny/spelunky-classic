local Simulation = require("src.platform.object_simulation")
local Enemy = require("src.platform.enemy")
local FullLevelPlaytest = require("src.screens.full_level_playtest")
local Item = require("src.platform.item")
local ItemActions = require("src.platform.item_actions")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local TrapSystem = require("src.platform.trap_system")
local ToolSystem = require("src.platform.tool_system")
local Depth = require("src.render.classic_depth")

local MineItemScenarios = {}

local CARRYABLES = {
    "rock", "skull", "arrow", "die", "jar", "crate", "chest", "locked_chest",
    "key", "gold_idol", "bow", "machete", "mattock", "pistol", "shotgun",
    "teleporter", "web_cannon", "mattock_head",
}

local function title(kind)
    return (kind:gsub("_", " "):gsub("^%l", string.upper))
end

local function actionInput(kind, test, tick)
    if test == "open" then
        return tick == 5 and kind == "chest" and { attack = true, up = true } or {}
    end
    if tick == 5 then return { down = true, attack = true } end
    if tick == 35 and test == "put_down" then return { down = true, attack = true } end
    if tick == 35 and (test == "action" or test == "back_hit") then
        return { attack = true, up = kind == "crate" or kind == "chest",
            down = false }
    end
    return {}
end

function MineItemScenarios.definitions(makeWorld, makePlayer)
    local pages = {}
    for _, kind in ipairs(CARRYABLES) do
        assert(Item.isCarryable(kind), "Mine item scenario needs a live carryable: " .. kind)
        local tests = {
            { key = "pickup", title = "Pick up", description = "DOWN + ACTION takes the item from the floor." },
            { key = "put_down", title = "Put down", description = "DOWN + ACTION releases the held item gently." },
            { key = "action", title = "Use ACTION",
                description = (kind == "crate" or kind == "chest")
                    and "UP + ACTION opens the held container."
                    or "ACTION uses a weapon or throws an ordinary item." },
        }
        if kind == "chest" or kind == "locked_chest" then
            tests[#tests + 1] = { key = "open", title = "Open on floor",
                description = kind == "chest" and "UP + ACTION opens the chest."
                    or "A held key opens the locked chest." }
        end
        if kind == "key" then
            tests[#tests + 1] = { key = "unlock", title = "Unlock nearby chest",
                description = "A held key unlocks the chest on contact; no ACTION press." }
        end
        if kind == "machete" then
            tests[#tests + 1] = { key = "back_hit", title = "Wind-up hit",
                description = "The rear wind-up can strike an enemy but not break a pot." }
        end
        local definitions = {}
        for _, test in ipairs(tests) do
            local testKey = test.key
            definitions[#definitions + 1] = {
                title = test.title, description = test.description,
                duration = 90, eventDuration = 90,
                mineItemKind = kind, mineItemTest = testKey,
                input = function(tick) return actionInput(kind, testKey, tick) end,
                build = function(assets)
                    local world = makeWorld()
                    if testKey == "action" and (kind == "jar" or kind == "skull") then
                        world:set("solid", 6, 6)
                    end
                    return world, nil, makePlayer(4 * 16 + 8, assets)
                end,
            }
        end
        pages[#pages + 1] = { name = title(kind), scenarios = definitions }
    end
    return pages
end

function MineItemScenarios.reset(scenario, renderer, viewer)
    local definition = scenario.definition
    if not definition.mineItemKind then return end
    local game = FullLevelPlaytest.new(viewer.app)
    game.world, game.player = scenario.world, scenario.player
    game.level = { entities = {}, absoluteLevel = 1 }
    game.renderer = renderer
    game.run = RunState.new(300 + #definition.mineItemKind)
    game.run:applyToPlayer(game.player)
    game.effects = scenario.effects
    game.projectiles = ProjectileSystem.new(game.world)
    game.traps = TrapSystem.new(game.world, game.level)
    game.tools = ToolSystem.new(game.world, game.player.TICK_RATE)
    game.tools:loadAssets()
    game.tools.explosionSound = nil
    game.sounds = viewer:scenarioAudio()
    game.player.sounds = game.sounds
    game.tools.sounds, game.traps.sounds = game.sounds, game.sounds
    game.effects.sounds, game.tools.effects.sounds = game.sounds, game.sounds
    game:configureProjectiles()
    local player = game.player
    local kind = definition.mineItemKind
    local offset = (kind == "chest" or kind == "locked_chest" or kind == "crate") and 4 or 8
    local entity = { kind = kind, x = (player.x + offset) / 16,
        y = player.y / 16, properties = {} }
    local sprite = renderer.entitySprites[kind]
    local item = Item.new(entity, sprite and sprite.metadata)
    game.items = { item }
    if definition.mineItemTest == "open" and kind == "locked_chest" then
        local key = Item.new({ kind = "key", x = player.x / 16, y = player.y / 16 })
        key:pickup(player)
        game.items[#game.items + 1] = key
        game.heldItem = key
    end
    scenario.mineItem, scenario.itemGame, scenario.itemRun = item, game, game.run
    scenario.projectiles = game.projectiles
end

function MineItemScenarios.prepare(scenario, input)
    local game = scenario.itemGame
    if not game then return end
    scenario.itemInput = input
    if not input.attack then return end
    scenario.itemContainerToOpen = Simulation.prepareAction(game, input, true) or nil
end

function MineItemScenarios.step(scenario, input)
    local game = scenario.itemGame
    if not game then return end
    local definition = scenario.definition
    local item = scenario.mineItem
    if scenario.tick == 25 and (definition.mineItemTest == "action"
        or definition.mineItemTest == "back_hit") then
        if item.kind == "mattock" then
            game.world:set("solid", 5, 6)
        elseif item.kind == "machete" then
            local behind = definition.mineItemTest == "back_hit"
            game.enemies[1] = Enemy.new("snake", game.player.x + (behind and -12 or 8),
                game.player.y + (behind and 4 or -8), { seed = 42 })
        end
    end
    if scenario.tick == 25 and definition.mineItemTest == "unlock" then
        if item.kind == "key" then
            local chest = Item.new({ kind = "locked_chest",
                x = (game.player.x + 12) / 16, y = game.player.y / 16 })
            game.items[#game.items + 1] = chest
        end
    end
    if game.heldItem then
        game.heldItem:updateHeldPosition(game.player)
        if game.heldItem.kind == "key" and game:openNearbyContainer() then
            scenario.event = "UNLOCKED"
            scenario.eventTick = scenario.tick
        end
    end
    if input and input.attack then
        local beforeHeld = game.heldItem
        game:handleActionPressed(input, scenario.itemContainerToOpen)
        if game.heldItem == item and not beforeHeld then
            scenario.event = "PICKED UP"
        elseif item.opened then
            scenario.event = item.kind == "key" and "UNLOCKED" or "OPENED"
        elseif beforeHeld and not game.heldItem then
            scenario.event = definition.mineItemTest == "put_down" and "PUT DOWN" or "THROWN"
        elseif beforeHeld then
            scenario.event = "USED"
        elseif definition.mineItemTest == "open" then
            scenario.event = item.opened and "OPENED" or "LOCKED"
        end
        if scenario.event then scenario.eventTick = scenario.tick end
    end
    ItemActions.updateBow(game, input)
    ItemActions.updateMelee(game)
    Simulation.stepItems(game, function(current)
        if current.opened and (current.kind == "jar" or current.kind == "skull") then
            scenario.event = current.kind == "jar" and "JAR SMASHED" or "SKULL SMASHED"
            scenario.eventTick = scenario.tick
        end
    end, true)
    ItemActions.recoverArrows(game)
    Simulation.stepCollectibles(game)
    game.tools:update(game.player, game.enemies, game.items)
    game:checkCollectibles()
    for _, enemy in ipairs(game.enemies) do
        if not enemy.alive and not enemy.deathCounted then
            enemy.deathCounted = true
            game.effects:blood(enemy.x, enemy.y - 8, enemy.kind == "snake" and 3 or 1)
        end
    end
end

function MineItemScenarios.submit(queue, scenario, renderer)
    local game = scenario.itemGame
    if not game then return end
    for _, item in ipairs(game.items) do
        if (not item.opened or item.kind == "chest") and item.visible ~= false then
            local current = item
            queue:add(current.held and Depth.heldItem(game.player) or Depth.entity(current.kind),
                function() renderer:drawItem(current, current.held and game.player.facing or current.facing) end)
        end
    end
    if game.meleeItem then
        queue:add(Depth.EFFECT, function()
            renderer:drawMeleeSwing(game.player, game.meleeItem)
        end)
    end
    game.tools:submit(queue)
    for _, collectible in ipairs(game.collectibles) do
        if collectible.alive then
            local current = collectible
            queue:add(Depth.entity(current.entity.kind),
                function() renderer:drawEntity(current.entity) end)
        end
    end
    for _, enemy in ipairs(game.enemies) do
        if enemy.alive then
            local current = enemy
            queue:add(Depth.entity(current.kind), function() current:draw() end)
        end
    end
end

return MineItemScenarios
