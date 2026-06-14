-- Ending: victory.
-- Sans takes the final hit, a victory dialogue plays, then the game returns
-- to the menu.  All mutable state is (re-)initialised in enter().

local Input        = require("src.systems.input")
local Audio        = require("src.systems.audio")
local Dialogue     = require("src.ui.dialogue")
local DamageNumber = require("src.ui.damage_number")

-- Dialogue anchor placed in the wide zone (same as action_resolve / ending_dunked).
local WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2 = 33, 251, 608, 391
local DLG_X = (WIDE_X1 + WIDE_X2) / 2
local DLG_Y = WIDE_Y2 - 6

-- Damage shown over Sans on the killing blow.
local VICTORY_DAMAGE = "9999"

-- Lines played after the hit.
local VICTORY_LINES = {
    "* ...",
    "* heh.",
    "* you know what's funny?",
    "* i always knew you could do it.",
    "* so, take care of yourself.",
    "* ok?",
}

-- Brief pause (seconds) between the hit and the first dialogue line.
local HIT_PAUSE = 0.8

local EndingVictory = {}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function EndingVictory:enter(battle)
    battle.hideHeart = true
    battle.combatZone:setSize(WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2)

    Audio:stopMusic()

    -- Spawn the big damage number over Sans.
    local sx, sy = battle.sans.x, battle.sans.y
    self.damageNumbers = { DamageNumber.new(VICTORY_DAMAGE, sx, sy - 50) }

    -- Play the hit SFX.
    Audio:playSfx("playerFight")

    self.lineIndex  = 0
    self.dlg        = Dialogue.new()
    self.hitPause   = HIT_PAUSE
    self.dialoguePending = true
end

function EndingVictory:exit(battle)
    battle.hideHeart = false
    self.dlg = nil
    self.damageNumbers = {}
end

function EndingVictory:nextLine()
    self.lineIndex = self.lineIndex + 1
    local line = VICTORY_LINES[self.lineIndex]
    if line then
        self.dlg:show(line, DLG_X, DLG_Y, "white")
    else
        -- All lines done: return to menu.
        self.dlg = nil
        self.done = true
    end
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function EndingVictory:update(dt, battle)
    battle.combatZone:update(dt)
    battle.sans:update(dt)

    -- Update floating damage numbers.
    for i = #self.damageNumbers, 1, -1 do
        self.damageNumbers[i]:update(dt)
        if self.damageNumbers[i].dead then
            table.remove(self.damageNumbers, i)
        end
    end

    -- Hit pause before dialogue begins.
    if self.dialoguePending then
        self.hitPause = self.hitPause - dt
        if self.hitPause <= 0 then
            self.dialoguePending = false
            self:nextLine()
        end
        return
    end

    if self.done then
        battle.game:setState("menu")
        return
    end

    if not self.dlg then return end

    self.dlg:update(dt)

    if Input:justPressed("confirm") then
        if not self.dlg:isComplete() then
            self.dlg:skip()
        else
            self.dlg:skip()
            self:nextLine()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function EndingVictory:draw(battle)
    battle:drawArena()

    -- Damage numbers floating above Sans.
    for _, dn in ipairs(self.damageNumbers) do
        dn:draw()
    end

    if self.dlg then
        self.dlg:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return EndingVictory
