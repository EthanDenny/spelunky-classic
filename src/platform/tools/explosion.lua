local Assets = require("src.platform.object_assets")
local Timing = require("src.platform.tool_timing")

local Explosion = { depth = 1 }

local function overlapsPointEntity(entity, x, y, radius)
    return math.abs(entity.x - x) <= radius and math.abs(entity.y - y) <= radius
end

function Explosion.spawn(self, x, y)
    local destroyed = self.world:destroyTerrain(x, y, 24)
    for _, cell in ipairs(destroyed) do
        self.effects:terrainBreak(cell.pixelX or (cell.x + 0.5) * self.world.tileSize,
            cell.pixelY or (cell.y + 0.5) * self.world.tileSize, self.world.tileSize)
    end
    self.explosions[#self.explosions + 1] = { x = x, y = y, age = 0, alive = true }
    self.effects:explosion(x, y)
    if self.explosionSound then self.explosionSound:clone():play() end
    if self.onExplosion then self:onExplosion(x, y, 24) end
end

function Explosion.update(self, player, enemies, items)
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            if explosion.age == 0 then
                if overlapsPointEntity(player, explosion.x, explosion.y, 25) then
                    player.health = 0
                elseif overlapsPointEntity(player, explosion.x, explosion.y, 34) then
                    player:hurt(explosion.x)
                end
                for _, enemy in ipairs(enemies or {}) do
                    if enemy.alive and overlapsPointEntity(enemy, explosion.x, explosion.y, 32) then
                        if enemy:damage(30) and not enemy.alive then
                            if enemy.kind == "skeleton" then
                                self.effects:skeletonBreak(enemy.x, enemy.y - 8)
                            else
                                self.effects:blood(enemy.x, enemy.y - 8, 3)
                            end
                            enemy.blastParticlesEmitted = true
                        end
                    end
                end
                for _, item in ipairs(items or {}) do
                    if not item.held and overlapsPointEntity(item, explosion.x, explosion.y, 32) then
                        local direction = item.x < explosion.x and -1 or 1
                        item.vx = direction * 5
                        item.vy = -6
                    end
                end
            end
            explosion.age = explosion.age + 1
            if explosion.age >= Timing.scaledTicks(13, self.tickRate) then explosion.alive = false end
        end
    end
end

function Explosion.draw(self)
    if not self.assets then return end
    love.graphics.setColor(1, 1, 1, 1)
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            local frame = math.min(#self.assets.explosion,
                math.floor(explosion.age * 0.8 * 30 / self.tickRate) + 1)
            love.graphics.draw(self.assets.explosion[frame], math.floor(explosion.x),
                math.floor(explosion.y), 0, 1, 1, 24, 24)
        end
    end
    self.effects:draw()
end

function Explosion.loadAssets(assets)
    assets.explosion = {}
    for frame = 0, 9 do
        assets.explosion[#assets.explosion + 1] = Assets.image("Effects", "sExplosion", frame)
    end
end

return Explosion
