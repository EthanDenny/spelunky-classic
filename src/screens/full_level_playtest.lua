local MinesGenerator = require("src.world.mines_generator")
local ClassicAreaGenerator = require("src.world.classic_area_generator")
local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local Enemy = require("src.platform.enemy")
local Item = require("src.platform.item")
local DynamicTerrain = require("src.platform.dynamic_terrain")
local ToolSystem = require("src.platform.tool_system")
local TrapSystem = require("src.platform.trap_system")
local OriginalHUD = require("src.ui.original_hud")
local Creature = require("src.platform.creature")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local SpecialGeneration = require("src.world.special_generation")

local FullLevelPlaytest = {}
FullLevelPlaytest.__index = FullLevelPlaytest

local STEP = 1 / Player.TICK_RATE
local HEADER_HEIGHT = 64
local FOOTER_HEIGHT = 40

local LEVEL_TYPES = {
    { label = "MINES", key = "mines", depths = 4, offset = 0 },
    { label = "JUNGLE", key = "jungle", depths = 4, offset = 4 },
    { label = "ICE CAVES", key = "ice", depths = 4, offset = 8 },
    { label = "TEMPLE", key = "temple", depths = 3, offset = 12 },
    { label = "OLMEC", key = "olmec", depths = 1, offset = 15 },
}

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
        areaIndex = 1,
        levelNumber = 1,
        seed = nil,
        level = nil,
        world = nil,
        player = nil,
        enemies = {},
        items = {},
        heldItem = nil,
        dynamicEntities = {},
        spikeEntities = {},
        accumulator = 0,
        cameraX = 0,
        cameraY = 0,
        debugCollision = false,
        deathTimer = 0,
        exitReady = false,
        hitSound = nil,
        throwSound = nil,
        actionHeld = false,
        tools = nil,
        traps = nil,
        hud = nil,
        run = nil,
        projectiles = nil,
        heldNpc = nil,
        collectibles = {},
        specialEntrance = nil,
        specialReturn = nil,
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
    self.hud = self.hud or OriginalHUD.new(self.renderer)
    self.hud:loadAssets()
end

function FullLevelPlaytest:selectedArea()
    return LEVEL_TYPES[self.areaIndex]
end

function FullLevelPlaytest:captureHeldItem()
    if not self.heldItem then return end
    if self.heldItem.kind == "gold_idol" or self.heldItem.kind == "crystal_skull" then
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
    local area = self:selectedArea()
    if area.key == "mines" then
        self.level = MinesGenerator.generate(seed, { levelNumber = self.levelNumber })
    else
        self.level = ClassicAreaGenerator.generate(area.key, seed, { levelNumber = self.levelNumber })
    end
    SpecialGeneration.apply(self.level, self.run)
    self:buildSimulation()
end

