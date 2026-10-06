local Camera = {}

local function follow(position, camera, size, border)
    if position < camera+border then return position-border end
    if position > camera+size-border then return position-size+border end
    return camera
end

function Camera.follow(game, viewport)
    local width, height = viewport.logicalWidth, viewport.logicalHeight
    game.cameraX = follow(game.player.x, game.cameraX, width, math.min(128, width/2))
    game.cameraY = follow(game.player.y, game.cameraY, height, math.min(game.viewBorderY or 96, height/2))
    game.cameraX = math.floor(math.max(0, math.min(game.cameraX,
        math.max(0, game.world.width*game.world.tileSize-width))))
    game.cameraY = math.floor(math.max(0, math.min(game.cameraY,
        math.max(0, game.world.height*game.world.tileSize-height))))
end

function Camera.look(game, input)
    local player = game.player
    if not player:isDead() and not player:isStunned()
        and (player:isGroundState() or player.state == "hanging")
        and not input.left and not input.right and (input.up or input.down) then
        if (game.viewCount or 0) <= 30 then game.viewCount = (game.viewCount or 0)+1
        else game.cameraY = game.cameraY+(input.down and 4 or -4) end
    else game.viewCount = 0 end
end

function Camera.shake(game)
    game.viewBorderY = 96
    if (game.shakeTicks or 0) <= 0 then return end
    if game.player.y < 96 or game.player.y > game.world.height*game.world.tileSize-96 then
        game.viewBorderY = 0
    end
    if game.shakeToggle or game.cameraY <= 0 then
        game.cameraY, game.shakeToggle = game.cameraY+3, false
    else
        game.cameraY, game.shakeToggle = game.cameraY-3, true
    end
    game.shakeTicks = game.shakeTicks-1
end

return Camera
