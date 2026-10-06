local TunnelMan = {}
TunnelMan.__index = TunnelMan

function TunnelMan.new(progress)
    return setmetatable({ progress = progress, talk = 0, donate = 0,
        upCounter = 0, downCounter = 0, upHeld = 0, downHeld = 0 }, TunnelMan)
end

function TunnelMan:pressAction(game)
    if self.talk == 1 then self.talk = 2
    elseif self.talk == 2 then
        if self.donate > 0 then
            self.talk = self.donate >= self.progress.tunnel1 and 5 or 3
            game.run.money = game.run.money-self.donate
            self.progress.tunnel1 = self.progress.tunnel1-self.donate
        else self.talk = 4 end
    end
end

function TunnelMan:pressDirection(direction, game)
    self.donate = math.max(0, math.min(game.run.money, self.progress.tunnel1, self.donate+direction*100))
end

function TunnelMan:step(input, game)
    if self.talk ~= 2 then return end
    if input.up then
        self.upHeld, self.downHeld = self.upHeld+1, 0
        if self.upCounter < 20 then self.upCounter = self.upCounter+1
        else self.donate = self.donate+(self.upHeld > 100 and 1000 or 100) end
        self.donate = math.min(self.donate, game.run.money, self.progress.tunnel1)
        self.downCounter = 0
    elseif input.down then
        self.downHeld, self.upHeld = self.downHeld+1, 0
        if self.downCounter < 20 then self.downCounter = self.downCounter+1
        else self.donate = math.max(0, self.donate-(self.downHeld > 100 and 1000 or 100)) end
        self.upCounter = 0
    else self.upCounter, self.downCounter, self.upHeld, self.downHeld = 0, 0, 0, 0 end
end

function TunnelMan:dialogue()
    if self.talk == 1 then return { "HEY THERE! I'M THE TUNNEL MAN!", "I DIG SHORTCUTS." }, 208
    elseif self.talk == 2 then
        return { "CAN YOU LEND ME A LITTLE MONEY?",
            "I NEED $" .. self.progress.tunnel1 .. " FOR A NEW SHORTCUT." }, 208
    elseif self.talk == 3 then return { "THANKS! YOU WON'T REGRET IT!" }, 216
    elseif self.talk == 4 then return { "I'LL NEVER GET THIS SHORTCUT BUILT!" }, 216
    elseif self.talk == 5 then return { "ONE SHORTCUT, COMING UP!" }, 216 end
    return {}, 216
end

return TunnelMan
