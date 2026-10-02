-- oShopkeeper's state machine. Coordinates here use the clone's center/bottom
-- anchor; the source's sprite origin is eight pixels left and sixteen above it.
local Shopkeeper = {
    creatureConfig = { hp = 20, npc = true },
    creatureHalfWidth = 6,
    canBeHeld = true,
    recoveryState = "attack",
    sacrifice = { favor = 12, deadFavor = 6, rewardOffset = 24 },
}
local Physics = require("src.platform.physical_body")
local Shop = require("src.platform.shop")
local sprites

local function setState(body, state, vx, vy, stun)
    body.state = state
    body.stunned = state == "stunned" and (stun or body.stunned) or 0
    body.angry = state ~= "idle" and state ~= "follow"
    body.vx, body.vy = vx or body.vx, vy or body.vy
    if state == "stunned" then body.counter, body.bounced = body.stunned, false end
end

function Shopkeeper.provoke(body)
    setState(body, "attack")
end

function Shopkeeper.initialize(body, seed)
    body.heavy = true
    body.physicsOriginY = -8
    body.definition = { hold = { standing = 4, ducking = 6 } }
    body.state = body.entity.properties and body.entity.properties.exitGuard and "patrol" or "idle"
    body.hasGun = true
    body.firing = 0
    body.turnTimer = 0
    body.counter = 0
    body.whipCooldown = 0
    body.angered = false
    body.random = love.math.newRandomGenerator(seed or 1)
end

function Shopkeeper.onThrown(body)
    if body.corpse then body.state = "dead"
    else setState(body, "stunned", nil, nil, body.stunned) end
end

function Shopkeeper.heldStep(body, _, _, game)
    if body.alive then Shopkeeper.dropGun(body, game) end
end

function Shopkeeper.dropGun(body, game)
    if not body.hasGun or not game or not game.spawnEntity then return end
    local gun = game:spawnEntity("shotgun", body.x, body.y - 8)
    gun.vy = body.random:random(4, 6)
    gun.vx = (body.vx < 0 and -1 or 1) * body.random:random(4, 6)
    body.hasGun = false
end

function Shopkeeper.die(body, game)
    Shopkeeper.dropGun(body, game)
    for _ = 1, body.random:random(1, 4) do
        local gold = game:spawnEntity("gold_nugget", body.x, body.y - 8)
        gold.vy = -1
        gold.vx = body.random:random(1, 3) - body.random:random(1, 3)
    end
    game.run.murderer = true
end

function Shopkeeper.damage(body, amount, sourceX, hit)
    local kind = hit and hit.kind
    if kind == "whip" and body.whipCooldown > 0 then return false end
    if kind == "item" and hit.fragile then amount = 0 end
    body.hp = body.hp - (amount or 1)
    local vx = sourceX and (sourceX < body.x and 1 or -1) or body.vx
    if kind == "whip" then
        vx = sourceX < body.x - 8 and 1 or -1
        body.whipCooldown = 10
        setState(body, "attack", vx, -2)
    elseif kind == "item" and not hit.fragile then
        setState(body, "attack", hit.vx, -6)
    else
        setState(body, "stunned", hit and hit.vx or vx,
            kind == "bullet" and -4 or -6, kind == "bullet" and 20 or 5)
    end
    if body.hp <= 0 then body.alive = false; setState(body, "dead") end
    return true
end

local function fire(body, game)
    local direction = body.facing
    local system = game.projectiles
    system.flashes[#system.flashes + 1] = {
        x = body.x + direction * 8, y = body.y - 7, direction = direction, age = 0,
    }
    for _ = 1, 6 do
        local vx = direction * body.random:random(6, 8) + body.vx
        vx = direction < 0 and math.min(-6, vx) or math.max(6, vx)
        local x, y = body.x + direction * 4, body.y - 8
        if not game.world:solidAtPoint(x, y) then
            system:spawn("bullet", x, y, vx, body.random:random() - body.random:random(),
                body, { damage = 4, safe = true })
        end
    end
    body.vy = body.vy - 1
    body.vx = body.vx - direction * 3
    body.firing = 30
    if game.sounds then game.sounds:play("shotgun") end
end

local function releaseStock(game)
    for _, group in ipairs({ game.items or {}, game.collectibles or {}, game.enemies or {} }) do
        for _, item in ipairs(group) do
            if Shop.forSale(item) then Shop.release(item) end
        end
    end
end

