-- sans_dialogue phase.
-- Shows a speech bubble above Sans with the current turn's dialogue line.
-- If the turn has no dialogue, skips immediately to the attack phase.

local Input    = require("src.systems.input")
local Dialogue = require("src.ui.dialogue")

-- Vertical offset from sans.y to the bottom anchor of the speech bubble.
-- sans.y is the body center (~168). The head top is roughly sans.y - 80,
-- so anchoring the bubble bottom at sans.y - 90 places it just above his skull.
local BUBBLE_Y_OFFSET = -90

local SansDialogue = {}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function SansDialogue:enter(battle)
    -- Retrieve the dialogue line for the current turn.
    local line = ""
    if battle.turnManager and battle.turnManager:current() then
        line = battle.turnManager:current().dialogue or ""
    end

    -- If there is nothing to say, skip straight to the attack.
    if line == "" then
        battle:onDialogueDone()
        return
    end

    -- Keep the heart hidden while Sans is speaking.
    battle.hideHeart = true

    -- Create and show the dialogue bubble above Sans.
    local bx = battle.sans.x
    local by = battle.sans.y + BUBBLE_Y_OFFSET

    self.dlg = Dialogue.new()
    self.dlg:show(line, bx, by, "white")
end

function SansDialogue:exit(battle)
    self.dlg = nil
    battle.hideHeart = false
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function SansDialogue:update(dt, battle)
    -- Keep Sans animating while the bubble is shown.
    battle.sans:update(dt)

    if not self.dlg then return end

    self.dlg:update(dt)

    -- Confirm: skip typewriter if still running, otherwise dismiss and proceed.
    if Input:justPressed("confirm") then
        if not self.dlg:isComplete() then
            self.dlg:skip()
        else
            self.dlg:skip()   -- deactivates the dialogue
            battle:onDialogueDone()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function SansDialogue:keypressed(key, battle)
    -- Navigation handled via Input singleton in update().
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function SansDialogue:draw(battle)
    -- Draw the arena (heart hidden via battle.hideHeart).
    battle:drawArena()

    -- Draw speech bubble above Sans.
    if self.dlg then
        self.dlg:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return SansDialogue
