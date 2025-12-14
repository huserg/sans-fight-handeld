-- Combat Zone Entity
-- Manages the battle area where the player heart fights

local AssetsConfig = require("src.core.assets_config")

local CombatZone = {}
CombatZone.__index = CombatZone

function CombatZone.new()
    local self = setmetatable({}, CombatZone)

    -- Load sprites
    local zoneCfg = AssetsConfig.sprites.combatZone
    local borderCfg = AssetsConfig.sprites.combatZoneBorder

    self.zoneImage = love.graphics.newImage(zoneCfg.path)
    self.borderImage = love.graphics.newImage(borderCfg.path)
    self.zoneImage:setFilter("nearest", "nearest")
    self.borderImage:setFilter("nearest", "nearest")

    -- Default bounds from config
    local uiCfg = AssetsConfig.ui.combatZone
    self.x1 = uiCfg.defaultX1
    self.y1 = uiCfg.defaultY1
    self.x2 = uiCfg.defaultX2
    self.y2 = uiCfg.defaultY2

    -- Target bounds for smooth resizing
    self.targetX1 = self.x1
    self.targetY1 = self.y1
    self.targetX2 = self.x2
    self.targetY2 = self.y2

    -- Resize speed (pixels per second)
    self.resizeSpeed = 540

    -- Border thickness
    self.borderSize = 5

    return self
end

function CombatZone:resize(x1, y1, x2, y2, instant)
    self.targetX1 = x1
    self.targetY1 = y1
    self.targetX2 = x2
    self.targetY2 = y2

    if instant then
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    end
end

-- Alias for animated resize
function CombatZone:resizeTo(x1, y1, x2, y2)
    self:resize(x1, y1, x2, y2, false)
end

-- Alias for instant resize
function CombatZone:setSize(x1, y1, x2, y2)
    self:resize(x1, y1, x2, y2, true)
end

-- Check if resize animation is complete
function CombatZone:isResizing()
    return self.x1 ~= self.targetX1 or
           self.y1 ~= self.targetY1 or
           self.x2 ~= self.targetX2 or
           self.y2 ~= self.targetY2
end

function CombatZone:setSpeed(speed)
    self.resizeSpeed = speed
end

function CombatZone:update(dt)
    -- Smooth resize towards target
    local speed = self.resizeSpeed * dt

    self.x1 = self:moveTowards(self.x1, self.targetX1, speed)
    self.y1 = self:moveTowards(self.y1, self.targetY1, speed)
    self.x2 = self:moveTowards(self.x2, self.targetX2, speed)
    self.y2 = self:moveTowards(self.y2, self.targetY2, speed)
end

function CombatZone:moveTowards(current, target, maxDelta)
    if math.abs(target - current) <= maxDelta then
        return target
    elseif target > current then
        return current + maxDelta
    else
        return current - maxDelta
    end
end

function CombatZone:getWidth()
    return self.x2 - self.x1
end

function CombatZone:getHeight()
    return self.y2 - self.y1
end

function CombatZone:getCenter()
    return (self.x1 + self.x2) / 2, (self.y1 + self.y2) / 2
end

function CombatZone:getBounds()
    return self.x1, self.y1, self.x2, self.y2
end

function CombatZone:getInnerBounds()
    -- Inner bounds accounting for border
    return self.x1 + self.borderSize,
           self.y1 + self.borderSize,
           self.x2 - self.borderSize,
           self.y2 - self.borderSize
end

function CombatZone:containsPoint(x, y)
    local ix1, iy1, ix2, iy2 = self:getInnerBounds()
    return x >= ix1 and x <= ix2 and y >= iy1 and y <= iy2
end

function CombatZone:clampPosition(x, y, margin)
    margin = margin or 0
    local ix1, iy1, ix2, iy2 = self:getInnerBounds()

    local clampedX = math.max(ix1 + margin, math.min(ix2 - margin, x))
    local clampedY = math.max(iy1 + margin, math.min(iy2 - margin, y))

    return clampedX, clampedY
end

function CombatZone:draw()
    -- Draw black background (combat zone interior)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", self.x1, self.y1, self:getWidth(), self:getHeight())

    -- Draw white border
    love.graphics.setColor(1, 1, 1)

    -- Top border
    love.graphics.rectangle("fill", self.x1, self.y1, self:getWidth(), self.borderSize)
    -- Bottom border
    love.graphics.rectangle("fill", self.x1, self.y2 - self.borderSize, self:getWidth(), self.borderSize)
    -- Left border
    love.graphics.rectangle("fill", self.x1, self.y1, self.borderSize, self:getHeight())
    -- Right border
    love.graphics.rectangle("fill", self.x2 - self.borderSize, self.y1, self.borderSize, self:getHeight())
end

return CombatZone
