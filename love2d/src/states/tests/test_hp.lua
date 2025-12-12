-- HP Bar Test
-- Test HP bar display with damage and karma

local Constants = require("src.core.constants")
local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local HpBar = require("src.ui.hp_bar")

local TestHp = {}

function TestHp:enter(game)
    self.game = game
    Fonts:load()

    self.hpBar = HpBar.new()
    self.hp = 92
    self.maxHp = 92
    self.karma = 0
end

function TestHp:update(dt, game)
    -- Damage with left
    if Input:justPressed("left") then
        self.hp = math.max(0, self.hp - 5)
    end

    -- Heal with right
    if Input:justPressed("right") then
        self.hp = math.min(self.maxHp, self.hp + 5)
    end

    -- Add karma with down
    if Input:justPressed("down") then
        self.karma = math.min(20, self.karma + 5)
    end

    -- Remove karma with up
    if Input:justPressed("up") then
        self.karma = math.max(0, self.karma - 5)
    end

    -- Reset with confirm
    if Input:justPressed("confirm") then
        self.hp = self.maxHp
        self.karma = 0
    end

    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    self.hpBar:update(dt, self.hp, self.maxHp, self.karma)
end

function TestHp:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("HP Bar Test", 320, 20, "center")

    -- Draw HP bar at different positions for testing
    self.hpBar:draw(self.hp, self.maxHp, self.karma)

    -- Info
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("HP: " .. self.hp .. " / " .. self.maxHp, 320, 200, "center")
    Fonts.default:draw("Karma: " .. self.karma, 320, 220, "center")

    local effectiveHp = math.max(0, self.hp - self.karma)
    Fonts.default:draw("Effective HP: " .. effectiveHp, 320, 240, "center")

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Left: Damage | Right: Heal", 320, 420, "center")
    Fonts.default:draw("Up: -Karma | Down: +Karma | Z: Reset", 320, 436, "center")
    Fonts.default:draw("X/Esc: Back", 320, 460, "center")
end

function TestHp:exit()
    self.hpBar = nil
end

return TestHp
