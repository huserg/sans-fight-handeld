-- Loading State
-- Shows loading progress with logo, then auto-transitions to menu

local Fonts = require("src.ui.fonts")
local Audio = require("src.systems.audio")

local Loading = {
    game = nil,

    -- Loading state
    progress = 0,
    totalSteps = 3,
    currentStep = 0,
    stepTimer = 0,
    minLoadTime = 0.5,

    -- Logo
    logo = nil,
    logoScale = 2,

    -- Done
    done = false,
    doneTimer = 0
}

function Loading:enter(game)
    self.game = game
    self.progress = 0
    self.currentStep = 0
    self.stepTimer = 0
    self.done = false
    self.doneTimer = 0

    -- Load logo
    self.logo = love.graphics.newImage("assets/sprites/loading-logo.png")
    self.logo:setFilter("nearest", "nearest")
end

function Loading:update(dt, game)
    if self.done then
        -- Wait a bit then go to menu
        self.doneTimer = self.doneTimer + dt
        if self.doneTimer >= 0.3 then
            game:setState("menu")
        end
        return
    end

    self.stepTimer = self.stepTimer + dt

    -- Load assets step by step
    if self.currentStep == 0 and self.stepTimer >= 0.1 then
        -- Step 1: Load fonts
        Fonts:load()
        self.currentStep = 1
        self.progress = 0.33
        self.stepTimer = 0

    elseif self.currentStep == 1 and self.stepTimer >= 0.1 then
        -- Step 2: Load audio
        Audio:load()
        self.currentStep = 2
        self.progress = 0.66
        self.stepTimer = 0

    elseif self.currentStep == 2 and self.stepTimer >= 0.1 then
        -- Step 3: Done
        self.currentStep = 3
        self.progress = 1.0
        self.done = true
    end
end

function Loading:draw(game)
    local screenW, screenH = 640, 480
    local centerX, centerY = screenW / 2, screenH / 2

    -- Background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Logo
    if self.logo then
        local logoW, logoH = self.logo:getDimensions()
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            self.logo,
            centerX, centerY - 40,
            0,
            self.logoScale, self.logoScale,
            logoW / 2, logoH / 2
        )
    end

    -- Progress bar background
    local barW, barH = 200, 10
    local barX = centerX - barW / 2
    local barY = centerY + 40

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    -- Progress bar fill
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", barX, barY, barW * self.progress, barH)

    -- Loading text
    love.graphics.setColor(1, 1, 1)
    local text = self.done and "READY" or "LOADING..."
    love.graphics.printf(text, 0, barY + 20, screenW, "center")
end

function Loading:exit()
    -- Keep logo loaded for potential reuse
end

return Loading