function Shopkeeper.step(body, world, player, context)
    local game = context and (context.game or context) or {}
    body.lastWorld = world
    if body.whipCooldown > 0 then body.whipCooldown = body.whipCooldown - 1 end
    if body.angry and body.state == "idle" and not (game.run and
        (game.run.shopkeeperAnger > 0 or game.run.murderer)) then setState(body, "attack") end
    Physics.move(world, body, "x", body.vx)
    Physics.move(world, body, "y", body.vy)
    body.vy = math.min(8, body.vy + 0.6)
    local left = Physics.probe(world, body, "x", -1)
    local right = Physics.probe(world, body, "x", 1)
    local floor = Physics.probe(world, body, "y", 1)
    local top = Physics.probe(world, body, "y", -1)
    if floor and body.state ~= "stunned" then body.vy = 0 end
    local dist = Shop.distanceToPlayer(body, player)
    local aligned = math.abs(player.y - (body.y - 8)) < 8
    if (body.state == "walk" or body.state == "patrol") and not player:isDead()
        and ((dist < 64 and player.y - (body.y - 8) < 16) or math.abs(player.x - body.x) < 4) then
        setState(body, "attack")
    end
    if body.state == "idle" then
        if left then body.x = body.x + 1 end
        if right then body.x = body.x - 1 end
        if left and right then setState(body, "attack") end
        body.facing = player.x < body.x and -1 or 1
        if top and body.vy < 0 then body.vy = 0 end
        if game.run and (game.run.shopkeeperAnger > 0 or game.run.murderer) then
            setState(body, "patrol")
        elseif (game.heldItem or game.heldNpc) and Shop.forSale(game.heldItem or game.heldNpc)
            and Shop.sameRoom(player, body) then setState(body, "follow") end
    elseif body.state == "follow" then
        if left or right then body.facing = -body.facing end
        if body.turnTimer > 0 then body.turnTimer = body.turnTimer - 1
        elseif aligned and floor and dist > 16 then
            body.facing = player.x < body.x - 8 and -1 or 1
            body.turnTimer = 10
        end
        body.vx = body.facing * math.min(3, dist / 16 * 1.5)
        if dist < 12 or player.y < body.y - 16 then body.vx = 0 end
        local held = game.heldItem or game.heldNpc
        if not held or not Shop.forSale(held) then setState(body, "idle") end
    elseif body.state == "patrol" then
        if top and body.vy < 0 then body.vy = 0 end
        if floor and body.counter > 0 then body.counter = body.counter - 1 end
        if body.counter < 1 then
            body.facing = body.random:random(0, 1) == 0 and -1 or 1
            setState(body, "walk")
        end
    elseif body.state == "walk" then
        if left or right then body.facing = -body.facing end
        local edgeX = body.x + (body.facing < 0 and -9 or 8)
        if not world:solidAtPoint(edgeX, body.y - 16) then
            setState(body, "patrol")
            body.counter = body.random:random(20, 50)
        end
        body.vx = body.facing * 1.5
        if body.random:random(1, 100) == 1 then
            setState(body, "patrol", 0)
            body.counter = body.random:random(20, 50)
        end
    elseif body.state == "attack" then
        if not body.angered then releaseStock(game); body.angered = true end
        if body.turnTimer > 0 then body.turnTimer = body.turnTimer - 1
        elseif aligned and floor and dist > 16 then
            body.facing = player.x < body.x - 8 and -1 or 1
            body.turnTimer = 20
        end
        if left or right then body.facing = -body.facing end
        body.vx = body.facing * 3
        if body.hasGun then
            if body.firing > 0 then body.firing = body.firing - 1
            elseif math.abs(player.y - (body.y - 8)) < 32 and dist < 96
                and (player.x - body.x) * body.facing > 0 and game.projectiles then fire(body, game) end
        end
        if not (player.y > body.y - 16 and math.abs(player.x - body.x) < 64) then
            local ahead = body.x + (body.facing < 0 and -24 or 24)
            local obstacle = world:solidAtPoint(ahead, body.y - 16)
            local ledge = player.y <= body.y and not world:solidAtPoint(ahead, body.y)
            if floor and not Physics.probe(world, body, "y", -1, 4) and (obstacle or ledge) then
                body.vy = -body.random:random(7, 8)
            end
        end
        if not floor and player.y > body.y - 8 then body.vx = body.facing * 1.5 end
        if player:isDead() then setState(body, "walk") end
        if not body.hasGun then
            for _, gun in ipairs(game.items or {}) do
                if gun.kind == "shotgun" and not gun.opened and gun:overlapsRectangle(body:getBounds()) then
                    gun.opened, gun.held = true, false
                    gun.x, gun.y = -1000, -1000
                    if game.heldItem == gun then game.heldItem = nil end
                    body.hasGun = true
                    break
                end
            end
        end
    elseif body.state == "throw" then
        body.animation = body.animation + 0.5
        if body.animation >= 7 then setState(body, "attack"); body.animation = 0 end
    elseif body.state == "stunned" then
        Shopkeeper.dropGun(body, game)
        -- scrCheckCollisions retains the shorter stunned mask after recovery.
        body.shortMask = true
        if left or right then
            if left and not right then body.x = body.x + 1 elseif right then body.x = body.x - 1 end
            body.vx = -body.vx * 0.5
        end
        if top and not floor then body.y = body.y + 1
        elseif floor then
            if body.vy > 1 then body.vy = -body.vy * 0.5
            elseif math.abs(body.vy) < 1 then body.vy = 0 end
            body.vx = math.abs(body.vx) < 0.1 and 0 or body.vx * 0.3
            body.bounced = true
        end
        if floor or body.held then
            if body.stunned > 0 then body.stunned = body.stunned - 1
            elseif body.hp > 0 then setState(body, "attack") end
        end
    end
    if body.vx > 0 then body.vx = body.vx - 0.1 end
    if body.vx < 0 then body.vx = body.vx + 0.1 end
    if math.abs(body.vx) < 0.5 then body.vx = 0 end
    if body.state ~= "throw" then body.animation = body.animation + (body.state == "attack" and 1 or 0.5) end
