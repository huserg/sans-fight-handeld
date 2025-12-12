-- Gaster Blaster Entity
-- The iconic skull that fires laser beams

local GasterBlaster = {}
GasterBlaster.__index = GasterBlaster

-- Shared sprites
local sprites = {
    loaded = false,
    blaster = nil,
    blast = nil,
    quads = {}
}

-- Animation frames: 2x2 grid, 57x44 each
local FRAME_W = 57
local FRAME_H = 44
local FRAMES = {
    closed = {0, 0},
    opening = {1, 0},
    open = {0, 1},
    firing = {1, 1}
}

local function loadSprites()
    if sprites.loaded then return end

    sprites.blaster = love.graphics.newImage("assets/sprites/gasterblaster-sheet0.png")
    sprites.blast = love.graphics.newImage("assets/sprites/gasterblast.png")
    sprites.blaster:setFilter("nearest", "nearest")
    sprites.blast:setFilter("nearest", "nearest")

    local imgW, imgH = sprites.blaster:getDimensions()
    for name, pos in pairs(FRAMES) do
        sprites.quads[name] = love.graphics.newQuad(
            pos[1] * FRAME_W,
            pos[2] * FRAME_H,
            FRAME_W, FRAME_H,
            imgW, imgH
        )
    end

    sprites.loaded = true
end

-- States
local STATE_APPEAR = "appear"
local STATE_AIM = "aim"
local STATE_CHARGE = "charge"
local STATE_FIRE = "fire"
local STATE_FADE = "fade"
local STATE_DEAD = "dead"

function GasterBlaster.new(x, y, angle, scale)
    loadSprites()

    local self = setmetatable({}, GasterBlaster)

    -- Position and rotation
    self.x = x
    self.y = y
    self.angle = angle or 0
    self.scale = scale or 1

    -- State machine
    self.state = STATE_APPEAR
    self.stateTimer = 0

    -- Timing
    self.appearTime = 0.2
    self.aimTime = 0.3
    self.chargeTime = 0.15
    self.fireTime = 0.5
    self.fadeTime = 0.3

    -- Visual
    self.alpha = 0
    self.currentFrame = "closed"

    -- Beam properties
    self.beamLength = 600
    self.beamWidth = 30
    self.beamActive = false
    self.beamTimer = 0
    self.wobbleSpeed = 30
    self.wobbleAmount = 8

    -- Damage
    self.damage = 5
    self.karma = 2

    -- Flags
    self.dead = false

    return self
end

function GasterBlaster:setTiming(appear, aim, charge, fire, fade)
    self.appearTime = appear or self.appearTime
    self.aimTime = aim or self.aimTime
    self.chargeTime = charge or self.chargeTime
    self.fireTime = fire or self.fireTime
    self.fadeTime = fade or self.fadeTime
end

function GasterBlaster:update(dt)
    self.stateTimer = self.stateTimer + dt

    if self.state == STATE_APPEAR then
        -- Fade in
        self.alpha = math.min(1, self.stateTimer / self.appearTime)
        self.currentFrame = "closed"
        if self.stateTimer >= self.appearTime then
            self.state = STATE_AIM
            self.stateTimer = 0
        end

    elseif self.state == STATE_AIM then
        -- Mouth starts opening
        self.currentFrame = "opening"
        if self.stateTimer >= self.aimTime then
            self.state = STATE_CHARGE
            self.stateTimer = 0
        end

    elseif self.state == STATE_CHARGE then
        -- Mouth fully open, charging
        self.currentFrame = "open"
        if self.stateTimer >= self.chargeTime then
            self.state = STATE_FIRE
            self.stateTimer = 0
            self.beamActive = true
        end

    elseif self.state == STATE_FIRE then
        -- Firing beam
        self.currentFrame = "firing"
        self.beamTimer = self.beamTimer + dt
        if self.stateTimer >= self.fireTime then
            self.state = STATE_FADE
            self.stateTimer = 0
            self.beamActive = false
            self.beamTimer = 0
        end

    elseif self.state == STATE_FADE then
        -- Fade out
        self.alpha = 1 - (self.stateTimer / self.fadeTime)
        self.currentFrame = "closed"
        if self.stateTimer >= self.fadeTime then
            self.state = STATE_DEAD
            self.dead = true
        end
    end
end

function GasterBlaster:getBeamHitbox()
    if not self.beamActive then
        return nil
    end

    -- Calculate beam rectangle based on angle
    local cos = math.cos(self.angle)
    local sin = math.sin(self.angle)

    -- Beam starts at blaster mouth
    local startX = self.x + cos * 20 * self.scale
    local startY = self.y + sin * 20 * self.scale

    -- Return beam line for collision
    return {
        x1 = startX,
        y1 = startY,
        x2 = startX + cos * self.beamLength,
        y2 = startY + sin * self.beamLength,
        width = self.beamWidth * self.scale
    }
end

function GasterBlaster:draw()
    if self.dead then return end

    love.graphics.setColor(1, 1, 1, self.alpha)

    -- Draw blaster
    local quad = sprites.quads[self.currentFrame]
    love.graphics.draw(
        sprites.blaster,
        quad,
        self.x, self.y,
        self.angle,
        self.scale, self.scale,
        FRAME_W / 2, FRAME_H / 2
    )

    -- Draw beam
    if self.beamActive then
        self:drawBeam()
    end
end

function GasterBlaster:drawBeam()
    local cos = math.cos(self.angle)
    local sin = math.sin(self.angle)

    -- Beam start position (at mouth)
    local startX = self.x + cos * 25 * self.scale
    local startY = self.y + sin * 25 * self.scale

    -- Wobble effect on width
    local wobble = math.sin(self.beamTimer * self.wobbleSpeed) * self.wobbleAmount
    local beamW = (self.beamWidth + wobble) * self.scale

    -- Draw beam as a rectangle
    love.graphics.setColor(1, 1, 1, self.alpha)

    love.graphics.push()
    love.graphics.translate(startX, startY)
    love.graphics.rotate(self.angle)

    -- Main beam with wobble
    love.graphics.rectangle("fill", 0, -beamW/2, self.beamLength, beamW)

    -- Brighter core (also wobbles)
    love.graphics.setColor(1, 1, 1, self.alpha * 0.8)
    love.graphics.rectangle("fill", 0, -beamW/4, self.beamLength, beamW/2)

    love.graphics.pop()
end

return GasterBlaster
