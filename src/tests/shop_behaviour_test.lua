local ItemBody = require("src.platform.item_body")
local Controls = require("src.input.classic_controls")
local Creature = require("src.platform.creature")
local Effects = require("src.platform.effects")
local FullLevel = require("src.screens.full_level_playtest")
local Item = require("src.platform.item")
local Shop = require("src.platform.shop")
local Player = require("src.platform.player")
local Projectiles = require("src.platform.projectile_system")
local RunState = require("src.game.run_state")
local Tools = require("src.platform.tool_system")
local Traps = require("src.platform.trap_system")
local World = require("src.platform.world")

local Test = {}
local function fixture(style)
    local game = FullLevel.new({ controls = Controls.fromContents(nil, nil) })
    game.seed = 17
    game.world = World.new(42, 34, 16)
    game.world:fill("solid", 0, 7, 42, 1)
    game.player = Player.new(80, 104)
    game.player.state = Player.STATES.standing
    game.level = { absoluteLevel = 2, entities = {}, roomPath = {
        { 4, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 },
    } }
    game.run = RunState.new(17)
    game.run.money = 50000
    game.effects = Effects.new(17)
    game.projectiles = Projectiles.new(game.world)
    game.tools = Tools.new(game.world)
    game.traps = Traps.new(game.world, game.level)
    game.renderer = { entitySprites = {} }
    game.sounds = { play = function() end }
    local keeper = Creature.new({ kind = "shopkeeper", x = 8, y = 6,
        properties = { shopType = style or "General" } }, nil, { seed = 17 })
    game.enemies = { keeper }
    return game, keeper
end
local function stock(game, kind)
    return game:spawnEntity(kind, 84, 108, { forSale = true })
end
local function pickup(game, sprint)
    game.player.state = Player.STATES.ducking
    game:handleActionPressed({ down = true, attack = true, sprint = sprint })
end
local function pay(game)
    game:keypressed("p", "p", false)
    game:simulationStepBody({})
end

