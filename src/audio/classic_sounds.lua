-- Love adapter for sound cues emitted by the live Mines playtest.
local ClassicSounds = {}
ClassicSounds.__index = ClassicSounds

local CUES = {
    throw = "throw", explosion = "explosion",
    alert = "alert", thud = "thud", push = "push", jetpack = "jetpack",
    arrowtrap = "arrowtrap", bat = "bat", bowpull = "bowpull", break_item = "break",
    caveman_die = "cavemandie", chest_open = "chestopen",
    damsel = "damsel", steps = "steps",
    ghost = "ghost", die = "die",
    coin = "coin", crunch = "crunch", gem = "gem",
    giant_spider = "giantspider", hit = "hit", hurt = "hurt", jump = "jump", kiss = "kiss",
    climb1 = "climb1", climb2 = "climb2",
    mattock_break = "mattockbreak", pickup = "pickup", shotgun = "shotgun", spider_jump = "spiderjump",
    teleport = "teleport", trap = "trap", whip = "whip",
    small_explode = "smallexplode", thump = "thump",
}

function ClassicSounds.configure(source, volume)
    source:setVolume(10^((2000+8000*((volume or 15)/18)-10000)/2000))
    return source
end

function ClassicSounds.load(filename, volume)
    return ClassicSounds.configure(love.audio.newSource(
        "original-game-reference/sound/" .. filename .. ".wav", "static"), volume)
end

function ClassicSounds.new(settings)
    return setmetatable({ sources = {}, playing = {}, settings = settings }, ClassicSounds)
end

function ClassicSounds:play(cue, pan)
    local filename = assert(CUES[cue], "Unknown Classic sound cue: " .. tostring(cue))
    local source = self.sources[cue]
    if not source then
        source = ClassicSounds.load(filename)
        self.sources[cue] = source
    end
    if pan then
        source:setRelative(true)
        source:setRolloff(0)
        source:setPosition(pan, 0, pan == 0 and -1 or 0)
    end
    local voice = ClassicSounds.configure(source, self.settings and self.settings.soundVol):clone()
    local playing = self.playing[cue] or {}
    for i = #playing, 1, -1 do
        if not playing[i]:isPlaying() then table.remove(playing, i) end
    end
    playing[#playing+1] = voice
    self.playing[cue] = playing
    voice:play()
end

function ClassicSounds:isPlaying(cue)
    for _, voice in ipairs(self.playing[cue] or {}) do
        if voice:isPlaying() then return true end
    end
    return false
end

function ClassicSounds:stop(cue)
    for _, voice in ipairs(self.playing[cue] or {}) do voice:stop() end
    self.playing[cue] = nil
end

function ClassicSounds:stopAll()
    for cue in pairs(self.playing) do self:stop(cue) end
end

return ClassicSounds
