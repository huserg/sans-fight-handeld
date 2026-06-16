-- Player Heart Entity
-- The player's soul that moves and takes damage

local Constants = require("src.core.constants")
local AssetsConfig = require("src.core.assets_config")
local Input = require("src.systems.input")

local PlayerHeart = {}
PlayerHeart.__index = PlayerHeart

-- Movement constants (match the C2 Battle sheet "PlayerMovement", lines 3037-4481)
-- Heart speed matches the original (HeartSpeed = 150)
local MOVE_SPEED = 150
-- Additive upward impulse applied on jump (HEART_JUMP_STRENGTH = 180)
local JUMP_STRENGTH = 180
-- Releasing jump while rising clamps the away-from-gravity speed to this
-- magnitude, giving variable jump height (HEART_JUMPHOLD_CUTOFF = 30).
local JUMP_HOLD_CUTOFF = 30
-- Max speed along the gravity axis (MaxFallSpeed = 750)
local MAX_FALL_SPEED = 750

-- Gravity magnitude curve from the original, keyed on downSpeed (the signed
-- velocity component along the gravity axis, positive = falling).
local function gravityFor(downSpeed)
    if downSpeed < 240 and downSpeed > 15 then
        return 540
    elseif downSpeed <= 15 and downSpeed > -30 then
        return 180
    elseif downSpeed <= -30 and downSpeed > -120 then
        return 450
    else -- downSpeed <= -120 (and the downSpeed >= 240 fall-through)
        return 180
    end
end

function PlayerHeart.new(combatZone)
    local self = setmetatable({}, PlayerHeart)

    -- Load sprite
    local cfg = AssetsConfig.sprites.playerHeart
    self.image = love.graphics.newImage(cfg.path)
    self.image:setFilter("nearest", "nearest")
    self.originX = cfg.originX
    self.originY = cfg.originY
    self.width = cfg.width
    self.height = cfg.height

    -- Reference to combat zone for bounds
    self.combatZone = combatZone

    -- Position (center of heart)
    local cx, cy = combatZone:getCenter()
    self.x = cx
    self.y = cy

    -- Velocity
    self.vx = 0
    self.vy = 0

    -- Heart mode (red = free movement, blue = gravity)
    self.mode = Constants.HEARTMODE_RED

    -- Blue mode state
    self.grounded = false
    self.gravityDirection = "down"

    -- Platforms the heart can land on (set by the battle each frame)
    self.platforms = {}
    self.ridingPlatform = nil

    -- Max fall speed (adjustable per attack via HeartMaxFallSpeed)
    self.maxFallSpeed = MAX_FALL_SPEED

    -- Slam attack state
    self.slamming = false
    self.slamDir = 1
    self.slamDamage = false
    self.pendingSlamDamage = false

    -- Invincibility frames
    self.invincible = false
    self.invincibleTimer = 0
    self.invincibleDuration = 1.0
    self.flashTimer = 0

    -- Karma (KR) display mirror; the battle owns the karma model and keeps
    -- this field in sync each frame for the HP bar.
    self.karma = 0

    return self
end

function PlayerHeart:setMode(mode)
    self.mode = mode
    if mode == Constants.HEARTMODE_RED then
        self.vy = 0
        self.grounded = false
    end
end

function PlayerHeart:setGravityDirection(direction)
    self.gravityDirection = direction
end

function PlayerHeart:setMaxFallSpeed(speed)
    self.maxFallSpeed = speed or self.maxFallSpeed
end

function PlayerHeart:setSlamDamage(enabled)
    self.slamDamage = enabled
end

-- Reset per-attack physics state so values do not leak between attacks
function PlayerHeart:resetForAttack()
    self.maxFallSpeed = MAX_FALL_SPEED -- 750, matching the original default
    self.vx, self.vy = 0, 0
    self.grounded = false
    self.gravityDirection = "down"
    self.ridingPlatform = nil
    self.slamming = false
    self.slamDamage = false
    self.pendingSlamDamage = false
end

-- Slam direction to the gravity direction it establishes once the soul is
-- pinned against that wall (0=right, 1=down, 2=left, 3=up).
local SLAM_DIRECTION = { [0] = "right", [1] = "down", [2] = "left", [3] = "up" }

-- Slam the heart against a wall (direction 0=right, 1=down, 2=left, 3=up)
function PlayerHeart:slam(direction)
    self.slamming = true
    self.slamDir = direction or 1
    self.vx, self.vy = 0, 0
end

