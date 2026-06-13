-- Battle UI
-- Bottom UI with action buttons and HP bar (Undertale style)
-- Layout mirrors the original Construct 2 BattleScreen (640x480 reference)

local Fonts = require("src.ui.fonts")

local BattleUI = {}
BattleUI.__index = BattleUI

-- Button sprite frame: normal on top, selected directly below (native 112x44)
local BUTTON_FRAME_W = 112
local BUTTON_FRAME_H = 44

-- Left-edge positions from the original layout (C2 hotspot is top-left)
local BUTTONS_Y = 432
local BUTTON_X = { 32, 184, 344, 496 }

-- Bottom info row (name / LV / HP), aligned to the C2 HP layout
local INFO_Y = 404
local HP_LABEL_X = 224
local HP_BAR_X = 256
local HP_BAR_W = 110
local HP_BAR_H = 16

function BattleUI.new()
    local self = setmetatable({}, BattleUI)

    local names = { "fight", "act", "item", "mercy" }
    self.buttons = {}
    for i, name in ipairs(names) do
        local image = love.graphics.newImage("assets/sprites/ui" .. name .. "-sheet0.png")
        image:setFilter("nearest", "nearest")

        local imgW, imgH = image:getDimensions()
        self.buttons[i] = {
            name = name,
            x = BUTTON_X[i],
            image = image,
            normalQuad = love.graphics.newQuad(0, 0, BUTTON_FRAME_W, BUTTON_FRAME_H, imgW, imgH),
            selectedQuad = love.graphics.newQuad(0, BUTTON_FRAME_H, BUTTON_FRAME_W, BUTTON_FRAME_H, imgW, imgH)
        }
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

    -- Black bar behind the bottom UI (sits just below the combat zone)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, INFO_Y - 8, 640, 480 - (INFO_Y - 8))

    -- Player name and LV
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw(self.playerName, 32, INFO_Y, "left")
    Fonts.default:draw("LV " .. self.playerLV, 130, INFO_Y, "left")

    -- HP label
    Fonts.default:draw("HP", HP_LABEL_X, INFO_Y, "left")

    -- HP bar background (dark red)
    love.graphics.setColor(0.3, 0, 0)
    love.graphics.rectangle("fill", HP_BAR_X, INFO_Y, HP_BAR_W, HP_BAR_H)

    -- Yellow HP
    local hpRatio = math.max(0, (hp - karma)) / maxHp
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill", HP_BAR_X, INFO_Y, HP_BAR_W * hpRatio, HP_BAR_H)

    -- Karma (purple) if active
    if karma > 0 then
        local karmaRatio = karma / maxHp
        love.graphics.setColor(0.6, 0, 0.6)
        love.graphics.rectangle("fill", HP_BAR_X + HP_BAR_W * hpRatio, INFO_Y, HP_BAR_W * karmaRatio, HP_BAR_H)
    end

    -- HP values
    love.graphics.setColor(1, 1, 1)
    local hpText = math.floor(math.max(0, hp - karma)) .. " / " .. maxHp
    Fonts.default:draw(hpText, HP_BAR_X + HP_BAR_W + 12, INFO_Y, "left")

    -- Action buttons at native size
    for i, btn in ipairs(self.buttons) do
        local isSelected = (self.selectedButton == i)
        local quad = isSelected and btn.selectedQuad or btn.normalQuad

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(btn.image, quad, btn.x, BUTTONS_Y)
    end
end

return BattleUI
