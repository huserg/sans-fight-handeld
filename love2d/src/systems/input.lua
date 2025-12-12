-- Input system (VPad abstraction)
-- Handles keyboard and gamepad input

local Constants = require("src.core.constants")

local Input = {
    -- Current frame state
    up = false,
    down = false,
    left = false,
    right = false,
    confirm = false,
    cancel = false,
    menu = false,

    -- Previous frame state
    last_up = false,
    last_down = false,
    last_left = false,
    last_right = false,
    last_confirm = false,
    last_cancel = false,
    last_menu = false,

    -- Active gamepad
    gamepad = nil
}

function Input:load()
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        self.gamepad = joysticks[1]
    end
end

function Input:joystickadded(joystick)
    if not self.gamepad then
        self.gamepad = joystick
    end
end

function Input:update()
    -- Store previous frame state
    self.last_up = self.up
    self.last_down = self.down
    self.last_left = self.left
    self.last_right = self.right
    self.last_confirm = self.confirm
    self.last_cancel = self.cancel
    self.last_menu = self.menu

    -- Reset current state
    self.up = false
    self.down = false
    self.left = false
    self.right = false
    self.confirm = false
    self.cancel = false
    self.menu = false

    -- Keyboard input
    if love.keyboard.isDown("up", "w") then self.up = true end
    if love.keyboard.isDown("down", "s") then self.down = true end
    if love.keyboard.isDown("left", "a") then self.left = true end
    if love.keyboard.isDown("right", "d") then self.right = true end
    if love.keyboard.isDown("z", "return") then self.confirm = true end
    if love.keyboard.isDown("x", "lshift", "rshift") then self.cancel = true end
    if love.keyboard.isDown("c", "lctrl", "rctrl", "escape") then self.menu = true end

    -- Gamepad input
    if self.gamepad and self.gamepad:isConnected() then
        -- D-Pad
        if self.gamepad:isGamepadDown("dpup") then self.up = true end
        if self.gamepad:isGamepadDown("dpdown") then self.down = true end
        if self.gamepad:isGamepadDown("dpleft") then self.left = true end
        if self.gamepad:isGamepadDown("dpright") then self.right = true end

        -- Left stick with deadzone
        local lx = self.gamepad:getGamepadAxis("leftx") or 0
        local ly = self.gamepad:getGamepadAxis("lefty") or 0
        if ly < -Constants.STICK_DEADZONE then self.up = true end
        if ly > Constants.STICK_DEADZONE then self.down = true end
        if lx < -Constants.STICK_DEADZONE then self.left = true end
        if lx > Constants.STICK_DEADZONE then self.right = true end

        -- Buttons (A/B/Start)
        if self.gamepad:isGamepadDown("a") then self.confirm = true end
        if self.gamepad:isGamepadDown("b") then self.cancel = true end
        if self.gamepad:isGamepadDown("start") then self.menu = true end
    end
end

function Input:justPressed(button)
    return self[button] and not self["last_" .. button]
end

function Input:justReleased(button)
    return not self[button] and self["last_" .. button]
end

function Input:isMoving()
    return self.up or self.down or self.left or self.right
end

function Input:getMovement()
    local x, y = 0, 0
    if self.left then x = x - 1 end
    if self.right then x = x + 1 end
    if self.up then y = y - 1 end
    if self.down then y = y + 1 end
    return x, y
end

return Input
