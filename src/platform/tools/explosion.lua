local Assets = require("src.platform.object_assets")
local Timing = require("src.platform.tool_timing")

local Collision = require("src.platform.entity_collision")
local Explosion = { depth = 1 }

function Explosion.collisionSprite(explosion)
    return "sExplosion", explosion.age*0.8*30/(explosion.tickRate or 30),
        explosion.x, explosion.y, false
end

local function blastTerrain(self, explosion)
    if not require("src.platform.activity").contains(self.world, explosion) then return {} end
    local contacts = {}
    local destroyed = self.world:destroyTerrain(explosion.x, explosion.y, 24,
        function(left, top, right, bottom)
            if not Collision.overlaps(explosion, nil, left, top, right, bottom) then return false end
            contacts[#contacts+1] = { x = left/16, y = top/16 }
            return true
        end)
    if #contacts > 0 then self.world:cleanExplosionTerrain(contacts) end
    return destroyed
end


function Explosion.spawn(self, x, y)
    local explosion = { kind = "explosion", definition = Explosion,
        x = x, y = y, age = 0, tickRate = self.tickRate, alive = true }
    local destroyed = blastTerrain(self, explosion)
    if self.game then self.game.shakeTicks = math.max(self.game.shakeTicks or 0, 5) end
    if not self.world.game then
        for _, cell in ipairs(destroyed) do
            self.effects:terrainBreak(cell.pixelX or (cell.x + 0.5) * self.world.tileSize,
                cell.pixelY or (cell.y + 0.5) * self.world.tileSize, self.world.tileSize, cell.entity)
        end
    end
    self.explosions[#self.explosions+1] = explosion
    self.effects:explosion(x, y)
    if self.explosionSound then self.explosionSound:clone():play() end
    if self.onExplosion then self:onExplosion(x, y, 24, explosion) end
end

local function release(self, item)
    item.held = false
    if self.game and self.game.heldItem == item then
        self.game.heldItem, self.game.cycleItemKind = nil, nil
    end
    if self.game and self.game.heldNpc == item then self.game.heldNpc = nil end
end

local function blastItem(self, explosion, item)
    if item.alive == false or item.opened and item.kind ~= "chest" or item.deployed
        or not Collision.touching(explosion, item, self.game and self.game.player) then return end
    release(self, item)
    if item.kind == "arrow" or item.kind == "jar" or item.kind == "skull" then
        if item.kind == "jar" and self.game then
            self.game:openContainer(item)
        elseif item.kind == "skull" then self.effects:skullBreak(item.x, item.y) end
        item.alive, item.visible, item.opened = false, false, true
    elseif item.kind == "bomb" then
        item.timer = Timing.scaledTicks(self.effects.random:random(4,8), self.tickRate)
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
    local playerContact, nearest, distance
    if not player:isDead() and player.state ~= "exiting" then
        for _, explosion in ipairs(self.explosions) do
            if explosion.alive then
                playerContact = playerContact or Collision.overlaps(explosion, player,
                    player.x-8, player.y-8, player.x+9, player.y+9, true)
                local d = (explosion.x-player.x)^2+(explosion.y-player.y)^2
                if not distance or d < distance then nearest, distance = explosion, d end
            end
        end
    end
    if playerContact then
        local vx = (nearest.x < player.x and 1 or -1)*self.effects.random:random(4,6)
        player.invincibleTimer = 0
        player:hurt(nearest.x, 10, "explosion", 100)
        player.vx, player.vy, player.burning = vx, -6, 50
        self.effects:blood(player.x, player.y, 1)
    end
    for _, explosion in ipairs(self.explosions) do
        if explosion.alive then
            local destroyed = blastTerrain(self, explosion)
            if not self.world.game then
                for _, cell in ipairs(destroyed) do
                    self.effects:terrainBreak((cell.x+0.5)*16, (cell.y+0.5)*16, 16, cell.entity)
                end
            end
            if self.onExplosion then self:onExplosion(explosion.x, explosion.y, 24, explosion) end
            for _, enemy in ipairs(enemies or {}) do
                if enemy.kind ~= "ghost" and (enemy.alive or enemy.corpse)
                    and not (enemy.invincible and enemy.invincible ~= 0)
                    and Collision.touching(explosion, enemy, player) then
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
                if Collision.overlaps(explosion, nil, web.x, web.y, web.x+16, web.y+16) then
                    web.destroyed = true
                end
            end
            for y = math.floor((explosion.y-24)/16), math.floor((explosion.y+24)/16) do
                for x = math.floor((explosion.x-24)/16), math.floor((explosion.x+24)/16) do
                    local web = self.world.web[x .. ":" .. y]
                    if web and Collision.overlaps(explosion, nil, x*16, y*16, x*16+16, y*16+16) then
                        if type(web) == "table" then web.destroyed = true end
                        self.world:remove("web", x, y)
                    end
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
