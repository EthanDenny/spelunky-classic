local Contact = require("src.platform.body_contact")
local Traits = require("src.platform.item_traits")

local PhysicalBody = require("src.platform.physical_body")

local Definition = Traits.carry({ stickOnWall = 6, gravity = 0.2, consumeOnEnemyHit = true })

Definition.depth = 100

function Definition.hangAt(world, x, y)
    local game = world.game
    if not game then return false end
    local Collision = require("src.platform.sprite_collision")
    local near, nearestDistance, head, above, below
    for _, arrows in ipairs({ game.items or {}, game.traps and game.traps.projectiles or {} }) do
        for _, arrow in ipairs(arrows) do
            if arrow.kind == "arrow" and arrow.alive ~= false and not arrow.opened then
                local function at(py)
                    return Collision.overlaps("sArrowRight", 0, arrow.x, arrow.y, false,
                        x, py, x+1, py+1, true, arrow.arrowAngle)
                end
                head = head or at(y-5) or at(y-6)
                above, below = above or at(y-9), below or at(y+9)
                local distance = (arrow.x-x)^2+(arrow.y-(y-5))^2
                if not nearestDistance or distance < nearestDistance then
                    near, nearestDistance = arrow, distance
                end
            end
        end
    end
    return head and not above and not below and near and near.stuck or false
end

local function materializeArrow(projectile, items, x, y, velocityFactor, retainFlight)
    if not items then return end
    local arrow = require("src.platform.item").new({ kind = "arrow", x = x / 16, y = y / 16 })
    arrow.vx, arrow.vy = projectile.vx * (velocityFactor or 1), projectile.vy
    if retainFlight then
        arrow.gravity, arrow.stuck = projectile.gravity, projectile.stuck
        arrow.facing, arrow.arrowAngle = projectile.facing, projectile.arrowAngle
    else
        arrow.facing = projectile.vx < 0 and -1 or 1
        arrow.arrowAngle = math.atan2(projectile.vy, projectile.vx)
        arrow.safeTimer = 10
        arrow.skipEnemyHitOnce = velocityFactor ~= nil
    end
    items[#items + 1] = arrow
end

function Definition.hitPlayer(arrow, player, game)
    if arrow.alive == false or arrow.opened or player:isDead() then return false end
    -- oPlayer1 asks collision_rectangle with prec=false, not its movement mask.
    local Collision = require("src.platform.sprite_collision")
    if not Collision.overlaps("sArrowRight", 0, arrow.x, arrow.y, false,
        player.x-8, player.y-8, player.x+9, player.y+9, true, arrow.arrowAngle) then return false end
    if game then
        arrow = require("src.platform.entity_collision").nearest({ game.items or {},
            game.traps and game.traps.projectiles or {},
            game.projectiles and game.projectiles.projectiles or {} }, "arrow", player.x, player.y) or arrow
    end
    if arrow.safe or (arrow.safeTimer or 0) > 0 or math.abs(arrow.vx) <= 3 then return false end
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
    if Contact.moving(projectile, 2) then
        local Sensor = require("src.platform.traps.arrow_trap_sensor")
        Contact.scan(projectile, enemies, 2, function(enemy)
            return enemy.alive and enemy.kind ~= "ghost" and not (enemy.invincible and enemy.invincible > 0)
        end, function(enemy)
            if PhysicalBody.strikeEnemy(projectile, enemy) and self.game then
                self.game.effects:blood(enemy.x, enemy.y-8, 1)
            end
            projectile.alive = false
            return true
        end, function(body, enemy, reach)
            return Sensor.overlaps(enemy, player, body.x-reach, body.y-reach,
                body.x+reach+1, body.y+reach+1, true)
        end)
        if not projectile.alive then return end
    end
    if items and (projectile.vx ~= oldVx or PhysicalBody.probe(self.world, projectile, "x", -1)
        or PhysicalBody.probe(self.world, projectile, "x", 1)
        or PhysicalBody.probe(self.world, projectile, "y", 1)
        or self.world:webRect(projectile.x-4, projectile.y-4, projectile.x+4, projectile.y+4)) then
        materializeArrow(projectile, items, projectile.x, projectile.y, nil, true)
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

function Definition.updateProjectile(system, arrow, enemies, items, player)
    Definition.updateTrapProjectile(system, arrow, player, enemies, items)
end

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
