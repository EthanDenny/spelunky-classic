local MinesGenerator = require("src.world.mines_generator")
local MinesVariants = require("src.world.mines_variants")
local MinesLevelSelection = require("src.world.mines_level_selection")
local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local Enemy = require("src.platform.enemy")
local Item = require("src.platform.item")
local ItemActions = require("src.platform.item_actions")
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
local PhysicalBody = require("src.platform.physical_body")
local Shop = require("src.platform.shop")
local Shopkeeper = require("src.platform.enemies.shopkeeper")
local Spikes = require("src.platform.traps.spikes")
local Exit = require("src.platform.structures.exit")
local Kali = require("src.platform.kali")

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
        payHeld = false,
        payQueued = false,
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
    self.spikeBloodImage = Spikes.bloodImage()
    self.hud = self.hud or OriginalHUD.new(self.renderer)
    self.hud:loadAssets()
end

function FullLevelPlaytest:captureHeldItem()
    if not self.heldItem then return end
    if self.heldItem.kind == "bomb" then return end
    if self.heldItem.definition.pickup then
        Item.collect(self.heldItem.kind, self.run, self.player, self)
    else
        self.run.heldItem = {
            kind = self.heldItem.kind,
            properties = self.heldItem.properties,
            new = self.heldItem.new,
        }
    end
end

function FullLevelPlaytest:captureHeldNpc()
    if self.heldNpc then
        self.run.heldCreature = { kind = self.heldNpc.kind, hp = self.heldNpc.hp,
            corpse = self.heldNpc.corpse, stunned = self.heldNpc.stunned }
    end
end

