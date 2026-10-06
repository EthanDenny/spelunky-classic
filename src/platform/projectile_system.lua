local ProjectileSystem = {}
ProjectileSystem.__index = ProjectileSystem
local Depth = require("src.render.classic_depth")
local Types = require("src.platform.projectiles.types")
local Body = require("src.platform.projectile_body")
local WebBall = require("src.platform.projectiles.web_ball")
local Web = require("src.platform.environment.web")
local Flash = require("src.platform.projectiles.muzzle_flash")

ProjectileSystem.placeWeb = Web.place
ProjectileSystem.updateWebs = Web.update
ProjectileSystem.updateWebBall = WebBall.update

function ProjectileSystem.new(world)
    return setmetatable({ world = world, projectiles = {}, webs = {}, flashes = {} }, ProjectileSystem)
end

function ProjectileSystem:spawn(kind, x, y, vx, vy, owner, options)
    options = options or {}
    local definition = assert(Types[kind], "Unknown projectile: " .. tostring(kind))
    local projectile = {
        definition = definition,
        kind = kind,
        x = x,
        y = y,
        vx = vx,
        vy = vy or 0,
        owner = owner,
        safe = options.safe or false,
        damage = options.damage or 1,
        radius = options.radius or 2,
        life = options.life or 60,
        gravity = options.gravity or 0,
        alive = true,
        phase = definition.projectile.phase,
        phaseAge = 0,
    }
    self.projectiles[#self.projectiles + 1] = projectile
    return projectile
end

function ProjectileSystem:fireGun(spec, player, owner, random)
    local direction = player.facing
    local x = player.x + (spec.muzzleOffset and direction * spec.muzzleOffset
        or direction < 0 and -9 or 8)
    local y = player.y - 2
    self.flashes[#self.flashes + 1] = {
        x = x, y = player.y + (spec.projectile == "web" and 0 or 1),
        direction = direction, age = 0,
    }
    for _ = 1, spec.count do
        local speed = random and random:random(spec.minSpeed, spec.maxSpeed)
            or spec.minSpeed
        local vx = direction * speed + player.vx
        if direction < 0 then vx = math.min(-spec.minSpeed, vx)
        else vx = math.max(spec.minSpeed, vx) end
        local vy = spec.verticalSpread and random
            and random:random() - random:random() or 0
        self:spawn(spec.projectile, x, y,
            vx, vy, owner or player,
            { damage = spec.damage,
                life = spec.projectile == "web" and random:random(20, 100) or spec.life,
                gravity = spec.gravity, radius = spec.radius })
    end
    if player.state ~= "hanging" and player.state ~= "climbing" then
        player.vy = player.vy - 1
        player.vx = player.vx - direction * spec.recoil
    end
    return spec.cooldown
end

function ProjectileSystem:update(enemies, player, items)
    self:updateWebs()
    for index = #self.flashes, 1, -1 do
        local flash = self.flashes[index]
        flash.age = flash.age + 0.8
        if flash.age >= 10 then table.remove(self.flashes, index) end
    end
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            local definition = projectile.definition or Types[projectile.kind]
            local update = definition.updateProjectile or definition.update
            if update then update(self, projectile, enemies, items, player)
            else Body.step(self, projectile, definition.projectile, enemies, player, items) end
        end
    end
end

function ProjectileSystem:drawOne(projectile)
    local definition = projectile.definition or Types[projectile.kind]
    definition.drawProjectile(projectile)
    love.graphics.setColor(1, 1, 1, 1)
end

function ProjectileSystem:submit(queue)
    for _, flash in ipairs(self.flashes) do
        local current = flash
        queue:add(0, function()
            Flash.draw(current)
        end)
    end
    for _, web in ipairs(self.webs) do
        local current = web
        queue:add(Depth.entity("web"), function()
            Web.draw(self, current)
        end)
    end
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            local current = projectile
            queue:add(Depth.entity(current.kind == "web" and "web_ball" or current.kind),
                function() self:drawOne(current) end)
        end
    end
end

return ProjectileSystem
