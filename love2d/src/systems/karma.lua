-- Karma (KR) system: pure Lua, no LOVE dependency, so it is headlessly testable.
-- Models the original Sans-fight HP/KR behaviour decoded from Battle.xml:
--   - Contact hits add raw damage to HP loss and karma to KR (no i-frames).
--   - Each frame KR is capped at 40, then clamped so KR can never reach HP
--     (karma alone leaves the player at 1 HP, it never directly kills).
--   - The purple "inertia" drains KR (and HP) over time, faster at higher KR.
--
-- HP is owned externally (battle.game.hp); this module mirrors it in self.hp
-- and the caller syncs after each :hit / :update.

local Karma = {}
Karma.__index = Karma

local KR_CAP = 40

-- Drain tiers: the FIRST matching tier fires per frame (mutually exclusive,
-- matching the C2 sub-event else-if chain). Each fires when KR >= krMin AND
-- the accumulated krT >= time, subtracting 1 from KR and 1 from HP.
-- Ordered from highest KR / fastest drain to lowest.
local DRAIN_TIERS = {
    { krMin = 40, time = 0.033 },
    { krMin = 30, time = 0.066 },
    { krMin = 20, time = 0.166 },
    { krMin = 10, time = 0.5 },
    { krMin = 1,  time = 1.0 },
}

function Karma.new(hp)
    local self = setmetatable({}, Karma)
    self.hp = hp or 0
    self.kr = 0
    self.krT = 0
    return self
end

-- Apply a contact hit: HP drops by dmg, KR rises by karma. No invincibility.
function Karma:hit(dmg, karma)
    self.hp = self.hp - (dmg or 0)
    self.kr = self.kr + (karma or 0)
end

-- Per-frame update: cap KR, clamp KR below HP, then run the tiered drain.
-- Returns the amount of HP lost to the drain this frame.
function Karma:update(dt)
    -- Cap KR at 40.
    if self.kr > KR_CAP then
        self.kr = KR_CAP
    end

    -- Karma can never reach HP: leave the player at 1.
    if self.kr >= self.hp then
        self.kr = self.hp - 1
    end

    -- Drain only when there is karma to bleed and the player is above 1 HP.
    if self.kr <= 0 or self.hp <= 1 then
        return 0
    end

    self.krT = self.krT + dt

    for _, tier in ipairs(DRAIN_TIERS) do
        if self.kr >= tier.krMin and self.krT >= tier.time then
            self.kr = self.kr - 1
            self.hp = self.hp - 1
            self.krT = 0
            return 1
        end
    end

    return 0
end

return Karma
