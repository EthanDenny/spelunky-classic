local MinesVariants = {}

-- scrInitLevel selects darkness before scrEntityGen, using the same RNG.
-- An explicit boolean is reserved for the Full game lighting playtest.
function MinesVariants.apply(level, run, rng, forceDark)
    if forceDark ~= nil then
        level.dark = forceDark
    else
        level.dark = (level.levelNumber or 1) > 1 and not run.hadDarkLevel
            and rng:integer(1, 12) == 1
    end
    if level.dark then run.hadDarkLevel = true end
    return level
end

return MinesVariants
