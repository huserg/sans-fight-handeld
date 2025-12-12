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

    if self.mode == Constants.HEARTMODE_RED then
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
    if self.gravityDirection == "down" then
        self.vy = math.min(self.vy, MAX_FALL_SPEED)
    elseif self.gravityDirection == "up" then
        self.vy = math.max(self.vy, -MAX_FALL_SPEED)
    elseif self.gravityDirection == "left" then
        self.vx = math.max(self.vx, -MAX_FALL_SPEED)
    elseif self.gravityDirection == "right" then
        self.vx = math.min(self.vx, MAX_FALL_SPEED)
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

    -- Apply velocity
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Check ground collision
    self:checkGroundCollision()
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
