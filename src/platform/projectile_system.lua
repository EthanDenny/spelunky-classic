local ProjectileSystem = {}
ProjectileSystem.__index = ProjectileSystem
local Depth = require("src.render.classic_depth")
local Item = require("src.platform.item")

local WEB_CREATE_FRAMES = 5
local webImages

local function loadWebImages()
    if webImages then return webImages end
    webImages = { create = {} }
    local root = "original-game-reference/source/extracted/spelunky/Sprites/Enemies/GiantSpider/"
    webImages.ball = love.graphics.newImage(root .. "sWebBall.images/image 0.png")
    webImages.web = love.graphics.newImage(root .. "sWeb.images/image 0.png")
    for frame = 0, WEB_CREATE_FRAMES - 1 do
        webImages.create[frame + 1] = love.graphics.newImage(
            string.format("%ssWebCreate.images/image %d.png", root, frame))
    end
    webImages.ball:setFilter("nearest", "nearest")
    webImages.web:setFilter("nearest", "nearest")
    for _, image in ipairs(webImages.create) do image:setFilter("nearest", "nearest") end
    return webImages
end

local function overlaps(projectile, actor)
    local half = actor:getCollisionHalfWidth()
    local top, bottom = actor:getVerticalBounds()
    return projectile.x + projectile.radius > actor.x - half
        and projectile.x - projectile.radius < actor.x + half
        and projectile.y + projectile.radius > actor.y + top
        and projectile.y - projectile.radius < actor.y + bottom
end

