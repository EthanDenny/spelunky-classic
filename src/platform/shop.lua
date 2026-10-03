-- Shop transactions and room-based theft from oPlayer1, oItem, and
-- oShopkeeper. Picking up merchandise and paying are separate actions.
local Shop = {}
local Item = require("src.platform.item")
local Stock = require("src.platform.shop_stock")

local function room(x, y)
    return math.max(0, math.min(3, math.floor((x - 16) / 160))),
        math.max(0, math.min(4, math.floor((y - 16) / 128)))
end

function Shop.sameRoom(a, b)
    local ax, ay = room(a.x, a.y)
    local bx, by = room(b.x, b.y - 16)
    return ax == bx and ay == by
end

function Shop.contains(game, x, y)
    local rx, ry = room(x, y)
    local path = game.level and game.level.roomPath
    local code = path and path[ry + 1] and path[ry + 1][rx + 1]
    return code == 4 or code == 5
end

function Shop.keeper(game, x, y)
    local nearest, distance
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "shopkeeper" and enemy.alive then
            local d = (enemy.x - x) ^ 2 + (enemy.y - 8 - y) ^ 2
            if not distance or d < distance then nearest, distance = enemy, d end
        end
    end
    return nearest
end

function Shop.distanceToPlayer(body, player)
    local left, top, right, bottom = body:getBounds()
    local half = player:getCollisionHalfWidth()
    local pt, pb = player:getVerticalBounds()
    local dx = math.max(0, left - player.x - half, player.x - half - right)
    local dy = math.max(0, top - player.y - pb, player.y + pt - bottom)
    return math.sqrt(dx * dx + dy * dy)
end

function Shop.forSale(body)
    return body.forSale or (body.properties or body.entity and body.entity.properties or {}).forSale or false
end

function Shop.release(body)
    body.forSale = false
    local properties = body.properties or body.entity.properties
    if properties then properties.forSale = false end
end

function Shop.price(game, body)
    if body.kind == "damsel" then return Shop.kissPrice(game) * 3 end
    -- scrGenerateItem's dice-house prize keeps its Create-event base price;
    -- only scrShopItemsGen applies the depth markup to regular stock.
    return Item.price(body.kind or body.entity.kind,
        body.properties.inDiceHouse and 2 or game.level.absoluteLevel)
end

function Shop.kissPrice(game)
    return 10000 + 5000 * ((game.level.absoluteLevel or 1) - 2)
end

local function notice(game, message, timer)
    game.run:addMessage(message, timer or 200)
end

function Shop.anger(game, x, y, reason)
    local keeper = Shop.keeper(game, x, y)
    if not keeper or keeper.angered then return false end
    if game.run.murderer then reason = "YOU'LL PAY FOR YOUR CRIMES!" end
    keeper.spec.provoke(keeper)
    game.run:angerShopkeepers(reason)
    notice(game, reason, 80)
    return true
end

function Shop.claim(game, body)
    local purchased = Shop.forSale(body)
    Shop.release(body)
    local pickup = body.definition and body.definition.pickup
    if pickup and body.definition.consumeOnPickup and body.held then
        Item.collect(body.kind, game.run, game.player, game)
        body.alive, body.held = false, false
        body.opened, body.visible = true, false
        game.heldItem = nil
        game.sounds:play(Item.pickupSound(body.kind))
    elseif purchased and body.held then
        if body.kind == "damsel" then notice(game, "YOU MUST BE IN LOVE!", 120)
        else Item.announce(body.kind, game.run, game) end
    end
end

function Shop.pay(game)
    local player = game.player
    if not player or player:isDead() or player:isStunned()
        or not Shop.contains(game, player.x, player.y) then return false end
    local keeper = Shop.keeper(game, player.x, player.y)
    if not keeper then return false end
    local held = game.heldItem or game.heldNpc
    local failed = false
    if held and Shop.forSale(held) then
        local price = Shop.price(game, held)
        if game.run.money < price then
            held.held = false
            game.heldItem, game.heldNpc = nil, nil
            notice(game, "YOU HAVEN'T GOT ENOUGH MONEY!", 80)
            failed = true
        else
            game.run.money = game.run.money - price
            Shop.claim(game, held)
            local message = game.run:currentMessage()
            if message then message.timer = 80 end
        end
    end
    if game.run.shopkeeperAnger > 0 or game.run.murderer or keeper.angry then return true end
    if keeper.shopType == "Craps" then
        local bet = 1000 + (game.level.absoluteLevel or 1) * 500
        if (player.bet or 0) > 0 then
            notice(game, "ONE BET AT A TIME!\nPLEASE ROLL THE DICE!")
        elseif game.run.money < bet then
            notice(game, "YOU NEED $" .. bet .. " TO BET!")
        else
            player.bet = bet
            game.run.money = game.run.money - bet
            notice(game, "YOU BET $" .. bet .. "!\nNOW ROLL THE DICE!")
        end
    elseif keeper.shopType == "Kissing" and not failed then
        for _, damsel in ipairs(game.enemies) do
            if damsel.kind == "damsel" and damsel.alive and damsel.forSale and not damsel.held
                and Shop.distanceToPlayer(damsel, player) < 16 then
                local price = Shop.kissPrice(game)
                if game.run.money >= price then
                    game.run.money = game.run.money - price
                    player.health = player.health + 1
                    player.maxHealth = math.max(player.maxHealth, player.health)
                    damsel.kissTimer = 12
                    game.sounds:play("kiss")
                    notice(game, "NOW AIN'T SHE SWEET!")
                else notice(game, "YOU NEED $" .. price .. "!\nGET OUTTA HERE, DEADBEAT!") end
                break
            end
        end
    end
    return true
