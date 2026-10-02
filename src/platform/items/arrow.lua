local Traits = require("src.platform.item_traits")

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

local function arrowHitsWorld(world, projectile, x, y)
    local left, top, right, bottom = x - 4, y - 4, x + 4, y + 4
    if projectile.launchTrapX == nil then
        return world:solidRect(left, top, right, bottom)
    end
    local size = world.tileSize
    local overlapsLaunch = right > projectile.launchTrapX * size
        and left < (projectile.launchTrapX + 1) * size
        and bottom > projectile.launchTrapY * size
        and top < (projectile.launchTrapY + 1) * size
    if not overlapsLaunch then projectile.clearOfLaunchTrap = true end
    for cellY = math.floor(top / size), math.floor((bottom - 0.001) / size) do
        for cellX = math.floor(left / size), math.floor((right - 0.001) / size) do
            if world:has("solid", cellX, cellY)
                and (projectile.clearOfLaunchTrap
                    or cellX ~= projectile.launchTrapX or cellY ~= projectile.launchTrapY) then
                return true
            end
        end
    end
    return world:dynamicSolidAt(left, top, right, bottom) ~= nil
end

function Definition.updateTrapProjectile(self, projectile, player, enemies, items)
    if not projectile.alive then return end
    projectile.vy = math.min(8, projectile.vy + 0.2)
    local steps = math.max(1, math.floor(math.max(math.abs(projectile.vx), math.abs(projectile.vy))))
    local dx, dy = projectile.vx / steps, projectile.vy / steps
    for _ = 1, steps do
        local nextX, nextY = projectile.x + dx, projectile.y + dy
        local solidHit = projectile.kind == "arrow"
            and arrowHitsWorld(self.world, projectile, nextX, nextY)
            or (projectile.kind ~= "arrow" and self.world:solidAtPoint(nextX, nextY))
        if solidHit then
            if projectile.kind == "arrow" and items then
                local arrow = require("src.platform.item").new({ kind = "arrow", x = projectile.x / 16,
                    y = projectile.y / 16 })
                arrow.vx, arrow.vy = projectile.vx, projectile.vy
                arrow.facing = projectile.direction
                items[#items + 1] = arrow
            end
            projectile.alive = false
            return
        end
        projectile.x, projectile.y = nextX, nextY
        if math.abs(projectile.x - player.x) < 7 and math.abs(projectile.y - player.y) < 8 then
            player:hurt(projectile.x)
            projectile.alive = false
            return
        end
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and math.abs(projectile.x - enemy.x) < 8
                and math.abs(projectile.y - enemy.y) < 8 then
                enemy:damage(2)
                projectile.alive = false
                return
            end
        end
    end
end

function Definition.drawTrapProjectile(system, arrow)
    love.graphics.setColor(1, 1, 1, 1)
    local image = arrow.direction < 0 and system.assets.arrowLeft or system.assets.arrowRight
    love.graphics.draw(image, math.floor(arrow.x), math.floor(arrow.y), 0, 1, 1, 4, 4)
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