function FullLevelPlaytest:configureProjectiles()
    self.projectiles.onImpact = function(kind, projectile, enemy)
        if kind == "solid" then
            self.effects:add("smoke", projectile.x, projectile.y)
        elseif kind == "player" then
            self.effects:blood(enemy.x, enemy.y, 1)
            return
        elseif enemy and enemy.kind ~= "skeleton" then
            self.effects:blood(enemy.x, enemy.y - 8, 1)
        end
        self.sounds:play("hit")
    end
    self.projectiles.onHitItem = function(item)
        if item.kind == "jar" then
            self:openContainer(item)
        else
            self.effects:skullBreak(item.x, item.y)
            self.sounds:play("break_item")
            item.opened = true
            item.x, item.y = -1000, -1000
        end
    end
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
    self.meleeItem = nil
    self.projectiles = ProjectileSystem.new(self.world)
    self:configureProjectiles()
    self.dynamicEntities = {}
    self.spikeEntities = {}
    self.fakeBones = {}
    if (self.run.shopkeeperAnger > 0 or self.run.murderer) and self.level.exit then
        self.level.entities[#self.level.entities + 1] = {
            kind = "shopkeeper",
            x = self.level.exit.x,
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
            item.new = carried.new == nil and true or carried.new
            item:pickup(self.player, self.run)
            self.heldItem = item
        end
    end
    if self.run.heldCreature then
        local carried = self.run.heldCreature
        self.run.heldCreature = nil
        local body = self:spawnEntity(carried.kind, self.player.x, self.player.y)
        body.hp, body.corpse, body.alive = carried.hp, carried.corpse, not carried.corpse
        body.stunned = carried.stunned
        body.state = body.corpse and "dead" or body.stunned > 0 and "stunned" or "idle"
        body.deathCounted = body.corpse
        if body.kind == "shopkeeper" and body.corpse then body.hasGun = false end
        if body:pickup(self.player) then self.heldNpc = body end
    end
    self.chains = {}
    self.shakeTicks = 0
    if self.run.kaliPunish >= 2 then Kali.attachBall(self) end

    self.accumulator = 0
    self.cameraX = clamp(spawnX - 160, 0, self.world.width * 16)
    self.cameraY = clamp(spawnY - 120, 0, self.world.height * 16)
    self.deathTimer = 0
    self.exitReady = false
    self.actionHeld = false
    self.payHeld, self.payQueued = false, false
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

FullLevelPlaytest.isNearExit = Exit.isNear

function FullLevelPlaytest:advanceLevel()
    if self.levelNumber >= MINES_DEPTHS then
        self.run:addMessage("MINES COMPLETE", 120)
        return
    end
    if self.heldNpc and self.heldNpc.kind == "damsel" and self.heldNpc.alive then
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

FullLevelPlaytest.checkSpikes = Spikes.check

function FullLevelPlaytest:checkWhip()
    local left = self.player:getWhipHitbox()
    if not left then return end
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive and self.player:whipCanHit(enemy)
            and self.player:whipOverlapsRectangle(enemy:getBounds()) then
            self.player:markWhipHit(enemy)
            if enemy.kind == "shopkeeper" then enemy:damage(0, self.player.x, { kind = "whip" })
            elseif enemy.kind == "damsel" and enemy.forSale then
                enemy.vy = -2
                Shop.anger(self, enemy.x, enemy.y, "YOU'LL PAY FOR YOUR CRIMES!")
            else enemy:damage(1) end
            if enemy.kind == "snake" then
                self.effects:blood(enemy.x, enemy.y - 8, 1)
            end
            if self.hitSound then self.hitSound:clone():play() end
        end
    end
    for _, item in ipairs(self.items) do
        if not item.held and not item.opened and item.definition.container
            and item.definition.container.effect == "jar" then
            local half = item:getCollisionHalfWidth()
            local itemTop, itemBottom = item:getVerticalBounds()
            if self.player:whipOverlapsRectangle(item.x - half, item.y + itemTop,
                item.x + half, item.y + itemBottom) then
                self:openContainer(item)
            end
        end
    end
end

function FullLevelPlaytest:openContainer(item)
    local x, y = item.x, item.y
    local rewards, message = item:open(self.run, self.effects.random)
    if not rewards then
        if message then self.run:addMessage(message, 60) end
        return false
    end
    local effect = item.definition.container.effect
    if effect == "jar" then
        self.effects:jarBreak(x, y, item.impactSide)
        self.sounds:play("break_item")
    elseif effect == "smoke" then
        self.effects:add("poof", x, y)
    elseif effect == "unlock" then
        self.effects:add("poof", x, y, -0.4)
        self.effects:add("poof", x, y, 0.4)
        self.sounds:play("chest_open")
    elseif not (rewards[1] and rewards[1].trapped) then
        self.sounds:play("chest_open")
    end
    for _, reward in ipairs(rewards) do
    if reward.kind == "snake" and effect == "jar" then
        -- oJar's Destroy event creates an oSnake at x/y-8 after a left hit,
        -- x-16/y-8 after a right hit, and x-8/y-8 otherwise. Our enemy
        -- coordinates are bottom-center rather than GameMaker's top-left.
        local snakeX = x + (item.impactSide == "left" and 8
            or item.impactSide == "right" and -8 or 0)
        local snakeY = y + 8
        local snake = self:spawnEntity(reward.kind, snakeX, snakeY)
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
    elseif reward.kind == "bomb" then
        self.tools:spawnBomb(x, y, { vx = reward.vx, vy = reward.vy,
            timer = 40 })
        self.sounds:play("trap")
    else
        local spawned = self:spawnEntity(reward.kind, x, y)
        if spawned then
            spawned.vx = reward.vx or spawned.vx
            spawned.vy = reward.vy or spawned.vy
        end
    end
    end
    if message then self.run:addMessage(message, 60) end
    if item.kind ~= "chest" then item.x, item.y = -1000, -1000 end
    return true
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
                    if not self.run:currentMessage() then
                        self.run:addMessage("$" .. price .. " - PICK UP, THEN "
                            .. self.app.controls:label("pay") .. " TO BUY", 45)
                    end
                else
                    local message = Item.collect(entity.kind, self.run, self.player, self)
                    collectible.alive = false
                    self.sounds:play(Item.pickupSound(entity.kind))
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

function FullLevelPlaytest:pickupNearestNpc()
    for _, creature in ipairs(self.enemies) do
        if creature.spec and creature.spec.canBeHeld and not creature.held
            and math.abs(creature.x - self.player.x) < 12
            and math.abs(creature.y - self.player.y) < 14 and creature:pickup(self.player) then
            self.heldNpc = creature
            return true
        end
    end
    return false
end

function FullLevelPlaytest:pickupNearestItem()
    local left, top = self.player.x - 8, self.player.y
    local right, bottom = self.player.x + 8, self.player.y + 8
    local nearest, nearestDistance
    local candidates = {}
    for _, item in ipairs(self.items) do candidates[#candidates + 1] = item end
    for _, bomb in ipairs(self.tools.bombs) do
        if bomb.alive then candidates[#candidates + 1] = bomb end
    end
    for _, item in ipairs(candidates) do
        if not item.held and not item.opened and item:overlapsRectangle(left, top, right, bottom)
            and not self.world:solidAtPoint(item.x, item.y) then
            local dx, dy = item.x - self.player.x, item.y - self.player.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest, nearestDistance = item, distance
            end
        end
    end
    if nearest and nearest:pickup(self.player, self.run) then
        self.heldItem = nearest
        if nearest.definition.consumeOnPickup
            and not Shop.forSale(nearest) then
            Shop.claim(self, nearest)
        else self.sounds:play("pickup") end
        if nearest.definition.trapOnPickup == "idol" and not nearest.idolTriggered then
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
        if item.definition.unlockWith and self.heldItem
            and self.heldItem.definition.unlocks == item.kind
            and not item.held and not item.opened and math.abs(item.x - self.player.x) < 15
            and math.abs(item.y - self.player.y) < 15 then
            self.heldItem.held = false
            self.heldItem.opened = true
            self.heldItem.x, self.heldItem.y = -1000, -1000
            self.heldItem = nil
            self.run.hasKey = true
            return self:openContainer(item)
        end
    end
    return false
end

function FullLevelPlaytest:containerAtPlayer()
    for _, item in ipairs(self.items) do
        if item.definition.action == "open" and not item.opened
            and item:overlapsRectangle(self.player.x, self.player.y,
                self.player.x, self.player.y) then
            return item
        end
    end
end

function FullLevelPlaytest:useHeldItem(input)
    local item = self.heldItem
    if not item then return false end
    return ItemActions.use(self, item, input)
end

function FullLevelPlaytest:dropHeldItemFromHurt()
    if self.heldItem then
        -- oPlayer1 calls scrFireBow before releasing an armed bow on stun/death.
        ItemActions.updateBow(self, {})
        self.heldItem.visible = true
        self.heldItem:dropFromHurt(self.player)
        self.heldItem = nil
    end
    self.meleeItem = nil
    if self.heldNpc then
        self.heldNpc:throw(self.player, {}, self.world)
        self.heldNpc = nil
    end
end

function FullLevelPlaytest:processItemImpact(item)
    local impact = item.definition.breakOnImpact
    if not item.justHit or item.opened or not impact then return end
    if item.definition.container then return self:openContainer(item) end
    if impact.effect == "skull" then
        self.effects:skullBreak(item.x, item.y, item.impactSide)
    end
    self.sounds:play("break_item")
    item.opened = true
    item.x, item.y = -1000, -1000
end

function FullLevelPlaytest:resolveItemEnemyContact(item)
    local speed = item.definition.hitSpeed or 2
    if item.held or item.opened or item.skipEnemyHitOnce
        or (math.abs(item.vx) <= speed and math.abs(item.vy) <= speed) then return end
    local reach = item.definition.flight == "fragile" and 3 or 2
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive and (not enemy.stunned or enemy.stunned == 0)
            and enemy:overlapsRectangle(item.x - reach, item.y - reach,
                item.x + reach, item.y + reach) and PhysicalBody.strikeEnemy(item, enemy) then
            if item.definition.breakOnImpact then
                item.justHit = true
                self:processItemImpact(item)
                break
            elseif item.definition.consumeOnEnemyHit then
                item.opened = true
                item.x, item.y = -1000, -1000
                break
            end
        end
    end
end

function FullLevelPlaytest:resolveItemPlayerContact(item)
    local player = self.player
    if item.held or item.opened or item.safeTimer > 0 or player:isDead()
        or player:isStunned() then return end
    local halfWidth = player:getCollisionHalfWidth()
    local top, bottom = player:getVerticalBounds()
    if not item:overlapsRectangle(player.x - halfWidth, player.y + top,
        player.x + halfWidth, player.y + bottom) then return end
    -- Classic's player Step names fast arrows and rocks. Falling ordinary
    -- carryables are an additional requested hazard; respect throw immunity.
    local arrowHit = item.kind == "arrow" and math.abs(item.vx) > 3
    local rockHit = item.kind == "rock" and math.abs(item.vx) > 4
    local fallHit = item.kind ~= "arrow" and item.vy > 4
    if not (arrowHit or rockHit or fallHit) then return end
    local damage = (arrowHit or rockHit or item.kind == "rock") and 2 or 1
    if not player:hurt(item.x, damage, item.kind, 20) then return end
    self.effects:blood(player.x, player.y, 3)
    self.sounds:play("hurt")
    self:dropHeldItemFromHurt()
    if arrowHit then
        item.opened = true
        item.x, item.y = -1000, -1000
    end
end

function FullLevelPlaytest:applyEnvironment(input)
    local player = self.player
    if self.world:webAtPoint(player.x, player.y) then
        player:web(12)
    end
end

function FullLevelPlaytest:handleActionPressed(input, containerToOpen)
    if self.player:isDead() or self.player:isStunned() then return end
    if containerToOpen then
        ItemActions.use(self, containerToOpen, input)
    elseif self.heldNpc then
        self.heldNpc:throw(self.player, input, self.world)
        self.heldNpc = nil
    elseif self.heldItem then
        self:useHeldItem(input)
    elseif input.down and self.player.state == Player.STATES.ducking then
        if not self:pickupNearestNpc() then self:pickupNearestItem() end
    end
end

function FullLevelPlaytest:simulationStepBody(input)
    local payPressed = self.payQueued or (input.pay and not self.payHeld)
    self.payQueued, self.payHeld = false, input.pay or false
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
    local containerToOpen = actionPressed and input.up and self:containerAtPlayer()
    if self.heldItem or self.heldNpc or containerToOpen then input.suppressWhip = true end
    local previousY = self.player.y
    local previousHealth = self.player.health
    local previousState = self.player.state
    self.player:step(self.world, input)
    if self.heldItem then self.heldItem:updateHeldPosition(self.player) end
    if self.heldNpc then self.heldNpc:updateHeldPosition(self.player) end
    Shop.update(self)
    if payPressed then Shop.pay(self) end
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
    if self.heldItem and self.heldItem.definition.unlocks then
        self.heldItem:updateHeldPosition(self.player)
        self:openNearbyContainer()
    end
    if actionPressed then self:handleActionPressed(input, containerToOpen) end
    ItemActions.updateBow(self, input)
    ItemActions.updateMelee(self)
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
    local trapTargets = {}
    for _, group in ipairs({ self.collectibles, self.tools.bombs, self.tools.ropes,
        self.projectiles.projectiles }) do
        for _, target in ipairs(group) do trapTargets[#trapTargets + 1] = target end
    end
    self.traps:update(self.player, self.enemies, self.items, trapTargets)
    self.tools:update(self.player, self.enemies, self.items)
    Kali.update(self)
    if self.heldItem and self.heldItem.kind == "bomb" and not self.heldItem.alive then
        self.heldItem = nil
    end
    -- oPlayer1 checks its center point against oSolid and dies on overlap,
    -- regardless of temporary invincibility.
    if not self.player:isDead() and self.world:solidAtPoint(self.player.x, self.player.y) then
        self.player:kill("crushed", 0, -3)
    end

    for _, enemy in ipairs(self.enemies) do
        if enemy.alive or enemy.corpse then
            local oldState, oldVy = enemy.state, enemy.vy
            enemy:step(self.world, self.player, self)
            if enemy.kind == "bat" and oldState == "HANG" and enemy.state ~= oldState then
                self.sounds:play("bat")
            elseif enemy.kind == "giant_spider" and oldState == "hang"
                and enemy.state ~= oldState then
                self.sounds:play("giant_spider")
            elseif enemy.kind == "giant_spider" and oldVy >= 0 and enemy.vy < -1
                and enemy.state == "bounce" then
                self.sounds:play("spider_jump")
            end
            local contact = enemy:resolvePlayerContact(self.player, previousY)
            if contact == "throw" then self:dropHeldItemFromHurt() end
            if enemy.kind == "damsel" and enemy.alive and self:isNearExit()
                and math.abs(enemy.x - self.player.x) < 24 then
                enemy.alive = false
                enemy.rescued = true
                self.run.damsels = self.run.damsels + 1
                self.player.health = math.min(self.player.maxHealth, self.player.health + 1)
                self.sounds:play("kiss")
                self.run:addMessage("A KISS FOR YOUR TROUBLE", 90)
            end
        end
        if not enemy.alive and not enemy.deathCounted and not enemy.rescued then
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
            if enemy.kind == "shopkeeper" and not enemy.sacrificed then
                Shopkeeper.die(enemy, self)
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
        self:processItemImpact(item)
        -- oItem's enemy collision has no safe-period gate.
        self:resolveItemEnemyContact(item)
        self:resolveItemPlayerContact(item)
        item.skipEnemyHitOnce = false
    end
    Kali.updateChains(self)
    ItemActions.recoverArrows(self)
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
    if controls:matches("pay", key) then
        self.payQueued = true
    elseif controls:matches("rope", key) then
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
    self.cameraWidth, self.cameraHeight = viewport.logicalWidth, viewport.logicalHeight
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale, viewport.scale)
    love.graphics.translate(-self.cameraX, -self.cameraY)
    if (self.shakeTicks or 0) > 0 then
        love.graphics.translate(self.shakeTicks % 2 == 0 and 2 or -2, 1)
    end

    self:drawBackground()
    local queue = DepthQueue.new()
    self.renderer:submitLevel(queue, self.level, {
        includeEntity = function(entity)
            return entity.kind ~= "player" and not self.dynamicEntities[entity]
        end,
        drawEntity = function(entity)
            if entity.kind == "spikes" and entity.bloody then
                Spikes.drawBloody(entity)
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
        if not item.held and (not item.opened or item.kind == "chest")
            and item.visible ~= false then
            local current = item
            queue:add(Depth.entity(current.kind), function()
                self.renderer:drawItem(current)
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
        if enemy.alive or enemy.corpse then
            local current = enemy
            queue:add(current.held and Depth.heldItem(self.player) or Depth.entity(current.kind), function()
                current:draw(self.renderer)
            end)
        end
    end
    if self.projectiles then self.projectiles:submit(queue) end
    if self.traps then self.traps:submit(queue) end
    if self.tools then self.tools:submit(queue, self.player) end
    Kali.submit(self, queue)

    if not (self.player.invincibleTimer > 0 and math.floor(self.player.invincibleTimer / 2) % 2 == 0) then
        queue:add(Depth.entity("player"),
            function() self.player:drawBody() end)
        if self.player:getWhipPhase() then
            queue:add(Depth.EFFECT, function() self.player:drawWhip() end)
        end
    end
    if self.heldItem and self.heldItem.kind ~= "bomb" then
        queue:add(Depth.heldItem(self.player), function()
            self.renderer:drawItem(self.heldItem, self.player.facing)
        end)
    end
    if self.meleeItem then
        queue:add(Depth.EFFECT, function()
            self.renderer:drawMeleeSwing(self.player, self.meleeItem)
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
        compass = self.run.equipment.compass and self.level.exit and {
            exitX = self.level.exit.x * 16,
            exitY = self.level.exit.y * 16,
            cameraX = self.cameraX,
            cameraY = self.cameraY,
            width = viewport.logicalWidth,
            height = viewport.logicalHeight,
        } or nil,
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
        string.format("%s/%s MOVE   %s RUN   %s JUMP   %s ACTION/PICK UP   %s BOMB   %s ROPE   %s PAY   %s/%s CLIMB\n"
            .. "R RESET   N NEXT SEED   -/= DEPTH   [/] TYPE   B COLLIDERS   ESC BACK",
            controls:label("left"), controls:label("right"), controls:label("run"),
            controls:label("jump"), controls:label("attack"), controls:label("bomb"),
            controls:label("rope"), controls:label("pay"), controls:label("up"), controls:label("down")),
        12, height - 37, width - 24, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return FullLevelPlaytest
