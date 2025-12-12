-- HP Bar UI Component
-- Displays player health with Undertale-style bar

local Fonts = require("src.ui.fonts")

local HpBar = {}
HpBar.__index = HpBar

-- Layout constants
local BAR_X = 30
local BAR_Y = 400
local BAR_WIDTH = 120
local BAR_HEIGHT = 21
local BAR_INNER_OFFSET = 2
local LABEL_OFFSET_X = -2
local VALUE_OFFSET_X = 140

function HpBar.new()
    local self = setmetatable({}, HpBar)

    self.displayHp = 0
    self.displayKarma = 0

    return self
end

function HpBar:update(dt, currentHp, maxHp, karma)
    -- Smooth HP display
    local targetHp = currentHp - karma
    if self.displayHp < targetHp then
        self.displayHp = math.min(self.displayHp + 100 * dt, targetHp)
    elseif self.displayHp > targetHp then
        self.displayHp = math.max(self.displayHp - 200 * dt, targetHp)
    end

    self.displayKarma = karma
end

function HpBar:draw(currentHp, maxHp, karma)
    karma = karma or 0

    -- Draw "HP" label
    love.graphics.setColor(1, 1, 1)
    Fonts.battle:setScale(2)
    Fonts.battle:draw("HP", BAR_X + LABEL_OFFSET_X, BAR_Y + 5, "left")

    -- Draw bar background (red = missing HP)
    love.graphics.setColor(0.5, 0, 0)
    love.graphics.rectangle("fill",
        BAR_X + 20,
        BAR_Y + BAR_INNER_OFFSET,
        BAR_WIDTH,
        BAR_HEIGHT - BAR_INNER_OFFSET * 2
    )

    -- Calculate bar widths
    local hpRatio = math.max(0, currentHp - karma) / maxHp
    local karmaRatio = karma / maxHp
    local yellowWidth = BAR_WIDTH * hpRatio
    local purpleWidth = BAR_WIDTH * karmaRatio

    -- Draw yellow HP bar
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill",
        BAR_X + 20,
        BAR_Y + BAR_INNER_OFFSET,
        yellowWidth,
        BAR_HEIGHT - BAR_INNER_OFFSET * 2
    )

    -- Draw purple karma bar (overlaps yellow from right)
    if karma > 0 then
        love.graphics.setColor(0.6, 0, 0.6)
        love.graphics.rectangle("fill",
            BAR_X + 20 + yellowWidth,
            BAR_Y + BAR_INNER_OFFSET,
            purpleWidth,
            BAR_HEIGHT - BAR_INNER_OFFSET * 2
        )
    end

    -- Draw HP text
    love.graphics.setColor(1, 1, 1)
    local hpText = tostring(math.floor(math.max(0, currentHp - karma))) .. " / " .. tostring(maxHp)
    Fonts.battle:setScale(2)
    Fonts.battle:draw(hpText, BAR_X + VALUE_OFFSET_X, BAR_Y + 5, "left")

    -- Draw KR label if karma active
    if karma > 0 then
        love.graphics.setColor(0.6, 0, 0.6)
        Fonts.battle:draw("KR", BAR_X + VALUE_OFFSET_X + 80, BAR_Y + 5, "left")
    end
end

return HpBar
