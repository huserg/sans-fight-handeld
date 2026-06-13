-- BoneStab Entity
-- A wall of bones that pops out of one side of the combat zone after a warning,
-- stays for a while, then disappears. Direction: 0=E, 1=S, 2=W, 3=N.

local AssetsConfig = require("src.core.assets_config")

local BoneStab = {}
BoneStab.__index = BoneStab

local sprites = { loaded = false }

local function loadSprites()
    if sprites.loaded then return end
    sprites.warn = love.graphics.newImage(AssetsConfig.sprites.boneStabWarn.path)
    sprites.h = love.graphics.newImage(AssetsConfig.sprites.boneStabH.path)
    sprites.v = love.graphics.newImage(AssetsConfig.sprites.boneStabV.path)
    for _, img in pairs({ sprites.warn, sprites.h, sprites.v }) do
        img:setFilter("nearest", "nearest")
    end
    sprites.loaded = true
end

function BoneStab.new(combatZone, direction, distance, warnTime, stayTime)
    loadSprites()

    local self = setmetatable({}, BoneStab)
    self.combatZone = combatZone
    self.direction = direction or 0
    self.distance = distance or 24
    self.warnTime = warnTime or 0.4
    -- Floor the stay so a stayTime of 0 still produces a brief, dangerous jab
    self.stayTime = math.max(stayTime or 0.3, 0.12)
    self.timer = 0
    self.dead = false
    self.damage = 1
    self.karma = 1
    return self
end

-- True once the bones are actually out (the dangerous phase)
function BoneStab:isStabbing()
    return self.timer >= self.warnTime
        and self.timer < self.warnTime + self.stayTime
end

-- Danger strip along the chosen wall, depth = distance
function BoneStab:getStrip()
    local x1, y1, x2, y2 = self.combatZone:getInnerBounds()
    local d = self.distance
    if self.direction == 0 then       -- East (right wall)
        return x2 - d, y1, x2, y2
    elseif self.direction == 1 then   -- South (bottom)
        return x1, y2 - d, x2, y2
    elseif self.direction == 2 then   -- West (left wall)
        return x1, y1, x1 + d, y2
    else                               -- North (top)
        return x1, y1, x2, y1 + d
    end
end

function BoneStab:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.warnTime + self.stayTime then
        self.dead = true
    end
end

-- Only collides while stabbing
function BoneStab:getHitbox()
    if not self:isStabbing() then
        return -1000, -1000, -1000, -1000
    end
    return self:getStrip()
end

function BoneStab:draw()
    local sx1, sy1, sx2, sy2 = self:getStrip()
    local vertical = (self.direction == 1 or self.direction == 3)

    if self:isStabbing() then
        love.graphics.setColor(1, 1, 1)
        local tile = vertical and sprites.v or sprites.h
        local tw, th = tile:getDimensions()
        -- Tile across the wall length to fill the strip
        if vertical then
            for x = sx1, sx2 - 1, tw do
                love.graphics.draw(tile, x, (self.direction == 1) and (sy2 - th) or sy1)
            end
        else
            for y = sy1, sy2 - 1, th do
                love.graphics.draw(tile, (self.direction == 0) and (sx2 - tw) or sx1, y)
            end
        end
    elseif self.timer < self.warnTime then
        -- Warning markers along the wall edge
        love.graphics.setColor(1, 1, 1, 0.8)
        local tw, th = sprites.warn:getDimensions()
        if vertical then
            local y = (self.direction == 1) and (sy2 - th) or sy1
            for x = sx1, sx2 - 1, tw do
                love.graphics.draw(sprites.warn, x, y)
            end
        else
            local x = (self.direction == 0) and (sx2 - tw) or sx1
            for y = sy1, sy2 - 1, th do
                love.graphics.draw(sprites.warn, x, y)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return BoneStab
