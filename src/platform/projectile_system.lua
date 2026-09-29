local ProjectileSystem = {}
ProjectileSystem.__index = ProjectileSystem

local function overlaps(projectile, actor)
    local half = actor:getCollisionHalfWidth()
    local top, bottom = actor:getVerticalBounds()
    return projectile.x + projectile.radius > actor.x - half
        and projectile.x - projectile.radius < actor.x + half
        and projectile.y + projectile.radius > actor.y + top
        and projectile.y - projectile.radius < actor.y + bottom
end

function ProjectileSystem.new(world)
    return setmetatable({ world = world, projectiles = {} }, ProjectileSystem)
end

function ProjectileSystem:spawn(kind, x, y, vx, vy, owner, options)
    options = options or {}
    local projectile = {
        kind = kind,
        x = x,
        y = y,
        vx = vx,
        vy = vy or 0,
        owner = owner,
        damage = options.damage or 1,
        radius = options.radius or 2,
        life = options.life or 60,
        gravity = options.gravity or 0,
        stun = options.stun or 0,
        alive = true,
    }
    self.projectiles[#self.projectiles + 1] = projectile
    return projectile
end

function ProjectileSystem:fireWeapon(kind, player, owner)
    local direction = player.facing
    local x, y = player.x + direction * 7, player.y - 2
    if kind == "pistol" then
        self:spawn("bullet", x, y, direction * 12, 0, owner or player,
            { damage = 2, life = 35 })
        player.vx = player.vx - direction * 1.5
        return 10
    elseif kind == "shotgun" then
        for index = -2, 2 do
            self:spawn("pellet", x, y, direction * (10 + math.abs(index) * 0.4), index * 0.35,
                owner or player, { damage = 1, life = 22 })
        end
        player.vx = player.vx - direction * 4
        return 24
    elseif kind == "bow" then
        self:spawn("arrow", x, y, direction * 10, 0, owner or player,
            { damage = 2, gravity = 0.12, radius = 3, life = 90 })
        return 18
    elseif kind == "web_cannon" then
        self:spawn("web", x, y, direction * 7, 0, owner or player,
            { damage = 0, radius = 4, life = 60, stun = 90 })
        return 20
    end
    return nil
end

function ProjectileSystem:update(enemies, player)
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            projectile.life = projectile.life - 1
            projectile.vy = projectile.vy + projectile.gravity
            local steps = math.max(1, math.ceil(math.max(math.abs(projectile.vx), math.abs(projectile.vy))))
            for _ = 1, steps do
                projectile.x = projectile.x + projectile.vx / steps
                projectile.y = projectile.y + projectile.vy / steps
                if self.world:solidAtPoint(projectile.x, projectile.y) then
                    if projectile.kind == "web" then
                        self.world:set("web", math.floor(projectile.x / 16), math.floor(projectile.y / 16))
                    end
                    projectile.alive = false
                    break
                end
                for _, enemy in ipairs(enemies or {}) do
                    if projectile.alive and enemy ~= projectile.owner and enemy.alive
                        and overlaps(projectile, enemy) then
                        if projectile.kind == "web" and enemy.web then enemy:web(projectile.stun) end
                        if projectile.damage > 0 then enemy:damage(projectile.damage, projectile.x) end
                        projectile.alive = false
                    end
                end
                if projectile.alive and player and projectile.owner ~= player and not player:isDead()
                    and overlaps(projectile, player) then
                    if projectile.kind == "web" then player:web(projectile.stun) end
                    if projectile.damage > 0 then player:hurt(projectile.x, projectile.damage, "projectile") end
                    projectile.alive = false
                end
            end
            if projectile.life <= 0 then projectile.alive = false end
        end
    end
end

function ProjectileSystem:draw()
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            if projectile.kind == "web" then
                love.graphics.setColor(0.85, 0.88, 0.82, 1)
                love.graphics.circle("line", math.floor(projectile.x), math.floor(projectile.y), 4)
            elseif projectile.kind == "arrow" then
                love.graphics.setColor(0.72, 0.48, 0.20, 1)
                love.graphics.rectangle("fill", math.floor(projectile.x - 5), math.floor(projectile.y), 10, 1)
            else
                love.graphics.setColor(1, 0.86, 0.34, 1)
                love.graphics.rectangle("fill", math.floor(projectile.x - 1), math.floor(projectile.y - 1), 3, 2)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ProjectileSystem
