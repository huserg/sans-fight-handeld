-- Dialogue Test
-- Test speech bubble system

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local Dialogue = require("src.ui.dialogue")

local TestDialogue = {
    dialogue = nil,
    testLines = {
        "* heya.",
        "* you look frustrated about something.",
        "* guess i'm pretty good at my job, huh?",
        "* it's a beautiful day outside.",
        "* birds are singing, flowers are blooming...",
        "* on days like these, kids like you...",
        "* should be burning in hell."
    },
    currentLine = 1
}

function TestDialogue:enter(game)
    self.game = game
    Fonts:load()

    self.dialogue = Dialogue.new()
    self.currentLine = 1

    -- Start first dialogue
    self.dialogue:show(self.testLines[1], 320, 180)
end

function TestDialogue:update(dt, game)
    -- Update dialogue
    self.dialogue:update(dt)

    -- Skip/advance on confirm
    if Input:justPressed("confirm") then
        if self.dialogue:isComplete() then
            -- Next line
            self.currentLine = self.currentLine + 1
            if self.currentLine > #self.testLines then
                self.currentLine = 1
            end
            self.dialogue:show(self.testLines[self.currentLine], 320, 180)
        else
            -- Skip to end
            self.dialogue:skip()
        end
    end

    -- Toggle style on cancel
    if Input:justPressed("cancel") then
        local newStyle = self.dialogue.style == "white" and "black" or "white"
        self.dialogue.style = newStyle
    end

    -- Back to test menu
    if Input:justPressed("menu") then
        game:setState("test_menu")
    end
end

function TestDialogue:draw(game)
    -- Dark background
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 0, 0, 640, 480)

    -- Draw a placeholder for Sans position
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 280, 200, 80, 120)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Sans", 320, 250, "center")

    -- Draw dialogue
    self.dialogue:draw()

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Z: Next/Skip | X: Toggle Style | Esc: Back", 320, 440, "center")

    -- Status
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Line " .. self.currentLine .. "/" .. #self.testLines, 320, 460, "center")
end

function TestDialogue:exit()
    self.dialogue = nil
end

return TestDialogue