function FullLevelPlaytest:buildSimulation()
    self.world = GeneratedWorld.fromLevel(self.level)
    local spawnX, spawnY = GeneratedWorld.spawnPoint(self.level)
    self.player = Player.new(spawnX, spawnY)
    self.run:applyToPlayer(self.player)
    self.player.state = Player.STATES.standing
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
    self.hiddenEntities = {}
    self.heldItem = nil
    self.heldNpc = nil
    self.projectiles = ProjectileSystem.new(self.world)
    self.dynamicEntities = {}
    self.spikeEntities = {}
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
            self.collectibles[#self.collectibles + 1] = { entity = entity, alive = true }
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
    return {
        left = love.keyboard.isDown("left", "a"),
        right = love.keyboard.isDown("right", "d"),
        up = love.keyboard.isDown("up", "w"),
        down = love.keyboard.isDown("down", "s"),
        jump = love.keyboard.isDown("space", "z"),
        sprint = love.keyboard.isDown("lshift", "rshift"),
        attack = love.keyboard.isDown("x", "c", "k", "lctrl", "rctrl"),
    }
end

function FullLevelPlaytest:isNearExit()
    if not self.level.exit or not self.player then return false end
    local exitX = self.level.exit.x * 16 + 8
    local exitY = self.level.exit.y * 16 + 8
    return math.abs(self.player.x - exitX) <= 11 and math.abs(self.player.y - exitY) <= 15
end

function FullLevelPlaytest:nearSpecialEntrance()
    if not self.player then return nil end
    for _, entrance in ipairs(self.level.specialEntrances or {}) do
        if math.abs(self.player.x - entrance.x * 16) <= 12
            and math.abs(self.player.y - entrance.y * 16) <= 18 then
            return entrance
        end
    end
end

function FullLevelPlaytest:enterSpecial(entrance)
    local kind = entrance.properties.special
    self.run.visited[kind] = true
    if kind == "moai" then
        self.run.equipment.ankh = false
        self.player.equipment.ankh = false
    end
    self.specialReturn = {
        areaIndex = self.areaIndex,
        levelNumber = self.levelNumber,
        seed = self.seed,
    }
    self:captureHeldItem()
    self:captureHeldNpc()
    self.level = SpecialGeneration.interior(kind, self.seed + #kind * 997)
    self:buildSimulation()
    self.run:addMessage(entrance.properties.label or string.upper(kind:gsub("_", " ")), 120)
end

function FullLevelPlaytest:returnFromSpecial()
    local state = self.specialReturn
    self.specialReturn = nil
    self.areaIndex = state.areaIndex
    self.levelNumber = state.levelNumber
    self:generateLevel(state.seed)
end

function FullLevelPlaytest:advanceLevel()
    if self.level.special and self.specialReturn then
        self:returnFromSpecial()
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
    local area = self:selectedArea()
    if self.levelNumber < area.depths then
        self.levelNumber = self.levelNumber + 1
    elseif self.areaIndex < #LEVEL_TYPES then
        self.areaIndex = self.areaIndex + 1
        self.levelNumber = 1
    else
        self.areaIndex = 1
        self.levelNumber = 1
        self.seed = (self.seed % 2147483646) + 1
    end
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:checkSpikes(previousY)
    if self.player.invincibleTimer > 0 then return end
    local halfWidth = self.player:getCollisionHalfWidth()
    local _, bottomOffset = self.player:getVerticalBounds()
    local bottom = self.player.y + bottomOffset
    local previousBottom = previousY + bottomOffset
    for _, spike in ipairs(self.spikeEntities) do
        local left = spike.x * 16
        local top = spike.y * 16 + 4
        if self.player.x + halfWidth > left and self.player.x - halfWidth < left + 16
            and bottom >= top and previousBottom <= top + 5 and self.player.vy >= 0 then
            self.player:hurt(left + 8)
            return
        end
    end
end

function FullLevelPlaytest:checkWhip()
    local left, top, right, bottom = self.player:getWhipHitbox()
    if not left then return end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive and self.player:whipCanHit(enemy)
            and enemy:overlapsRectangle(left, top, right, bottom) then
            self.player:markWhipHit(enemy)
            enemy:damage(1)
            if enemy.kind == "shopkeeper" then
                enemy.angry = true
                self.run:angerShopkeepers("VANDAL! THIEF!")
            end
            if self.hitSound then self.hitSound:clone():play() end
        end
    end
    for _, item in ipairs(self.items) do
        if not item.held and not item.opened and item:overlapsRectangle(left, top, right, bottom)
            and (item.kind == "jar" or item.kind == "crate" or item.kind == "chest") then
            local reward, message = item:open(self.run)
            if reward then self:spawnEntity(reward, item.x, item.y - 4) end
            if message then self.run:addMessage(message, 60) end
            item.x, item.y = -1000, -1000
        end
    end
    for _, entity in ipairs(self.level.entities) do
        if entity.kind == "web" and not self.dynamicEntities[entity] then
            local entityLeft, entityTop = entity.x * 16, entity.y * 16
            if right >= entityLeft and left <= entityLeft + 16
                and bottom >= entityTop and top <= entityTop + 16 then
                self.dynamicEntities[entity] = true
                self.world:remove("web", math.floor(entity.x), math.floor(entity.y))
            end
        end
    end
end

function FullLevelPlaytest:checkCollectibles()
    local half = self.player:getCollisionHalfWidth()
    local top, bottom = self.player:getVerticalBounds()
    for _, collectible in ipairs(self.collectibles) do
        if collectible.alive then
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

function FullLevelPlaytest:talkToTunnelMan()
    for _, creature in ipairs(self.enemies) do
        if creature.kind == "tunnel_man" and creature.alive
            and math.abs(creature.x - self.player.x) < 18
            and math.abs(creature.y - self.player.y) < 18 then
            local tunnel = creature.entity.properties.tunnel or 1
            local field = tunnel == 1 and "tunnel1" or "tunnel2"
            local remaining = self.run[field]
            local donation = math.min(10000, self.run.money, remaining)
            if donation > 0 then
                self.run.money = self.run.money - donation
                self.run[field] = remaining - donation
                if self.run[field] == 0 then
                    self.run.shortcuts[tunnel] = true
                    self.run:addMessage("THE SHORTCUT IS COMPLETE!", 120)
                else
                    self.run:addMessage("DONATED $" .. donation .. " - $" .. self.run[field] .. " TO GO", 120)
                end
            else
                self.run:addMessage("I STILL NEED $" .. remaining, 90)
            end
            return true
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
        if nearest.kind == "gold_idol" and not nearest.idolTriggered then
            nearest.idolTriggered = true
            self.traps:triggerIdol(self.player, self.level.area or self:selectedArea().key)
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
        creature.x, creature.y = x, y
        self.enemies[#self.enemies + 1] = creature
        return creature
    elseif Item.isCollectible(kind) then
        local collectible = { entity = entity, alive = true }
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
            if cooldown then item.cooldown = cooldown return true end
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
    local inLiquid = self.world:cellAt("liquid", player.x, player.y)
        or self.world:cellAt("liquid", player.x, player.y + 7)
    if inLiquid then
        if self.world:cellAt("lava", player.x, player.y)
            or self.world:cellAt("lava", player.x, player.y + 7) then
            player:enterLava()
            return
        end
        player.vx = player.vx * 0.82
        player.vy = math.min(2, player.vy * 0.6 + 0.15)
        if input.jump or input.up then
            player.vy = -3
            player:setState(Player.STATES.jumping)
        end
    end
    if self.world:cellAt("web", player.x, player.y) then
        player:web(12)
        player.vx = player.vx * 0.15
        player.vy = player.vy * 0.15
    end
end

function FullLevelPlaytest:simulationStep()
    if self.player:isDead() then
        if self.run:resurrect(self.player) then
            self.player.x, self.player.y = GeneratedWorld.spawnPoint(self.level)
            self.player.stunTimer, self.player.burnTimer, self.player.webTimer = 0, 0, 0
            self.player:refreshStatus()
            self.player.state = Player.STATES.standing
            self.player.invincibleTimer = 90
            self.run:addMessage("THE ANKH RESTORES YOU", 120)
            return
        end
        self.deathTimer = self.deathTimer - 1
        if self.deathTimer <= 0 then
            self.run = RunState.new(self.seed)
            self.areaIndex, self.levelNumber = 1, 1
            self.specialReturn = nil
            self:generateLevel(self.seed)
        end
        return
    end

    local input = self:getInput()
    local actionPressed = input.attack and not self.actionHeld
    self.actionHeld = input.attack
    if self.heldItem or self.heldNpc then input.suppressWhip = true end
    local previousY = self.player.y
    local previousHealth = self.player.health
    self.player:step(self.world, input)
    self:applyEnvironment(input)
    if actionPressed then
        if self.heldNpc then
            self.heldNpc:throw(self.player, input)
            self.heldNpc = nil
        elseif self.heldItem then
            if not (input.down and self.heldItem.kind == "key" and self:openNearbyContainer()) then
                self:useHeldItem(input)
            end
        elseif input.down and self.player.state == Player.STATES.ducking then
            if not (input.sprint and self:stealNearbyItem())
                and not self:talkToTunnelMan() and not self:interactShopkeeper()
                and not self:buyNearbyCollectible() and not self:openNearbyContainer()
                and not self:pickupNearestNpc(input.sprint) then
                self:pickupNearestItem()
            end
        end
    end
    self:checkWhip()
    self:checkSpikes(previousY)
    self:revealHiddenContents()
    DynamicTerrain.update(self.world, self.player)
    self.traps:update(self.player, self.enemies, self.items)
    self.tools:update(self.player, self.enemies, self.items)
    -- oPlayer1 checks its center point against oSolid and dies on overlap,
    -- regardless of temporary invincibility.
    if not self.player:isDead() and self.world:solidAtPoint(self.player.x, self.player.y) then
        self.player:kill("crushed", 0, -3)
    end

    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then
            enemy:step(self.world, self.player, {
                run = self.run,
                projectiles = self.projectiles,
            })
            enemy:resolvePlayerContact(self.player, previousY)
            if enemy.kind == "damsel" and self:isNearExit()
                and math.abs(enemy.x - self.player.x) < 24 then
                enemy.alive = false
                enemy.rescued = true
                self.run.damsels = self.run.damsels + 1
                self.player.health = math.min(self.player.maxHealth, self.player.health + 1)
                self.run:addMessage("A KISS FOR YOUR TROUBLE", 90)
            end
        elseif not enemy.deathCounted then
            enemy.deathCounted = true
            self.run.kills = self.run.kills + 1
            if enemy.config and enemy.config.explosive then self.tools:explode(enemy.x, enemy.y - 4) end
            if enemy.kind == "giant_spider" then self:spawnEntity("paste", enemy.x, enemy.y - 4) end
            if enemy.kind == "olmec" then
                self.level.exit = { x = math.floor(self.player.x / 16), y = math.floor(self.player.y / 16) }
                local exit = { kind = "exit", x = self.level.exit.x, y = self.level.exit.y, properties = {} }
                self.level.entities[#self.level.entities + 1] = exit
                self.run:addMessage("OLMEC HAS FALLEN - THE EXIT IS OPEN", 180)
            end
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

    self.projectiles:update(self.enemies, self.player)

    if self.player.health < previousHealth then self:dropHeldItemFromHurt() end
    for _, item in ipairs(self.items) do
        item:update(self.world, self.player)
        if item.justHit and not item.opened and (item.kind == "jar" or item.kind == "crate") then
            local reward, message = item:open(self.run)
            if reward then self:spawnEntity(reward, item.x, item.y - 4) end
            if message then self.run:addMessage(message, 60) end
            item.x, item.y = -1000, -1000
        end
        if not item.held and item.safeTimer == 0 and math.abs(item.vx) + math.abs(item.vy) > 2 then
            for _, enemy in ipairs(self.enemies) do
                if enemy.alive and item:overlapsRectangle(enemy:getBounds()) then
                    enemy:damage(item.heavy and 2 or 1, item.x)
                    item.vx = -item.vx * 0.35
                    item.vy = -2
                end
            end
        end
    end
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
        self:generateLevel(self.seed)
        return
    end
    self.exitReady = self:isNearExit()
    self.specialEntrance = self:nearSpecialEntrance()
end

function FullLevelPlaytest:update(dt)
    self.accumulator = math.min(self.accumulator + dt, STEP * 5)
    while self.accumulator >= STEP do
        self:simulationStep()
        self.accumulator = self.accumulator - STEP
    end
end

function FullLevelPlaytest:changeArea(direction)
    self.areaIndex = ((self.areaIndex - 1 + direction) % #LEVEL_TYPES) + 1
    self.levelNumber = 1
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:changeDepth(direction)
    local depths = self:selectedArea().depths
    self.levelNumber = ((self.levelNumber - 1 + direction) % depths) + 1
    self:generateLevel(self.seed)
end

function FullLevelPlaytest:keypressed(key, _, isRepeat)
    if isRepeat then return end
    if key == "f" and self.run.bombs > 0 and self.player and not self.player:isDead() then
        self.tools:throwBomb(self.player)
        self.run.bombs = self.run.bombs - 1
    elseif key == "g" and self.run.ropes > 0 and self.player and not self.player:isDead() then
        if self.tools:throwRope(self.player, self:getInput()) then
            self.run.ropes = self.run.ropes - 1
        end
    elseif (key == "up" or key == "w") and self.specialEntrance then
        self:enterSpecial(self.specialEntrance)
    elseif (key == "up" or key == "w") and self:isNearExit() then
        self:advanceLevel()
    elseif key == "r" then
        self:generateLevel(self.seed)
    elseif key == "n" then
        self:generateLevel((self.seed % 2147483646) + 1)
    elseif key == "[" or key == "q" then
        self:changeArea(-1)
    elseif key == "]" or key == "e" then
        self:changeArea(1)
    elseif key == "-" then
        self:changeDepth(-1)
    elseif key == "=" then
        self:changeDepth(1)
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
    local background = (self.level.area == "temple" or self.level.area == "olmec")
        and self.renderer.images.bg_temple or self.renderer.images.bg_cave
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
    -- GameMaker draws loose oItem instances (depth 101) before oSolid
    -- terrain (depth 100), so tile foreground pixels naturally cover them.
    for _, entity in ipairs(self.level.entities) do
        if entity.kind ~= "player" and not self.dynamicEntities[entity]
            and Item.rendersBehindTerrain(entity.kind) then
            self.renderer:drawEntity(entity)
        end
    end
    for _, item in ipairs(self.items) do
        if not item.held then
            self.renderer:drawEntity({
                kind = item.kind,
                x = item.x / 16,
                y = item.y / 16,
                properties = item.properties,
            })
        end
    end
    if self.tools then self.tools:drawBack() end
    for y = 0, self.level.height - 1 do
        for x = 0, self.level.width - 1 do
            self.renderer:drawTile(self.level.tiles[y + 1][x + 1], x * 16, y * 16)
        end
    end
    DynamicTerrain.draw(self.world, self.renderer)
    for _, decoration in ipairs(self.level.decorations or {}) do
        if decoration.y >= 0 then
            love.graphics.draw(self.renderer.images.bg_cave_top,
                self.renderer.caveTopQuads[decoration.variant], decoration.x * 16, decoration.y * 16)
        end
    end
    for _, entity in ipairs(self.level.entities) do
        if entity.kind ~= "player" and not self.dynamicEntities[entity]
            and not Item.rendersBehindTerrain(entity.kind) then
            self.renderer:drawEntity(entity)
        end
    end
    for _, collectible in ipairs(self.collectibles) do
        if collectible.alive then self.renderer:drawEntity(collectible.entity) end
    end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive then enemy:draw(self.renderer) end
    end
    if self.projectiles then self.projectiles:draw() end
    if self.traps then self.traps:draw() end
    if self.tools then self.tools:drawFront() end

    if not (self.player.invincibleTimer > 0 and math.floor(self.player.invincibleTimer / 2) % 2 == 0) then
        self.player:draw()
    end
    if self.heldItem then
        self.renderer:drawEntity({
            kind = self.heldItem.kind,
            x = self.heldItem.x / 16,
            y = self.heldItem.y / 16,
            properties = self.heldItem.properties,
        })
    end
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
    local area = self:selectedArea()
    local absolute = area.offset + self.levelNumber
    if area.key == "olmec" then return "4-4" end
    return (math.floor((absolute - 1) / 4) + 1) .. "-" .. (((absolute - 1) % 4) + 1)
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
    love.graphics.print(self:selectedArea().label .. "  " .. self:levelLabel()
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

    if self.specialEntrance then
        love.graphics.setColor(0.04, 0.03, 0.02, 0.9)
        love.graphics.rectangle("fill", width / 2 - 155, HEADER_HEIGHT + 56, 310, 30, 4, 4)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf("PRESS UP: " .. (self.specialEntrance.properties.label or "ENTER"),
            width / 2 - 150, HEADER_HEIGHT + 63, 300, "center")
    end
    local message = self.run and self.run:currentMessage()
    if message then
        love.graphics.setColor(0.04, 0.03, 0.02, 0.9)
        love.graphics.rectangle("fill", width / 2 - 190, height - FOOTER_HEIGHT - 42, 380, 30, 4, 4)
        love.graphics.setColor(COLORS.text)
        love.graphics.printf(message.text, width / 2 - 185,
            height - FOOTER_HEIGHT - 35, 370, "center")
    end

    love.graphics.setColor(COLORS.muted)
    love.graphics.printf(
        "A/D MOVE   SHIFT SPRINT   Z/SPACE JUMP   X WHIP/THROW   DOWN+X PICK UP/DROP   F BOMB   G ROPE   W/S CLIMB   R RESET   N SEED   [ ] AREA   B COLLIDERS   ESC BACK",
        12, height - 27, width - 24, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return FullLevelPlaytest
