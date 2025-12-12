-- Game Manager
-- Handles game states, loading, and main loop

local Constants = require("src.core.constants")
local Input = require("src.systems.input")
local Fonts = require("src.ui.fonts")

local Game = {
    state = "loading",
    states = {},
    currentState = nil,

    -- Loading state
    loadProgress = 0,
    loadTotal = 0,
    loadComplete = false,

    -- Global game data
    simulatorMode = 0,
    singleAttack = "",
    endlessStage = 0,
    hp = 92,
    maxHp = 92
}

function Game:load()
    Input:load()

    -- Register states
    self.states.loading = require("src.states.loading")
    self.states.menu = require("src.states.menu")
    self.states.battle = require("src.states.battle")
    self.states.fonttest = require("src.states.font_test")

    -- Test states
    self.states.test_menu = require("src.states.test_menu")
    self.states.test_heart = require("src.states.tests.test_heart")
    self.states.test_bones = require("src.states.tests.test_bones")
    self.states.test_combat = require("src.states.tests.test_combat")
    self.states.test_hp = require("src.states.tests.test_hp")
    self.states.test_audio = require("src.states.tests.test_audio")

    -- Start with loading state
    self:setState("loading")
end

function Game:setState(stateName)
    if self.currentState and self.currentState.exit then
        self.currentState:exit()
    end

    self.state = stateName
    self.currentState = self.states[stateName]

    if self.currentState and self.currentState.enter then
        self.currentState:enter(self)
    end
end

function Game:update(dt)
    Input:update()

    if self.currentState and self.currentState.update then
        self.currentState:update(dt, self)
    end
end

function Game:draw()
    -- Clear screen with black
    love.graphics.clear(0, 0, 0)

    if self.currentState and self.currentState.draw then
        self.currentState:draw(self)
    end
end

function Game:keypressed(key)
    if self.currentState and self.currentState.keypressed then
        self.currentState:keypressed(key, self)
    end
end

function Game:keyreleased(key)
    if self.currentState and self.currentState.keyreleased then
        self.currentState:keyreleased(key, self)
    end
end

function Game:gamepadpressed(joystick, button)
    if self.currentState and self.currentState.gamepadpressed then
        self.currentState:gamepadpressed(joystick, button, self)
    end
end

function Game:gamepadreleased(joystick, button)
    if self.currentState and self.currentState.gamepadreleased then
        self.currentState:gamepadreleased(joystick, button, self)
    end
end

function Game:joystickadded(joystick)
    Input:joystickadded(joystick)
end

return Game
