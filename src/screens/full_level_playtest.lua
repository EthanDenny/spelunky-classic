local MinesGenerator = require("src.world.mines_generator")
local MinesLevelSelection = require("src.world.mines_level_selection")
local GeneratedWorld = require("src.platform.generated_world")
local Player = require("src.platform.player")
local Enemy = require("src.platform.enemy")
local Item = require("src.platform.item")
local ItemActions = require("src.platform.item_actions")
local EntityBody = require("src.platform.entity_body")
local Effects = require("src.platform.effects")
local FakeBones = require("src.platform.fake_bones")
local DynamicTerrain = require("src.platform.dynamic_terrain")
local ToolSystem = require("src.platform.tool_system")
local TrapSystem = require("src.platform.trap_system")
local OriginalHUD = require("src.ui.original_hud")
local OriginalMessages = require("src.ui.original_messages")
local ProjectileSystem = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local Depth = require("src.render.classic_depth")
local DepthQueue = require("src.render.depth_queue")
local LevelPreview = require("src.render.level_preview")
local Camera = require("src.render.game_camera")
local ItemCycle = require("src.platform.item_cycle")
local ClassicSounds = require("src.audio.classic_sounds")
local Shop = require("src.platform.shop")
local Shopkeeper = require("src.platform.enemies.shopkeeper")
local Spikes = require("src.platform.traps.spikes")
local Exit = require("src.platform.structures.exit")
local Kali = require("src.platform.kali")
local TerrainDestruction = require("src.platform.terrain_destruction")
local ItemContents = require("src.platform.item_contents")

local Simulation = require("src.platform.object_simulation")

local FullLevelPlaytest = {}
FullLevelPlaytest.__index = FullLevelPlaytest

local STEP = 1 / Player.TICK_RATE
local HEADER_HEIGHT = 64
local FOOTER_HEIGHT = 40

