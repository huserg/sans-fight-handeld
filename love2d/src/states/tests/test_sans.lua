-- Sans Character Test
-- Test Sans sprite and expressions - shows ALL expressions in a grid

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

local TestSans = {}

local expressions = {
    "neutral", "wink", "closed",
    "smile", "serious", "angry",
    "tired", "sweat", "dark"
}

function TestSans:enter(game)
    self.game = game
    Fonts:load()

    -- Load head sprite directly for grid display
    self.headImage = love.graphics.newImage("assets/sprites/sanshead-sheet0.png")
    self.headImage:setFilter("nearest", "nearest")

    -- Load body sprite
    self.bodyImage = love.graphics.newImage("assets/sprites/sansbody-sheet0.png")
    self.bodyImage:setFilter("nearest", "nearest")
end

function TestSans:update(dt, game)
    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
    end
end

function TestSans:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Sans Expressions - 9 (3x3 grid, 34x32 each)", 320, 10, "center")

    -- Draw the full spritesheet scaled up
    love.graphics.draw(self.headImage, 10, 40, 0, 3, 3)

    -- Draw grid overlay to show frame boundaries (34x32 per frame)
    love.graphics.setColor(0, 1, 0, 0.7)
    for row = 0, 3 do
        love.graphics.line(10, 40 + row * 32 * 3, 10 + 102 * 3, 40 + row * 32 * 3)
    end
    for col = 0, 3 do
        love.graphics.line(10 + col * 34 * 3, 40, 10 + col * 34 * 3, 40 + 96 * 3)
    end

    -- Draw labels
    love.graphics.setColor(1, 1, 1)
    local idx = 1
    for row = 0, 2 do
        for col = 0, 2 do
            local name = expressions[idx] or "?"
            local x = 10 + col * 34 * 3 + 51
            local y = 40 + row * 32 * 3 + 100
            Fonts.default:draw(name, x, y, "center")
            idx = idx + 1
        end
    end

    -- Draw body spritesheet too
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Body (4x4, 64x70 each):", 450, 40, "left")
    love.graphics.draw(self.bodyImage, 450, 60, 0, 0.7, 0.7)

    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("X/Esc: Back", 320, 460, "center")
end

function TestSans:exit()
    self.headImage = nil
    self.bodyImage = nil
end

return TestSans
