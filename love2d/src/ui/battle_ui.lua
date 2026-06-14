-- Battle UI
-- Bottom UI with action buttons and HP bar (Undertale style)
-- Layout mirrors the original Construct 2 BattleScreen (640x480 reference)

local Fonts = require("src.ui.fonts")
local HpBar = require("src.ui.hp_bar")

local BattleUI = {}
BattleUI.__index = BattleUI

-- Button sprite frame: normal on top, selected directly below (native 112x44)
local BUTTON_FRAME_W = 112
local BUTTON_FRAME_H = 44

-- Left-edge positions from the original layout (C2 hotspot is top-left)
local BUTTONS_Y = 432
local BUTTON_X = { 32, 184, 344, 496 }

-- Bottom info row (name / LV), aligned to the C2 layout
local INFO_Y = 404

-- HP bar position: bx+20 aligns to original HP_BAR_X (256), by matches INFO_Y (404)
local HP_BAR_ORIGIN_X = 236
local HP_BAR_ORIGIN_Y = 404

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

    -- Delegate HP bar rendering to the shared HpBar component
    self.hpBar = HpBar.new(HP_BAR_ORIGIN_X, HP_BAR_ORIGIN_Y)

    return self
end

function BattleUI:setSelectedButton(index)
    self.selectedButton = index
end

-- Update smooth HP animation; call each frame before draw.
function BattleUI:update(dt, hp, maxHp, karma)
    self.hpBar:update(dt, hp, maxHp, karma or 0)
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

    -- HP bar (label + bar + values + optional KR) delegated to HpBar component
    self.hpBar:draw(hp, maxHp, karma)

    -- Action buttons at native size
    for i, btn in ipairs(self.buttons) do
        local isSelected = (self.selectedButton == i)
        local quad = isSelected and btn.selectedQuad or btn.normalQuad

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(btn.image, quad, btn.x, BUTTONS_Y)
    end
end

return BattleUI