end

local function settleBet(game, keeper)
    local bet = game.player.bet or 0
    if bet == 0 or keeper.shopType ~= "Craps" or keeper.state ~= "idle" then return end
    local dice = {}
    for _, item in ipairs(game.items) do
        if item.kind == "die" and not item.opened then dice[#dice + 1] = item end
    end
    if #dice ~= 2 or not dice[1].rolled or not dice[2].rolled then return end
    local value = dice[1].diceValue + dice[2].diceValue
    game.player.bet = 0
    for _, die in ipairs(dice) do die.rolled = false end
    if value > 7 then
        game.run.money = game.run.money + bet * 2
        notice(game, "YOU ROLLED A " .. value .. "!\nCONGRATULATIONS! YOU WIN!")
    elseif value == 7 then
        notice(game, "YOU ROLLED A SEVEN!\nYOU WIN A PRIZE!")
        for _, group in ipairs({ game.items, game.collectibles }) do
            for _, prize in ipairs(group) do
                if prize.properties.inDiceHouse then
                    local x, y = prize.x, prize.y
                    Shop.release(prize)
                    prize.properties.inDiceHouse = false
                    prize.x = x + (game.player.x < x and -32 or 32)
                    game:spawnEntity(Stock.prize(keeper.random), x, y, {
                        forSale = true, inDiceHouse = true,
                    })
                    -- One display prize is exchanged per win.
                    return
                end
            end
        end
    else notice(game, "YOU ROLLED A " .. value .. "!\nI'M SORRY, BUT YOU LOSE!") end
end

function Shop.update(game)
    local player = game.player
    local keeper = Shop.keeper(game, player.x, player.y)
    local wanted = game.run.shopkeeperAnger > 0 or game.run.murderer
    for _, wall in ipairs(game.world.destroyedShopWalls or {}) do
        Shop.anger(game, wall.x, wall.y, "DIE, YOU VANDAL!")
    end
    game.world.destroyedShopWalls = nil
    for _, die in ipairs(game.items) do
        if die.diceCheated then
            die.diceCheated = false
            Shop.anger(game, die.x, die.y, "HEY, ONLY I CAN DO THAT!")
            wanted = game.run.shopkeeperAnger > 0 or game.run.murderer
        end
    end
    for _, group in ipairs({ game.items, game.collectibles, game.enemies }) do
        for _, body in ipairs(group) do
            if body.kind == "damsel" and Shop.forSale(body) and body.hp <= 0 then
                Shop.anger(game, body.x, body.y, "YOU'LL PAY FOR YOUR CRIMES!")
                wanted = game.run.shopkeeperAnger > 0 or game.run.murderer
            end
            if Shop.forSale(body) and not body.opened and body.alive ~= false then
                if not keeper or wanted then
                    Shop.claim(game, body)
                elseif not Shop.contains(game, body.held and player.x or body.x,
                    body.held and player.y or body.y) then
                    Shop.claim(game, body)
                    Shop.anger(game, body.x, body.y, "COME BACK HERE, THIEF!")
                    wanted = game.run.shopkeeperAnger > 0
                end
            end
        end
    end
    for _, bomb in ipairs(game.tools and game.tools.bombs or {}) do
        if bomb.alive and bomb.armed and Shop.contains(game, bomb.x, bomb.y) then
            local nearby = Shop.keeper(game, bomb.x, bomb.y)
            if nearby and (nearby.x - bomb.x) ^ 2 + (nearby.y - 8 - bomb.y) ^ 2 < 96 ^ 2 then
                Shop.anger(game, bomb.x, bomb.y, "TERRORIST!")
            end
        end
    end
    local held = game.heldItem or game.heldNpc
    if keeper and (keeper.state == "idle" or keeper.state == "follow") and held and Shop.forSale(held) then
        local template = held.kind == "damsel" and "I'LL LET YOU HAVE HER FOR $%s!"
            or held.definition and held.definition.buyMessage
        if template then
            notice(game, string.format(template, Shop.price(game, held))
                .. "\nPRESS " .. game.app.controls:label("pay") .. " TO PURCHASE.")
        end
    end
    if keeper and keeper.state == "idle" and not wanted then
        if not keeper.welcomed and Shop.sameRoom(player, keeper) then
            keeper.welcomed = true
            local shops = { Bomb = "BOMB SHOP", Weapon = "ARMORY", Clothing = "CLOTHING SHOP",
                Rare = "SPECIALTY SHOP", Craps = "DICE HOUSE", Kissing = "KISSING PARLOR" }
            local text = keeper.shopType == "Ankh" and "I HAVE SOMETHING SPECIAL..."
                or "WELCOME TO " .. keeper.spec.name(keeper) .. "'S "
                    .. (shops[keeper.shopType] or "SUPPLY SHOP") .. "!"
            local key = game.app.controls:label("pay")
            if keeper.shopType == "Craps" then
                text = text .. "\nPRESS " .. key .. " TO BET $" .. (1000 + game.level.absoluteLevel * 500) .. "."
            elseif keeper.shopType == "Kissing" then
                text = text .. "\n$" .. Shop.kissPrice(game) .. " A KISS. PRESS " .. key .. "."
            end
            notice(game, text)
        end
        settleBet(game, keeper)
    end
end

return Shop