function PlayerHeart:updateSlam(dt)
    local s = self.maxFallSpeed
    local dir = self.slamDir

    -- A zero/negative slam speed would never reach a wall: end immediately
    -- so the heart can't freeze (e.g. sans_final sets MaxFallSpeed 0 first).
    if s <= 0 then
        self.slamming = false
        self.vx, self.vy = 0, 0
        return
    end

    if dir == 0 then self.x = self.x + s * dt
    elseif dir == 1 then self.y = self.y + s * dt
    elseif dir == 2 then self.x = self.x - s * dt
    elseif dir == 3 then self.y = self.y - s * dt end

    local ix1, iy1, ix2, iy2 = self.combatZone:getInnerBounds()
    local mx, my = self.originX, self.originY
    if dir == 0 and self.x + mx >= ix2 then self.x = ix2 - mx; self.slamming = false
    elseif dir == 1 and self.y + my >= iy2 then self.y = iy2 - my; self.slamming = false
    elseif dir == 2 and self.x - mx <= ix1 then self.x = ix1 + mx; self.slamming = false
    elseif dir == 3 and self.y - my <= iy1 then self.y = iy1 + my; self.slamming = false end

    if not self.slamming then
        self.vx, self.vy = 0, 0
        -- Impact damage if SansSlamDamage was enabled (battle applies it)
        if self.slamDamage then self.pendingSlamDamage = true end
        -- The slam pins the soul against the wall it hit, which becomes the
        -- new gravity direction (0=right, 1=down, 2=left, 3=up).
        self.gravityDirection = SLAM_DIRECTION[dir] or "down"
        self.grounded = true
    end
end

function PlayerHeart:teleport(x, y)
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
end

function PlayerHeart:damage(amount)
    if self.invincible then
        return false
    end

    self.invincible = true
    self.invincibleTimer = self.invincibleDuration

    return true
end

function PlayerHeart:update(dt)
    -- Handle invincibility
    if self.invincible then
        self.invincibleTimer = self.invincibleTimer - dt
        self.flashTimer = self.flashTimer + dt
        if self.invincibleTimer <= 0 then
            self.invincible = false
            self.invincibleTimer = 0
        end
    end

    -- Get input
    local moveX, moveY = Input:getMovement()

    if self.slamming then
        self:updateSlam(dt)
    elseif self.mode == Constants.HEARTMODE_RED then
        self:updateRedMode(dt, moveX, moveY)
    else
        self:updateBlueMode(dt, moveX, moveY)
    end

    -- Clamp to combat zone
    self.x, self.y = self.combatZone:clampPosition(self.x, self.y, self.originX)
end

function PlayerHeart:updateRedMode(dt, moveX, moveY)
    -- Free 4-directional movement
    self.x = self.x + moveX * MOVE_SPEED * dt
    self.y = self.y + moveY * MOVE_SPEED * dt
end

-- Gravity unit vector for a direction (0=right, 90=down, 180=left, 270=up
-- in the original; here just the cardinal unit vectors).
local GRAVITY_UNIT = {
    down  = { 0,  1 },
    up    = { 0, -1 },
    left  = { -1, 0 },
    right = { 1,  0 },
}

-- Sprite rotation per gravity direction. The art's natural orientation points
-- right (east), so the rotation equals the C2 Angle the gravity maps to and the
-- soul's point visibly faces along gravity (down keeps the prior baseline).
local GRAVITY_ANGLE = {
    right = 0,
    down  = math.pi / 2,
    left  = math.pi,
    up    = 3 * math.pi / 2,
}

