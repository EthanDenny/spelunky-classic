local Collision = require("src.platform.entity_collision")
local Body = {}

function Body.overlaps(projectile, actor)
    return Collision.touching(projectile, actor, actor.spriteName and not actor.config and actor or nil)
end

function Body.step(self, projectile, spec, enemies, player, items)
    -- oBullet moves once by its floating-point velocity before collision events.
    projectile.x, projectile.y = projectile.x+projectile.vx, projectile.y+projectile.vy
    if Collision.solid(self.world, projectile, player) then
        if spec.impact and self.onImpact then self.onImpact("solid", projectile) end
        projectile.alive = false
        return
    end
    for _, item in ipairs(items or {}) do
        if not item.opened and item.definition and item.definition.breakOnBullet
            and Collision.touching(projectile, item, player) and self.onHitItem then
            self.onHitItem(item, projectile)
        end
    end
    for _, enemy in ipairs(enemies or {}) do
        if (not projectile.safe or enemy.kind == "damsel") and enemy.kind ~= "ghost"
            and (enemy.alive or enemy.corpse)
            and not (enemy.kind == "damsel" and enemy.invincible == 1)
            and Collision.touching(projectile, enemy, player) then
            local hit = enemy:damage(projectile.damage, projectile.x, {
                kind = "bullet", vx = projectile.vx*(enemy.kind == "damsel" and 0.3 or 1),
                vy = enemy.kind == "damsel" and -6 or -4,
            })
            if hit and spec.impact and self.onImpact then self.onImpact("enemy", projectile, enemy) end
            projectile.alive = false
            return
        end
    end
    if player and not player:isDead() and player.state ~= "exiting"
        and Collision.touching(projectile, player, player) then
        if player:hurt(projectile.x, projectile.damage, "projectile", 20, "bullet", projectile.vx)
            and spec.impact and self.onImpact then self.onImpact("player", projectile, player) end
        projectile.alive = false
    end
    if not spec.persistent then
        projectile.life = projectile.life-1
        if projectile.life <= 0 then projectile.alive = false end
    end
end

return Body
