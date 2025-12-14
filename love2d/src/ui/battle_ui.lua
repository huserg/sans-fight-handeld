-- Battle UI
-- Bottom UI with action buttons and HP bar (Undertale style)

local Fonts = require("src.ui.fonts")

local BattleUI = {}
BattleUI.__index = BattleUI

-- Button dimensions (each button has 2 frames: normal on top, selected on bottom)
local BUTTON_W = 57
local BUTTON_H = 26

-- Layout constants
local UI_Y = 398
local BUTTONS_Y = 430
local BUTTON_SPACING = 105
local FIRST_BUTTON_X = 50

function BattleUI.new()
    local self = setmetatable({}, BattleUI)

    -- Load button sprites
    self.buttons = {
        { name = "fight", image = nil, x = FIRST_BUTTON_X },
        { name = "act", image = nil, x = FIRST_BUTTON_X + BUTTON_SPACING },
        { name = "item", image = nil, x = FIRST_BUTTON_X + BUTTON_SPACING * 2 },
        { name = "mercy", image = nil, x = FIRST_BUTTON_X + BUTTON_SPACING * 3 }
    }

    -- Load images
    for _, btn in ipairs(self.buttons) do
        local path = "assets/sprites/ui" .. btn.name .. "-sheet0.png"
        btn.image = love.graphics.newImage(path)
        btn.image:setFilter("nearest", "nearest")

        -- Create quads for normal and selected states
        local imgW, imgH = btn.image:getDimensions()
        btn.normalQuad = love.graphics.newQuad(0, 0, BUTTON_W, BUTTON_H, imgW, imgH)
        btn.selectedQuad = love.graphics.newQuad(0, BUTTON_H, BUTTON_W, BUTTON_H, imgW, imgH)
    end

    -- Selected button (nil during attack phase)
    self.selectedButton = nil

    -- Player info
    self.playerName = "CHARA"
    self.playerLV = 1

    return self
end

function BattleUI:setSelectedButton(index)
    self.selectedButton = index
end

function BattleUI:draw(hp, maxHp, karma)
    karma = karma or 0

    -- Draw bottom black bar background
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, UI_Y, 640, 80)

    -- Draw player name and LV
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw(self.playerName, 32, UI_Y + 8, "left")

    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("LV " .. self.playerLV, 110, UI_Y + 8, "left")

    -- Draw HP label
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("HP", 175, UI_Y + 8, "left")

    -- Draw HP bar background (dark red)
    local barX = 205
    local barY = UI_Y + 6
    local barW = 100
    local barH = 16

    love.graphics.setColor(0.3, 0, 0)
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    -- Draw yellow HP
    local hpRatio = math.max(0, (hp - karma)) / maxHp
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill", barX, barY, barW * hpRatio, barH)

    -- Draw karma (purple) if active
    if karma > 0 then
        local karmaRatio = karma / maxHp
        love.graphics.setColor(0.6, 0, 0.6)
        love.graphics.rectangle("fill", barX + barW * hpRatio, barY, barW * karmaRatio, barH)
    end

    -- Draw HP values
    love.graphics.setColor(1, 1, 1)
    local hpText = math.floor(math.max(0, hp - karma)) .. " / " .. maxHp
    Fonts.default:draw(hpText, barX + barW + 10, UI_Y + 8, "left")

    -- Draw action buttons
    for i, btn in ipairs(self.buttons) do
        local isSelected = (self.selectedButton == i)
        local quad = isSelected and btn.selectedQuad or btn.normalQuad

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(btn.image, quad, btn.x, BUTTONS_Y)
    end
end

return BattleUI
