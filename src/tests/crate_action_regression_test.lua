local Test = {}

function Test.run(app)
    local screen = app.screens.full_level_playtest
    for _, held in ipairs({ false, true }) do
        screen:buildSimulation()
        local crate = screen:spawnEntity("crate", screen.player.x, screen.player.y)
        screen.items = { crate }
        if held then
            crate:pickup(screen.player)
            screen.heldItem = crate
        end
        screen:simulationStepBody({ up = true, attack = true, suppressWhip = true })
        assert(crate.opened and screen.heldItem == nil,
            "Up+Attack must open a " .. (held and "held" or "nearby")
                .. " crate before the regular throw/whip action")
    end
end

return Test
