-- Gaster Blaster Entity
-- Faithful port of the original Battle.xml "GasterBlasters" group.
-- The blaster is a skull sprite that enters, charges, fires a short flash,
-- recoils away, while a screen-spanning beam grows, holds, then decays.
--
-- State machine (matches the original):
--   ENTER  : lerp position toward End (pos += (End-pos)*dt*10, snap < 3) and
--            rotate Ang -> EndAng the same way.
--   WAIT   : charge for chargeTime seconds (Timer counts down by min(dt, Timer)).
--   FIRE   : hardcoded 0.1s flash before the beam appears.
--   LEAVE  : skull recoils backward along its angle (LeaveSpeed += 30/tick),
--            while the beam plays out and OUTLIVES the skull.
--
-- The whole entity is destroyed when the beam's BaseSize decays below 2.

local AssetsConfig = require("src.core.assets_config")
local Audio = require("src.systems.audio")

local GasterBlaster = {}
GasterBlaster.__index = GasterBlaster

-- Shared sprites (loaded once)
local sprites = {
    loaded = false,
    blaster = nil,
    beam = nil,
    quads = {}
}

-- Skull sheet: 2x2 grid, native frame 57x44
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
    sprites.beam = love.graphics.newImage("assets/sprites/gasterblast.png")
    sprites.blaster:setFilter("nearest", "nearest")
    sprites.beam:setFilter("nearest", "nearest")

    local imgW, imgH = sprites.blaster:getDimensions()
    for name, pos in pairs(FRAMES) do
        sprites.quads[name] = love.graphics.newQuad(
            pos[1] * FRAME_W, pos[2] * FRAME_H,
            FRAME_W, FRAME_H,
            imgW, imgH
        )
    end

    sprites.loaded = true
end

-- States
local STATE_ENTER = "enter"
local STATE_WAIT = "wait"
local STATE_FIRE = "fire"
local STATE_LEAVE = "leave"

-- Original constants
local FIRE_TIME = 0.1                -- hardcoded flash duration before the beam
local BEAM_LENGTH = 1000            -- beam spans the screen along the angle
local BEAM_ANCHOR = 70             -- beam centre is this far in front, scaled
local BEAM_BASE = 35               -- target thickness, scaled (35 * scale)
local SNAP_DIST = 3                 -- ENTER lerp snaps when this close

function GasterBlaster.new(startX, startY, targetX, targetY, angle, size)
    loadSprites()

    local self = setmetatable({}, GasterBlaster)

    self.startX = startX or targetX
    self.startY = startY or targetY
    self.endX = targetX
    self.endY = targetY

    self.x = self.startX
    self.y = self.startY

    -- Live angle (radians). Ang lerps toward endAng during ENTER.
    self.endAng = math.rad(angle or 0)
    self.ang = self.endAng

    -- Size enum 0/1/2 -> skull dimensions.
    -- size 0 -> (w 2x, h 1x), 1 -> 2x both, 2 -> 3x both. Never zero-scale.
    self.size = size or 0
    if self.size == 2 then
        self.scaleX, self.scaleY = 3, 3
    elseif self.size == 1 then
        self.scaleX, self.scaleY = 2, 2
    else
        self.scaleX, self.scaleY = 2, 1
    end

    -- Beam scale derives from the skull height, not the size enum:
    -- scale = skullHeight / nativeHeight / 2.
    self.skullHeight = FRAME_H * self.scaleY
    self.beamScale = self.skullHeight / FRAME_H / 2

    -- Timers (set via setTiming).
    self.chargeTime = 0
    self.blastTime = 0

    -- State machine
    self.state = STATE_ENTER
    self.timer = 0                  -- generic state timer (WAIT/FIRE countdown)
    self.leaveSpeed = 0

    -- Beam lifecycle
    self.beamActive = false         -- beam visible / playing out
    self.beamTimer = 0              -- time since the beam appeared
    self.baseSize = 0               -- current beam thickness (grows then decays)
    self.beamOpacity = 1            -- 0..1

    -- Damage (applied while the beam is at damaging opacity)
    self.damage = 1
    self.karma = 10

    self.currentFrame = "closed"
    self.alpha = 1

    -- Blasters fire from outside the box; draw unclipped (battle.lua reads this).
    self.clipToZone = false

    self.dead = false

    -- Charge sfx at creation (matches the original "GasterBlaster" play).
    Audio:playSfx("gasterBlaster")

    return self
end

-- chargeTime = WAIT duration (Param6), blastTime = beam hold duration (Param7).
function GasterBlaster:setTiming(chargeTime, blastTime)
    self.chargeTime = chargeTime or 0
    self.blastTime = blastTime or 0
    self.timer = self.chargeTime
end

local function lerpToward(current, target, dt)
    return current + (target - current) * dt * 10
end

function GasterBlaster:update(dt)
    if self.state == STATE_ENTER then
        self:updateEnter(dt)
    elseif self.state == STATE_WAIT then
        self:updateWait(dt)
    elseif self.state == STATE_FIRE then
        self:updateFire(dt)
    elseif self.state == STATE_LEAVE then
        self:updateLeave(dt)
    end

    -- The beam plays out independently and outlives the skull's FIRE state.
    if self.beamActive then
        self:updateBeam(dt)
    end
end

