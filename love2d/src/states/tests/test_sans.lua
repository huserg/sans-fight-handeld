-- Sans Character Test
-- Test Sans sprite and expressions

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local Sans = require("src.entities.sans")

local TestSans = {}

local expressions = {"neutral", "wink", "closed", "smile", "serious", "angry", "tired", "sweat", "dark"}

function TestSans:enter(game)
    self.game = game
    Fonts:load()

    self.sans = Sans.new(320, 200)
    self.expressionIndex = 1
    self.sans:setExpression(expressions[self.expressionIndex])
end

function TestSans:update(dt, game)
    -- Change expression
    if Input:justPressed("left") then
        self.expressionIndex = self.expressionIndex - 1
        if self.expressionIndex < 1 then
            self.expressionIndex = #expressions
        end
        self.sans:setExpression(expressions[self.expressionIndex])
    elseif Input:justPressed("right") then
        self.expressionIndex = self.expressionIndex + 1
        if self.expressionIndex > #expressions then
            self.expressionIndex = 1
        end
        self.sans:setExpression(expressions[self.expressionIndex])
    end

    -- Toggle sweat
    if Input:justPressed("confirm") then
        self.sans:setSweat(not self.sans.showSweat)
    end

    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    self.sans:update(dt)
end

function TestSans:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Sans Character Test", 320, 20, "center")

    -- Draw Sans
    self.sans:draw()

    -- Draw head separately with current expression (larger)
    self.sans:drawHead(320, 350, 2)

    -- Info
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Expression: " .. expressions[self.expressionIndex], 320, 420, "center")
    Fonts.default:draw("Sweat: " .. (self.sans.showSweat and "ON" or "OFF"), 320, 436, "center")

    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Left/Right: Expression | Z: Toggle sweat", 320, 456, "center")
    Fonts.default:draw("X/Esc: Back", 320, 472, "center")
end

function TestSans:exit()
    self.sans = nil
end

return TestSans
