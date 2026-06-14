-- Ending: "get dunked on."
-- Shows Sans's mocking dialogue, then triggers the standard game-over shatter
-- and returns to the menu.  All mutable state is (re-)initialised in enter().

local Input    = require("src.systems.input")
local Dialogue = require("src.ui.dialogue")

-- Dialogue anchor: centered in the wide zone, same as action_resolve.
local WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2 = 33, 251, 608, 391
local DLG_X = (WIDE_X1 + WIDE_X2) / 2
local DLG_Y = WIDE_Y2 - 6

-- Lines spoken before the shatter.
local DUNKED_LINES = {
    "* did you really think i'd let you\n  spare me?",
    "* get dunked on!!!",
}

local EndingDunked = {}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function EndingDunked:enter(battle)
    battle.hideHeart = true
    battle.combatZone:setSize(WIDE_X1, WIDE_Y1, WIDE_X2, WIDE_Y2)

    self.lineIndex = 0
    self.dlg = Dialogue.new()
    self:nextLine()
end

function EndingDunked:exit(battle)
    battle.hideHeart = false
    self.dlg = nil
end

function EndingDunked:nextLine()
    self.lineIndex = self.lineIndex + 1
    local line = DUNKED_LINES[self.lineIndex]
    if line then
        self.dlg:show(line, DLG_X, DLG_Y, "white")
        self.done = false
    else
        -- All lines exhausted: trigger the shatter game-over.
        self.done = true
    end
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function EndingDunked:update(dt, battle)
    battle.combatZone:update(dt)
    battle.sans:update(dt)

    if self.done then
        -- Hand off to the shatter ending immediately.
        battle:triggerGameOver()
        return
    end

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

function EndingDunked:draw(battle)
    battle:drawArena()
    if self.dlg then
        self.dlg:draw()
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return EndingDunked