function GasterBlaster:updateEnter(dt)
    self.currentFrame = "opening"

    -- Lerp X
    if math.abs(self.x - self.endX) > SNAP_DIST then
        self.x = lerpToward(self.x, self.endX, dt)
    else
        self.x = self.endX
    end

    -- Lerp Y
    if math.abs(self.y - self.endY) > SNAP_DIST then
        self.y = lerpToward(self.y, self.endY, dt)
    else
        self.y = self.endY
    end

    -- Rotate Ang toward EndAng
    if math.abs(self.ang - self.endAng) > math.rad(SNAP_DIST) then
        self.ang = lerpToward(self.ang, self.endAng, dt)
    else
        self.ang = self.endAng
    end

    if self.x == self.endX and self.y == self.endY and self.ang == self.endAng then
        self.state = STATE_WAIT
        self.timer = self.chargeTime
    end
end

function GasterBlaster:updateWait(dt)
    self.currentFrame = "open"

    -- Timer counts down by min(dt, Timer) so it never overshoots below zero.
    self.timer = self.timer - math.min(dt, self.timer)

    if self.timer <= 0 then
        self.state = STATE_FIRE
        self.timer = FIRE_TIME
        self.currentFrame = "firing"
    end
end

function GasterBlaster:updateFire(dt)
    self.currentFrame = "firing"

    self.timer = self.timer - math.min(dt, self.timer)

    if self.timer <= 0 then
        -- Beam appears at the start of LEAVE; play the firing sfx now.
        self.state = STATE_LEAVE
        self.leaveSpeed = 0
        self.beamActive = true
        self.beamTimer = 0
        self.baseSize = 0
        self.beamOpacity = 1
        Audio:playSfx("gasterBlast")
    end
end

function GasterBlaster:updateLeave(dt)
    self.currentFrame = "firing"

    -- Skull recoils backward along its angle, accelerating each tick.
    self.leaveSpeed = self.leaveSpeed + 30
    self.x = self.x - math.cos(self.ang) * dt * self.leaveSpeed
    self.y = self.y - math.sin(self.ang) * dt * self.leaveSpeed
end

function GasterBlaster:updateBeam(dt)
    self.beamTimer = self.beamTimer + dt

    local targetSize = BEAM_BASE * self.beamScale
    local holdEnd = 5 / 30 + self.blastTime

    if self.baseSize < targetSize and self.beamTimer < holdEnd then
        -- Grow: original lerps to 35*scale over ~4 frames at 30fps.
        self.baseSize = self.baseSize + (targetSize / 4) * dt * 30
        if self.baseSize > targetSize then
            self.baseSize = targetSize
        end
    elseif self.beamTimer >= holdEnd then
        -- Decay thickness and fade opacity.
        self.baseSize = self.baseSize * (0.8 ^ (dt * 30))

        -- Opacity: 100 - ((Timer - BlastTime)*30 - 5)*10, normalised to 0..1.
        local op = 100 - ((self.beamTimer - self.blastTime) * 30 - 5) * 10
        self.beamOpacity = math.max(0, math.min(1, op / 100))

        if self.baseSize < 2 then
            self.dead = true
            self.beamActive = false
        end
    else
        -- Holding at full thickness.
        self.baseSize = targetSize
    end
end

-- Current sine pulse added to the beam thickness.
function GasterBlaster:beamSine()
    return math.sin(self.beamTimer * 30 / 1.5) * self.baseSize / 4
end

-- Beam centre point, BEAM_ANCHOR*scale in front of the skull along the angle.
function GasterBlaster:beamCenter()
    local s = BEAM_ANCHOR * self.beamScale
    return self.x + math.cos(self.ang) * s, self.y + math.sin(self.ang) * s
end

-- Hitbox for battle.lua checkBeamCollision: a line along the angle with a
-- perpendicular half-width. The damage rectangle height is BaseSize*3/4
-- (matching GasterBlastHit). Returns nil while not damaging (faded out).
function GasterBlaster:getBeamHitbox()
    if not self.beamActive then return nil end
    -- Original disables hit damage once opacity drops to/below 80%.
    if self.beamOpacity <= 0.8 then return nil end

    local cx, cy = self:beamCenter()
    local cos = math.cos(self.ang)
    local sin = math.sin(self.ang)
    local half = BEAM_LENGTH / 2

    return {
        x1 = cx - cos * half,
        y1 = cy - sin * half,
        x2 = cx + cos * half,
        y2 = cy + sin * half,
        width = self.baseSize * 3 / 4
    }
end

function GasterBlaster:draw()
    if self.dead then return end

    -- Beam is drawn behind the skull so the skull mouth overlaps it.
    if self.beamActive then
        self:drawBeam()
    end

    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.draw(
        sprites.blaster,
        sprites.quads[self.currentFrame],
        self.x, self.y,
        self.ang,
        self.scaleX, self.scaleY,
        FRAME_W / 2, FRAME_H / 2
    )

    love.graphics.setColor(1, 1, 1, 1)
end

function GasterBlaster:drawBeam()
    local cx, cy = self:beamCenter()
    local thickness = self.baseSize + self:beamSine()
    if thickness < 1 then return end

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.ang)

    -- Outer beam (full thickness)
    love.graphics.setColor(1, 1, 1, self.beamOpacity)
    love.graphics.rectangle("fill", -BEAM_LENGTH / 2, -thickness / 2, BEAM_LENGTH, thickness)

    -- Brighter inner core (matches the layered GasterBlast2/3 sprites)
    love.graphics.setColor(1, 1, 1, self.beamOpacity * 0.9)
    love.graphics.rectangle("fill", -BEAM_LENGTH / 2, -thickness / 4, BEAM_LENGTH, thickness / 2)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return GasterBlaster
