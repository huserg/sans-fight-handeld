-- HP Bar UI Component
-- Displays player health with Undertale-style bar

local Fonts = require("src.ui.fonts")

local HpBar = {}
HpBar.__index = HpBar

-- Default layout constants (standalone / test_hp usage)
local DEFAULT_BAR_X = 30
local DEFAULT_BAR_Y = 400
-- Original HUD: HPBackground width = floor(MaxHP * 1.2) = 110 at MaxHP 92,
-- "KR" label persistent before the value, value zero-padded to 2 digits.
local BAR_WIDTH = 110
local BAR_HEIGHT = 21
local BAR_INNER_OFFSET = 2
local LABEL_OFFSET_X = -2
local KR_OFFSET_X = 150
local VALUE_OFFSET_X = 180

-- Optional x/y override so callers (e.g. battle_ui) can position the bar
-- at a custom location without duplicating drawing logic.
function HpBar.new(x, y)
    local self = setmetatable({}, HpBar)

    self.barX = x or DEFAULT_BAR_X
    self.barY = y or DEFAULT_BAR_Y
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

    local bx = self.barX
    local by = self.barY

    -- Draw "HP" label
    love.graphics.setColor(1, 1, 1)
    Fonts.battle:setScale(2)
    Fonts.battle:draw("HP", bx + LABEL_OFFSET_X, by + 5, "left")

    -- Draw bar background (dark red = missing HP)
    love.graphics.setColor(0.5, 0, 0)
    love.graphics.rectangle("fill",
        bx + 20,
        by + BAR_INNER_OFFSET,
        BAR_WIDTH,
        BAR_HEIGHT - BAR_INNER_OFFSET * 2
    )

    -- Calculate bar widths
    local hpRatio = math.max(0, currentHp - karma) / maxHp
    local karmaRatio = karma / maxHp
    local yellowWidth = BAR_WIDTH * hpRatio
    local purpleWidth = BAR_WIDTH * karmaRatio

    -- Draw yellow HP segment
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill",
        bx + 20,
        by + BAR_INNER_OFFSET,
        yellowWidth,
        BAR_HEIGHT - BAR_INNER_OFFSET * 2
    )

    -- Draw purple karma segment immediately right of yellow
    if karma > 0 then
        love.graphics.setColor(0.6, 0, 0.6)
        love.graphics.rectangle("fill",
            bx + 20 + yellowWidth,
            by + BAR_INNER_OFFSET,
            purpleWidth,
            BAR_HEIGHT - BAR_INNER_OFFSET * 2
        )
    end

    -- Persistent "KR" label before the value (matches the original HUD, where it
    -- sits between the bar and the HP readout regardless of karma).
    love.graphics.setColor(1, 1, 1)
    Fonts.battle:setScale(2)
    Fonts.battle:draw("KR", bx + KR_OFFSET_X, by + 5, "left")

    -- Draw HP value text, zero-padded to two digits as in the original.
    local hp = math.floor(math.max(0, currentHp - karma))
    local hpText = string.format("%02d / %d", hp, maxHp)
    Fonts.battle:draw(hpText, bx + VALUE_OFFSET_X, by + 5, "left")
end

return HpBar
