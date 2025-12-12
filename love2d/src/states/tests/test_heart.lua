-- Heart Modes Test
-- Test red and blue heart modes

local Constants = require("src.core.constants")
local AssetsConfig = require("src.core.assets_config")
local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local CombatZone = require("src.entities.combat_zone")
local PlayerHeart = require("src.entities.player_heart")

local TestHeart = {}

function TestHeart:enter(game)
    self.game = game
    Fonts:load()

    self.combatZone = CombatZone.new()
    self.playerHeart = PlayerHeart.new(self.combatZone)
end

function TestHeart:update(dt, game)
    if Input:justPressed("cancel") then
        if self.playerHeart.mode == Constants.HEARTMODE_RED then
            self.playerHeart:setMode(Constants.HEARTMODE_BLUE)
        else
            self.playerHeart:setMode(Constants.HEARTMODE_RED)
        end
    end

    if Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    self.combatZone:update(dt)
    self.playerHeart:update(dt)
end

function TestHeart:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Heart Modes Test", 320, 20, "center")

    self.combatZone:draw()
    self.playerHeart:draw()

    -- Instructions
    love.graphics.setColor(1, 1, 1)
    local modeText = self.playerHeart.mode == Constants.HEARTMODE_RED and "RED (free move)" or "BLUE (gravity)"
    Fonts.default:draw("Mode: " .. modeText, 320, 410, "center")
    Fonts.default:draw("Arrows: Move | X: Toggle Mode | Z: Jump (blue)", 320, 430, "center")

    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Esc: Back to test menu", 320, 460, "center")
end

function TestHeart:exit()
    self.combatZone = nil
    self.playerHeart = nil
end

return TestHeart
