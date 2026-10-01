-- Love adapter for sound cues emitted by the live Mines playtest.
local ClassicSounds = {}
ClassicSounds.__index = ClassicSounds

local CUES = {
    bat = "bat", bowpull = "bowpull", break_item = "break",
    caveman_die = "cavemandie", chest_open = "chestopen",
    coin = "coin", crunch = "crunch", gem = "gem",
    giant_spider = "giantspider", hurt = "hurt", jump = "jump", kiss = "kiss",
    climb1 = "climb1", climb2 = "climb2",
    pickup = "pickup", spider_jump = "spiderjump",
}

function ClassicSounds.new()
    return setmetatable({ sources = {} }, ClassicSounds)
end

function ClassicSounds:play(cue)
    local filename = assert(CUES[cue], "Unknown Classic sound cue: " .. tostring(cue))
    local source = self.sources[cue]
    if not source then
        source = love.audio.newSource("original-game-reference/sound/" .. filename .. ".wav", "static")
        self.sources[cue] = source
    end
    source:clone():play()
end

return ClassicSounds
