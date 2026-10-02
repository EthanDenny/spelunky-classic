-- oEnemy/oDamsel sacrifices and scrGetFavorMsg. Object-specific values and
-- altar/head/ball behavior remain in their owning object modules.
local Altar = require("src.platform.structures.sacrifice_altar")
local Head = require("src.platform.structures.kali_head")
local Chain = require("src.platform.environment.chain")

local Kali = {}
local gifts = { "cape", "gloves", "spectacles", "mitt", "spring_shoes",
    "spike_shoes", "paste", "compass" }

local function equipmentGift(game)
    local equipment = game.player.equipment
    local first = game.effects.random:random(1, #gifts)
    for offset = 0, #gifts - 1 do
        local kind = gifts[(first + offset - 1) % #gifts + 1]
        if not equipment[kind] and not (kind == "cape" and equipment.jetpack) then return kind end
    end
    return not equipment.jetpack and "jetpack" or "bomb_box"
end

local function vitality(game)
    game.run.kaliGift = game.run.kaliGift + 1
    game.player.health = game.player.health + game.effects.random:random(4, 8)
    game.player.maxHealth = math.max(game.player.maxHealth, game.player.health)
    return "YOU FEEL INVIGORATED!"
end

local function favorMessage(game, body, altar)
    local run, favor = game.run, game.run.favor
    if favor <= -8 then return "SHE SEEMS VERY ANGRY WITH YOU!" end
    if favor < 0 then return "SHE SEEMS ANGRY WITH YOU." end
    if favor == 0 then return "SHE HAS FORGIVEN YOU!" end
    if favor >= 32 then
        if run.kaliGift >= 3 then
            if favor >= 32 + (run.kaliGift - 2) * 16 then return vitality(game) end
            return "SHE SEEMS ECSTATIC WITH YOU!"
        end
        if run.bombs >= 80 then return vitality(game) end
        run.kaliGift, run.bombs = 3, 99
        return "YOUR SATCHEL FEELS VERY FULL NOW!"
    end
    local gift
    if favor >= 16 then
        if run.kaliGift >= 2 then return "SHE SEEMS VERY HAPPY WITH YOU!" end
        run.kaliGift, gift = 2, "kapala"
    elseif favor >= 8 then
        if run.kaliGift >= 1 then return "SHE SEEMS HAPPY WITH YOU." end
        run.kaliGift, gift = 1, equipmentGift(game)
    else return "SHE SEEMS PLEASED WITH YOU." end
    local x, y = (altar.x + 1) * 16, body.y - body.spec.sacrifice.rewardOffset
    if gift ~= "kapala" then
        game.effects:add("poof", x, y, -1)
        game.effects:add("poof", x, y, 1)
    end
    game:spawnEntity(gift, x, y, { cost = 0, forSale = false })
    return "SHE BESTOWS A GIFT UPON YOU!"
end

local function sacrifice(game, body, altar)
    local spec = body.spec.sacrifice
    local message = body.kind == "damsel" and "KALI ACCEPTS YOUR SACRIFICE!"
        or "KALI ACCEPTS THE SACRIFICE!"
    if game.run.favor <= -8 then message = "KALI DEVOURS THE SACRIFICE!"
    else game.run.favor = game.run.favor + (body.corpse and spec.deadFavor or spec.favor) end
    local response = favorMessage(game, body, altar)
    game.run.messages = {}
    game.run:addMessage(message .. "\n" .. response, 200)
    game.shakeTicks = 10
    game.effects:add("flame", body.x, body.y - 8)
    game.effects:blood(body.x, body.y - 8, 3)
    game.sounds:play("small_explode")
    body.alive, body.corpse, body.sacrificed = false, false, true
    body.deathCounted = true
    body.entity.destroyed = true
end

function Kali.attachBall(game)
    -- oLevel recreates the punishment whenever kaliPunish >= 2, including
    -- when the player carried some other item through the exit.
    local ball
    for _, item in ipairs(game.items) do
        if item.kind == "ball" and item.alive then ball = item break end
    end
    ball = ball or game:spawnEntity("ball", game.player.x, game.player.y)
    game.player.ball = ball
    game.chains = {}
    for link = 1, 4 do game.chains[link] = Chain.new(ball, game.player, link) end
end

local function armHeads(game)
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "kali_head" then Head.arm(entity) end
    end
end

local function punish(game)
    local run = game.run
    run.favor = run.favor - 16
    game.shakeTicks = 10
    run.messages = {}
    run:addMessage("YOU DARE DEFILE MY ALTAR?\nI WILL PUNISH YOU!", 200)
    if run.kaliPunish == 0 then armHeads(game)
    elseif run.kaliPunish == 1 then Kali.attachBall(game)
    elseif game.level.dark and game.ghostSpawned then armHeads(game)
    else
        game.level.dark = true
        if not game.ghostSpawned then
            local width = game.cameraWidth or 320
            local height = game.cameraHeight or 240
            local x = (game.cameraX or 0) + (game.player.x > game.world.width * 8 and width + 8 or -32)
            -- Convert oGhost's top-left sprite anchor to the live mask's
            -- bottom-center anchor, as Creature.new does for generated ghosts.
            game:spawnEntity("ghost", x + 8, (game.cameraY or 0) + math.floor(height / 2) + 16)
            game.ghostSpawned = true
        end
    end
    run.kaliPunish = run.kaliPunish + 1
    -- Right inherits Left in Classic. Destroy every pair without recursively
    -- charging a second penalty, including pairs broken by the same blast.
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "sacrifice_altar" then Altar.destroy(game, entity) end
    end
end

function Kali.update(game)
    if (game.shakeTicks or 0) > 0 then game.shakeTicks = game.shakeTicks - 1 end
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "kali_head" then Head.update(game, entity) end
    end
    for _, entity in ipairs(game.level.entities) do
        if entity.kind == "sacrifice_altar" and not entity.defileHandled then
            Altar.update(game, entity)
            if entity.destroyed then punish(game) break end
        end
    end
    for _, body in ipairs(game.enemies) do
        local spec = body.spec and body.spec.sacrifice
        if spec and (body.alive or body.corpse) then
            if body.held or body.vx ~= 0 or body.vy ~= 0 then body.sacrificeTicks = 20
            elseif body.corpse or body.state == "stunned" or body.stunned > 0 then
                local altar = Altar.at(game, body.x, body.y)
                if altar then
                    body.sacrificeTicks = body.sacrificeTicks or 20
                    if body.sacrificeTicks > 0 then body.sacrificeTicks = body.sacrificeTicks - 1
                    else sacrifice(game, body, altar) end
                end
            end
        end
    end
end

function Kali.updateChains(game)
    for _, chain in ipairs(game.chains or {}) do Chain.update(chain) end
end

function Kali.submit(game, queue)
    for _, chain in ipairs(game.chains or {}) do
        if chain.alive then
            local current = chain
            queue:add(Chain.depth, function() Chain.draw(current) end)
        end
    end
end

return Kali
