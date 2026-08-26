local Enemy = require("src.platform.enemy")
local Player = require("src.platform.player")
local World = require("src.platform.world")

local Test = {}

local function flatWorld()
    local world = World.new(20, 14, 16)
    world:fill("solid", 0, 10, 20, 4)
    return world
end

function Test.run()
    do
        local world = World.new(16, 14, 16)
        world:fill("solid", 5, 10, 4, 1)
        local snake = Enemy.new("snake", 5 * 16 + 8, 10 * 16,
            { facing = -1, seed = 7 })
        snake.random = function(_, maximum) return maximum end
        snake:setState(Enemy.STATES.walk)
        snake:step(world)
        snake:step(world)
        assert(snake.facing == 1,
            "A patrolling snake must turn before walking off a ledge")

        snake.x = 9 * 16 - snake:getCollisionHalfWidth()
        snake.facing = 1
        snake:step(world)
        assert(snake.facing == -1,
            "A patrolling snake must reverse when it reaches a wall or platform end")
    end

    do
        local world = flatWorld()
        world:set("solid", 5, 4)
        local bat = Enemy.new("bat", 5 * 16 + 8, 5 * 16 + 16, { seed = 3 })
        local player = Player.new(bat.x, 10 * 16 - 8)
        player.state = Player.STATES.standing
        bat:step(world, player)
        assert(bat.state == Enemy.STATES.attack and bat.justAlerted,
            "A hanging bat must attack a living player below it within 90 pixels")
        local oldY = bat.y
        bat:step(world, player)
        assert(bat.y > oldY,
            "An attacking bat must steer toward a player below it")
    end

    do
        local world = flatWorld()
        world:set("solid", 8, 4)
        local spider = Enemy.new("spider", 8 * 16 + 8, 5 * 16 + 16, { seed = 5 })
        local player = Player.new(spider.x, 10 * 16 - 8)
        player.state = Player.STATES.standing
        spider:step(world, player)
        assert(spider.state == Enemy.STATES.recover and spider.justAlerted,
            "A ceiling spider must drop when the player passes directly beneath it")
        local startY = spider.y
        for _ = 1, 45 do spider:step(world, player) end
        assert(spider.y > startY and spider.state ~= Enemy.STATES.hang,
            "A dropped spider must fall and enter its recovery or bouncing behavior")
    end

    do
        local world = flatWorld()
        local enemy = Enemy.new("snake", 8 * 16, 10 * 16, { seed = 9 })
        local player = Player.new(enemy.x, 139)
        player.state = Player.STATES.falling
        player.vy = 3
        local result = enemy:resolvePlayerContact(player, 134)
        assert(result == "stomp" and not enemy.alive,
            "A descending player landing from above must stomp a one-HP enemy")
        assert(player.vy < 0 and player.state == Player.STATES.jumping,
            "A successful stomp must bounce the player upward")
    end

    do
        local enemy = Enemy.new("snake", 8 * 16, 10 * 16, { seed = 10 })
        local player = Player.new(enemy.x - 8, 10 * 16 - 8)
        player.state = Player.STATES.standing
        local result = enemy:resolvePlayerContact(player, player.y)
        assert(result == "hurt" and player.health == 3 and player.invincibleTimer == 30,
            "Side contact must damage and briefly protect the player")
        assert(enemy:resolvePlayerContact(player, player.y) == "invincible"
            and player.health == 3,
            "Contact during invincibility must not deal repeated damage")
    end
end

return Test