end

function Shopkeeper.contact(body, player)
    if body.state == "idle" or body.state == "follow" or body.state == "stunned"
        or body.hp < 1 or player:isDead() or player:isStunned() or math.abs(player.x - body.x) > 8 then return end
    if (player.state == "falling" or player.state == "jumping") and player.y < body.y - 11 then
        local damage = math.ceil(player.fallTimer / 16) * (player.equipment.spike_shoes and 3 or 1)
        player.vy, player.fallTimer = -6 - 0.2 * player.vy, 0
        body:damage(damage, player.x, { kind = "stomp",
            vx = body.vx + (player.x < body.x and 1 or -1) })
        return "stomp"
    end
    if player.invincibleTimer > 0 or body.state == "throw" then return end
    if body.lastWorld and body.lastWorld:solidAtPoint(body.x, body.y - 20) then
        return player:hurt(body.x - 8, 1, "shopkeeper", nil, "enemy_contact") and "hurt" or nil
    end
    setState(body, "throw", 0)
    body.animation = 0
    body.facing = player.x > body.x and 1 or -1
    player.x = body.x - body.facing * 8
    player.y = body.y - 16
    player.vx, player.vy = body.facing * 6, -6
    player.stunTimer, player.deadBounced = 30, false
    player.wallHurt = 1
    player:setState("stunned")
    return "throw"
end

function Shopkeeper.draw(body)
    if not sprites then
        sprites = {}
        for name, count in pairs({ sShopLeft = 1, sShopRunLeft = 6, sShopThrowL = 7,
            sShopStunL = 6, sShopFallL = 1, sShopBounceL = 1, sShopDieLL = 1, sShopDieLR = 1,
            sShopHeldL = 6, sShopDHeldL = 1 }) do
            sprites[name] = {}
            for frame = 0, count - 1 do
                local image = love.graphics.newImage("original-game-reference/source/extracted/spelunky/Sprites/Enemies/Shopkeeper/"
                    .. name .. ".images/image " .. frame .. ".png")
                image:setFilter("nearest", "nearest")
                sprites[name][frame + 1] = image
            end
        end
        local weapons = "original-game-reference/source/extracted/spelunky/Sprites/Items/Weapons/"
        sprites.gunLeft = love.graphics.newImage(weapons .. "sShotgunLeft.images/image 0.png")
        sprites.gunRight = love.graphics.newImage(weapons .. "sShotgunRight.images/image 0.png")
        sprites.gunLeft:setFilter("nearest", "nearest")
        sprites.gunRight:setFilter("nearest", "nearest")
    end
    local name = body.vx == 0 and "sShopLeft" or "sShopRunLeft"
    if body.corpse then name = body.held and "sShopDHeldL" or "sShopDieLL"
    elseif body.held then name = "sShopHeldL"
    elseif body.state == "throw" then name = "sShopThrowL"
    elseif body.state == "stunned" then
        name = body.bounced and (body.vy < 0 and "sShopBounceL" or "sShopFallL")
            or (body.vx < 0 and "sShopDieLL" or "sShopDieLR")
        if body.vy == 0 then name = "sShopStunL" end
    end
    local frames = sprites[name]
    local image = frames[math.floor(body.animation) % #frames + 1]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(body.x), math.floor(body.y - 16), 0,
        body.facing < 0 and 1 or -1, 1, 8, 0)
    if body.hasGun and not body.corpse and not body.held
        and body.state ~= "idle" and body.state ~= "follow" then
        love.graphics.draw(body.facing < 0 and sprites.gunLeft or sprites.gunRight,
            math.floor(body.x + body.facing * 2), math.floor(body.y - 6), 0, 1, 1, 8, 4)
    end
end
Shopkeeper.initializeCreature = Shopkeeper.initialize
Shopkeeper.stepCreature = Shopkeeper.step
Shopkeeper.resolvePlayerContact = Shopkeeper.contact
Shopkeeper.drawCreature = Shopkeeper.draw
function Shopkeeper.creatureVerticalBounds(body)
    return body.shortMask and -10 or -16, 0
end
Shopkeeper.depth = 60

Shopkeeper.deathBlood = 0

return Shopkeeper
