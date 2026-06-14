-- Turn manager: walks the ordered fight script and reports per-turn data.
-- Pure logic, no LOVE dependency.

local script = require("src.data.fight_script")

local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new()
    return setmetatable({ index = 0 }, TurnManager)
end

function TurnManager:currentTurn()
    return self.index
end

-- Advance to the next turn and return its entry, or nil past the end
function TurnManager:advance()
    if self.index >= #script then
        self.index = #script + 1
        return nil
    end
    self.index = self.index + 1
    return script[self.index]
end

function TurnManager:current()
    return script[self.index]
end

function TurnManager:isLastTurn()
    return self.index >= #script
end

-- The intro turn (turn 1) runs without a preceding player menu
function TurnManager:isIntro(turn)
    return turn ~= nil and turn.attack == "sans_intro"
end

return TurnManager
