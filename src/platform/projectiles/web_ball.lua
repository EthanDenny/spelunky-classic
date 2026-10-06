local WebBall = { depth = 1, projectile = { phase = "flight" } }
local Body = require("src.platform.projectile_body")
local WEB_CREATE_FRAMES = 5
local webImages

function WebBall.collisionSprite(projectile)
    return projectile.phase == "create" and "sWebCreate" or "sWebBall",
        projectile.phase == "create" and projectile.phaseAge or 0,
        projectile.x, projectile.y, false
end

function WebBall.loadImages()
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

local function startWebCreate(projectile, stopped)
    if projectile.phase == "create" then return end
    projectile.phase = "create"
    projectile.phaseAge = 0
    if stopped then projectile.vx, projectile.vy = 0, 0 end
end

function WebBall.update(self, projectile, enemies, items)
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
                and Body.overlaps(projectile, enemy) then
                startWebCreate(projectile, true)
                projectile.vx, projectile.vy = 0, 0
            end
        end
        for _, item in ipairs(items or {}) do
            if not item.opened and Body.overlaps(projectile, item) then
                startWebCreate(projectile, true)
            end
        end
        if self.world.water and self.world:cellAt("water", projectile.x, projectile.y) then
            startWebCreate(projectile, true)
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

function WebBall.drawProjectile(projectile)
    local sprites = WebBall.loadImages()
    local image = projectile.phase == "create"
        and sprites.create[math.min(WEB_CREATE_FRAMES, projectile.phaseAge + 1)]
        or sprites.ball
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor(projectile.x - 8), math.floor(projectile.y - 8))
end

return WebBall
