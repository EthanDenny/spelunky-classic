-- oGiantSpiderHang converts to oGiantSpider without moving its top-left corner.
-- Source: Objects/Enemies/oGiantSpider{Hang}.events and their sprite resources.
local GiantSpider = {}

local SPRITES = {
    sGiantSpiderHang = { count = 1, path = "assets/original/entities/giant_spider.png" },
    sGiantSpiderFlip = { count = 9, directory = "assets/original/animations/sGiantSpiderFlip/" },
    sGiantSpider = { count = 4, directory = "assets/original/animations/sGiantSpider/" },
    sGiantSpiderJump = { count = 1, path =
        "original-game-reference/source/extracted/spelunky/Sprites/Enemies/GiantSpider/sGiantSpiderJump.images/image 0.png" },
    sGiantSpiderCrawl = { count = 4, directory = "assets/original/animations/sGiantSpiderCrawl/" },
    sGiantSpiderSquirt = { count = 8, directory = "assets/original/animations/sGiantSpiderSquirt/" },
}

local images

local function loadSprites()
    if images then return images end
    images = {}
    for name, spec in pairs(SPRITES) do
        local frames = {}
        for index = 0, spec.count - 1 do
            local path = spec.path or string.format("%s%03d.png", spec.directory, index)
            local image = love.graphics.newImage(path)
            image:setFilter("nearest", "nearest")
            frames[#frames + 1] = image
        end
        images[name] = frames
    end
    return images
end

local function setSprite(spider, name, speed)
    if spider.spriteName ~= name then
        spider.spriteName = name
        spider.animation = 0
    end
    spider.imageSpeed = speed or spider.imageSpeed
end

local function activeDistance(spider, player)
    if not player then return math.huge end
    local dx, dy = player.x - spider.x, player.y - (spider.y - 16)
    return math.sqrt(dx * dx + dy * dy)
end

function GiantSpider.initialize(spider, seed)
    spider.height = 16 -- oGiantSpiderHang uses a 32x16 sprite and collision box.
    spider.state = "hang"
    spider.spriteName = "sGiantSpiderHang"
    spider.animation = 0
    spider.imageSpeed = 0.4
    spider.rng = love.math.newRandomGenerator(seed or 1)
    spider.squirtTimer = spider.rng:random(100, 1000)
    spider.squirtFired = false
end

local function launch(spider, player, minimum, maximum)
    spider.vy = -spider.rng:random(minimum, maximum)
    spider.facing = player and player.x < spider.x and -1 or 1
    spider.vx = spider.facing * 2.5
    setSprite(spider, "sGiantSpider", 0.4)
end

local function advanceAnimation(spider, context)
    spider.animation = spider.animation + spider.imageSpeed
    if spider.spriteName == "sGiantSpiderFlip" and spider.animation >= SPRITES.sGiantSpiderFlip.count then
        setSprite(spider, "sGiantSpider", 0.4)
    elseif spider.spriteName == "sGiantSpiderSquirt" then
        if not spider.squirtFired and spider.animation >= 5 then
            spider.squirtFired = true
            if context and context.projectiles then
                -- oWebBall Create rolls vertical speed before horizontal speed and sign.
                local vy = -(spider.rng:random() * 3 + 1)
                local vx = spider.rng:random(1, 3)
                    * (spider.rng:random(1, 2) == 1 and -1 or 1)
                context.projectiles:spawn("web", spider.x, spider.y - 16,
                    vx, vy, spider,
                    { damage = 0, radius = 4, life = spider.rng:random(20, 100),
                        gravity = 0.2 })
            end
            spider.squirtTimer = spider.rng:random(100, 1000)
        end
        if spider.animation >= SPRITES.sGiantSpiderSquirt.count then
            spider.state = "idle"
            setSprite(spider, "sGiantSpider", 0.4)
        end
    end
end

function GiantSpider.step(spider, world, player, context)
    if spider.state ~= "hang" then spider.whipped = math.max(0, (spider.whipped or 0)-1) end
    if spider.state == "hang" then
        local top = spider.y - spider.height
        local left = spider.x - spider.width / 2
        local ceiling = world:solidAtPoint(left, top - 16)
        local dx, dy = player and player.x - spider.x or 0,
            player and player.y - (top + 8) or 0
        local nearPlayer = player and player.y > top
            and math.abs(dx) < 8 and dx * dx + dy * dy < 90 * 90
        if spider.hp < 10 or not ceiling or nearPlayer then
            -- The source creates oGiantSpider at the same x,y as the hanging
            -- object. Our physics position is bottom-centered, so add 16.
            spider.y = spider.y + 16
            spider.height = 32
            spider.whipped = 10
            spider.state = "recover"
            spider.timer = spider.rng:random(5, 20)
            setSprite(spider, "sGiantSpiderFlip", 0.8)
        end
        return
    end

    local grounded = spider:groundPhysics(world, 0.3, 10)
    if spider.squirtTimer > 0 then spider.squirtTimer = spider.squirtTimer - 1 end

    if spider.state ~= "crawl" and grounded
        and world:collidesSolid(spider, spider.x, spider.y - 1) then
        spider.state = "crawl"
        spider.vx = player and player.x < spider.x and -1 or 1
    end
    if spider.state == "crawl" then
        setSprite(spider, "sGiantSpiderCrawl", 0.4)
        if not grounded or not world:collidesSolid(spider, spider.x, spider.y - 1) then
            spider.state = "idle"
        end
    elseif spider.state == "recover" then
        if grounded then spider.vx = 0 end
        spider.timer = spider.timer - 1
        if spider.timer <= 0 then
            spider.state = "bounce"
            setSprite(spider, "sGiantSpiderJump", 0.4)
            if grounded then launch(spider, player, 2, 5) end
        end
    elseif spider.state == "bounce" then
        if activeDistance(spider, player) >= 120 then
            spider.state = "idle"
        else
            setSprite(spider, "sGiantSpiderJump", 0.4)
            if grounded then
                launch(spider, player, 3, 6)
                if spider.rng:random(1, 4) == 1 then
                    spider.state = "idle"
                    spider.vx, spider.vy = 0, 0
                end
            end
        end
    elseif spider.state == "idle" then
        setSprite(spider, "sGiantSpider", 0.4)
        spider.state = spider.squirtTimer == 0 and "squirt" or "recover"
        if spider.state == "squirt" then
            spider.squirtFired = false
            setSprite(spider, "sGiantSpiderSquirt", 0.4)
        else
            spider.timer = spider.rng:random(5, 20)
        end
    end
    advanceAnimation(spider, context)
end

function GiantSpider.draw(spider)
    local frames = loadSprites()[spider.spriteName]
    local frame = (math.floor(spider.animation) % #frames) + 1
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(frames[frame], math.floor(spider.x - spider.width / 2),
        math.floor(spider.y - spider.height))
end


local Spider = {
    creatureConfig = { hp = 10, width = 32 },
    creatureVerticalBounds = { -16, 0 },
    stepCreature = GiantSpider.step,
    drawCreature = GiantSpider.draw,
    initializeCreature = GiantSpider.initialize,
}

function Spider.creatureHalfWidth(self)
    return self.state == "hang" and 16 or math.max(3, self.width / 2 - 2)
end

function Spider.canReachPlayer(self, player)
    local center = self.state == "hang" and self.x - 8 or self.x
    local reach = self.state == "hang" and 12 or 16
    return math.abs(player.x - center) <= reach
end

function Spider.damage(self, amount, sourceX, hit)
    if hit and self.state ~= "hang"
        and (hit.kind == "item" or hit.kind == "whip" and hit.phase ~= "back") then
        if (self.whipped or 0) > 0 then return false end
        self.whipped, amount = 10, 1
    end
    self.hp = self.hp - (amount or 1)
    if self.hp <= 0 then self.alive, self.state = false, "dead" end
    if self.alive and hit then self.vx, self.vy = hit.vx or self.vx, hit.vy or self.vy end
    return true
end

function Spider.contactPlayer(self, player)
    -- The hanging mask uses a shifted center; active contact has a different
    -- damage/launch rule in the Classic object collision events.
    local active = self.state ~= "hang"
    local hurt = player:hurt(self.x - self.width / 2,
        active and 2 or 1, self.kind, nil, "enemy_contact")
    if hurt and active and player.y < self.y - self.height then player.vy = -6 end
    return hurt and "hurt" or "invincible"
end

Spider.depth = 40
Spider.deathBlood = 4
function Spider.deathY(body) return body.y-body.height+24 end
function Spider.onDeath(body, game)
    local y = Spider.deathY(body)
    game:spawnEntity("paste", body.x, y)
    local random = game.effects.random
    for _ = 1, random:random(1,3) do
        local gem = game:spawnEntity(({ "emerald_big", "sapphire_big", "ruby_big" })[
            random:random(1,3)], body.x, y)
        gem.vx, gem.vy = random:random(0,3)-random:random(0,3), -2
    end
end

return Spider