function Test.run()
    local cases = {
        { "stock quotes and purchases use Classic's two message lines", function()
            local game, keeper = fixture()
            keeper.welcomed = true
            local gun = stock(game, "shotgun")
            pickup(game)
            Shop.update(game)
            assert(game.run:currentMessage().text == "A SHOTGUN FOR $15000.\nPRESS P TO PURCHASE.")
            Shop.pay(game)
            assert(game.run:currentMessage().text == "YOU GOT A SHOTGUN!"
                and game.run:currentMessage().timer == 80)
            gun.held, game.heldItem = false, nil
            pickup(game)
            assert(game.run:currentMessage().timer == 80,
                "Dropping and picking up an owned gun must not announce it again")
        end },
        { "the source keeper welcome happens once on entry", function()
            local game, keeper = fixture("Craps")
            Shop.update(game)
            local welcome = game.run:currentMessage()
            assert(welcome.text:match("^WELCOME TO %u+'S DICE HOUSE!\nPRESS P TO BET %$2000%.$")
                and welcome.timer == 200)
            game.run:addMessage("I'M OUT OF ARROWS!", 80)
            Shop.update(game)
            assert(game.run:currentMessage().text == "I'M OUT OF ARROWS!",
                "An already welcomed keeper must not replace subsequent messages")
        end },
        { "dice and kissing messages preserve the source second line", function()
            local game, keeper = fixture("Craps")
            keeper.welcomed = true
            Shop.pay(game)
            assert(game.run:currentMessage().text == "YOU BET $2000!\nNOW ROLL THE DICE!")
            Shop.pay(game)
            assert(game.run:currentMessage().text == "ONE BET AT A TIME!\nPLEASE ROLL THE DICE!")
            local parlor, owner = fixture("Kissing")
            owner.welcomed = true
            parlor:spawnEntity("damsel", 84, 108, { forSale = true })
            parlor.run.money = 0
            Shop.pay(parlor)
            assert(parlor.run:currentMessage().text == "YOU NEED $10000!\nGET OUTTA HERE, DEADBEAT!")
        end },
        { "a hard landing blocks held-item ACTION before dropping the item", function()
            for _, kind in ipairs({ "shotgun", "teleporter", "crate", "rock", "machete" }) do
                local game, keeper = fixture()
                keeper.x = 600
                local item = game:spawnEntity(kind, game.player.x, game.player.y)
                item:pickup(game.player)
                game.heldItem = item
                game.player.fallTimer = 17
                game:simulationStepBody({ attack = true, up = true })
                assert(game.player:isStunned() and not game.player.whipping
                    and game.player.x == 80 and #game.projectiles.projectiles == 0
                    and not item.opened and item.cooldown == 0 and item.vx == 0
                    and not game.heldItem and not item.held,
                    "Stun must block " .. kind .. " use, then release it with hurt rather than throw velocity")
            end
        end },
        { "stunned players cannot launch tools or spend their supply", function()
            local game = fixture()
            game.player:hurt(70)
            game:keypressed("a", "a", false)
            game:keypressed("s", "s", false)
            assert(game.run.bombs == 4 and game.run.ropes == 4
                and #game.tools.bombs == 0 and #game.tools.ropes == 0,
                "Configured bomb and rope presses during stun must neither spawn a tool nor consume one")
        end },
        { "fall stun cancels a live melee stroke before it hits", function()
            local game, keeper = fixture()
            keeper.x = 600
            local blade = game:spawnEntity("machete", game.player.x, game.player.y)
            blade:pickup(game.player)
            game.heldItem = blade
            game:simulationStepBody({ attack = true })
            for _ = 1, 5 do game:simulationStepBody({}) end
            assert(game.player.whipping and game.player.meleeVisualPhase == "front",
                "The regression requires a live machete stroke")
            keeper.x, keeper.y = game.player.x + 16, game.player.y + 8
            game.player.fallTimer = 17
            game:simulationStepBody({})
            assert(game.player:isStunned() and not game.player.whipping and keeper.hp == 20,
                "A hard landing must destroy the active slash before it can hit the keeper")
        end },
        { "stun releases an armed bow once even with ACTION held", function()
            local game, keeper = fixture()
            keeper.x = 600
            local bow = game:spawnEntity("bow", game.player.x, game.player.y)
            bow:pickup(game.player, game.run)
            game.heldItem = bow
            game:simulationStepBody({ attack = true })
            assert(bow.bowArmed, "The regression requires a bow armed by ACTION")
            local arrows = game.run.arrows
            game.player.fallTimer = 17
            game:simulationStepBody({ attack = true })
            assert(game.player:isStunned() and not game.heldItem and not bow.bowArmed
                and game.run.arrows == arrows - 1 and #game.projectiles.projectiles == 1,
                "The source fires the already armed bow on stun, then drops it without accepting more ACTION")
            game:simulationStepBody({ attack = true })
            assert(game.run.arrows == arrows - 1, "Dropping the same bow must not discharge it twice")
        end },
        { "whipping a stunned keeper restores thrown-item vulnerability", function()
            local game, keeper = fixture()
            game.player.x = 120
            keeper:damage(1, game.player.x)
            game.player.whipping, game.player.animationFrame, game.player.facing = true, 5, 1
            game.player.whipHits = {}
            game:checkWhip()
            for tick = 1, 10 do game.world.time = tick; keeper:step(game.world, game.player, game) end
            local rock = game:spawnEntity("rock", keeper.x, keeper.y - 8)
            rock.vx = 5
            local hp = keeper.hp
            ItemBody.resolveEnemyContacts(rock, nil, game)
            assert(keeper.hp == hp - 1 and keeper.hasGun,
                "A keeper awakened by a whip must take the next rock hit without dropping his gun")
        end },
        { "thrown merchandise reaches enemy impacts in the simulation", function()
            for _, kind in ipairs({ "bomb_bag", "bomb_box", "rope_pile", "cape", "jetpack", "spectacles" }) do
                local game, keeper = fixture()
                local item = game:spawnEntity(kind, 123, 104, { forSale = true })
                item.vx = 8
                game:simulationStepBody({})
                assert(keeper.hp == 19 and keeper.hasGun and keeper.angry,
                    "Thrown " .. kind .. " must deal an ordinary item hit without disarming the keeper")
            end
        end },
        { "PAY uses the same movement and theft ordering for events and held input", function()
            local results = {}
            for _, events in ipairs({ true, false }) do
                local game = fixture()
                game.player.x, game.player.vx = 175, 3
                local gun = game:spawnEntity("shotgun", 175, 104, { forSale = true })
                gun:pickup(game.player)
                game.heldItem = gun
                if events then game:keypressed("p", "p", false) end
                game:simulationStepBody({ right = true, pay = true })
                results[#results + 1] = { game.run.money, game.run.shopkeeperAnger }
            end
            assert(results[1][1] == results[2][1] and results[1][2] == results[2][2]
                and results[1][1] == 50000 and results[1][2] == 2,
                "Crossing the room boundary must trigger theft before either PAY path can purchase")
        end },
        { "brief PAY events survive until a tick without repeating held bets", function()
            local game = fixture("Craps")
            game:keypressed("p", "p", false)
            assert(game.player.bet == nil and game.run.money == 50000,
                "PAY callbacks must only queue input, leaving transactions to the simulation")
            game:simulationStepBody({})
            assert(game.player.bet == 2000 and game.run.money == 48000,
                "A PAY press released before the next tick must still place its bet")
            game:simulationStepBody({})
            assert(game.run.money == 48000, "A queued PAY press must be consumed once")
            game:simulationStepBody({ pay = true })
            game.player.bet = 0
            game:simulationStepBody({ pay = true })
            assert(game.run.money == 48000, "Holding PAY must not place a second bet after settlement")
        end },
        { "picking up unpaid weapons does not charge", function()
            local game = fixture()
            local gun = stock(game, "shotgun")
            pickup(game)
            assert(game.heldItem == gun and gun.properties.forSale and game.run.money == 50000,
                "DOWN + ACTION must hold shop stock without buying it")
        end },
        { "supply stock is carried before buying", function()
            local game = fixture()
            local bag = stock(game, "bomb_bag")
            pickup(game)
            assert(game.heldItem == bag and bag.held and game.run.bombs == 4 and game.run.money == 50000,
                "An unpaid bomb bag must enter the player's hands without granting bombs")
            pay(game)
            assert(game.heldItem == nil and not bag.alive and game.run.bombs == 7
                and game.run.money == 47500, "PAY must consume supply stock and grant it exactly once")
            pay(game)
            assert(game.run.bombs == 7 and game.run.money == 47500, "Repeated PAY cannot duplicate a purchase")
        end },
        { "PAY buys a held weapon at the level markup", function()
            local game = fixture()
            game.level.absoluteLevel = 3
            local gun = stock(game, "shotgun")
            gun:pickup(game.player)
            game.heldItem = gun
            pay(game)
            assert(game.run.money == 33500 and not gun.properties.forSale and game.heldItem == gun,
                "PAY must charge the marked-up price and leave the weapon held")
            local diceShop = fixture()
            diceShop.level.absoluteLevel = 3
            local prize = stock(diceShop, "shotgun")
            prize.properties.inDiceHouse = true
            prize:pickup(diceShop.player)
            diceShop.heldItem = prize
            pay(diceShop)
            assert(diceShop.run.money == 35000,
                "Dice-house display prizes retain their base price instead of the regular shop markup")
        end },
        { "failed PAY releases unpaid stock", function()
            local game, keeper = fixture()
            game.run.money = 14999
            local gun = stock(game, "shotgun")
            gun:pickup(game.player)
            game.heldItem = gun
            pay(game)
            assert(game.heldItem == nil and not gun.held and gun.properties.forSale
                and game.run.money == 14999 and not keeper.angry,
                "An unaffordable purchase drops the stock without charging or angering the keeper")
        end },
        { "running does not invent a theft command", function()
            local game, keeper = fixture()
            local gun = stock(game, "shotgun")
            pickup(game, true)
            assert(game.heldItem == gun and gun.properties.forSale and not keeper.angry
                and game.run.shopkeeperAnger == 0, "SHIFT + pickup is still an unpaid pickup inside the shop")
        end },
        { "carrying unpaid stock out triggers theft", function()
            local game, keeper = fixture()
            local gun = stock(game, "shotgun")
            gun:pickup(game.player)
            game.heldItem = gun
            game.player.x = 200
            game:simulationStepBody({})
            assert(not gun.properties.forSale and game.heldItem == gun
                and game.run.shopkeeperAnger == 2 and keeper.angry and game.run.money == 50000,
                "Leaving the shop room must steal unpaid stock and start the two-level theft penalty")
        end },
        { "unattended shops release their stock", function()
            local game, keeper = fixture()
            local gun = stock(game, "shotgun")
            keeper.alive = false
            keeper.deathCounted = true
            game:simulationStepBody({})
            assert(not gun.properties.forSale, "Stock cannot demand payment when its keeper is gone")
        end },
        { "calm keepers do not attack on touch", function()
            local game, keeper = fixture()
            game.player.x, game.player.y = keeper.x, keeper.y - 8
            keeper:resolvePlayerContact(game.player, game.player.y)
            assert(game.player.health == 4 and not game.player:isStunned(),
                "Idle shopkeepers must ignore ordinary player contact")
        end },
        { "keepers follow unpaid merchandise", function()
            local game, keeper = fixture()
            local gun = stock(game, "shotgun")
            gun:pickup(game.player)
            game.heldItem = gun
            for tick = 1, 3 do game.world.time = tick; keeper:step(game.world, game.player, game) end
            assert(keeper.x < 136 and not keeper.angry and #game.projectiles.projectiles == 0,
                "A peaceful keeper must follow the customer carrying unpaid stock")
        end },
        { "wanted keepers patrol before noticing a distant player", function()
            local game, keeper = fixture()
            game.run.shopkeeperAnger = 2
            game.player.x = 520
            keeper:step(game.world, game.player, game)
            assert(math.abs(keeper.vx) <= 1.5 and #game.projectiles.projectiles == 0,
                "A distant wanted keeper patrols instead of immediately chasing at attack speed")
        end },
        { "attacking keepers fire six source bullets", function()
            local game, keeper = fixture()
            keeper.angry, keeper.state, keeper.facing = true, "attack", -1
            keeper:step(game.world, game.player, game)
            local shots = game.projectiles.projectiles
            assert(#shots == 6 and keeper.vx == 0 and keeper.vy == -1,
                "The shotgun fires six bullets and applies the source recoil")
            for _, shot in ipairs(shots) do
                assert(shot.kind == "bullet" and shot.damage == 4 and shot.vx >= -11 and shot.vx <= -9,
                    "Shopkeeper bullets use four-heart damage and six-to-eight speed plus attack momentum")
            end
        end },
        { "shopkeeper shots require vertical alignment", function()
            local game, keeper = fixture()
            keeper.angry, keeper.state = true, "attack"
            game.player.y = 56
            keeper:step(game.world, game.player, game)
            assert(#game.projectiles.projectiles == 0, "The keeper cannot shoot across more than 32 vertical pixels")
        end },
        { "stunned keepers drop their gun and recover only on ground", function()
            local game, keeper = fixture()
            keeper.y = 48
            keeper.state, keeper.angry = "attack", true
            game.player.x, game.player.y, game.player.vy = keeper.x, 32, 4
            game.player.state, game.player.fallTimer = "falling", 16
            keeper:resolvePlayerContact(game.player, game.player.y)
            local initial = keeper.stunned
            for tick = 1, 4 do game.world.time = tick; keeper:step(game.world, game.player, game) end
            assert(keeper.stunned == initial and #game.items == 1 and game.items[1].kind == "shotgun",
                "Airborne stun must not count down, and the source gun drops exactly once")
        end },
        { "kisses heal without purchasing the damsel", function()
            local game = fixture("Kissing")
            game.player.x = 64
            game.player.health, game.player.maxHealth = 4, 4
            local damsel = Creature.new({ kind = "damsel", x = 84 / 16, y = 104 / 16,
                properties = { forSale = true } }, { width = 16, height = 16, originX = 8, originY = 8 })
            game.enemies[#game.enemies + 1] = damsel
            pay(game)
            assert(game.run.money == 40000 and game.player.health == 5 and damsel.forSale and not damsel.held,
                "A level-two kiss costs $10000, adds a heart, and leaves the damsel for sale")
        end },
        { "buying a damsel costs three kisses", function()
            local game = fixture("Kissing")
            local damsel = Creature.new({ kind = "damsel", x = 84 / 16, y = 104 / 16,
                properties = { forSale = true } }, { width = 16, height = 16, originX = 8, originY = 8 })
            game.enemies[#game.enemies + 1] = damsel
            pickup(game)
            assert(game.heldNpc == damsel and game.run.money == 50000 and damsel.forSale,
                "Picking up the kissing-parlor damsel does not buy her")
            pay(game)
            assert(game.heldNpc == damsel and not damsel.forSale and game.run.money == 20000
                and game.player.health == 4, "Buying the held damsel charges three kisses without healing")
        end },
        { "PAY starts a bet without rolling dice automatically", function()
            local game = fixture("Craps")
            pay(game)
            assert(game.run.money == 48000 and game.player.bet == 2000 and #game.items == 0,
                "A bet spends money and waits for the player's dice, without inventing a roll or prize")
            pay(game)
            assert(game.run.money == 48000 and game.player.bet == 2000, "Only one bet may be active")
        end },
        { "murder remains wanted after theft forgiveness", function()
            local game, keeper = fixture()
            game.run.murderer = true
            game.run.shopkeeperAnger = 1
            game.run:finishLevel()
            game.player.x = 520
            keeper:step(game.world, game.player, game)
            assert(keeper.angry and game.run.murderer, "Murder remains wanted even when the theft counter reaches zero")
        end },
        { "theft escalation uses the source penalties", function()
            local run = RunState.new(1)
            run:angerShopkeepers()
            assert(run.shopkeeperAnger == 2, "A first theft adds two levels")
            run:angerShopkeepers()
            assert(run.shopkeeperAnger == 5, "Further incidents add three levels")
        end },
        { "the configured PAY key reaches purchasing", function()
            local game = fixture()
            game.app.controls = Controls.fromContents("38\n40\n37\n39\n90\n88\n67\n16\n65\n83\n70\n79", nil)
            local gun = stock(game, "shotgun")
            gun:pickup(game.player)
            game.heldItem = gun
            pay(game)
            assert(game.run.money == 50000, "The original P binding must stop paying after a remap")
            game:keypressed("o", "o", false)
            game:simulationStepBody({})
            assert(game.run.money == 35000 and not gun.properties.forSale,
                "The configured O binding must buy the held item")
        end },
        { "whipping a keeper provokes without ordinary whip damage", function()
            local game, keeper = fixture()
            keeper.x = game.player.x + 16
            game.player.facing = 1
            game.player.whipping = true
            game.player.animationFrame = 5
            game.player.whipHits = {}
            game:checkWhip()
            assert(keeper.hp == 20 and keeper.stunned == 0 and keeper.angry and keeper.vy == -2,
                "A normal whip changes the keeper to ATTACK and kicks him without taking health")
        end },
        { "an attacking keeper throws the player before dealing contact damage", function()
            local game, keeper = fixture()
            keeper.state, keeper.angry = "attack", true
            game.player.x = keeper.x + 4
            game.player.y = keeper.y - 8
            local contact = keeper:resolvePlayerContact(game.player, game.player.y)
            assert(contact == "throw" and game.player.health == 4 and game.player:isStunned()
                and game.player.vx == 6 and game.player.vy == -6,
                "With headroom the keeper grabs and throws instead of dealing an ordinary contact hit")
        end },
        { "real settled dice determine the bet payout", function()
            for _, faces in ipairs({ { 2, 3 }, { 4, 5 }, { 3, 4 } }) do
                local game = fixture("Craps")
                local prize = stock(game, "shotgun")
                prize.properties.inDiceHouse = true
                prize.x = 152
                local dice = {}
                for index = 1, 2 do
                    local die = Item.new({ kind = "die", x = (96 + index * 16) / 16, y = 104 / 16 })
                    game.items[#game.items + 1] = die
                    dice[index] = die
                end
                pay(game)
                -- A real fast flight tick arms each die's roll, then a floor
                -- rest presents two known faces, as in the source oDice Step.
                for _, die in ipairs(dice) do
                    die.vx, die.vy = 3, -3
                    die:update(game.world, game.player)
                end
                for index, die in ipairs(dice) do
                    die.vx, die.vy, die.y, die.diceValue = 0, 0, 104, faces[index]
                    die:update(game.world, game.player)
                end
                game:simulationStepBody({})
                local sum = faces[1] + faces[2]
                assert(game.player.bet == 0 and game.run.money == (sum > 7 and 52000 or 48000),
                    "A settled total above seven pays twice the bet; lower totals lose")
                if sum == 7 then
                    assert(not prize.properties.forSale and not prize.properties.inDiceHouse and prize.x == 120,
                        "Seven awards the existing display prize and moves it toward the player")
                    local replacements = 0
                    for _, group in ipairs({ game.items, game.collectibles }) do
                        for _, item in ipairs(group) do
                            if item.properties.inDiceHouse then replacements = replacements + 1 end
                        end
                    end
                    assert(replacements == 1, "A seven must create exactly one replacement display prize")
                end
            end
        end },
        { "purchasing a back item releases the previous one", function()
            for _, kinds in ipairs({ { "cape", "jetpack" }, { "jetpack", "cape" } }) do
                local game = fixture()
                game.run.equipment[kinds[1]], game.player.equipment[kinds[1]] = true, true
                local purchase = stock(game, kinds[2])
                pickup(game)
                pay(game)
                assert(game.run.equipment[kinds[2]] and game.player.equipment[kinds[2]]
                    and not game.run.equipment[kinds[1]] and not game.player.equipment[kinds[1]],
                    "Buying a cape or jetpack must replace the other back item")
                local dropped = game.items[#game.items]
                assert(dropped ~= purchase and dropped.kind == kinds[1] and dropped.vy < 0
                    and not dropped.properties.forSale and dropped.x == game.player.x,
                    "The replaced back item must fall from the player as free equipment")
                game:simulationStepBody({})
                assert(game.player.equipment[kinds[2]] and not game.player.equipment[kinds[1]],
                    "Contact with the released back item must not automatically undo the purchase")
            end
        end },
        { "destroying a shop wall provokes its keeper", function()
            local game, keeper = fixture()
            game.level.tiles = { [6] = { [10] = { kind = "brick", shopWall = true } } }
            game.world.level = game.level
            game.world:set("solid", 9, 5)
            game.world:destroyTerrain(152, 88, 1)
            game:simulationStepBody({})
            assert(keeper.angry and game.run.shopkeeperAnger == 2,
                "Removing a shop wall must invoke vandalism even without hitting merchandise")
        end },
        { "whipping shop damsels provokes without ordinary whip damage", function()
            local game, keeper = fixture("Kissing")
            local damsel = Creature.new({ kind = "damsel", x = 96 / 16, y = 104 / 16,
                properties = { forSale = true } }, { width = 16, height = 16, originX = 8, originY = 8 })
            game.enemies[#game.enemies + 1] = damsel
            game.player.facing, game.player.whipping, game.player.animationFrame = 1, true, 5
            game.player.whipHits = {}
            game:checkWhip()
            assert(damsel.hp == 4 and damsel.vy == -2 and keeper.angry and game.run.shopkeeperAnger == 2,
                "An ordinary whip must anger the keeper without damaging the for-sale damsel")
        end },
        { "shopkeeper throws deal one impact heart", function()
            local game, keeper = fixture()
            keeper.state, keeper.angry = "attack", true
            game.player.x, game.player.y = keeper.x + 4, keeper.y - 8
            keeper:resolvePlayerContact(game.player, game.player.y)
            assert(game.player.health == 4, "The initial throw must not take a heart")
            game.world:set("solid", 10, 5)
            game.player.x, game.player.y = 150, 88
            game.player:step(game.world, {})
            assert(game.player.health == 3 and game.player.wallHurt == 0,
                "The thrown body must lose one heart on its first wall or floor impact")
            game.player:step(game.world, {})
            assert(game.player.health == 3, "Further bounces cannot repeat the throw's impact damage")
        end },
        { "free supplies collect on contact", function()
            local game = fixture()
            local bag = stock(game, "bomb_bag")
            bag.entity.properties.forSale = false
            game:simulationStepBody({})
            assert(not bag.alive and not game.heldItem and game.run.bombs == 7,
                "Free supplies must collect on contact without ACTION or PAY")
        end },
        { "ordinary thrown items provoke without disarming", function()
            local game, keeper = fixture()
            local rock = Item.new({ kind = "rock", x = keeper.x / 16, y = (keeper.y - 8) / 16 })
            rock.vx = 5
            ItemBody.resolveEnemyContacts(rock, nil, game)
            assert(keeper.hp == 19 and keeper.state == "attack" and keeper.stunned == 0,
                "A fast ordinary oItem costs one keeper heart and enters ATTACK rather than STUNNED")
            keeper:step(game.world, game.player, game)
            assert(keeper.hasGun and #game.items == 0, "An ordinary rock hit must not drop the keeper's gun")
        end },
        { "keeper bullets spare enemies but still hit damsels", function()
            local game, keeper = fixture()
            game.player.x = 20
            local blocker = Creature.new({ kind = "shopkeeper", x = 104 / 16, y = 96 / 16 })
            local damsel = Creature.new({ kind = "damsel", x = 88 / 16, y = 104 / 16 },
                { width = 16, height = 16, originX = 8, originY = 8 })
            game.enemies = { keeper, blocker, damsel }
            game.projectiles:spawn("bullet", 130, 104, -10, 0, keeper, { damage = 4, safe = true })
            for _ = 1, 5 do game.projectiles:update(game.enemies, game.player, game.items) end
            assert(blocker.hp == 20 and damsel.hp == 0,
                "The source safe flag bypasses oEnemy collisions, but oDamsel still takes four hearts")
        end },
    }
    local failures = {}
    for _, case in ipairs(cases) do
        local ok, err = pcall(case[2])
        if not ok then failures[#failures + 1] = case[1] .. ": " .. err end
    end
    assert(#failures == 0, table.concat(failures, "\n"))
end
return Test
