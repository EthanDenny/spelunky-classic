local Bullet = { depth = 0, projectile = { persistent = true, impact = "bullet" } }

function Bullet.drawProjectile(projectile)
    local image = Bullet.image
    if not image then
        image = require("src.platform.object_assets").image("Effects", "sBullet")
        Bullet.image = image
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(projectile.x - 4), math.floor(projectile.y))
end

return Bullet
