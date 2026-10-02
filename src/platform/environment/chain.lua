local Assets = require("src.platform.object_assets")
local Chain = { depth = 1 }
local image

function Chain.new(ball, player, link)
    local chain = { ball = ball, player = player, link = link, alive = true }
    Chain.update(chain)
    return chain
end

function Chain.update(chain)
    chain.alive = chain.ball.alive
    if not chain.alive then return end
    chain.x = chain.ball.x + (chain.player.x - chain.ball.x) * chain.link / 4
    chain.y = chain.ball.y + (chain.player.y - chain.ball.y) * chain.link / 4
end

function Chain.draw(chain)
    image = image or Assets.image("Items/Weapons", "sChain")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(chain.x), math.floor(chain.y), 0, 1, 1, 8, 8)
end

return Chain