function ProjectileSystem.new(world)
    return setmetatable({ world = world, projectiles = {}, webs = {} }, ProjectileSystem)
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
        alive = true,
        phase = kind == "web" and "flight" or nil,
        phaseAge = 0,
    }
    self.projectiles[#self.projectiles + 1] = projectile
    return projectile
end

local function startWebCreate(projectile, stopped)
    if projectile.phase == "create" then return end
    projectile.phase = "create"
    projectile.phaseAge = 0
    if stopped then projectile.vx, projectile.vy = 0, 0 end
end

function ProjectileSystem:placeWeb(x, y)
    -- oWebBall's animation end creates oWeb at (x-8, y-8).
    local web = { x = x - 8, y = y - 8, life = 12 }
    self.world.dynamicWebs[#self.world.dynamicWebs + 1] = web
    self.webs[#self.webs + 1] = web
end

function ProjectileSystem:updateWebBall(projectile, enemies)
    local creatingAtStart = projectile.phase == "create"
    if projectile.phase == "flight" or (projectile.phase == "create"
        and (projectile.vx ~= 0 or projectile.vy ~= 0)) then
        -- oWebBall moves directly, then accelerates by 0.2 until it reaches 6.
        projectile.x = projectile.x + projectile.vx
        projectile.y = projectile.y + projectile.vy
        if projectile.vy < 6 then projectile.vy = projectile.vy + projectile.gravity end
        if self.world:solidRect(projectile.x - 4, projectile.y - 4,
            projectile.x + 4, projectile.y + 4)
            or self.world:webAtPoint(projectile.x, projectile.y) then
            startWebCreate(projectile, true)
            projectile.vx, projectile.vy = 0, 0
        end
        for _, enemy in ipairs(enemies or {}) do
            if enemy.alive and enemy.kind ~= "giant_spider"
                and overlaps(projectile, enemy) then
                startWebCreate(projectile, true)
                projectile.vx, projectile.vy = 0, 0
            end
        end
    end
    if projectile.phase == "flight" then
        if projectile.life > 0 then
            projectile.life = projectile.life - 1
        else
            startWebCreate(projectile, false)
        end
    elseif projectile.phase == "create" and creatingAtStart then
        projectile.phaseAge = projectile.phaseAge + 1
        if projectile.phaseAge >= WEB_CREATE_FRAMES then
            self:placeWeb(projectile.x, projectile.y)
            projectile.alive = false
        end
    end
end

function ProjectileSystem:updateWebs()
    for index = #self.webs, 1, -1 do
        local web = self.webs[index]
        web.life = web.life - 0.02
        if web.life <= 1 then
            for worldIndex = #self.world.dynamicWebs, 1, -1 do
                if self.world.dynamicWebs[worldIndex] == web then
                    table.remove(self.world.dynamicWebs, worldIndex)
                    break
                end
            end
            table.remove(self.webs, index)
        end
    end
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
            { damage = 0, radius = 4, life = 60, gravity = 0.2 })
        return 20
    end
    return nil
end

function ProjectileSystem:update(enemies, player, items)
    self:updateWebs()
    for _, projectile in ipairs(self.projectiles) do
        if projectile.alive then
            if projectile.kind == "web" then
                self:updateWebBall(projectile, enemies)
            else
                if projectile.kind ~= "arrow" then
                    projectile.life = projectile.life - 1
                end
                projectile.vy = projectile.vy + projectile.gravity
                local steps = math.max(1,
                    math.ceil(math.max(math.abs(projectile.vx), math.abs(projectile.vy))))
                for _ = 1, steps do
                    projectile.x = projectile.x + projectile.vx / steps
                    projectile.y = projectile.y + projectile.vy / steps
                    local solidHit = projectile.kind == "arrow"
                        and self.world:solidRect(projectile.x - 4, projectile.y - 4,
                            projectile.x + 4, projectile.y + 4)
                        or self.world:solidAtPoint(projectile.x, projectile.y)
                    if solidHit then
                        if projectile.kind == "arrow" and items then
                            local arrow = Item.new({ kind = "arrow",
                                x = (projectile.x - projectile.vx / steps) / 16,
                                y = (projectile.y - projectile.vy / steps) / 16 })
                            arrow.vx, arrow.vy = projectile.vx, projectile.vy
                            arrow.facing = projectile.vx < 0 and -1 or 1
                            items[#items + 1] = arrow
                        end
                        projectile.alive = false
                        break
                    end
                    for _, enemy in ipairs(enemies or {}) do
                        if projectile.alive and enemy ~= projectile.owner and enemy.alive
                            and overlaps(projectile, enemy) then
                            if projectile.damage > 0 then
                                enemy:damage(projectile.damage, projectile.x)
                            end
                            projectile.alive = false
                        end
                    end
                    if projectile.alive and player and projectile.owner ~= player
                        and not player:isDead() and overlaps(projectile, player) then
                        if projectile.damage > 0 then
                            player:hurt(projectile.x, projectile.damage, "projectile")
                        end
                        projectile.alive = false
                    end
                end
                if projectile.kind == "arrow" then
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
        end
    end
end

function ProjectileSystem:drawOne(projectile)
    if projectile.kind == "web" then
        local sprites = loadWebImages()
        local image = projectile.phase == "create"
            and sprites.create[math.min(WEB_CREATE_FRAMES, projectile.phaseAge + 1)]
            or sprites.ball
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, math.floor(projectile.x - 8), math.floor(projectile.y - 8))
    elseif projectile.kind == "arrow" then
        love.graphics.setColor(0.72, 0.48, 0.20, 1)
        love.graphics.rectangle("fill", math.floor(projectile.x - 5), math.floor(projectile.y), 10, 1)
    else
        love.graphics.setColor(1, 0.86, 0.34, 1)
        love.graphics.rectangle("fill", math.floor(projectile.x - 1), math.floor(projectile.y - 1), 3, 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function ProjectileSystem:submit(queue)
    for _, web in ipairs(self.webs) do
        local current = web
        queue:add(Depth.entity("web"), function()
            love.graphics.setColor(1, 1, 1, current.life / 12)
            love.graphics.draw(loadWebImages().web, math.floor(current.x), math.floor(current.y))
            love.graphics.setColor(1, 1, 1, 1)
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
