local MinesMusic = {}
MinesMusic.__index = MinesMusic

function MinesMusic.new()
    local source = love.audio.newSource("original-game-reference/sound/cave.ogg", "stream")
    source:setLooping(true)
    return setmetatable({ source = source, enabled = true, fadeTicks = 0 }, MinesMusic)
end

function MinesMusic:start(volume)
    self.source:stop()
    self.fadeTicks = 0
    self.source:setPitch(1)
    -- scrInit/startMusic use SuperSound's 0..10000 volume scale. Its wrapper
    -- subtracts 10000 for DirectSound's hundredths of a decibel attenuation.
    local attenuation = 2000 + 8000*(volume/18) - 10000
    self.source:setVolume(10^(attenuation/2000))
    if self.enabled then self.source:play() end
end

function MinesMusic:stop()
    self.source:stop()
end

function MinesMusic:toggle()
    self.enabled = not self.enabled
    if self.enabled then self.source:play() else self:stop() end
end

function MinesMusic:fade()
    if self.fadeTicks >= 100 then return end
    self.fadeTicks = self.fadeTicks+1
    -- oLevel/scrMusicFade lower the 44100 Hz track by 100 Hz each tick.
    self.source:setPitch((44100-100*self.fadeTicks)/44100)
end

return MinesMusic
