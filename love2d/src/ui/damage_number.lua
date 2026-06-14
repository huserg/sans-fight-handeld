-- Floating damage number (MISS or a hit value) that rises and fades.
-- Construction and update are LOVE-free so they can be headless-tested.
local Fonts = require("src.ui.fonts")

local DamageNumber = {}
DamageNumber.__index = DamageNumber

local LIFETIME   = 1.0  -- seconds until the number disappears
local RISE_SPEED = 40   -- pixels per second upward

function DamageNumber.new(text, x, y)
    return setmetatable({
        text   = tostring(text),
        isMiss = (tostring(text) == "MISS"),
        x      = x,
        y      = y,
        timer  = 0,
        dead   = false,
    }, DamageNumber)
end

function DamageNumber:update(dt)
    self.timer = self.timer + dt
    self.y     = self.y - RISE_SPEED * dt
    if self.timer >= LIFETIME then
        self.dead = true
    end
end

-- Alpha fades from 1 to 0 over the lifetime.
function DamageNumber:draw()
    local alpha = math.max(0, 1 - self.timer / LIFETIME)

    if self.isMiss then
        love.graphics.setColor(0.6, 0.6, 0.6, alpha)
    else
        love.graphics.setColor(1, 0, 0, alpha)
    end

    -- Fonts.damage is a SpriteFont; draw(text, x, y, align) centers on x.
    Fonts.damage:setScale(1)
    Fonts.damage:draw(self.text, self.x, self.y, "center")

    love.graphics.setColor(1, 1, 1, 1)
end

return DamageNumber
