local Test = {}

function Test.run(app)
    local hud = app.screens.full_level_playtest.hud
    hud:loadAssets()
    local originalDraw = love.graphics.draw
    local drawn = {}
    love.graphics.draw = function(image, x, y)
        drawn[#drawn + 1] = { image = image, x = x, y = y }
    end
    local ok, err = xpcall(function()
        for _, kind in ipairs({ "crate", "gold_idol", "chest" }) do
            drawn = {}
            hud:drawHeldItem({ kind = kind })
            assert(#drawn == 1 and drawn[1].image == hud.images.held,
                "Classic leaves the held-item HUD slot blank for " .. kind)
        end
        drawn = {}
        hud:drawHeldItem({ kind = "rock" })
        assert(#drawn == 2 and drawn[2].image == hud.renderer.entitySprites.rock.image,
            "A supported held item must still show its HUD sprite")
        drawn = {}
        hud:drawHeldItem({ kind = "bow" })
        assert(#drawn == 2 and drawn[2].image == hud.images.bowDisplay,
            "Classic uses the dedicated bow display sprite in the held-item slot")
        drawn = {}
        hud:draw({ health = 4, bombs = 4, ropes = 4, money = 0,
            equipment = { compass = true }, compass = {
                exitX = 400, exitY = 120, cameraX = 0, cameraY = 0,
                width = 320, height = 240,
            } })
        local rightAtEdge = false
        for _, entry in ipairs(drawn) do
            if entry.image == hud.images.compassRight and entry.x == 304
                and entry.y == 120 then rightAtEdge = true end
        end
        assert(rightAtEdge, "The compass must point from the viewport edge, not draw a HUD glyph mid-screen")
        drawn = {}
        hud:draw({ health = 4, bombs = 4, ropes = 4, money = 0,
            equipment = { compass = true }, compass = {
                exitX = 152, exitY = 300, cameraX = 0, cameraY = 0,
                width = 320, height = 240,
            } })
        local downAtEdge = false
        for _, entry in ipairs(drawn) do
            if entry.image == hud.images.compassDown and entry.x == 152
                and entry.y == 224 then downAtEdge = true end
        end
        assert(downAtEdge, "An exit below the camera must use the bottom-edge compass sprite")
    end, debug.traceback)
    love.graphics.draw = originalDraw
    assert(ok, err)
end

return Test
