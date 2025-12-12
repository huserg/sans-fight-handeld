-- Bone Entity
-- Basic bone attack element with horizontal/vertical variants
-- Bones are drawn by repeating a middle segment between two end caps

local AssetsConfig = require("src.core.assets_config")

local Bone = {}
Bone.__index = Bone

-- Shared sprites (loaded once)
local sprites = {
    loaded = false,
    horizontal = nil,
    vertical = nil,
    -- Quads for slicing
    hQuads = {},
    vQuads = {}
}

local function loadSprites()
    if sprites.loaded then return end

    sprites.horizontal = love.graphics.newImage(AssetsConfig.sprites.boneH.path)
    sprites.vertical = love.graphics.newImage(AssetsConfig.sprites.boneV.path)
    sprites.horizontal:setFilter("nearest", "nearest")
    sprites.vertical:setFilter("nearest", "nearest")

    local hW, hH = sprites.horizontal:getDimensions()
    local vW, vH = sprites.vertical:getDimensions()

    -- Horizontal bone: 24x10, split into left cap (7px), middle (10px), right cap (7px)
    sprites.hQuads.left = love.graphics.newQuad(0, 0, 7, hH, hW, hH)
    sprites.hQuads.mid = love.graphics.newQuad(7, 0, 10, hH, hW, hH)
    sprites.hQuads.right = love.graphics.newQuad(17, 0, 7, hH, hW, hH)
    sprites.hCapSize = 7
    sprites.hMidSize = 10
    sprites.hThickness = hH

    -- Vertical bone: 10x24, split into top cap (7px), middle (10px), bottom cap (7px)
    sprites.vQuads.top = love.graphics.newQuad(0, 0, vW, 7, vW, vH)
    sprites.vQuads.mid = love.graphics.newQuad(0, 7, vW, 10, vW, vH)
    sprites.vQuads.bottom = love.graphics.newQuad(0, 17, vW, 7, vW, vH)
    sprites.vCapSize = 7
    sprites.vMidSize = 10
    sprites.vThickness = vW

    sprites.loaded = true
end

function Bone.new(x, y, length, orientation, isBlue)
    loadSprites()

    local self = setmetatable({}, Bone)

    -- Position (center of bone)
    self.x = x
    self.y = y

    -- Orientation and length
    self.orientation = orientation or "vertical"
    self.length = math.max(length or 24, 14) -- Minimum length = 2 caps

    -- Calculate dimensions
    if self.orientation == "vertical" then
        self.width = sprites.vThickness
        self.height = self.length
    else
        self.width = self.length
        self.height = sprites.hThickness
    end

    -- Velocity
    self.vx = 0
    self.vy = 0

    -- Blue bone (only hurts when player is moving)
    self.isBlue = isBlue or false

    -- Damage
    self.damage = 1

    -- Karma (poison damage)
    self.karma = 1

    -- Lifetime
    self.dead = false
    self.lifetime = nil
    self.timer = 0

    return self
end

function Bone:setVelocity(vx, vy)
    self.vx = vx
    self.vy = vy
end

function Bone:setLifetime(time)
    self.lifetime = time
end

function Bone:setDamage(damage)
    self.damage = damage
end

function Bone:setKarma(karma)
    self.karma = karma
end

function Bone:update(dt)
    -- Move
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Update lifetime
    if self.lifetime then
        self.timer = self.timer + dt
        if self.timer >= self.lifetime then
            self.dead = true
        end
    end

    -- Kill if way off screen
    if self.x < -200 or self.x > 840 or self.y < -200 or self.y > 680 then
        self.dead = true
    end
end

function Bone:getHitbox()
    local halfW = self.width / 2
    local halfH = self.height / 2
    return self.x - halfW, self.y - halfH, self.x + halfW, self.y + halfH
end

function Bone:draw()
    -- Set color based on type
    if self.isBlue then
        love.graphics.setColor(0, 0.7, 1)
    else
        love.graphics.setColor(1, 1, 1)
    end

    if self.orientation == "vertical" then
        self:drawVertical()
    else
        self:drawHorizontal()
    end
end

function Bone:drawVertical()
    local capSize = sprites.vCapSize
    local midSize = sprites.vMidSize
    local thickness = sprites.vThickness

    -- Calculate middle section length
    local middleLength = self.length - (capSize * 2)
    local startY = self.y - self.length / 2

    -- Draw top cap
    love.graphics.draw(sprites.vertical, sprites.vQuads.top,
        self.x - thickness / 2, startY)

    -- Draw middle sections
    local currentY = startY + capSize
    local remaining = middleLength
    while remaining > 0 do
        local drawHeight = math.min(remaining, midSize)
        if drawHeight < midSize then
            -- Partial quad for last segment
            local partialQuad = love.graphics.newQuad(0, 7, thickness, drawHeight,
                sprites.vertical:getDimensions())
            love.graphics.draw(sprites.vertical, partialQuad,
                self.x - thickness / 2, currentY)
        else
            love.graphics.draw(sprites.vertical, sprites.vQuads.mid,
                self.x - thickness / 2, currentY)
        end
        currentY = currentY + drawHeight
        remaining = remaining - midSize
    end

    -- Draw bottom cap
    love.graphics.draw(sprites.vertical, sprites.vQuads.bottom,
        self.x - thickness / 2, self.y + self.length / 2 - capSize)
end

function Bone:drawHorizontal()
    local capSize = sprites.hCapSize
    local midSize = sprites.hMidSize
    local thickness = sprites.hThickness

    -- Calculate middle section length
    local middleLength = self.length - (capSize * 2)
    local startX = self.x - self.length / 2

    -- Draw left cap
    love.graphics.draw(sprites.horizontal, sprites.hQuads.left,
        startX, self.y - thickness / 2)

    -- Draw middle sections
    local currentX = startX + capSize
    local remaining = middleLength
    while remaining > 0 do
        local drawWidth = math.min(remaining, midSize)
        if drawWidth < midSize then
            -- Partial quad for last segment
            local partialQuad = love.graphics.newQuad(7, 0, drawWidth, thickness,
                sprites.horizontal:getDimensions())
            love.graphics.draw(sprites.horizontal, partialQuad,
                currentX, self.y - thickness / 2)
        else
            love.graphics.draw(sprites.horizontal, sprites.hQuads.mid,
                currentX, self.y - thickness / 2)
        end
        currentX = currentX + drawWidth
        remaining = remaining - midSize
    end

    -- Draw right cap
    love.graphics.draw(sprites.horizontal, sprites.hQuads.right,
        self.x + self.length / 2 - capSize, self.y - thickness / 2)
end

return Bone
