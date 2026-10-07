-- oGiantSpiderHang converts to oGiantSpider without moving its top-left corner.
-- Source: Objects/Enemies/oGiantSpider{Hang}.events and their sprite resources.
local Physics = require("src.platform.physical_body")
local Collision = require("src.platform.entity_collision")
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
    return player and Collision.distance(spider, player, player) or math.huge
end

function GiantSpider.initialize(spider, seed, random)
    spider.height = 16 -- oGiantSpiderHang uses a 32x16 sprite and collision box.
    spider.state = "hang"
    spider.timer = 0
    spider.spriteName = "sGiantSpiderHang"
    spider.animation = 0
    spider.imageSpeed = 0.4
    spider.rng = random or require("src.platform.source_random").new(seed)
    spider.squirtTimer = 0
    spider.squirtFired = false
end

local function launch(spider, player, minimum, maximum)
    spider.vy = -spider.rng:random(minimum, maximum)
    spider.facing = player and player.x < spider.x and -1 or 1
    spider.vx = spider.facing * 2.5
    setSprite(spider, "sGiantSpider")
end

function GiantSpider.advanceAnimation(spider)
    spider.animation = spider.animation + spider.imageSpeed
    if spider.spriteName == "sGiantSpiderFlip" and spider.animation >= SPRITES.sGiantSpiderFlip.count then
        setSprite(spider, "sGiantSpider", 0.4)
    elseif spider.spriteName == "sGiantSpiderSquirt" then
        if spider.animation >= SPRITES.sGiantSpiderSquirt.count then
            spider.state = "idle"
            setSprite(spider, "sGiantSpider", 0.4)
        end
    end
end

function GiantSpider.alarm(spider, world, player)
    if spider.timer > 0 then
        spider.timer = spider.timer-1
        if spider.timer == 0 and spider.spriteName ~= "sGiantSpiderSquirt" then
            spider.state = "bounce"
            setSprite(spider, "sGiantSpiderJump")
            if Physics.probe(world, spider, "y", 1) then launch(spider, player, 2, 5) end
        end
    end
end

function GiantSpider.step(spider, world, player, context)
    if spider.state ~= "hang" then spider.whipped = math.max(0, (spider.whipped or 0)-1) end
    if spider.state == "hang" then
        local top = spider.y - spider.height
        local left = spider.x - spider.width / 2
        local ceiling = world:solidAtPoint(left, top - 16)
        local nearPlayer = player and player.y > top
            and math.abs(player.x-spider.x) < 8 and activeDistance(spider, player) < 90
        if spider.hp < 10 or not ceiling or nearPlayer then
            -- The source creates oGiantSpider at the same x,y as the hanging
            -- object. Our physics position is bottom-centered, so add 16.
            spider.y = spider.y + 16
            spider.height = 32
            spider.whipped = 10
            spider.state, spider.timer = "idle", 0
            spider.squirtTimer = spider.rng:random(100, 1000)
            setSprite(spider, "sGiantSpiderFlip", 0.8)
            if context and context.sounds then context.sounds:play("giant_spider") end
        end
        return
    end

    Physics.move(world, spider, "x", spider.vx)
    Physics.move(world, spider, "y", spider.vy)
    spider.vy = math.min(10, spider.vy+0.3)
    local right = Physics.probe(world, spider, "x", 1)
    local left = Physics.probe(world, spider, "x", -1)
    local grounded = Physics.probe(world, spider, "y", 1)
    local ceiling = Physics.probe(world, spider, "y", -1)
    if right then spider.vx = 1 end
    if left then spider.vx = -1 end
    if ceiling and grounded and spider.state ~= "crawl" then
        spider.state = "crawl"
        spider.vx = player and player.x < spider.x and -1 or 1
    end
    if spider.squirtTimer > 0 then spider.squirtTimer = spider.squirtTimer-1 end
    if spider.state == "idle" then
        if spider.spriteName ~= "sGiantSpiderFlip" then setSprite(spider, "sGiantSpider") end
        spider.timer = spider.rng:random(5, 20)
        spider.state = spider.squirtTimer == 0 and "squirt" or "recover"
        spider.squirtFired = false
    elseif spider.state == "crawl" then
        setSprite(spider, "sGiantSpiderCrawl")
        if not ceiling or not grounded then spider.state = "idle"
        elseif right then spider.vx = -1
        elseif left then spider.vx = 1 end
    elseif spider.state == "squirt" then
        setSprite(spider, "sGiantSpiderSquirt")
        if spider.squirtTimer == 0 and spider.animation >= 5 then
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
    elseif spider.state == "recover" then
        if grounded then spider.vx = 0 end
    elseif spider.state == "bounce" and activeDistance(spider, player) < 120 then
        setSprite(spider, "sGiantSpiderJump")
        if grounded then
            launch(spider, player, 3, 6)
            if context and context.sounds then context.sounds:play("spider_jump") end
            if spider.rng:random(1, 4) == 1 then
                spider.state, spider.vx, spider.vy = "idle", 0, 0
            end
        end
    else spider.state = "idle" end
    if ceiling then spider.vy = 1 end
    GiantSpider.advanceAnimation(spider)
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
    alarm = GiantSpider.alarm,
    advanceAnimation = GiantSpider.advanceAnimation,
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
