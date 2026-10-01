local Test = {}

function Test.run(app)
    local hud = app.screens.full_level_playtest.hud
    hud:loadAssets()
    local originalDraw = love.graphics.draw
    local drawn = {}
    love.graphics.draw = function(image)
        drawn[#drawn + 1] = image
    end
    local ok, err = xpcall(function()
        for _, kind in ipairs({ "crate", "gold_idol", "chest" }) do
            drawn = {}
            hud:drawHeldItem({ kind = kind })
            assert(#drawn == 1 and drawn[1] == hud.images.held,
                "Classic leaves the held-item HUD slot blank for " .. kind)
        end
        drawn = {}
        hud:drawHeldItem({ kind = "rock" })
        assert(#drawn == 2 and drawn[2] == hud.renderer.entitySprites.rock.image,
            "A supported held item must still show its HUD sprite")
        drawn = {}
        hud:drawHeldItem({ kind = "bow" })
        assert(#drawn == 2 and drawn[2] == hud.images.bowDisplay,
            "Classic uses the dedicated bow display sprite in the held-item slot")
    end, debug.traceback)
    love.graphics.draw = originalDraw
    assert(ok, err)
end

return Test