function PlayerHeart:updateBlueMode(dt, moveX, moveY)
    local unit = GRAVITY_UNIT[self.gravityDirection] or GRAVITY_UNIT.down
    local gx, gy = unit[1], unit[2]

    -- Signed velocity component along the gravity axis (positive = falling)
    local downSpeed = self.vx * gx + self.vy * gy

    -- Jump: ADDITIVE impulse opposite gravity, only when grounded
    local jumpPressed = Input:justPressed("confirm") or Input:justPressed("up")
    if self.grounded and jumpPressed then
        self.vx = self.vx - gx * JUMP_STRENGTH
        self.vy = self.vy - gy * JUMP_STRENGTH
        self.grounded = false
        downSpeed = self.vx * gx + self.vy * gy
    end

    -- Variable jump cut: releasing jump while still rising clamps the
    -- away-from-gravity speed magnitude to JUMP_HOLD_CUTOFF (not a multiply).
    if Input:justReleased("confirm") or Input:justReleased("up") then
        if downSpeed < -JUMP_HOLD_CUTOFF then
            -- Currently rising faster than the cutoff: clamp to exactly 30.
            self.vx = self.vx - gx * (downSpeed + JUMP_HOLD_CUTOFF)
            self.vy = self.vy - gy * (downSpeed + JUMP_HOLD_CUTOFF)
            downSpeed = -JUMP_HOLD_CUTOFF
        end
    end

    -- Apply the gravity curve while airborne
    if not self.grounded then
        local g = gravityFor(downSpeed)
        self.vx = self.vx + gx * g * dt
        self.vy = self.vy + gy * g * dt
        downSpeed = downSpeed + g * dt
    end

    -- Clamp the along-gravity speed to MaxFallSpeed
    if downSpeed > self.maxFallSpeed then
        local excess = downSpeed - self.maxFallSpeed
        self.vx = self.vx - gx * excess
        self.vy = self.vy - gy * excess
    end

    -- Perpendicular axis: zeroed each tick and driven directly by player input.
    -- For down/up gravity the player controls X; for left/right they control Y.
    if gx == 0 then
        self.vx = moveX * MOVE_SPEED
    else
        self.vy = moveY * MOVE_SPEED
    end

    -- Apply velocity
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Check ground collision
    self:checkGroundCollision()
    self:checkPlatforms(dt)
end

-- Land on and ride moving platforms (downward gravity only)
function PlayerHeart:checkPlatforms(dt)
    if self.gravityDirection ~= "down" then
        self.ridingPlatform = nil
        return
    end

    -- Jumping up: release any platform and let the jump play out
    if self.vy < 0 then
        self.ridingPlatform = nil
        return
    end

    -- Keep riding the current platform, carrying its horizontal motion
    local riding = self.ridingPlatform
    if riding and not riding.dead
        and self.x >= riding.x and self.x <= riding.x + riding.width then
        self.x = self.x + riding.vx * dt
        self.y = riding.y - self.originY
        self.vy = 0
        self.grounded = true
        return
    end
    self.ridingPlatform = nil

    -- Land when the heart's bottom crosses a platform top this frame
    local bottom = self.y + self.originY
    local prevBottom = bottom - self.vy * dt
    for _, p in ipairs(self.platforms) do
        if not p.dead and self.x >= p.x and self.x <= p.x + p.width
            and bottom >= p.y and prevBottom <= p.y + 6 then
            self.y = p.y - self.originY
            self.vy = 0
            self.grounded = true
            self.ridingPlatform = p
            return
        end
    end
end

function PlayerHeart:checkGroundCollision()
    local ix1, iy1, ix2, iy2 = self.combatZone:getInnerBounds()
    local margin = self.originY

    self.grounded = false

    if self.gravityDirection == "down" then
        if self.y + margin >= iy2 then
            self.y = iy2 - margin
            self.vy = 0
            self.grounded = true
        end
    elseif self.gravityDirection == "up" then
        if self.y - margin <= iy1 then
            self.y = iy1 + margin
            self.vy = 0
            self.grounded = true
        end
    elseif self.gravityDirection == "left" then
        if self.x - margin <= ix1 then
            self.x = ix1 + margin
            self.vx = 0
            self.grounded = true
        end
    elseif self.gravityDirection == "right" then
        if self.x + margin >= ix2 then
            self.x = ix2 - margin
            self.vx = 0
            self.grounded = true
        end
    end
end

function PlayerHeart:getHitbox()
    -- Return hitbox for collision detection (smaller than visual)
    local hitboxSize = 4
    return self.x - hitboxSize, self.y - hitboxSize,
           self.x + hitboxSize, self.y + hitboxSize
end

function PlayerHeart:draw()
    -- Skip drawing during invincibility flash
    if self.invincible then
        if math.floor(self.flashTimer * 10) % 2 == 0 then
            return
        end
    end

    -- Set color and rotation based on mode. Red mode has no gravity and keeps
    -- its original point-down look; blue mode rotates the soul along gravity.
    local rotation
    if self.mode == Constants.HEARTMODE_RED then
        love.graphics.setColor(1, 0, 0)
        rotation = math.pi / 2
    else
        love.graphics.setColor(0, 0, 1)
        rotation = GRAVITY_ANGLE[self.gravityDirection] or math.pi / 2
    end

    love.graphics.draw(
        self.image,
        self.x, self.y,
        rotation,
        1, 1,
        self.originX, self.originY
    )
end

return PlayerHeart
