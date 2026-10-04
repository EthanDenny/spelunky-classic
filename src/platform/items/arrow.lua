local Traits = require("src.platform.item_traits")

local PhysicalBody = require("src.platform.physical_body")

local Definition = Traits.carry({ stickOnWall = 6, gravity = 0.2, consumeOnEnemyHit = true })

Definition.depth = 100

local function materializeArrow(projectile, items, x, y, velocityFactor)
    if not items then return end
    local arrow = require("src.platform.item").new({ kind = "arrow", x = x / 16, y = y / 16 })
    arrow.vx, arrow.vy = projectile.vx * (velocityFactor or 1), projectile.vy
    arrow.facing = projectile.vx < 0 and -1 or 1
    arrow.arrowAngle = math.atan2(projectile.vy, projectile.vx)
    arrow.safeTimer = 10
    arrow.skipEnemyHitOnce = velocityFactor ~= nil
    items[#items + 1] = arrow
end

function Definition.hitPlayer(arrow, player, game)
    if arrow.alive == false or arrow.opened or arrow.held or arrow.safe
        or (arrow.safeTimer or 0) > 0 or math.abs(arrow.vx) <= 3 or player:isDead() then return false end
    -- oPlayer1 asks collision_rectangle with prec=false, not its movement mask.
    local Collision = require("src.platform.sprite_collision")
    if not Collision.overlaps("sArrowRight", 0, arrow.x, arrow.y, false,
        player.x-8, player.y-8, player.x+9, player.y+9, true, arrow.arrowAngle) then return false end
    if not player:hurt(arrow.x, 2, "arrow", 20, "arrow", arrow.vx) then return false end
    arrow.alive, arrow.opened = false, true
    if game then
        game.effects:blood(player.x, player.y, 3)
        game.sounds:play("hurt")
        game:dropHeldItemFromHurt()
    end
    return true
end

function Definition.updateTrapProjectile(self, projectile, player, enemies, items)
    if not projectile.alive or not require("src.platform.activity").contains(self.world, projectile) then return end
    projectile.definition = Definition
    projectile.gravity = projectile.gravity or 0.2
    local oldVx = projectile.vx
    PhysicalBody.stepItem(self.world, projectile)
    Definition.updateLoose(projectile)
    PhysicalBody.stopInWeb(self.world, projectile)
    if Definition.hitPlayer(projectile, player, self.game) then return end
    if math.abs(projectile.vx) > 2 or math.abs(projectile.vy) > 2 then
        local Sensor = require("src.platform.traps.arrow_trap_sensor")
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and enemy.kind ~= "ghost" and not (enemy.invincible and enemy.invincible > 0)
                and Sensor.overlaps(enemy, player, projectile.x-2, projectile.y-2,
                    projectile.x+3, projectile.y+3, true) then
                if PhysicalBody.strikeEnemy(projectile, enemy) and self.game then
                    self.game.effects:blood(enemy.x, enemy.y-8, 1)
                end
                projectile.alive = false
                return
            end
        end
    end
    if items and (projectile.vx ~= oldVx or PhysicalBody.probe(self.world, projectile, "x", -1)
        or PhysicalBody.probe(self.world, projectile, "x", 1)
        or PhysicalBody.probe(self.world, projectile, "y", 1)
        or self.world:webRect(projectile.x-4, projectile.y-4, projectile.x+4, projectile.y+4)) then
        local arrow = require("src.platform.item").new({ kind = "arrow",
            x = projectile.x/16, y = projectile.y/16 })
        arrow.vx, arrow.vy, arrow.gravity = projectile.vx, projectile.vy, projectile.gravity
        arrow.stuck, arrow.facing, arrow.arrowAngle = projectile.stuck, projectile.facing, projectile.arrowAngle
        items[#items+1] = arrow
        projectile.alive = false
    end
end

function Definition.drawTrapProjectile(system, arrow)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(system.assets.arrowRight, math.floor(arrow.x), math.floor(arrow.y),
        arrow.arrowAngle or math.atan2(arrow.vy, arrow.vx), 1, 1, 4, 4)
end

function Definition.loadTrapAssets(assets)
    local Assets = require("src.platform.object_assets")
    assets.arrowLeft = Assets.image("Items/Weapons", "sArrowLeft")
    assets.arrowRight = Assets.image("Items/Weapons", "sArrowRight")
end

Definition.projectile = {
    persistent = true,
    solidBounds = 4,
    materialize = materializeArrow,
    nextGravity = 0.6,
}

function Definition.drawProjectile(projectile)
    local image = Definition.projectileImage
    if not image then
        image = require("src.platform.object_assets").image("Items/Weapons", "sArrowRight")
        Definition.projectileImage = image
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(projectile.x), math.floor(projectile.y),
        math.atan2(projectile.vy, projectile.vx), 1, 1, 4, 4)
end

function Definition.updateLoose(self)
    if self.vx ~= 0 then
        self.arrowAngle = math.atan2(self.vy, self.vx)
    elseif not self.stuck then self.arrowAngle = 0 end
end

function Definition.loadRenderAssets(self)
    for key, sprite in pairs({ arrow = "sArrowRight", arrow_left = "sArrowLeft" }) do
        local image = love.graphics.newImage(
            "original-game-reference/source/extracted/spelunky/Sprites/Items/Weapons/"
                .. sprite .. ".images/image 0.png")
        image:setFilter("nearest", "nearest")
        self.entitySprites[key] = { image = image,
            metadata = { originX = 4, originY = 4, width = 8, height = 8 } }
    end
end

function Definition.drawItem(renderer, item)
    love.graphics.setColor(1, 1, 1, 1)
    -- Picking up a falling arrow discards its previous angle.
    local angle = item.held and 0 or item.arrowAngle or math.atan2(item.vy, item.vx)
    love.graphics.draw(renderer.entitySprites.arrow.image, math.floor(item.x), math.floor(item.y),
        angle, 1, 1, 4, 4)
end

return Definition
