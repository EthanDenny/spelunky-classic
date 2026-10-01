local MinesGenerator = require("src.world.mines_generator")
local MinesVariants = require("src.world.mines_variants")
local MinesLevelSelection = require("src.world.mines_level_selection")
local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local Enemy = require("src.platform.enemy")
local Item = require("src.platform.item")
local Treasure = require("src.platform.treasure")
local Effects = require("src.platform.effects")
local FakeBones = require("src.platform.fake_bones")
local DynamicTerrain = require("src.platform.dynamic_terrain")
local ToolSystem = require("src.platform.tool_system")
local TrapSystem = require("src.platform.trap_system")
local OriginalHUD = require("src.ui.original_hud")
local Creature = require("src.platform.creature")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local Depth = require("src.render.classic_depth")
local DepthQueue = require("src.render.depth_queue")
local ClassicSounds = require("src.audio.classic_sounds")

local FullLevelPlaytest = {}
FullLevelPlaytest.__index = FullLevelPlaytest

local STEP = 1 / Player.TICK_RATE
local HEADER_HEIGHT = 64
local FOOTER_HEIGHT = 40

local MINES_DEPTHS = 4

local DYNAMIC_ENEMIES = {
    snake = true,
    bat = true,
    spider = true,
}

local COLORS = {
    background = { 0.035, 0.031, 0.027 },
    panel = { 0.075, 0.064, 0.052 },
    border = { 0.28, 0.22, 0.16 },
    text = { 0.92, 0.86, 0.72 },
    muted = { 0.56, 0.50, 0.40 },
    accent = { 0.72, 0.18, 0.10 },
    danger = { 0.95, 0.28, 0.16 },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function FullLevelPlaytest.new(app)
    return setmetatable({
        app = app,
        renderer = nil,
        levelNumber = 1,
        subtypeIndex = 1,
        selectionError = nil,
        seed = nil,
        level = nil,
        world = nil,
        player = nil,
        enemies = {},
        items = {},
        heldItem = nil,
        dynamicEntities = {},
        spikeEntities = {},
        fakeBones = {},
        accumulator = 0,
        cameraX = 0,
        cameraY = 0,
        debugCollision = false,
        deathTimer = 0,
        exitReady = false,
        hitSound = nil,
        spikeBloodImage = nil,
        throwSound = nil,
        sounds = ClassicSounds.new(),
        actionHeld = false,
        climbSoundTick = 0,
        climbSoundToggle = false,
        tools = nil,
        traps = nil,
        hud = nil,
        run = nil,
        projectiles = nil,
        heldNpc = nil,
        collectibles = {},
        effects = nil,
        weaponCooldown = 0,
        levelTime = 0,
        ghostSpawned = false,
        hiddenEntities = {},
    }, FullLevelPlaytest)
end

function FullLevelPlaytest:loadAssets()
    self.renderer = self.renderer or self.app.screens.world_generation
    self.renderer:loadAssets()
    Enemy.loadAssets()
    self.hitSound = self.hitSound
        or love.audio.newSource("original-game-reference/sound/hit.wav", "static")
    self.throwSound = self.throwSound
        or love.audio.newSource("original-game-reference/sound/throw.wav", "static")
    if not self.spikeBloodImage then
        self.spikeBloodImage = love.graphics.newImage(
            "original-game-reference/source/extracted/spelunky/Sprites/Traps/sSpikesBlood.images/image 0.png")
        self.spikeBloodImage:setFilter("nearest", "nearest")
    end
    self.hud = self.hud or OriginalHUD.new(self.renderer)
    self.hud:loadAssets()
end

function FullLevelPlaytest:captureHeldItem()
    if not self.heldItem then return end
    if self.heldItem.kind == "gold_idol" then
        Item.collect(self.heldItem.kind, self.run, self.player)
    else
        self.run.heldItem = {
            kind = self.heldItem.kind,
            properties = self.heldItem.properties,
            durability = self.heldItem.durability,
        }
    end
end

function FullLevelPlaytest:captureHeldNpc()
    if self.heldNpc and self.heldNpc.kind == "damsel" then self.run.heldDamsel = true end
end

function FullLevelPlaytest:generateLevel(seed)
    if self.run then
        if self.heldItem then self:captureHeldItem() end
        self:captureHeldNpc()
    end
    self.seed = seed
    self.run = self.run or RunState.new(seed)
    self.level = MinesGenerator.generate(seed, { levelNumber = self.levelNumber })
    MinesVariants.apply(self.level, self.run)
    self.level.selectedSubtype = MinesLevelSelection.choices[self.subtypeIndex].key
    self:buildSimulation()
end

function FullLevelPlaytest:generateSelectedLevel(startSeed, freshRun)
    local subtype = MinesLevelSelection.choices[self.subtypeIndex].key
    local seed = startSeed
    if subtype ~= "random" then
        local foundSeed, _, err = MinesLevelSelection.find(startSeed, self.levelNumber, subtype)
        if not foundSeed then self.selectionError = err return false end
        seed = foundSeed
    end
    if freshRun then
        self.run = nil
        self.heldItem = nil
        self.heldNpc = nil
    end
    self.selectionError = nil
    self:generateLevel(seed)
    return true
end

function FullLevelPlaytest:buildSimulation()
    self.world = GeneratedWorld.fromLevel(self.level)
    local spawnX, spawnY = GeneratedWorld.spawnPoint(self.level)
    self.player = Player.new(spawnX, spawnY)
    self.player.playtestLog = self.app.playtestLog
    self.run:applyToPlayer(self.player)
    self.player.state = Player.STATES.standing
    self.climbSoundTick = 0
    self.climbSoundToggle = false
    self.player.spriteName = "sStandLeft"
    self.player:loadAssets()
    self.tools = ToolSystem.new(self.world, Player.TICK_RATE)
    self.tools:loadAssets()
    self.traps = TrapSystem.new(self.world, self.level, self.renderer)
    self.traps:loadAssets()
    self.tools.onExplosion = function(_, x, y, radius)
        self.traps:explode(x, y, radius)
    end

    self.enemies = {}
    self.items = {}
    self.collectibles = {}
    self.effects = Effects.new(self.seed)
    self.tools.onRopeHit = function(_, enemy)
        if enemy.kind ~= "skeleton" then self.effects:blood(enemy.x, enemy.y - 8, 1) end
        if self.hitSound then self.hitSound:clone():play() end
    end
    Effects.loadAssets()
    self.hiddenEntities = {}
    self.heldItem = nil
    self.heldNpc = nil
    self.projectiles = ProjectileSystem.new(self.world)
    self.dynamicEntities = {}
    self.spikeEntities = {}
    self.fakeBones = {}
    if self.run.shopkeeperAnger > 0 and self.level.exit then
        self.level.entities[#self.level.entities + 1] = {
            kind = "shopkeeper",
            x = self.level.exit.x + 1,
            y = self.level.exit.y,
            properties = { exitGuard = true },
        }
    end
    for index, entity in ipairs(self.level.entities) do
        if entity.kind == "hidden_sapphire" or entity.kind == "hidden_emerald"
            or entity.kind == "hidden_ruby" or entity.kind == "hidden_item" then
            self.hiddenEntities[#self.hiddenEntities + 1] = entity
            self.dynamicEntities[entity] = true
        elseif TrapSystem.isTrap(entity.kind) then
            self.dynamicEntities[entity] = true
        elseif DYNAMIC_ENEMIES[entity.kind] then
            local enemy = Enemy.new(entity.kind, entity.x * 16 + 8, entity.y * 16 + 16, {
                seed = self.seed + index * 97,
                hanging = entity.kind ~= "snake",
            })
            self.enemies[#self.enemies + 1] = enemy
            self.dynamicEntities[entity] = true
        elseif Creature.supports(entity.kind) then
            local sprite = self.renderer.entitySprites[entity.kind]
            local creature = Creature.new(entity, sprite and sprite.metadata, {
                seed = self.seed + index * 97,
                angry = entity.kind == "shopkeeper" and self.run.shopkeeperAnger > 0,
            })
            self.enemies[#self.enemies + 1] = creature
            self.dynamicEntities[entity] = true
        elseif Item.isCarryable(entity.kind) then
            local sprite = self.renderer.entitySprites[entity.kind]
            local item = Item.new(entity, sprite and sprite.metadata)
            self.items[#self.items + 1] = item
            self.dynamicEntities[entity] = true
        elseif Item.isCollectible(entity.kind) then
            self.collectibles[#self.collectibles + 1] = Treasure.new(entity, false)
            self.dynamicEntities[entity] = true
        elseif entity.kind == "fake_bones" then
            self.fakeBones[#self.fakeBones + 1] = FakeBones.new(entity)
            self.dynamicEntities[entity] = true
        elseif entity.kind == "spikes" then
            self.spikeEntities[#self.spikeEntities + 1] = entity
        end
    end

    if self.run.heldItem then
        local carried = self.run.heldItem
        self.run.heldItem = nil
        local item = self:spawnEntity(carried.kind, self.player.x, self.player.y, carried.properties)
        if item then
            item.durability = carried.durability or item.durability
            item:pickup(self.player)
            self.heldItem = item
        end
    end
    if self.run.heldDamsel then
        self.run.heldDamsel = false
        local damsel = self:spawnEntity("damsel", self.player.x, self.player.y)
        if damsel then damsel:pickup(self.player) self.heldNpc = damsel end
    end

    self.accumulator = 0
    self.cameraX = clamp(spawnX - 160, 0, self.world.width * 16)
    self.cameraY = clamp(spawnY - 120, 0, self.world.height * 16)
    self.deathTimer = 0
    self.exitReady = false
    self.actionHeld = false
    self.weaponCooldown = 0
    self.levelTime = 0
    self.ghostSpawned = false
    if self.app.playtestLog then self.app.playtestLog:level("full_level_playtest", self) end
end

function FullLevelPlaytest:enter()
    self:loadAssets()
    if not self.level then
        self.seed = os.time() % 2147483646 + 1
        self:generateLevel(self.seed)
    else
        self.run = self.run or RunState.new(self.seed or self.level.seed or 1)
        self:buildSimulation()
    end
end

function FullLevelPlaytest:getInput()
    return self.app.controls:playerInput()
end

function FullLevelPlaytest:isNearExit()
    if not self.level.exit or not self.player then return false end
    local exitX = self.level.exit.x * 16 + 8
    local exitY = self.level.exit.y * 16 + 8
    return math.abs(self.player.x - exitX) <= 11 and math.abs(self.player.y - exitY) <= 15
end

function FullLevelPlaytest:advanceLevel()
    if self.levelNumber >= MINES_DEPTHS then
        self.run:addMessage("MINES COMPLETE", 120)
        return
    end
    if self.heldNpc and self.heldNpc.kind == "damsel" then
        self.run.damsels = self.run.damsels + 1
        self.player.health = math.min(self.player.maxHealth, self.player.health + 1)
        self.heldNpc.rescued = true
        self.heldNpc.alive = false
        self.heldNpc = nil
    end
    self.run:capturePlayer(self.player)
    self.run:finishLevel()
    self.levelNumber = self.levelNumber + 1
    self.subtypeIndex = 1
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:checkSpikes()
    if self.player:isDead() or self.player.vy <= 0
        or (self.player.fallTimer <= 4 and not self.player:isStunned()) then return end
    local x, y = self.player.x, self.player.y
    for _, spike in ipairs(self.spikeEntities) do
        local left = spike.x * 16
        local top = spike.y * 16
        if not spike.destroyed and x + 4 > left and x - 4 < left + 16
            and y + 8 > top and y - 4 < top + 16 then
            spike.bloody = true
            self.effects:blood(x, y, 3)
            self.player:kill("spikes", 0, 0)
            return
        end
    end
end

function FullLevelPlaytest:checkWhip()
    local left = self.player:getWhipHitbox()
    if not left then return end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive and self.player:whipCanHit(enemy)
            and self.player:whipOverlapsRectangle(enemy:getBounds()) then
            self.player:markWhipHit(enemy)
            enemy:damage(1)
            if enemy.kind == "snake" then
                self.effects:blood(enemy.x, enemy.y - 8, 1)
            end
            if enemy.kind == "shopkeeper" then
                enemy.angry = true
                self.run:angerShopkeepers("VANDAL! THIEF!")
            end
            if self.hitSound then self.hitSound:clone():play() end
        end
    end
    for _, item in ipairs(self.items) do
        if not item.held and not item.opened
            and (item.kind == "jar" or item.kind == "crate" or item.kind == "chest") then
            local half = item:getCollisionHalfWidth()
            local itemTop, itemBottom = item:getVerticalBounds()
            if self.player:whipOverlapsRectangle(item.x - half, item.y + itemTop,
                item.x + half, item.y + itemBottom) then
                self:openContainer(item)
            end
        end
    end
    for _, entity in ipairs(self.level.entities) do
        if entity.kind == "web" and not self.dynamicEntities[entity] then
            local entityLeft, entityTop = entity.x * 16, entity.y * 16
            if self.player:whipOverlapsRectangle(entityLeft, entityTop,
                entityLeft + 16, entityTop + 16) then
                self.dynamicEntities[entity] = true
                self.world:remove("web", math.floor(entity.x), math.floor(entity.y))
            end
        end
    end
end

function FullLevelPlaytest:openContainer(item)
    local x, y = item.x, item.y
    local reward, message = item:open(self.run)
    if item.kind == "jar" then
        self.effects:jarBreak(x, y)
        self.sounds:play("break_item")
    elseif item.kind == "chest" or item.kind == "locked_chest" then
        self.sounds:play("chest_open")
    end
    if reward == "snake" and item.kind == "jar" then
        -- oJar's Destroy event creates an oSnake at x/y-8 after a left hit,
        -- x-16/y-8 after a right hit, and x-8/y-8 otherwise. Our enemy
        -- coordinates are bottom-center rather than GameMaker's top-left.
        local snakeX = x + (item.impactSide == "left" and 8
            or item.impactSide == "right" and -8 or 0)
        local snakeY = y + 8
        local snake = self:spawnEntity(reward, snakeX, snakeY)
        if self.world:collidesSolid(snake, snake.x, snake.y) then
            local normal = item.impactSide == "left" and { 1, 0 }
                or item.impactSide == "right" and { -1, 0 }
                or item.impactSide == "ceiling" and { 0, 1 }
                or { 0, -1 }
            local directions = { normal, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 },
                { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
            local placed = false
            for distance = 1, 16 do
                for _, direction in ipairs(directions) do
                    local nextX = snakeX + direction[1] * distance
                    local nextY = snakeY + direction[2] * distance
                    if not self.world:collidesSolid(snake, nextX, nextY) then
                        snake.x, snake.y = nextX, nextY
                        snake.spawnX, snake.spawnY = nextX, nextY
                        local entity = self.level.entities[#self.level.entities]
                        entity.x, entity.y = nextX / 16, nextY / 16
                        placed = true
                        break
                    end
                end
                if placed then break end
            end
        end
    elseif reward then
        -- oJar creates treasure at its own origin; the old y-4 offset could
        -- insert a four-pixel gem into the ceiling that broke the pot.
        self:spawnEntity(reward, x, item.kind == "jar" and y or y - 4)
    end
    if message then self.run:addMessage(message, 60) end
    item.x, item.y = -1000, -1000
end

function FullLevelPlaytest:checkCollectibles()
    local half = self.player:getCollisionHalfWidth()
    local top, bottom = self.player:getVerticalBounds()
    for _, collectible in ipairs(self.collectibles) do
        if collectible.alive and collectible.pickupDelay == 0 then
            local entity = collectible.entity
            local x, y = entity.x * 16, entity.y * 16
            if x + 8 > self.player.x - half and x - 8 < self.player.x + half
                and y + 8 > self.player.y + top and y - 8 < self.player.y + bottom then
                if entity.properties and entity.properties.forSale then
                    local price = Item.price(entity.kind, self.level.absoluteLevel)
                    self.run:addMessage("$" .. price .. " - DOWN+ATTACK TO BUY", 45)
                else
                    local message = Item.collect(entity.kind, self.run, self.player)
                    collectible.alive = false
                    if entity.kind == "gold_bar" or entity.kind == "gold_bars" then
                        self.sounds:play("coin")
                    elseif entity.kind == "emerald_big" or entity.kind == "sapphire_big"
                        or entity.kind == "ruby_big" then
                        self.sounds:play("gem")
                    else
                        self.sounds:play("pickup")
                    end
                    if entity.kind == "key" then self.run.hasKey = true end
                    if message then self.run:addMessage(message, 75) end
                end
            end
        end
    end
end

function FullLevelPlaytest:revealHiddenContents()
    for _, entity in ipairs(self.hiddenEntities) do
        if not entity.revealed and not self.world:solidAtPoint(entity.x * 16, entity.y * 16) then
            entity.revealed = true
            local kind = entity.kind == "hidden_sapphire" and "sapphire_big"
                or entity.kind == "hidden_emerald" and "emerald_big"
                or entity.kind == "hidden_ruby" and "ruby_big"
                or ({ "bomb_bag", "rope_pile", "compass", "gloves" })[
                    (math.floor(entity.x * 17 + entity.y * 31 + self.seed) % 4) + 1]
            self:spawnEntity(kind, entity.x * 16, entity.y * 16)
        end
    end
end

function FullLevelPlaytest:buyNearbyCollectible()
    for _, collectible in ipairs(self.collectibles) do
        local entity = collectible.entity
        if collectible.alive and entity.properties and entity.properties.forSale
            and math.abs(self.player.x - entity.x * 16) < 14
            and math.abs(self.player.y - entity.y * 16) < 18 then
            local price = Item.price(entity.kind, self.level.absoluteLevel)
            if self.run.money < price then
                self.run:addMessage("YOU CAN'T AFFORD IT!", 90)
                return true
            end
            self.run.money = self.run.money - price
            local message = Item.collect(entity.kind, self.run, self.player)
            collectible.alive = false
            self.sounds:play("pickup")
            self.run:addMessage(message or "PURCHASED", 75)
            return true
        end
    end
    return false
end

function FullLevelPlaytest:stealNearbyItem()
    for _, collectible in ipairs(self.collectibles) do
        local entity = collectible.entity
        if collectible.alive and entity.properties and entity.properties.forSale
            and math.abs(self.player.x - entity.x * 16) < 14
            and math.abs(self.player.y - entity.y * 16) < 18 then
            entity.properties.forSale = false
            collectible.alive = false
            Item.collect(entity.kind, self.run, self.player)
            self.run:angerShopkeepers("STOP, THIEF!")
            for _, enemy in ipairs(self.enemies) do
                if enemy.kind == "shopkeeper" then enemy.angry = true end
            end
            return true
        end
    end
    for _, item in ipairs(self.items) do
        if not item.held and item.properties.forSale
            and math.abs(self.player.x - item.x) < 14 and math.abs(self.player.y - item.y) < 18 then
            item.properties.forSale = false
            item:pickup(self.player)
            self.heldItem = item
            self.run:angerShopkeepers("STOP, THIEF!")
            for _, enemy in ipairs(self.enemies) do
                if enemy.kind == "shopkeeper" then enemy.angry = true end
            end
            return true
        end
    end
    return false
end

function FullLevelPlaytest:pickupNearestNpc(steal)
    for _, creature in ipairs(self.enemies) do
        if creature.kind == "damsel" and creature.alive and not creature.held
            and math.abs(creature.x - self.player.x) < 12
            and math.abs(creature.y - self.player.y) < 14 then
            if creature.forSale then
                local price = 8000 + math.max(0, (self.level.absoluteLevel or 1) - 1) * 500
                if steal then
                    creature.forSale = false
                    creature.entity.properties.forSale = false
                    self.run:angerShopkeepers("KIDNAPPER!")
                    for _, enemy in ipairs(self.enemies) do
                        if enemy.kind == "shopkeeper" then enemy.angry = true end
                    end
                elseif self.run.money >= price then
                    self.run.money = self.run.money - price
                    creature.forSale = false
                    creature.entity.properties.forSale = false
                    self.run:addMessage("A KISS COSTS $" .. price, 75)
                else
                    self.run:addMessage("A KISS COSTS $" .. price, 90)
                    return true
                end
            end
            if creature:pickup(self.player) then
            self.heldNpc = creature
            return true
            end
        end
    end
    return false
end

function FullLevelPlaytest:interactShopkeeper()
    for _, creature in ipairs(self.enemies) do
        if creature.kind == "shopkeeper" and creature.alive and not creature.angry
            and math.abs(creature.x - self.player.x) < 24
            and math.abs(creature.y - self.player.y) < 20 then
            if creature.shopType == "Craps" then
                local bet = 1000 + (self.level.absoluteLevel or 1) * 500
                if self.run.money < bet then
                    self.run:addMessage("YOU NEED $" .. bet .. " TO PLAY", 90)
                    return true
                end
                self.run.money = self.run.money - bet
                local roll1 = (math.floor(self.run.time * 30 + self.seed) % 6) + 1
                local roll2 = (math.floor(self.run.time * 47 + self.seed * 3) % 6) + 1
                if roll1 + roll2 == 7 then
                    local rewards = { "bomb_box", "shotgun", "jetpack", "cape" }
                    self:spawnEntity(rewards[(roll1 % #rewards) + 1], creature.x + 20, creature.y - 4)
                    self.run:addMessage("YOU ROLLED A SEVEN! YOU WIN!", 120)
                else
                    self.run:addMessage("YOU ROLLED " .. (roll1 + roll2), 90)
                end
                return true
            elseif creature.shopType == "Kissing" then
                self.run:addMessage("A KISS IS GOOD FOR ONE HEART", 90)
                return true
            end
        end
    end
    return false
end

function FullLevelPlaytest:pickupNearestItem()
    local left, top = self.player.x - 8, self.player.y
    local right, bottom = self.player.x + 8, self.player.y + 8
    local nearest, nearestDistance
    for _, item in ipairs(self.items) do
        if not item.held and item:overlapsRectangle(left, top, right, bottom)
            and not self.world:solidAtPoint(item.x, item.y) then
            local dx, dy = item.x - self.player.x, item.y - self.player.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = item, distance
            end
        end
    end
    if nearest and nearest.properties.forSale then
        local price = Item.price(nearest.kind, self.level.absoluteLevel)
        if self.run.money < price then
            self.run:addMessage("YOU CAN'T AFFORD IT!", 90)
            return true
        end
        self.run.money = self.run.money - price
        nearest.properties.forSale = false
        self.run:addMessage("PURCHASED FOR $" .. price, 75)
    end
    if nearest and nearest:pickup(self.player) then
        self.heldItem = nearest
        self.sounds:play("pickup")
        if nearest.kind == "gold_idol" and not nearest.idolTriggered then
            nearest.idolTriggered = true
            self.traps:triggerIdol(self.player)
        end
        return true
    end
    return false
end

function FullLevelPlaytest:spawnEntity(kind, x, y, properties)
    local entity = { kind = kind, x = x / 16, y = y / 16, properties = properties or {} }
    self.level.entities[#self.level.entities + 1] = entity
    self.dynamicEntities[entity] = true
    if Item.isCarryable(kind) then
        local sprite = self.renderer.entitySprites[kind]
        local item = Item.new(entity, sprite and sprite.metadata)
        item.x, item.y = x, y
        self.items[#self.items + 1] = item
        return item
    elseif DYNAMIC_ENEMIES[kind] then
        local enemy = Enemy.new(kind, x, y, {
            seed = self.seed + #self.enemies,
            hanging = false,
        })
        self.enemies[#self.enemies + 1] = enemy
        return enemy
    elseif Creature.supports(kind) then
        local sprite = self.renderer.entitySprites[kind]
        local creature = Creature.new(entity, sprite and sprite.metadata, { seed = self.seed + #self.enemies })
        if kind == "skeleton" then creature.facing = entity.properties.facing or -1 end
        creature.x, creature.y = x, y
        self.enemies[#self.enemies + 1] = creature
        return creature
    elseif Item.isCollectible(kind) then
        local collectible = Treasure.new(entity, true)
        self.collectibles[#self.collectibles + 1] = collectible
        return collectible
    end
end

function FullLevelPlaytest:openNearbyContainer()
    for _, item in ipairs(self.items) do
        if not item.held and not item.opened and math.abs(item.x - self.player.x) < 15
            and math.abs(item.y - self.player.y) < 15
            and (item.kind == "chest" or item.kind == "locked_chest") then
            if item.kind == "locked_chest" and self.heldItem and self.heldItem.kind == "key" then
                self.heldItem.held = false
                self.heldItem.opened = true
                self.heldItem.x, self.heldItem.y = -1000, -1000
                self.heldItem = nil
                self.run.hasKey = true
            end
            local reward, message = item:open(self.run)
            if reward then self.sounds:play("chest_open") end
            if message then self.run:addMessage(message, 90) end
            if reward then
                item.x, item.y = -1000, -1000
                self:spawnEntity(reward, self.player.x, self.player.y - 6)
            end
            return reward ~= nil or message ~= nil
        end
    end
    return false
end

function FullLevelPlaytest:crateAtPlayer()
    for _, item in ipairs(self.items) do
        if item.kind == "crate" and not item.opened
            and item:overlapsRectangle(self.player.x, self.player.y,
                self.player.x, self.player.y) then
            return item
        end
    end
end

function FullLevelPlaytest:meleeHeldWeapon(item)
    local reach = item.kind == "mattock" and 18 or 14
    local left = self.player.facing < 0 and self.player.x - reach or self.player.x
    local right = self.player.facing > 0 and self.player.x + reach or self.player.x
    if left > right then left, right = right, left end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive and enemy:overlapsRectangle(left, self.player.y - 12, right, self.player.y + 5) then
            enemy:damage(item.kind == "machete" and 2 or 1, self.player.x)
            if enemy.kind == "shopkeeper" then
                enemy.angry = true
                self.run:angerShopkeepers("YOU'LL PAY FOR THAT!")
            end
        end
    end
    if item.kind == "mattock" then
        local x = self.player.x + self.player.facing * 14
        self.world:destroyTerrain(x, self.player.y - 4, 10)
        item.durability = item.durability - 1
        if item.durability <= 0 then
            item.held = false
            item.x, item.y = -1000, -1000
            self.heldItem = nil
            self.run:addMessage("THE MATTOCK BROKE", 75)
        end
    end
    item.cooldown = 10
    return true
end

function FullLevelPlaytest:useHeldItem(input)
    local item = self.heldItem
    if not item then return false end
    if item.weapon and not input.down then
        if item.cooldown > 0 then return true end
        if item.kind == "machete" or item.kind == "mattock" then
            return self:meleeHeldWeapon(item)
        elseif item.kind == "teleporter" then
            local destination = self.player.x + self.player.facing * 64
            while self.world:solidAtPoint(destination, self.player.y) and destination ~= self.player.x do
                destination = destination - self.player.facing
            end
            self.player.x = destination
            item.cooldown = 45
            return true
        else
            local cooldown = self.projectiles:fireWeapon(item.kind, self.player, self.player)
            if cooldown then
                if item.kind == "bow" then self.sounds:play("bowpull") end
                item.cooldown = cooldown
                return true
            end
        end
    end
    if item.weapon then item:dropWeapon(self.player)
    else item:throw(self.player, input) end
    self.heldItem = nil
    if self.throwSound then self.throwSound:clone():play() end
    return true
end

function FullLevelPlaytest:dropHeldItemFromHurt()
    if self.heldItem then
        self.heldItem:dropFromHurt(self.player)
        self.heldItem = nil
    end
    if self.heldNpc then
        self.heldNpc:throw(self.player, {})
        self.heldNpc = nil
    end
end

function FullLevelPlaytest:applyEnvironment(input)
    local player = self.player
    if self.world:webAtPoint(player.x, player.y) then
        player:web(12)
        player.vx = player.vx * 0.15
        player.vy = player.vy * 0.15
    end
end

function FullLevelPlaytest:simulationStepBody(input)
    if self.player:isDead() then
        self.player:step(self.world, {})
        self.deathTimer = self.deathTimer - 1
        if self.deathTimer <= 0 then
            self.run = RunState.new(self.seed)
            self.levelNumber = 1
            self:generateLevel(self.seed)
        end
        return
    end

    local actionPressed = input.attack and not self.actionHeld
    self.actionHeld = input.attack
    local crateToOpen = actionPressed and input.up and self:crateAtPlayer()
    if self.heldItem or self.heldNpc or crateToOpen then input.suppressWhip = true end
    local previousY = self.player.y
    local previousHealth = self.player.health
    local previousState = self.player.state
    self.player:step(self.world, input)
    if self.player.state == Player.STATES.jumping
        and previousState ~= Player.STATES.jumping
        and (previousState == Player.STATES.standing or previousState == Player.STATES.running
            or previousState == Player.STATES.hanging or previousState == Player.STATES.climbing) then
        self.sounds:play("jump")
    end
    if self.player.state == Player.STATES.climbing and (input.up or input.down)
        and math.abs(self.player.y - previousY) > 0.05 then
        self.climbSoundTick = self.climbSoundTick - 1
        if self.climbSoundTick <= 0 then
            self.sounds:play(self.climbSoundToggle and "climb2" or "climb1")
            self.climbSoundToggle = not self.climbSoundToggle
            self.climbSoundTick = 8
        end
    else
        self.climbSoundTick = 0
    end
    self:applyEnvironment(input)
    if actionPressed then
        if crateToOpen then
            if self.heldItem == crateToOpen then
                self.heldItem = nil
                crateToOpen.held = false
            end
            self:openContainer(crateToOpen)
            self.sounds:play("pickup")
        elseif self.heldNpc then
            self.heldNpc:throw(self.player, input)
            self.heldNpc = nil
        elseif self.heldItem then
            if not (input.down and self.heldItem.kind == "key" and self:openNearbyContainer()) then
                self:useHeldItem(input)
            end
        elseif input.down and self.player.state == Player.STATES.ducking then
            if not (input.sprint and self:stealNearbyItem())
                and not self:interactShopkeeper()
                and not self:buyNearbyCollectible() and not self:openNearbyContainer()
                and not self:pickupNearestNpc(input.sprint) then
                self:pickupNearestItem()
            end
        end
    end
    self:checkWhip()
    self:checkSpikes()
    self:revealHiddenContents()
    for _, bones in ipairs(self.fakeBones) do
        if bones:update(self.world, self.player) then
            self:spawnEntity("skeleton", bones.x + 8, bones.y + 16, {
                facing = self.player.x < bones.x + 8 and -1 or 1,
            })
        end
    end
    DynamicTerrain.update(self.world)
    self.traps:update(self.player, self.enemies, self.items)
    self.tools:update(self.player, self.enemies, self.items)
    -- oPlayer1 checks its center point against oSolid and dies on overlap,
    -- regardless of temporary invincibility.
    if not self.player:isDead() and self.world:solidAtPoint(self.player.x, self.player.y) then
        self.player:kill("crushed", 0, -3)
    end

    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then
            local oldState, oldVy = enemy.state, enemy.vy
            enemy:step(self.world, self.player, {
                run = self.run,
                projectiles = self.projectiles,
            })
            if enemy.kind == "bat" and oldState == "HANG" and enemy.state ~= oldState then
                self.sounds:play("bat")
            elseif enemy.kind == "giant_spider" and oldState == "hang"
                and enemy.state ~= oldState then
                self.sounds:play("giant_spider")
            elseif enemy.kind == "giant_spider" and oldVy >= 0 and enemy.vy < -1
                and enemy.state == "bounce" then
                self.sounds:play("spider_jump")
            end
            enemy:resolvePlayerContact(self.player, previousY)
            if enemy.kind == "damsel" and self:isNearExit()
                and math.abs(enemy.x - self.player.x) < 24 then
                enemy.alive = false
                enemy.rescued = true
                self.run.damsels = self.run.damsels + 1
                self.player.health = math.min(self.player.maxHealth, self.player.health + 1)
                self.sounds:play("kiss")
                self.run:addMessage("A KISS FOR YOUR TROUBLE", 90)
            end
        elseif not enemy.deathCounted then
            enemy.deathCounted = true
            if enemy.kind == "caveman" then self.sounds:play("caveman_die") end
            self.run.kills = self.run.kills + 1
            if enemy.kind ~= "skeleton" and not enemy.blastParticlesEmitted then
                self.effects:blood(enemy.x, enemy.y - 8,
                    enemy.kind == "snake" and 3 or 1)
            end
            if enemy.kind == "giant_spider" then self:spawnEntity("paste", enemy.x, enemy.y - 4) end
            if self.run.equipment.kapala then
                self.run.blood = self.run.blood + 1
                if self.run.blood >= 8 then
                    self.run.blood = self.run.blood - 8
                    self.player.health = math.min(99, self.player.health + 1)
                    self.player.maxHealth = math.max(self.player.maxHealth, self.player.health)
                    self.run:addMessage("THE KAPALA FILLS WITH BLOOD", 90)
                end
            end
            if enemy.kind == "shopkeeper" then
                self.run.murderer = true
                self.run:angerShopkeepers("MURDERER!")
                self:spawnEntity("shotgun", enemy.x, enemy.y - 4)
            end
        end
    end

    self.projectiles:update(self.enemies, self.player, self.items)

    if self.player.health < previousHealth then
        self.sounds:play("hurt")
        self:dropHeldItemFromHurt()
    end
    for _, item in ipairs(self.items) do
        item:update(self.world, self.player)
        if item.justHit and not item.opened and item.kind == "skull" then
            self.effects:skullBreak(item.x, item.y)
            self.sounds:play("break_item")
            item.opened = true
            item.x, item.y = -1000, -1000
        end
        if item.justHit and not item.opened and (item.kind == "jar" or item.kind == "crate") then
            self:openContainer(item)
        end
        -- oItem's enemy collision has no safe-period gate.
        if not item.held and not item.opened and math.abs(item.vx) + math.abs(item.vy) > 2 then
            for _, enemy in ipairs(self.enemies) do
                if enemy.alive and (not enemy.stunned or enemy.stunned == 0)
                    and item:overlapsRectangle(enemy:getBounds()) then
                    enemy:damage(item.heavy and 2 or 1, item.x)
                    if item.kind == "skull" then
                        self.effects:skullBreak(item.x, item.y)
                        self.sounds:play("break_item")
                        item.opened = true
                        item.x, item.y = -1000, -1000
                        break
                    elseif item.kind == "arrow" then
                        item.opened = true
                        item.x, item.y = -1000, -1000
                        break
                    end
                    item.vx = -item.vx * 0.35
                    item.vy = -2
                end
            end
        end
    end
    for _, collectible in ipairs(self.collectibles) do collectible:update(self.world) end
    self.effects:update(self.world)
    self:checkCollectibles()
    self.run:capturePlayer(self.player)
    self.run.time = self.run.time + 1 / Player.TICK_RATE
    self.levelTime = self.levelTime + 1 / Player.TICK_RATE
    if self.levelTime >= 150 and not self.ghostSpawned then
        self.ghostSpawned = true
        local side = self.player.x < self.world.width * 8 and self.player.x + 180 or self.player.x - 180
        self:spawnEntity("ghost", side, self.player.y)
        self.run:addMessage("A TERRIBLE CHILL RUNS UP YOUR SPINE", 120)
    end
    self.run:update()

    if self.player:isDead() then self.deathTimer = 75 end
    if self.player.y > self.world.height * self.world.tileSize + 32 then
        self:generateSelectedLevel(self.seed, self.subtypeIndex ~= 1)
        return
    end
    self.exitReady = self:isNearExit()
end

function FullLevelPlaytest:simulationStep()
    local input = self:getInput()
    local log = self.app.playtestLog
    local before = log and log.capture(self)
    if log then log:tickStart("full_level_playtest", input, before) end
    self:simulationStepBody(input)
    if log then log:tick("full_level_playtest", input, before, self) end
end

function FullLevelPlaytest:update(dt)
    self.accumulator = math.min(self.accumulator + dt, STEP * 5)
    while self.accumulator >= STEP do
        self:simulationStep()
        self.accumulator = self.accumulator - STEP
    end
end

function FullLevelPlaytest:changeDepth(direction)
    self.levelNumber = ((self.levelNumber - 1 + direction) % MINES_DEPTHS) + 1
    local subtype = MinesLevelSelection.choices[self.subtypeIndex].key
    local resetType = self.levelNumber < MinesLevelSelection.requiredDepth(subtype)
    if resetType then self.subtypeIndex = 1 end
    self:generateSelectedLevel(self.seed, resetType or self.subtypeIndex ~= 1)
end

function FullLevelPlaytest:changeSubtype(direction)
    self.subtypeIndex = ((self.subtypeIndex - 1 + direction)
        % #MinesLevelSelection.choices) + 1
    local subtype = MinesLevelSelection.choices[self.subtypeIndex].key
    self.levelNumber = math.max(self.levelNumber, MinesLevelSelection.requiredDepth(subtype))
    self:generateSelectedLevel(self.seed, true)
end

function FullLevelPlaytest:keypressed(key, _, isRepeat)
    if isRepeat then return end
    local controls = self.app.controls
    if controls:matches("rope", key) then
        if self.run.ropes > 0 and self.player and not self.player:isDead()
            and self.tools:throwRope(self.player, self:getInput()) then
            self.run.ropes = self.run.ropes - 1
            if self.throwSound then self.throwSound:clone():play() end
        end
    elseif controls:matches("bomb", key) then
        if self.run.bombs > 0 and self.player and not self.player:isDead()
            and self.tools:throwBomb(self.player, self:getInput()) then
            self.run.bombs = self.run.bombs - 1
            if self.throwSound then self.throwSound:clone():play() end
        end
    elseif controls:matches("up", key) then
        if self:isNearExit() then self:advanceLevel() end
    elseif key == "r" then
        self:generateSelectedLevel(self.seed, true)
    elseif key == "n" then
        self:generateSelectedLevel(MinesLevelSelection.nextSeed(self.seed), self.subtypeIndex ~= 1)
    elseif key == "-" then
        self:changeDepth(-1)
    elseif key == "=" then
        self:changeDepth(1)
    elseif key == "[" then
        self:changeSubtype(-1)
    elseif key == "]" then
        self:changeSubtype(1)
    elseif key == "b" then
        self.debugCollision = not self.debugCollision
    end
end

function FullLevelPlaytest:getViewport()
    local width, height = love.graphics.getDimensions()
    local availableHeight = height - HEADER_HEIGHT - FOOTER_HEIGHT
    -- Keep the generated art on an integer pixel grid while presenting a
    -- camera-sized slice of the level instead of shrinking the whole map.
    local scale = math.max(1, math.floor(math.min(width / 480, availableHeight / 320)))
    return {
        x = 0,
        y = HEADER_HEIGHT,
        width = width,
        height = availableHeight,
        scale = scale,
        logicalWidth = math.floor(width / scale),
        logicalHeight = math.floor(availableHeight / scale),
    }
end

function FullLevelPlaytest:updateCamera(viewport)
    local worldWidth = self.world.width * self.world.tileSize
    local worldHeight = self.world.height * self.world.tileSize
    local targetX = self.player.x - viewport.logicalWidth / 2
    local targetY = self.player.y - viewport.logicalHeight / 2
    self.cameraX = math.floor(clamp(targetX, 0, math.max(0, worldWidth - viewport.logicalWidth)))
    self.cameraY = math.floor(clamp(targetY, 0, math.max(0, worldHeight - viewport.logicalHeight)))
end

function FullLevelPlaytest:drawBackground()
    local worldWidth = self.world.width * self.world.tileSize
    local worldHeight = self.world.height * self.world.tileSize
    local background = self.renderer.images.bg_cave
    local quad = love.graphics.newQuad(0, 0, worldWidth, worldHeight, background:getDimensions())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(background, quad, 0, 0)
end

function FullLevelPlaytest:drawDebugBounds(entity, color)
    local halfWidth = entity:getCollisionHalfWidth()
    local topOffset, bottomOffset = entity:getVerticalBounds()
    love.graphics.setColor(color)
    love.graphics.setLineWidth(0.5)
    love.graphics.rectangle("line", entity.x - halfWidth, entity.y + topOffset,
        halfWidth * 2, bottomOffset - topOffset)
end

function FullLevelPlaytest:drawWorld(viewport)
    self:updateCamera(viewport)
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale, viewport.scale)
    love.graphics.translate(-self.cameraX, -self.cameraY)

    self:drawBackground()
    local queue = DepthQueue.new()
    self.renderer:submitLevel(queue, self.level, {
        includeEntity = function(entity)
            return entity.kind ~= "player" and not self.dynamicEntities[entity]
        end,
        drawEntity = function(entity)
            if entity.kind == "spikes" and entity.bloody then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.spikeBloodImage, entity.x * 16, entity.y * 16)
            else
                self.renderer:drawEntity(entity)
            end
        end,
    })
    for _, bones in ipairs(self.fakeBones) do
        local current = bones
        queue:add(Depth.entity("fake_bones"), function() current:draw(self.renderer) end)
    end
    for _, item in ipairs(self.items) do
        if not item.held and not item.opened then
            local current = item
            queue:add(Depth.entity(current.kind), function()
                self.renderer:drawEntity({
                    kind = current.kind == "arrow" and current.facing < 0
                        and "arrow_left" or current.kind,
                    x = current.x / 16, y = current.y / 16,
                    properties = current.properties,
                })
            end)
        end
    end
    for _, collectible in ipairs(self.collectibles) do
        if collectible.alive then
            local current = collectible
            queue:add(Depth.entity(current.entity.kind), function()
                self.renderer:drawEntity(current.entity)
            end)
        end
    end
    DynamicTerrain.submit(queue, self.world, self.renderer)
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then
            local current = enemy
            queue:add(current.held and Depth.heldItem(self.player) or Depth.entity(current.kind), function()
                current:draw(self.renderer)
            end)
        end
    end
    if self.projectiles then self.projectiles:submit(queue) end
    if self.traps then self.traps:submit(queue) end
    if self.tools then self.tools:submit(queue) end

    if not (self.player.invincibleTimer > 0 and math.floor(self.player.invincibleTimer / 2) % 2 == 0) then
        queue:add(Depth.entity("player"),
            function() self.player:drawBody() end)
        if self.player:getWhipPhase() then
            queue:add(Depth.EFFECT, function() self.player:drawWhip() end)
        end
    end
    if self.heldItem then
        queue:add(Depth.heldItem(self.player), function()
            self.renderer:drawEntity({
                kind = self.heldItem.kind == "arrow" and self.player.facing < 0
                    and "arrow_left" or self.heldItem.kind,
                x = self.heldItem.x / 16,
                y = self.heldItem.y / 16,
                properties = self.heldItem.properties,
            })
        end)
    end
    if self.effects then queue:add(Depth.EFFECT, function() self.effects:draw() end) end
    queue:draw()
    if self.level.dark then
        love.graphics.stencil(function()
            love.graphics.circle("fill", math.floor(self.player.x), math.floor(self.player.y - 4),
                self.player.equipment.spectacles and 72 or 48)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 0)
        love.graphics.setColor(0, 0, 0, 0.92)
        love.graphics.rectangle("fill", self.cameraX, self.cameraY,
            viewport.logicalWidth, viewport.logicalHeight)
        love.graphics.setStencilTest()
    end
    if self.debugCollision then
        self:drawDebugBounds(self.player, { 0.2, 1, 0.35, 0.9 })
        for _, enemy in ipairs(self.enemies) do
            if enemy.alive then self:drawDebugBounds(enemy, { 1, 0.25, 0.2, 0.9 }) end
        end
        for _, item in ipairs(self.items) do
            self:drawDebugBounds(item, { 0.25, 0.65, 1, 0.9 })
        end
        local left, top, right, bottom = self.player:getWhipHitbox()
        if left then
            love.graphics.setColor(0.95, 0.75, 0.18, 0.9)
            love.graphics.rectangle("line", left, top, right - left, bottom - top)
        end
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

function FullLevelPlaytest:drawPlayerHUD(viewport)
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale, viewport.scale)
    self.hud:draw({
        health = self.player.health,
        bombs = self.run.bombs,
        ropes = self.run.ropes,
        money = self.run.money,
        heldItem = self.heldItem or self.heldNpc,
        equipment = self.run.equipment,
        stickyBombs = self.run.equipment.paste,
        compassDirection = self.run.equipment.compass and self.level.exit
            and ((self.level.exit.x * 16 < self.player.x) and "<" or ">") or nil,
    })
    love.graphics.pop()
    love.graphics.setScissor()
end

function FullLevelPlaytest:levelLabel()
    return "1-" .. self.levelNumber
end

function FullLevelPlaytest:draw()
    local width, height = love.graphics.getDimensions()
    local viewport = self:getViewport()
    love.graphics.clear(COLORS.background)
    self:drawWorld(viewport)
    self:drawPlayerHUD(viewport)

    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, width, HEADER_HEIGHT)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.line(0, HEADER_HEIGHT - 1, width, HEADER_HEIGHT - 1)
    love.graphics.line(0, height - FOOTER_HEIGHT, width, height - FOOTER_HEIGHT)

    love.graphics.setFont(self.app.fonts.menu)
    love.graphics.setColor(COLORS.text)
    love.graphics.print("FULL LEVEL PLAYTEST", 18, 10)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print("MINES  " .. self:levelLabel()
        .. "    " .. string.upper(MinesLevelSelection.choices[self.subtypeIndex].label)
        .. "    SEED " .. self.seed, 20, 42)

    if self.exitReady then
        love.graphics.setColor(0.04, 0.03, 0.02, 0.88)
        love.graphics.rectangle("fill", width / 2 - 155, HEADER_HEIGHT + 18, 310, 34, 4, 4)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("PRESS UP TO ENTER THE EXIT", width / 2 - 150,
            HEADER_HEIGHT + 26, 300, "center")
    elseif self.player:isDead() then
        love.graphics.setColor(COLORS.danger)
        love.graphics.printf("YOU DIED", 0, HEADER_HEIGHT + 24, width, "center")
    end

    local message = self.selectionError or (self.run and self.run:currentMessage())
    if message then
        love.graphics.setColor(0.04, 0.03, 0.02, 0.9)
        love.graphics.rectangle("fill", width / 2 - 190, height - FOOTER_HEIGHT - 42, 380, 30, 4, 4)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(type(message) == "table" and message.text or message, width / 2 - 185,
            height - FOOTER_HEIGHT - 35, 370, "center")
    end

    love.graphics.setColor(COLORS.muted)
    local controls = self.app.controls
    love.graphics.printf(
        string.format("%s/%s MOVE   %s RUN   %s JUMP   %s ACTION/PICK UP   %s BOMB   %s ROPE   %s/%s CLIMB\n"
            .. "R RESET   N NEXT SEED   -/= DEPTH   [/] TYPE   B COLLIDERS   ESC BACK",
            controls:label("left"), controls:label("right"), controls:label("run"),
            controls:label("jump"), controls:label("attack"), controls:label("bomb"),
            controls:label("rope"), controls:label("up"), controls:label("down")),
        12, height - 37, width - 24, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return FullLevelPlaytest
