local Traits = require("src.platform.item_traits")
local Physics = require("src.platform.physical_body")
local Assets = require("src.platform.object_assets")
local image
local Ball = Traits.carry({ depth = 99, heavy = true, gravity = 1, bounds = { 5, -5, 5 } })

function Ball.updateLoose(ball, world, player)
    local dx, dy = player.x - ball.x, player.y - ball.y
    local floor = Physics.probe(world, ball, "y", 1)
    if dx * dx + dy * dy >= 24 * 24 then
        if math.abs(dx) >= 24 or not floor then
            if math.abs(dx) < 1 then ball.x, ball.vx = player.x, 0 end
            if dx > 0 then
                if player.vx > 0 and ball.y >= player.y then ball.vx = player.vx
                elseif ball.vx < 0 then ball.vx = ball.vx * -0.5
                elseif ball.vx == 0 then ball.vx = 2 end
            elseif dx < 0 then
                if player.vx < 0 and ball.y >= player.y then ball.vx = player.vx
                elseif ball.vx > 0 then ball.vx = ball.vx * -0.5
                elseif ball.vx == 0 then ball.vx = -2 end
            end
        else
            ball.vx = ball.vx * 0.5
            if math.abs(ball.vx) < 0.5 then ball.vx = 0 end
        end
        if math.abs(dy) >= 24 and dy < 0 then ball.vy = 0 end
    elseif floor then ball.vx = 0 end
end

function Ball.restrain(player, input)
    local ball = player.ball
    if not ball or not ball.alive then return end
    local dx, dy = player.x - ball.x, player.y - ball.y
    if dx * dx + dy * dy < 24 * 24 then return end
    if math.abs(dx) > 24 and player.vx * dx > 0 then player.vx = 0 end
    if dy > 24 and player.vy > 0 then
        if math.abs(dx) < 1 then player.x = ball.x
        elseif dx > 0 and not input.right then
            player.vx = player.vx > 0 and player.vx * -0.25 or player.vx == 0 and -1 or player.vx
        elseif dx < 0 and not input.left then
            player.vx = player.vx < 0 and player.vx * -0.25 or player.vx == 0 and 1 or player.vx
        end
        player.vy, player.fallTimer = 0, 0
    end
    if dy < -24 and player.vy < 0 then player.vy = 0 end
end

function Ball.drawItem(_, ball)
    image = image or Assets.image("Items/Weapons", "sBall")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(ball.x), math.floor(ball.y), 0, 1, 1, 8, 10)
end

function Ball.draw(renderer, entity)
    Ball.drawItem(renderer, { x = entity.x * 16, y = entity.y * 16 })
end

return Ball
