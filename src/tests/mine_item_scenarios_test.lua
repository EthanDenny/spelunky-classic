local Item = require("src.platform.item")

local Test = {}

local function stepTo(viewer, scenario, tick)
    while scenario.tick < tick do viewer:stepScenario(scenario) end
end

local function hasParticle(scenario, kind)
    for _, particle in ipairs(scenario.effects.particles) do
        if particle.kind == kind then return true end
    end
    return false
end

function Test.run(app)
    local viewer = app.screens.enemy_ai
    viewer:enter()
    local seen = {}
    for page = 10, 27 do
        viewer:setPage(page)
        viewer:draw()
        local cases = viewer.scenarios
        local kind = cases[1].definition.mineItemKind
        assert(Item.isCarryable(kind) and not seen[kind],
            "Each Mines carryable must have its own scenario page")
        seen[kind] = true
        assert(cases[1].definition.mineItemTest == "pickup"
            and cases[2].definition.mineItemTest == "put_down"
            and cases[3].definition.mineItemTest == "action",
            kind .. " needs pickup, put-down, and action scenarios")

        for index = 1, 3 do
            local scenario = cases[index]
            stepTo(viewer, scenario, 5)
            assert(scenario.itemGame.heldItem == scenario.mineItem
                and scenario.mineItem.x > scenario.player.x,
                kind .. " must be picked up by DOWN + ACTION: state="
                    .. tostring(scenario.player.state) .. " event=" .. tostring(scenario.event)
                    .. " item=" .. tostring(scenario.mineItem.x) .. "," .. tostring(scenario.mineItem.y))
        end

        local putDown = cases[2]
        stepTo(viewer, putDown, 35)
        assert(putDown.itemGame.heldItem == nil and not putDown.mineItem.held,
            kind .. " must leave the player's hands on DOWN + ACTION")
        if kind == "jar" then
            stepTo(viewer, putDown, 60)
            assert(not putDown.mineItem.opened and not hasParticle(putDown, "smoke"),
                "Putting down a " .. kind .. " gently must not smash it")
        elseif kind == "skull" then
            stepTo(viewer, putDown, 45)
            assert(putDown.mineItem.opened and hasParticle(putDown, "bone"),
                "The skull's lower held position and same-tick gravity make this drop exceed its floor break threshold")
        end

        local action = cases[3]
        stepTo(viewer, action, 35)
        if action.mineItem.weapon then
            assert(action.itemGame.heldItem == action.mineItem,
                kind .. " ACTION must use the weapon without throwing it")
            if kind == "mattock" then
                assert(action.player:getMeleePhase() == "back" and not action.mineItem.visible,
                    "The mattock must begin with a visible wind-up, not an immediate terrain hit")
                stepTo(viewer, action, 50)
                assert(action.world:has("solid", 5, 6),
                    "The slow mattock wind-up must not break terrain immediately")
                while action.tick < 70 and action.world:has("solid", 5, 6) do
                    viewer:stepScenario(action)
                end
                assert(not action.world:has("solid", 5, 6)
                    and hasParticle(action, "rubbleLarge"),
                    "The mattock strike must eventually break the tile and emit debris")
            elseif kind == "teleporter" then
                assert(action.player.x > 72, "The teleporter must move the player")
            elseif kind == "machete" then
                assert(action.player:getMeleePhase() == "back" and not action.mineItem.visible
                    and action.itemGame.enemies[1].alive,
                    "A machete must show its wind-up before it can hit")
                stepTo(viewer, action, 39)
                assert(action.itemGame.enemies[1].alive,
                    "The wind-up cannot damage an enemy before the slash appears")
                stepTo(viewer, action, 40)
                assert(not action.itemGame.enemies[1].alive and hasParticle(action, "blood"),
                    "The slash must hit at the source attack frame and emit blood")
            elseif kind == "bow" then
                assert(action.mineItem.bowArmed and #action.projectiles.projectiles == 0,
                    "The bow must draw on press, not fire immediately")
                stepTo(viewer, action, 36)
                assert(#action.projectiles.projectiles == 1
                    and action.projectiles.projectiles[1].kind == "arrow"
                    and action.itemRun.arrows == 5,
                    "Releasing a drawn bow must fire one arrow and spend one of its six arrows")
            elseif kind == "pistol" or kind == "shotgun" or kind == "web_cannon" then
                local shots = action.projectiles.projectiles
                local expected = kind == "pistol" and 1 or 6
                if kind == "web_cannon" then expected = 1 end
                assert(#shots == expected and action.mineItem.cooldown > 0,
                    kind .. " ACTION must fire its Classic shot count and start cooldown")
                for _, shot in ipairs(shots) do
                    assert(shot.kind == (kind == "web_cannon" and "web" or "bullet")
                        and shot.damage == (kind == "web_cannon" and 0 or 4),
                        kind .. " must produce the source projectile type and damage")
                end
            end
        elseif kind == "crate" or kind == "chest" then
            assert(action.mineItem.opened and #action.itemGame.items
                + #action.itemGame.collectibles + #action.itemGame.tools.bombs > 1,
                "UP + ACTION must open a held " .. kind .. " and spawn its contents, including trapped bombs")
            if kind == "crate" then
                assert(hasParticle(action, "poof"), "Opening a crate must emit its poof")
            end
        else
            assert(not action.mineItem.held and action.mineItem.vx > 0,
                kind .. " ACTION must throw an ordinary carryable")
        end
        if kind == "jar" or kind == "skull" then
            while action.tick < 60 and not action.mineItem.opened do
                viewer:stepScenario(action)
            end
            assert(action.mineItem.opened and hasParticle(action, "smoke")
                and hasParticle(action, kind == "jar" and "rubble" or "bone"),
                "A thrown " .. kind .. " must smash with its original particle types")
        end
        if kind == "machete" then
            local backHit = cases[4]
            assert(backHit and backHit.definition.mineItemTest == "back_hit",
                "The machete needs a rear wind-up combat scenario")
            stepTo(viewer, backHit, 34)
            assert(backHit.itemGame.enemies[1].alive,
                "The enemy behind the player must survive before ACTION")
            stepTo(viewer, backHit, 35)
            assert(not backHit.itemGame.enemies[1].alive and hasParticle(backHit, "blood"),
                "Classic's rear wind-up must damage an enemy behind the player")
        end
        if kind == "chest" or kind == "locked_chest" then
            local open = cases[4]
            assert(open and open.definition.mineItemTest == "open",
                kind .. " needs a floor-opening case")
            stepTo(viewer, open, 5)
            local hasReward = #open.itemGame.collectibles > 0 or #open.itemGame.tools.bombs > 0
            for _, item in ipairs(open.itemGame.items) do
                if item.kind == "udjat_eye" then hasReward = true end
            end
            assert(open.mineItem.opened and hasReward,
                "The source interaction must open a " .. kind .. " on the floor")
            if kind == "locked_chest" then
                assert(hasParticle(open, "poof"),
                    "Unlocking a chest must emit its poof particles")
            end
        end
        if kind == "key" then
            local unlock = cases[4]
            assert(unlock and unlock.definition.mineItemTest == "unlock",
                "The key needs a no-button chest-unlock case")
            stepTo(viewer, unlock, 25)
            local eye
            for _, item in ipairs(unlock.itemGame.items) do
                if item.kind == "udjat_eye" then eye = item; break end
            end
            assert(unlock.mineItem.opened and eye and eye.entity.kind == "udjat_eye"
                and eye.vy < 0
                and hasParticle(unlock, "poof"),
                "A held key must release an immediately collectible eye upward with poofs")
        end
    end
    viewer:setPage(1)
end

return Test
