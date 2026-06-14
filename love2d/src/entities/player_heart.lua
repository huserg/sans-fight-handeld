-- Player Heart Entity
-- The player's soul that moves and takes damage

local Constants = require("src.core.constants")
local AssetsConfig = require("src.core.assets_config")
local Input = require("src.systems.input")

local PlayerHeart = {}
PlayerHeart.__index = PlayerHeart

-- Movement constants
local MOVE_SPEED = 200
local GRAVITY = 800
local JUMP_SPEED = -350
local MAX_FALL_SPEED = 400
-- Releasing jump mid-ascent keeps this fraction of the upward velocity,
-- giving variable jump height based on how long the button is held.
local JUMP_CUT = 0.4

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

    -- Karma (poison damage from original game)
    self.karma = 0
    self.karmaTimer = 0

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
    self.maxFallSpeed = MAX_FALL_SPEED
    self.vx, self.vy = 0, 0
    self.grounded = false
    self.gravityDirection = "down"
    self.ridingPlatform = nil
    self.slamming = false
    self.slamDamage = false
    self.pendingSlamDamage = false
end

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
        if dir == 1 then
            self.gravityDirection = "down"
            self.grounded = true
        end
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

function PlayerHeart:addKarma(amount)
    self.karma = self.karma + amount
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

    -- Handle karma damage over time
    if self.karma > 0 then
        self.karmaTimer = self.karmaTimer + dt
        if self.karmaTimer >= 0.05 then
            self.karmaTimer = 0
            self.karma = math.max(0, self.karma - 1)
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

function PlayerHeart:updateBlueMode(dt, moveX, moveY)
    -- Horizontal movement
    self.x = self.x + moveX * MOVE_SPEED * dt

    -- Determine gravity direction
    local gravX, gravY = 0, 0
    if self.gravityDirection == "down" then
        gravY = GRAVITY
    elseif self.gravityDirection == "up" then
        gravY = -GRAVITY
    elseif self.gravityDirection == "left" then
        gravX = -GRAVITY
    elseif self.gravityDirection == "right" then
        gravX = GRAVITY
    end

    -- Apply gravity
    self.vx = self.vx + gravX * dt
    self.vy = self.vy + gravY * dt

    -- Clamp fall speed
    local maxFall = self.maxFallSpeed
    if self.gravityDirection == "down" then
        self.vy = math.min(self.vy, maxFall)
    elseif self.gravityDirection == "up" then
        self.vy = math.max(self.vy, -maxFall)
    elseif self.gravityDirection == "left" then
        self.vx = math.max(self.vx, -maxFall)
    elseif self.gravityDirection == "right" then
        self.vx = math.min(self.vx, maxFall)
    end

    -- Jump when grounded
    if self.grounded and Input:justPressed("confirm") then
        if self.gravityDirection == "down" then
            self.vy = JUMP_SPEED
        elseif self.gravityDirection == "up" then
            self.vy = -JUMP_SPEED
        elseif self.gravityDirection == "left" then
            self.vx = -JUMP_SPEED
        elseif self.gravityDirection == "right" then
            self.vx = JUMP_SPEED
        end
        self.grounded = false
    end

    -- Variable jump height: releasing jump while still rising cuts the ascent
    if Input:justReleased("confirm") then
        if self.gravityDirection == "down" and self.vy < 0 then
            self.vy = self.vy * JUMP_CUT
        elseif self.gravityDirection == "up" and self.vy > 0 then
            self.vy = self.vy * JUMP_CUT
        elseif self.gravityDirection == "left" and self.vx > 0 then
            self.vx = self.vx * JUMP_CUT
        elseif self.gravityDirection == "right" and self.vx < 0 then
            self.vx = self.vx * JUMP_CUT
        end
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

    -- Set color based on mode
    if self.mode == Constants.HEARTMODE_RED then
        love.graphics.setColor(1, 0, 0)
    else
        love.graphics.setColor(0, 0, 1)
    end

    -- Rotated 90 degrees so point faces down
    love.graphics.draw(
        self.image,
        self.x, self.y,
        math.pi/2,
        1, 1,
        self.originX, self.originY
    )
end

return PlayerHeart
