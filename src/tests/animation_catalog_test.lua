local Catalog = require("src.animation.original_catalog")

local Test = {}

local function findAnimation(page, name)
    for _, animation in ipairs(page.animations) do
        if animation.name == name then
            return animation
        end
    end
end

function Test.run()
    assert(Catalog.roomSpeed == 30, "Original gameplay animation timing requires 30 steps/s")
    assert(#Catalog.pages == 82, "Expected all 82 mapped animation entity pages")
    assert(Catalog.pages[1].id == "player", "Player must be the default animation page")

    local pageIds = {}
    local sprites = {}
    local spriteCount = 0
    local animationCount = 0
    local frameCount = 0

    for _, page in ipairs(Catalog.pages) do
        assert(not pageIds[page.id], "Duplicate animation page id: " .. page.id)
        pageIds[page.id] = true
        assert(page.name and page.name ~= "", "Animation page is missing a display name")
        assert(page.category and page.category ~= "", page.name .. " has no category")
        assert(#page.animations > 0, page.name .. " has no animations")

        for _, animation in ipairs(page.animations) do
            animationCount = animationCount + 1
            assert(animation.name and animation.name ~= "", page.name .. " has an unnamed animation")
            assert(animation.pattern and animation.pattern ~= "", animation.name .. " has no playback pattern")
            assert(type(animation.previewFps) == "number" and animation.previewFps >= 0,
                animation.name .. " has no source playback rate")
            assert(type(animation.speedRules) == "table", animation.name .. " has no timing rules")

            local sideCount = 0
            for _, sideName in ipairs({ "left", "right", "neutral" }) do
                local side = animation[sideName]
                if side then
                    sideCount = sideCount + 1
                    assert(not sprites[side.sprite], "Sprite appears in multiple animations: " .. side.sprite)
                    sprites[side.sprite] = true
                    spriteCount = spriteCount + 1
                    assert(type(side.originX) == "number" and type(side.originY) == "number",
                        side.sprite .. " is missing its GameMaker origin")
                    assert(side.width > 0 and side.height > 0, side.sprite .. " has invalid dimensions")
                    assert(#side.frames > 1, side.sprite .. " is not an animation")

                    for _, path in ipairs(side.frames) do
                        frameCount = frameCount + 1
                        assert(love.filesystem.getInfo(path, "file"), "Missing extracted frame: " .. path)
                    end
                end
            end
            assert(sideCount > 0, page.name .. "/" .. animation.name .. " has no sprite sequence")
        end
    end

    assert(animationCount == 194, "Expected 194 mapped animations")
    assert(spriteCount == 208, "Expected 208 catalog sprites after redundant Right removal")
    assert(frameCount == 1484, "Expected 1,484 catalog frames after redundant Right removal")

    for sprite in pairs(sprites) do
        assert(not sprite:find("Right"), "Redundant Right sprite remains in catalog: " .. sprite)
    end

    local player = Catalog.pages[1]
    assert(#player.animations == 15, "Expected all 15 player animation groups")
    local run = assert(findAnimation(player, "Run"), "Player Run animation is missing")
    assert(run.left and run.speedRules[1] == "abs(xVel) * 0.1 + 0.1 (capped at 1)",
        "Player Run must retain its velocity-driven timing formula")
    local attack = assert(findAnimation(player, "Attack"), "Player Attack animation is missing")
    assert(attack.previewFps == 18 and attack.pattern == "one-shot / state transition",
        "Player Attack must retain its 0.6 image_speed and Animation End transition")

    local spider
    for _, page in ipairs(Catalog.pages) do
        if page.id == "spider" then
            spider = page
            break
        end
    end
    assert(spider and #spider.animations == 3,
        "Spider, Spider Drowning, and Spider Flip must share the mapped Spider page")

    local caravan
    for _, page in ipairs(Catalog.pages) do
        if page.id == "caravan" then
            caravan = page
            break
        end
    end
    assert(caravan and #caravan.animations == 3,
        "The three Caravan sprites must have a page separate from Caveman")
end

return Test