local MINES_DEPTHS = 4


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
        screenName = "full_level_playtest",
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
        mapPreview = false,
        showRoomPath = false,
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
    self.renderer = self.renderer or self.app.renderer
    self.renderer:loadAssets()
    Enemy.loadAssets()
    self.hitSound = self.hitSound or ClassicSounds.load("hit")
    self.throwSound = self.throwSound or ClassicSounds.load("throw")
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
            if enemy.kind == "damsel" and enemy.held then
                enemy.held = false
                if self.heldNpc == enemy then self.heldNpc = nil end
            end
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
    seed = seed or self.seed
    if self.run then
        if self.heldItem then self:captureHeldItem() end
        self:captureHeldNpc()
    end
    self.seed = seed
    self.run = self.run or RunState.new(seed)
    self.level = MinesGenerator.generate(seed, { levelNumber = self.levelNumber,
        run = self.run, forceDark = self.forceDarkLevels })
    self.level.selectedSubtype = MinesLevelSelection.choices[self.subtypeIndex].key
    if self.app.playtestLog then
        self.app.playtestLog:generatedLevel(self.screenName, self.level, self.levelNumber)
    end
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
    self.app.controls:clearJumpEdges()
    self.itemQueued, self.itemHeld = false, false
    self.cycleItemKind = nil
    self.world = GeneratedWorld.fromLevel(self.level)
    local spawnX, spawnY = GeneratedWorld.spawnPoint(self.level)
    self.player = Player.new(spawnX, spawnY)
    self.player.playtestLog = self.app.playtestLog
    self.run:applyToPlayer(self.player)
    self.player.state = Player.STATES.standing
    self.climbSoundTick = 0
    self.climbSoundToggle = false
    self.player.spriteName = "sStandLeft"
    local soundVolume = self.app.controls.settings.soundVol
    self.sounds.settings = self.app.controls.settings
    if self.hitSound then ClassicSounds.configure(self.hitSound, soundVolume) end
    if self.throwSound then ClassicSounds.configure(self.throwSound, soundVolume) end
    self.player:loadAssets(soundVolume)
    self.tools = ToolSystem.new(self.world, Player.TICK_RATE)
    self.tools:loadAssets(soundVolume)
    self.traps = TrapSystem.new(self.world, self.level, self.renderer)
    self.traps:loadAssets(soundVolume)
    self.world.game, self.tools.game, self.traps.game = self, self, self
    self.tools.onExplosion = function(_, x, y, radius)
        self.traps:explode(x, y, radius)
    end

    self.enemies = {}
    self.items = {}
    self.collectibles = {}
    self.effects = Effects.new(self.seed)
    self.effects.sounds = self.sounds
    self.tools.effects.sounds = self.sounds
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
            entity.contentKind = entity.kind == "hidden_sapphire" and "sapphire_big"
                or entity.kind == "hidden_emerald" and "emerald_big"
                or entity.kind == "hidden_ruby" and "ruby_big"
            if not entity.contentKind then
                entity.contentKind, entity.contentX, entity.contentY = ItemContents.underground(self.effects.random)
            end
            self.hiddenEntities[#self.hiddenEntities + 1] = entity
            self.dynamicEntities[entity] = true
        elseif TrapSystem.isTrap(entity.kind) then
            self.dynamicEntities[entity] = true
        elseif entity.kind == "fake_bones" then
            self.fakeBones[#self.fakeBones + 1] = FakeBones.new(entity)
            self.dynamicEntities[entity] = true
        elseif entity.kind == "spikes" then
            self.spikeEntities[#self.spikeEntities + 1] = entity
        elseif EntityBody.create(self, entity, { placed = true, seed = self.seed+index*97 }) then
            self.dynamicEntities[entity] = true
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
    self.shakeTicks, self.shakeToggle, self.viewBorderY = 0, false, 96
    self.viewCount = 0
    if self.run.kaliPunish >= 2 then Kali.attachBall(self) end

    self.accumulator = 0
    self.cameraX = clamp(spawnX - 160, 0, self.world.width * 16)
    self.cameraY = clamp(spawnY - 120, 0, self.world.height * 16)
    self.deathTimer = 0
    self.exitReady = false
    self.exiting, self.completed, self.rescues = nil, false, 0
    self.actionHeld = false
    self.payHeld, self.payQueued = false, false
    self.weaponCooldown = 0
    self.levelTime = 0
    self.ghostSpawned, self.ghostWarningSent = false, false
    self.run.messages = {}
    self.entryMessageTimer, self.darkEntryAnnounced = 10, false
    if self.app.playtestLog then self.app.playtestLog:level(self.screenName, self) end
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

function FullLevelPlaytest:getInput(consumeJumpEdges)
    return self.app.controls:playerInput(consumeJumpEdges)
end

FullLevelPlaytest.isNearExit = Exit.isNear

function FullLevelPlaytest:finishMines()
    self.completed = true
end

function FullLevelPlaytest:advanceLevel()
    Exit.prepare(self)
    self.exiting = nil
    self.player.health = self.player.health + (self.rescues or 0)
    self.player.maxHealth = math.max(self.player.maxHealth, self.player.health)
    self.rescues = 0
    self.run:capturePlayer(self.player)
    if self.levelNumber >= MINES_DEPTHS then
        self:finishMines()
        return
    end
    self.run:capturePlayer(self.player)
    self.run:finishLevel()
    self.levelNumber = self.levelNumber + 1
    self.subtypeIndex = 1
    self:generateLevel()
end

FullLevelPlaytest.checkSpikes = Spikes.check

function FullLevelPlaytest:combatActors()
    local actors = {}
    for _, enemy in ipairs(self.enemies) do actors[#actors+1] = enemy end
    for _, treasure in ipairs(self.collectibles) do
        if treasure.hp then actors[#actors+1] = treasure end
    end
    return actors
end

function FullLevelPlaytest:checkWhip()
    local left = self.player:getWhipHitbox()
    if not left then return end
    for _, enemy in ipairs(self:combatActors()) do
        if Simulation.whipContact(self.player, enemy) then
            local hit
            if enemy.kind == "shopkeeper" then hit = enemy:damage(0, self.player.x, { kind = "whip" })
            elseif enemy.spec and enemy.spec.melee then hit = enemy.spec.melee(enemy, self, 0)
            else hit = enemy:damage(1, self.player.x, { kind = "whip", phase = self.player:getWhipPhase() }) end
            if hit and enemy.kind ~= "damsel" and not (enemy.spec and enemy.spec.bloodless) then
                self.effects:blood(enemy.x, enemy.y-8, 1)
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
    local rewards = item:open(self.run, self.effects.random)
    if not rewards then return false end
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
    if effect == "jar" and (reward.kind == "snake" or reward.kind == "spider") then
        -- oJar creates spiders at x-8/y-8. Snakes use the same origin,
        -- shifted eight pixels away from a side impact. Convert both from
        -- GameMaker's top-left to our bottom-center coordinates.
        local enemyX = x
        if reward.kind == "snake" then
            enemyX = x + (item.impactSide == "left" and 8
                or item.impactSide == "right" and -8 or 0)
        end
        local enemyY = y + 8
        local enemy = self:spawnEntity(reward.kind, enemyX, enemyY)
        -- The released enemy's collision mask is larger than the pot's.
        -- Keep its source position when clear; otherwise place the whole
        -- body in nearby free space, preferring the impact's outward normal.
        if self.world:collidesSolid(enemy, enemy.x, enemy.y) then
            local normal = item.impactSide == "left" and { 1, 0 }
                or item.impactSide == "right" and { -1, 0 }
                or item.impactSide == "ceiling" and { 0, 1 }
                or { 0, -1 }
            local directions = { normal, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 },
                { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
            local placed = false
            for distance = 1, 16 do
                for _, direction in ipairs(directions) do
                    local nextX = enemyX + direction[1] * distance
                    local nextY = enemyY + direction[2] * distance
                    if not self.world:collidesSolid(enemy, nextX, nextY) then
                        enemy.x, enemy.y = nextX, nextY
                        enemy.spawnX, enemy.spawnY = nextX, nextY
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
    if item.kind ~= "chest" then item.x, item.y = -1000, -1000 end
    return true
end

function FullLevelPlaytest:checkCollectibles()
    if self.player:isDead() or self.player:isStunned() then return end
    for _, item in ipairs(self.items) do
        local pickup = item.definition.pickup
        if item.alive and not item.held and pickup and pickup.resource
            and not Shop.forSale(item) and not self.world:solidAtPoint(item.x, item.y)
            and item:overlapsRectangle(self.player.x-8, self.player.y-8, self.player.x+8, self.player.y+8) then
            Item.collect(item.kind, self.run, self.player, self)
            item.alive, item.visible, item.opened = false, false, true
            self.sounds:play("pickup")
        end
    end
    for _, collectible in ipairs(self.collectibles) do
        if collectible.alive and collectible.pickupDelay == 0 then
            local entity = collectible.entity
            local x, y = entity.x * 16, entity.y * 16
            if collectible:overlapsRectangle(self.player.x-8, self.player.y-8,
                self.player.x+8, self.player.y+8) then
                if not (entity.properties and entity.properties.forSale) then
                    Item.collect(entity.kind, self.run, self.player, self)
                    if collectible.definition.onCollected then collectible.definition.onCollected(collectible, self) end
                    collectible.alive = false
                    self.sounds:play(Item.pickupSound(entity.kind))
                end
            end
        end
    end
end

function FullLevelPlaytest:revealHiddenContents()
    for _, entity in ipairs(self.hiddenEntities) do
        if not entity.revealed and not self.world:solidAtPoint(entity.x * 16, entity.y * 16) then
            entity.revealed = true
            local kind = entity.contentKind or entity.kind == "hidden_sapphire" and "sapphire_big"
                or entity.kind == "hidden_emerald" and "emerald_big"
                or entity.kind == "hidden_ruby" and "ruby_big"
            local dx, dy = entity.contentX or 0, entity.contentY or 0
            if not kind then kind, dx, dy = ItemContents.underground(self.effects.random) end
            self:spawnEntity(kind, entity.x*16+8+dx, entity.y*16+8+dy)

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
        if item.alive and not item.held and (not item.opened or item.kind == "chest")
            and item:overlapsRectangle(left, top, right, bottom)
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
    return EntityBody.create(self, entity, { x = x, y = y })
end

function FullLevelPlaytest:openNearbyContainer()
    for _, item in ipairs(self.items) do
        if item.definition.unlockWith and self.heldItem
            and self.heldItem.definition.unlocks == item.kind
            and not item.held and not item.opened
            and require("src.platform.entity_collision").touching(self.heldItem, item, self.player) then
            self.heldItem.held = false
            self.heldItem.opened, self.heldItem.alive = true, false
            self.heldItem, self.cycleItemKind = nil, nil
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
        ItemCycle.restore(self)
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

function FullLevelPlaytest:resolveItemPlayerContact(item)
    local player = self.player
    if item.kind == "arrow" then
        return require("src.platform.items.arrow").hitPlayer(item, player, self)
    end
    if item.held or item.opened or item.safeTimer > 0 or player:isDead()
        or player:isStunned() then return end
    local halfWidth = player:getCollisionHalfWidth()
    local top, bottom = player:getVerticalBounds()
    if not item:overlapsRectangle(player.x - halfWidth, player.y + top,
        player.x + halfWidth, player.y + bottom) then return end
    if item.kind ~= "rock" or math.abs(item.vx) <= 4 then return end
    local damage = 2
    if not player:hurt(item.x, damage, item.kind, 20) then return end
    self.effects:blood(player.x, player.y, 3)
    self.sounds:play("hurt")
    self:dropHeldItemFromHurt()
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

function FullLevelPlaytest:updateTraps()
    local targets = {}
    for _, group in ipairs({ self.collectibles, self.tools.bombs, self.tools.ropes,
        self.projectiles.projectiles }) do
        for _, target in ipairs(group) do targets[#targets+1] = target end
    end
    self.traps:update(self.player, self:combatActors(), self.items, targets)
end

function FullLevelPlaytest:simulationStepBody(input)
    local viewport = self:getViewport()
    self:updateCamera(viewport)
    Camera.shake(self)
    self.world.activeView = { x = self.cameraX, y = self.cameraY,
        width = viewport.logicalWidth, height = viewport.logicalHeight }
    local payPressed = self.payQueued or (input.pay and not self.payHeld)
    self.payQueued, self.payHeld = false, input.pay or false
    local itemPressed = self.itemQueued or (input.item and not self.itemHeld)
    self.itemQueued, self.itemHeld = false, input.item or false
    if self.completed then return end
    self.run:update()
    if self.exiting then
        self.exiting = self.exiting+1
        self.world.time = self.world.time+1
        for _, enemy in ipairs(self.enemies) do enemy:step(self.world, self.player, self) end
        Simulation.stepItems(self)
        Simulation.stepCollectibles(self, self.player)
        self.projectiles:update(self:combatActors(), self.player, self.items)
        self.tools:update(self.player, self:combatActors(), self.items)
        self:updateTraps()
        TerrainDestruction.update(self)
        self.effects:update(self.world)
        if self.exiting >= 32 then self:advanceLevel() end
        return
    end
    if self.player:isDead() then
        for _, enemy in ipairs(self.enemies) do enemy:step(self.world, self.player, self) end
        Simulation.stepItems(self)
        self.effects:burning(self.player)
        self.effects:update(self.world)
        self.tools:update(self.player, self:combatActors(), self.items)
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
    local containerToOpen = Simulation.prepareAction(self, input, actionPressed, true)
    if itemPressed then input.suppressWhip = true end
    local previousY = self.player.y
    local previousHealth = self.player.health
    local previousState = self.player.state
    self.player:step(self.world, input)
    Camera.follow(self, viewport)
    Camera.look(self, input)
    if itemPressed then ItemCycle.select(self); actionPressed = false end
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
    for _, entity in ipairs(self.level.entities) do
        if entity.kind == "bones" and not entity.destroyed then
            require("src.platform.structures.bones").update(entity, self.world)
        end
    end
    DynamicTerrain.update(self.world)
    self.tools:update(self.player, self:combatActors(), self.items)
    TerrainDestruction.update(self)
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
            Spikes.checkActor(self, enemy)
            enemy:step(self.world, self.player, self)
            if enemy.kind ~= "spider" and enemy.kind ~= "giant_spider" and enemy.kind ~= "ghost"
                and not enemy.held and enemy.alive
                and self.world:webRect(enemy:getBounds()) then
                enemy.vx, enemy.vy = 0, 0
                if enemy.kind == "shopkeeper" then Shopkeeper.provoke(enemy) end
            end
            if enemy.kind == "bat" and oldState == "HANG" and enemy.state ~= oldState then
                self.sounds:play("bat")
            elseif enemy.kind == "giant_spider" and oldState == "hang"
                and enemy.state ~= oldState then
                self.sounds:play("giant_spider")
            elseif enemy.kind == "giant_spider" and oldVy >= 0 and enemy.vy < -1
                and enemy.state == "bounce" then
                self.sounds:play("spider_jump")
            end
            local contact = enemy:resolvePlayerContact(self.player, previousY, self)
            if contact == "throw" then self:dropHeldItemFromHurt() end
            if enemy.kind == "damsel" then require("src.platform.enemies.damsel").checkExit(enemy, self) end
        end
        if not enemy.alive and not enemy.deathCounted and not enemy.rescued then
            enemy.deathCounted = true
            if enemy.kind == "caveman" then self.sounds:play("caveman_die") end
            if enemy.countsAsKill ~= false then self.run.kills = self.run.kills + 1 end
            if self.recordKill then self:recordKill(enemy.kind) end
            local blood = enemy.spec.deathBlood or 0
            if blood > 0 and not enemy.blastParticlesEmitted then self.effects:blood(enemy.x, enemy.spec.deathY and enemy.spec.deathY(enemy) or enemy.y-8, blood) end
            if enemy.spec.onDeath then enemy.spec.onDeath(enemy, self) end
            if enemy.kind == "shopkeeper" and not enemy.sacrificed then
                Shopkeeper.die(enemy, self)
            end
        end
    end

    self.projectiles:update(self:combatActors(), self.player, self.items)

    if self.player.health < previousHealth then
        self.sounds:play("hurt")
        self:dropHeldItemFromHurt()
    end
    Simulation.stepItems(self, function(item) self:resolveItemPlayerContact(item) end)
    Kali.updateChains(self)
    ItemActions.recoverArrows(self)
    for _, collectible in ipairs(self.collectibles) do
        collectible:update(self.world, self.player)
        if collectible.alive and collectible.definition.ghostConvertible then
            for _, ghost in ipairs(self.enemies) do
                if ghost.kind == "ghost" and ghost.alive
                    and ghost:overlapsRectangle(collectible.x-4, collectible.y-4, collectible.x+4, collectible.y+4) then
                    collectible.alive = false
                    self:spawnEntity("diamond", collectible.x, collectible.y)
                    break
                end
            end
        end
    end
    -- oArrowTrapTest collision events observe bodies after their Step events.
    self:updateTraps()
    self.effects:burning(self.player)
    for _, enemy in ipairs(self.enemies) do self.effects:burning(enemy) end
    self.effects:update(self.world)
    self:checkCollectibles()
    self.effects:collectBlood(self.player, self.run)
    self.tools.effects:collectBlood(self.player, self.run)
    self.run:capturePlayer(self.player)
    self.run.time = self.run.time + 1 / Player.TICK_RATE
    self.levelTime = self.levelTime + 1 / Player.TICK_RATE
    if self.entryMessageTimer then
        self.entryMessageTimer = self.entryMessageTimer - 1
        if self.entryMessageTimer == 0 then
            local text = self.level.hasSnakePit and "I HEAR SNAKES... I HATE SNAKES!"
                or self.level.hasAltar and "I CAN HEAR PRAYERS TO KALI!"
            if self.level.dark and not self.darkEntryAnnounced then
                self.darkEntryAnnounced = true
                self.entryMessageTimer = 210
                text = "I CAN'T SEE A THING!\nI'D BETTER USE THESE FLARES!"
            else self.entryMessageTimer = nil end
            if text then self.run:addMessage(text, 200) end
        end
    end
    if self.levelNumber > 1 and self.levelTime > 120 and not self.ghostWarningSent then
        self.ghostWarningSent = true
        self.run:addMessage("A CHILL RUNS UP YOUR SPINE...\nLET'S GET OUT OF HERE!", 200)
    end
    if self.levelNumber > 1 and self.levelTime > 150 and not self.ghostSpawned then
        self.ghostSpawned = true
        local x = self.cameraX + (self.player.x > self.world.width*8 and viewport.logicalWidth+8 or -32)
        self:spawnEntity("ghost", x+8, self.cameraY+math.floor(viewport.logicalHeight/2)+16)
        self.sounds:play("ghost")
    end
    if self.player:isDead() then self.deathTimer = 75 end
    if self.player.y > self.world.height * self.world.tileSize + 32 then
        self:fallOutOfLevel()
        return
    end
    Exit.contact(self)
    self.exitReady = self:isNearExit()
    if input.up then Exit.begin(self) end
end

function FullLevelPlaytest:fallOutOfLevel()
    self:generateSelectedLevel(self.seed, self.subtypeIndex ~= 1)
end

function FullLevelPlaytest:simulationStep()
    local input = self:getInput(true)
    local log = self.app.playtestLog
    local before = log and log.capture(self)
    if log then log:tickStart(self.screenName, input, before) end
    self:simulationStepBody(input)
    if log then log:tick(self.screenName, input, before, self) end
end

function FullLevelPlaytest:update(dt)
    if self.mapPreview then return end
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
    if self.screenName == "full_level_playtest" and key == "tab" then
        self.mapPreview = not self.mapPreview
        self.accumulator = 0
        controls:clearJumpEdges()
        return
    elseif self.screenName == "full_level_playtest" and key == "f2" then
        self.showRoomPath = not self.showRoomPath
        return
    end
    if self.mapPreview and key ~= "r" and key ~= "n" and key ~= "-"
        and key ~= "=" and key ~= "[" and key ~= "]" and key ~= "b" then return end
    if (self.exiting or self.completed) and key ~= "r" and key ~= "n" then return end
    if controls:matches("pay", key) then
        self.payQueued = true
    elseif controls:matches("item", key) then
        self.itemQueued = true
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
        Exit.begin(self)
    elseif key == "r" then
        if self.completed then self.levelNumber, self.subtypeIndex = 1, 1 end
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
    Camera.follow(self, viewport)
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
                self.renderer:drawEntity(entity, self.world.time)
            end
        end,
    })
    for _, entity in ipairs(self.hiddenEntities) do
        local current = entity
        local isItem = Item.isCarryable(current.contentKind)
        if not current.revealed and (self.player.equipment.spectacles
            or not isItem and self.player.equipment.udjat_eye) then
            queue:add(isItem and 51 or 0, function()
                self.renderer:drawEntity({ kind = current.contentKind,
                    x = current.x+0.5+(current.contentX or 0)/16,
                    y = current.y+0.5+(current.contentY or 0)/16, properties = {} })
            end)
        end
    end
    for _, bones in ipairs(self.fakeBones) do
        local current = bones
        queue:add(Depth.entity("fake_bones"), function() current:draw(self.renderer) end)
    end
    for _, item in ipairs(self.items) do
        if not item.held and (not item.opened or item.kind == "chest")
            and item.visible ~= false then
            local current = item
            queue:add(Depth.item(current, self.player), function()
                self.renderer:drawItem(current)
            end)
        end
    end
    for _, collectible in ipairs(self.collectibles) do
        if collectible.alive then
            local current = collectible
            queue:add(Depth.treasure(current, self.player), function()
                self.renderer:drawEntity(current.entity)
            end)
        end
    end
    DynamicTerrain.submit(queue, self.world, self.renderer)
    for _, enemy in ipairs(self.enemies) do
        if enemy.alive or enemy.corpse then
            local current = enemy
            queue:add(current.held and Depth.heldItem(self.player) or Depth.entity(current.kind, current.state), function()
                current:draw(self.renderer)
            end)
        end
    end
    if self.projectiles then self.projectiles:submit(queue) end
    if self.traps then self.traps:submit(queue) end
    if self.tools then self.tools:submit(queue, self.player) end
    Kali.submit(self, queue)

    if self.player.visible ~= false and not (self.player.invincibleTimer > 0 and math.floor(self.player.invincibleTimer / 2) % 2 == 0) then
        queue:add(Depth.entity("player", self.player.state),
            function()
                if self.exiting then Exit.drawPlayer(self) else self.player:drawBody() end
            end)
        if self.player:getWhipPhase() then
            queue:add(Depth.EFFECT, function() self.player:drawWhip() end)
        end
    end
    if self.heldItem and self.heldItem.kind ~= "bomb" and self.heldItem.kind ~= "rope" then
        queue:add(Depth.heldItem(self.player), function()
            self.renderer:drawItem(self.heldItem, self.player.facing)
        end)
    end
    if self.meleeItem then
        queue:add(Depth.EFFECT, function()
            self.renderer:drawMeleeSwing(self.player, self.meleeItem)
        end)
    end
    if self.effects then self.effects:submit(queue) end
    queue:draw()
    require("src.platform.lighting").draw(self, viewport)
    if self.showRoomPath then LevelPreview.drawRoomPath(self.level, self.app.fonts.small) end
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
    if self.player.visible == false then return end
    love.graphics.setScissor(viewport.x, viewport.y, viewport.width, viewport.height)
    love.graphics.push()
    love.graphics.translate(viewport.x, viewport.y)
    love.graphics.scale(viewport.scale, viewport.scale)
    self.hud:draw({
        health = self.player.health,
        bombs = self.run.bombs,
        ropes = self.run.ropes,
        money = self.run.money,
        heldItem = self.cycleItemKind and { kind = self.cycleItemKind } or self.heldItem or self.heldNpc,
        equipment = self.run.equipment,
        blood = self.run.blood, arrows = self.run.arrows, pendingMoney = self.run.pendingMoney,
        messageTimer = self.run:currentMessage() and self.run:currentMessage().timer or 0,
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

function FullLevelPlaytest:drawGameplayMessages(viewport)
    OriginalMessages.draw(self.run, viewport)
end

function FullLevelPlaytest:levelLabel()
    return "1-" .. self.levelNumber
end

function FullLevelPlaytest:draw()
    local width, height = love.graphics.getDimensions()
    local viewport = self:getViewport()
    love.graphics.clear(COLORS.background)
    if self.mapPreview then
        LevelPreview.draw(self.renderer, self.level, viewport, self.showRoomPath, self.app.fonts.small)
    else
        self:drawWorld(viewport)
        self:drawPlayerHUD(viewport)
        self:drawGameplayMessages(viewport)
    end

    love.graphics.setColor(COLORS.panel)
    love.graphics.rectangle("fill", 0, 0, width, HEADER_HEIGHT)
    love.graphics.rectangle("fill", 0, height - FOOTER_HEIGHT, width, FOOTER_HEIGHT)
    love.graphics.setColor(COLORS.border)
    love.graphics.line(0, HEADER_HEIGHT - 1, width, HEADER_HEIGHT - 1)
    love.graphics.line(0, height - FOOTER_HEIGHT, width, height - FOOTER_HEIGHT)

    love.graphics.setFont(self.app.fonts.menu)
    love.graphics.setColor(COLORS.text)
    love.graphics.print(self.mapPreview and "LEVEL MAP (PAUSED)" or "FULL LEVEL PLAYTEST", 18, 10)
    love.graphics.setFont(self.app.fonts.small)
    love.graphics.setColor(COLORS.muted)
    love.graphics.print("MINES  " .. self:levelLabel()
        .. "    " .. string.upper(MinesLevelSelection.choices[self.subtypeIndex].label)
        .. "    SEED " .. self.seed, 20, 42)

    if self.selectionError then
        love.graphics.setColor(COLORS.danger)
        love.graphics.printf(self.selectionError, width / 2, 42, width / 2 - 20, "right")
    end

    love.graphics.setColor(COLORS.muted)
    local controls = self.app.controls
    love.graphics.printf(
        string.format("%s/%s MOVE   %s RUN   %s JUMP   %s ACTION/PICK UP   %s BOMB   %s ROPE   %s PAY   %s/%s CLIMB\n"
            .. "R RESET   N NEXT SEED   -/= DEPTH   [/] TYPE   B COLLIDERS   TAB MAP/PLAY   F2 ROOM PATH   ESC BACK",
            controls:label("left"), controls:label("right"), controls:label("run"),
            controls:label("jump"), controls:label("attack"), controls:label("bomb"),
            controls:label("rope"), controls:label("pay"), controls:label("up"), controls:label("down")),
        12, height - 37, width - 24, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return FullLevelPlaytest
