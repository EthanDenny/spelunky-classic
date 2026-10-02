local Body = {}

function Body.overlaps(projectile, actor)
    local half = actor:getCollisionHalfWidth()
    local top, bottom = actor:getVerticalBounds()
    return projectile.x + projectile.radius > actor.x - half
        and projectile.x - projectile.radius < actor.x + half
        and projectile.y + projectile.radius > actor.y + top
        and projectile.y - projectile.radius < actor.y + bottom
end

function Body.step(self, projectile, spec, enemies, player, items)
    if not spec.persistent then
        projectile.life = projectile.life - 1
    end
    if not spec.materialize then projectile.vy = projectile.vy + projectile.gravity end
    local steps = math.max(1,
        math.ceil(math.max(math.abs(projectile.vx), math.abs(projectile.vy))))
    for _ = 1, steps do
        projectile.x = projectile.x + projectile.vx / steps
        projectile.y = projectile.y + projectile.vy / steps
        local solidHit = spec.solidBounds ~= nil
            and self.world:solidRect(projectile.x - spec.solidBounds, projectile.y - spec.solidBounds,
                projectile.x + spec.solidBounds, projectile.y + spec.solidBounds)
            or self.world:solidAtPoint(projectile.x, projectile.y)
        if solidHit then
            if spec.materialize ~= nil then
                spec.materialize(projectile, items,
                    projectile.x - projectile.vx / steps,
                    projectile.y - projectile.vy / steps)
            end
            if spec.impact ~= nil and self.onImpact then
                self.onImpact("solid", projectile)
            end
            projectile.alive = false
            break
        end
        if spec.materialize ~= nil
            and self.world:webRect(projectile.x - spec.solidBounds, projectile.y - spec.solidBounds,
                projectile.x + spec.solidBounds, projectile.y + spec.solidBounds) then
            spec.materialize(projectile, items, projectile.x, projectile.y, 0)
            if items then
                items[#items].vx, items[#items].vy = 0, 0
                projectile.alive = false
            end
            break
        end
        if spec.impact ~= nil then
            for _, item in ipairs(items or {}) do
                if not item.opened and not item.held
                    and item.definition and item.definition.breakOnBullet
                    and Body.overlaps(projectile, item) and self.onHitItem then
                    self.onHitItem(item, projectile)
                end
            end
        end
        for _, enemy in ipairs(enemies or {}) do
            if projectile.alive and (not projectile.safe or enemy.kind == "damsel")
                and enemy ~= projectile.owner and enemy.alive
                and not (spec.persistent and enemy.kind == "ghost")
                and not (spec.impact and enemy.kind == "damsel" and enemy.invincible == 1)
                and Body.overlaps(projectile, enemy) then
                if projectile.damage > 0 then
                    local impulse = spec.impact ~= nil and {
                        kind = "bullet", vx = projectile.vx, vy = enemy.kind == "damsel" and -6 or -4,
                    } or nil
                    local hit
                    if spec.materialize then
                        hit = require("src.platform.physical_body").strikeEnemy(projectile, enemy)
                    else hit = enemy:damage(projectile.damage, projectile.x, impulse) end
                    if hit and spec.impact ~= nil then
                        if self.onImpact then self.onImpact("enemy", projectile, enemy) end
                    end
                end
                if spec.materialize ~= nil then
                    spec.materialize(projectile, items, projectile.x, projectile.y, 0.3)
                end
                projectile.alive = false
            end
        end
        if projectile.alive and player and projectile.owner ~= player
            and not player:isDead() and player.state ~= "exiting" and Body.overlaps(projectile, player) then
            if projectile.damage > 0 then
                if spec.impact ~= nil then
                    if player:hurt(projectile.x, projectile.damage,
                        "projectile", 20, "bullet", projectile.vx)
                        and self.onImpact then
                        self.onImpact("player", projectile, player)
                    end
                else
                    player:hurt(projectile.x, projectile.damage, "projectile")
                end
            end
            projectile.alive = false
        end
    end
    if spec.materialize then projectile.vy = math.min(8, projectile.vy+projectile.gravity) end
    if spec.nextGravity then projectile.gravity = spec.nextGravity end
    if spec.persistent then
        local margin = 32
        if projectile.x < -margin or projectile.x > self.world.width * self.world.tileSize + margin
            or projectile.y < -margin
            or projectile.y > self.world.height * self.world.tileSize + margin then
            projectile.alive = false
        end
    elseif projectile.life <= 0 then
        projectile.alive = false
    end
end

return Body
