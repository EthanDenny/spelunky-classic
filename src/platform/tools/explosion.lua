local Assets = require("src.platform.object_assets")
local Timing = require("src.platform.tool_timing")

local Explosion = { depth = 1 }

local function overlapsPointEntity(entity, x, y, radius)
    return math.abs(entity.x - x) <= radius and math.abs(entity.y - y) <= radius
end

function Explosion.spawn(self, x, y)
    local destroyed = self.world:destroyTerrain(x, y, 24)
    self.world:cleanExplosionTerrain(destroyed)
    if self.game then self.game.shakeTicks = math.max(self.game.shakeTicks or 0, 5) end
    if not self.world.game then
        for _, cell in ipairs(destroyed) do
            self.effects:terrainBreak(cell.pixelX or (cell.x + 0.5) * self.world.tileSize,
                cell.pixelY or (cell.y + 0.5) * self.world.tileSize, self.world.tileSize, cell.entity)
        end
    end
    self.explosions[#self.explosions + 1] = { x = x, y = y, age = 0, alive = true }
    self.effects:explosion(x, y)
    if self.explosionSound then self.explosionSound:clone():play() end
    if self.onExplosion then self:onExplosion(x, y, 24) end
end

local function release(self, item)
    item.held = false
    if self.game and self.game.heldItem == item then self.game.heldItem = nil end
    if self.game and self.game.heldNpc == item then self.game.heldNpc = nil end
end

local function blastItem(self, explosion, item)
    if item.alive == false or item.opened
        or not overlapsPointEntity(item, explosion.x, explosion.y, 24) then return end
    release(self, item)
    if item.kind == "arrow" or item.kind == "jar" or item.kind == "skull" then
        if item.kind == "jar" and self.game then
            self.game:openContainer(item)
        elseif item.kind == "skull" then self.effects:skullBreak(item.x, item.y) end
        item.alive, item.visible, item.opened = false, false, true
    elseif item.kind == "bomb" then
        item.timer = math.min(item.timer, Timing.scaledTicks(self.effects.random:random(4,8), self.tickRate))
        item.attached, item.stuck = nil, false
        item.armed = true
        if item.y < explosion.y then item.vy = -self.effects.random:random(2,4) end
        item.vx = (item.x < explosion.x and -1 or 1)*self.effects.random:random(2,4)
    elseif not item.deployed then
        item.vx = item.vx + (item.x < explosion.x and -1 or 1)*self.effects.random:random(4,6)
        item.vy = item.vy + (item.y < explosion.y and -6 or 6)
    end
end

function Explosion.update(self, player, enemies, items)
    local skeletons = {}
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            local destroyed = self.world:destroyTerrain(explosion.x, explosion.y, 24)
            self.world:cleanExplosionTerrain(destroyed)
            if not self.world.game then
                for _, cell in ipairs(destroyed) do
                    self.effects:terrainBreak((cell.x+0.5)*16, (cell.y+0.5)*16, 16, cell.entity)
                end
            end
            if self.onExplosion then self:onExplosion(explosion.x, explosion.y, 24) end
            if not player:isDead() and player.state ~= "exiting"
                and math.abs(player.x-explosion.x) < 32 and math.abs(player.y-explosion.y) < 32 then
                local vx = (player.x < explosion.x and -1 or 1)*self.effects.random:random(4,6)
                player.invincibleTimer = 0
                player:hurt(explosion.x, 10, "explosion", 100)
                player.vx, player.vy, player.burning = vx, -6, 50
                self.effects:blood(player.x, player.y, 1)
            end
            for _, enemy in ipairs(enemies or {}) do
                if enemy.alive and enemy:overlapsRectangle(explosion.x-24, explosion.y-24, explosion.x+24, explosion.y+24) then
                    local vx = (enemy.x < explosion.x and -1 or 1)*self.effects.random:random(4,6)
                    if enemy:damage(enemy.kind == "damsel" and 100 or 30, explosion.x,
                        { kind = "explosion", vx = vx, vy = -6 }) then
                        enemy.vx, enemy.vy, enemy.burning = vx, -6, 50
                        if not enemy.alive then
                            if enemy.kind == "skeleton" then
                                skeletons[#skeletons+1] = enemy
                            else self.effects:blood(enemy.x, enemy.spec.deathY and enemy.spec.deathY(enemy) or enemy.y-8, enemy.spec.deathBlood or 0) end
                            enemy.blastParticlesEmitted = true
                        end
                    end
                end
            end
            for _, group in ipairs({ items or {}, self.bombs, self.ropes }) do
                for _, item in ipairs(group) do blastItem(self, explosion, item) end
            end
            for _, web in ipairs(self.world.dynamicWebs) do
                if overlapsPointEntity(web, explosion.x-8, explosion.y-8, 32) then web.destroyed = true end
            end
            for y = math.floor((explosion.y-24)/16), math.floor((explosion.y+24)/16) do
                for x = math.floor((explosion.x-24)/16), math.floor((explosion.x+24)/16) do
                    local web = self.world.web[x .. ":" .. y]
                    if type(web) == "table" then web.destroyed = true end
                    self.world:remove("web", x, y)
                end
            end
            explosion.age = explosion.age + 1
            if explosion.age >= Timing.scaledTicks(13, self.tickRate) then explosion.alive = false end
        end
    end
    for _, enemy in ipairs(skeletons) do
        self.effects:skeletonBreak(enemy.x, enemy.y-8, items)
        enemy.deathDebrisEmitted = true
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
end

function Explosion.loadAssets(assets)
    assets.explosion = {}
    for frame = 0, 9 do
        assets.explosion[#assets.explosion + 1] = Assets.image("Effects", "sExplosion", frame)
    end
end

return Explosion
