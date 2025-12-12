-- Font Test State
-- Displays test text in all 4 fonts

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

local FontTest = {}

function FontTest:enter(game)
    self.game = game
    -- Load fonts if not already loaded
    Fonts:load()
end

function FontTest:update(dt, game)
    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("menu")
    end
end

function FontTest:draw(game)
    love.graphics.setColor(1, 1, 1)

    local testText = "Sans Fight ? Go !"
    local y = 40

    -- Default font
    Fonts.default:setScale(2)
    Fonts.default:draw("DefaultFont:", 320, y, "center")
    y = y + 40
    Fonts.default:draw(testText, 320, y, "center")
    y = y + 60

    -- Battle font (scale 3 for visibility) - UPPERCASE ONLY (no lowercase in this font)
    Fonts.battle:setScale(3)
    Fonts.battle:draw("BATTLEFONT:", 320, y, "center")
    y = y + 30
    Fonts.battle:draw(testText:upper(), 320, y, "center")
    y = y + 50

    -- Sans font
    Fonts.sans:setScale(2)
    Fonts.sans:draw("SansFont:", 320, y, "center")
    y = y + 40
    Fonts.sans:draw(testText, 320, y, "center")
    y = y + 60

    -- Damage font
    Fonts.damage:setScale(1)
    Fonts.damage:draw("DamageFont:", 320, y, "center")
    y = y + 50
    Fonts.damage:draw(testText, 320, y, "center")

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:setScale(1)
    Fonts.default:draw("Press X or Esc to return", 320, 450, "center")
end

function FontTest:exit()
end

return FontTest
