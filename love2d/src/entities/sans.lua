-- Sans Character Entity
-- The skeleton boss character

local Sans = {}
Sans.__index = Sans

-- Shared sprites
local sprites = {
    loaded = false,
    body = nil,
    head = nil,
    torso = nil,
    legs = nil,
    sweat = nil,
    bodyQuads = {},
    headQuads = {}
}

-- Body frames are NOT a regular grid - different sizes per animation
-- HandDown/HandUp idle: 64x70
-- HandRight/HandLeft: 96x48
-- We define each frame manually with {x, y, w, h}
local BODY_FRAMES = {
    -- Idle animation (HandDown) - 64x70
    [0] = {99, 101, 64, 70},   -- idle frame 0
    [1] = {165, 101, 64, 70},  -- idle frame 1
    -- More idle frames
    [2] = {1, 151, 64, 70},
    [3] = {67, 173, 64, 70},
    [4] = {133, 173, 64, 70},
    -- Hand poses (96x48)
    [5] = {1, 1, 96, 48},      -- hand right
    [6] = {99, 1, 96, 48},
    [7] = {1, 51, 96, 48},
}

-- Default frame size for positioning
local BODY_FRAME_W = 64
local BODY_FRAME_H = 70

-- Head expressions: 34x32 each, 3 cols x 3 rows
local HEAD_FRAME_W = 34
local HEAD_FRAME_H = 32
local HEAD_COLS = 3
local HEAD_ROWS = 3

-- The original C2 SansBody is displayed at 2x the native sprite size
local SCALE = 2

-- Expression names mapped to grid positions (col, row)
local EXPRESSIONS = {
    neutral = {0, 0},
    wink = {1, 0},
    closed = {2, 0},
    smile = {0, 1},
    serious = {1, 1},
    angry = {2, 1},
    tired = {0, 2},
    sweat = {1, 2},
    dark = {2, 2}
}

-- Map CSV animation names to the port's available sprites
local HEAD_MAP = {
    Default = "neutral", LookLeft = "neutral", Wink = "wink",
    ClosedEyes = "closed", NoEyes = "dark", BlueEye = "wink",
    Tired1 = "tired", Tired2 = "tired",
}
local BODY_MAP = { HandDown = 0, HandUp = 1, HandRight = 5, HandLeft = 7 }

-- Default pose used as a fallback whenever a requested frame is unknown.
local DEFAULT_BODY_FRAME = 0

-- Horizontal bounds for moveTo / scroll wrap (native combat-area coordinates).
local SANS_X_MIN = -60
local SANS_X_MAX = 700

local function clampX(x)
    if x < SANS_X_MIN then return SANS_X_MIN end
    if x > SANS_X_MAX then return SANS_X_MAX end
    return x
end

local function loadSprites()
    if sprites.loaded then return end

    sprites.body = love.graphics.newImage("assets/sprites/sansbody-sheet0.png")
    sprites.head = love.graphics.newImage("assets/sprites/sanshead-sheet0.png")
    sprites.sweat = love.graphics.newImage("assets/sprites/sanssweat-sheet0.png")

    sprites.body:setFilter("nearest", "nearest")
    sprites.head:setFilter("nearest", "nearest")
    sprites.sweat:setFilter("nearest", "nearest")

    -- Create body quads from manual frame definitions
    local bodyW, bodyH = sprites.body:getDimensions()
    for idx, frame in pairs(BODY_FRAMES) do
        sprites.bodyQuads[idx] = love.graphics.newQuad(
            frame[1], frame[2],  -- x, y
            frame[3], frame[4],  -- w, h
            bodyW, bodyH
        )
        -- Store frame dimensions for later use
        sprites.bodyFrameSizes = sprites.bodyFrameSizes or {}
        sprites.bodyFrameSizes[idx] = {w = frame[3], h = frame[4]}
    end

    -- Create head quads
    local headW, headH = sprites.head:getDimensions()
    for name, pos in pairs(EXPRESSIONS) do
        sprites.headQuads[name] = love.graphics.newQuad(
            pos[1] * HEAD_FRAME_W,
            pos[2] * HEAD_FRAME_H,
            HEAD_FRAME_W, HEAD_FRAME_H,
            headW, headH
        )
    end

    sprites.loaded = true
end

function Sans.new(x, y)
    loadSprites()

    local self = setmetatable({}, Sans)

    -- Position
    self.x = x or 320
    self.y = y or 120

    -- Animation
    self.bodyFrame = 0
    self.expression = "neutral"
    self.animTimer = 0
    self.animSpeed = 0.15

    -- State
    self.visible = true
    self.alpha = 1
    self.showSweat = false

    -- Idle animation frames
    -- Default idle holds the arms-down pose (frame 0). Frame 1 is the HandUp pose,
    -- which the original only shows for specific attacks, not while idle.
    self.idleFrames = {0}
    self.currentIdleIndex = 1
    self.animateIdle = true

    -- Horizontal scroll (SansRepeat)
    self.scrolling = false
    self.scrollSpeed = 120

    return self
end

function Sans:setExpression(expression)
    if EXPRESSIONS[expression] then
        self.expression = expression
    end
end

function Sans:setBodyFrame(frame)
    self.bodyFrame = frame
end

function Sans:setVisible(visible)
    self.visible = visible
end

function Sans:setSweat(show)
    self.showSweat = show
end

-- CSV-facing animation commands -------------------------------------------

function Sans:setHead(name)
    self.expression = HEAD_MAP[name] or "neutral"
end

function Sans:setBody(name)
    local frame = BODY_MAP[name]
    if frame then
        self.bodyFrame = frame
    else
        -- Unknown pose: fall back to the idle frame rather than keeping a stale
        -- (possibly hand) pose that would leave the head detached.
        self.bodyFrame = DEFAULT_BODY_FRAME
    end
    -- Idle stepping must only run while an idle pose is held, otherwise it would
    -- overwrite the fixed hand pose on the next update tick.
    self.animateIdle = (self.bodyFrame == DEFAULT_BODY_FRAME)
end

-- Sweat level 0-3 (the port only has a single sweat sprite)
function Sans:setSweatLevel(level)
    self.showSweat = (tonumber(level) or 0) > 0
end

function Sans:moveTo(x)
    self.x = clampX(tonumber(x) or self.x)
end

function Sans:setAnimation(name)
    if name == "Tired" then
        self.expression = "tired"
    end
    -- Idle / HeadBob / Tired all resume idle motion, but only when an idle pose
    -- is actually held; a fixed hand pose must not be snapped back to frame 0.
    self.animateIdle = (self.bodyFrame == DEFAULT_BODY_FRAME)
end

function Sans:startScroll()
    self.scrolling = true
end

function Sans:stopScroll()
    self.scrolling = false
end

-- Reset transient pose/scroll state so nothing leaks between attacks (e.g. a
-- SansRepeat without a matching SansEndRepeat leaving Sans drifting forever).
function Sans:resetForAttack()
    self.scrolling = false
    self.bodyFrame = DEFAULT_BODY_FRAME
    self.animateIdle = true
    self.animTimer = 0
    self.currentIdleIndex = 1
    self.x = clampX(self.x)
end

function Sans:update(dt)
    -- Idle animation (suspended while a fixed body pose is held)
    if self.animateIdle then
        self.animTimer = self.animTimer + dt
        if self.animTimer >= self.animSpeed then
            self.animTimer = 0
            self.currentIdleIndex = self.currentIdleIndex + 1
            if self.currentIdleIndex > #self.idleFrames then
                self.currentIdleIndex = 1
            end
            self.bodyFrame = self.idleFrames[self.currentIdleIndex]
        end
    end

    -- Scroll horizontally across the screen, wrapping around
    if self.scrolling then
        self.x = self.x + self.scrollSpeed * dt
        if self.x > SANS_X_MAX then self.x = SANS_X_MIN end
    end
end

function Sans:draw()
    if not self.visible then return end

    love.graphics.setColor(1, 1, 1, self.alpha)

    -- Draw body (origin at the current frame's own center, since hand poses
    -- use a different frame size than the idle frames)
    -- Guard against an out-of-range / unmapped frame index: fall back to the
    -- default idle frame so the sprite never draws a nil quad (garbage).
    local frame = self.bodyFrame
    if not sprites.bodyQuads[frame] then
        frame = DEFAULT_BODY_FRAME
    end
    local bodyQuad = sprites.bodyQuads[frame]
    if bodyQuad then
        local size = sprites.bodyFrameSizes[frame]
            or { w = BODY_FRAME_W, h = BODY_FRAME_H }
        love.graphics.draw(
            sprites.body,
            bodyQuad,
            self.x, self.y,
            0,
            SCALE, SCALE,
            size.w / 2, size.h / 2
        )
    end

    -- Draw sweat effect if active
    if self.showSweat then
        love.graphics.draw(
            sprites.sweat,
            self.x - 20 * SCALE, self.y - 30 * SCALE,
            0,
            SCALE, SCALE
        )
    end
end

function Sans:drawHead(x, y, scale)
    -- Attach the skull to the jacket collar. The collar sits a fixed number of
    -- native pixels above the body frame's *top*, so the offset has to track the
    -- current frame height: idle frames are 64x70 while the hand poses are
    -- 96x48. Anchoring to a flat offset from self.y detaches the head whenever
    -- Sans switches to a hand pose (the "falling apart" symptom).
    local frame = self.bodyFrame
    if not (sprites.bodyFrameSizes and sprites.bodyFrameSizes[frame]) then
        frame = DEFAULT_BODY_FRAME
    end
    local size = (sprites.bodyFrameSizes and sprites.bodyFrameSizes[frame])
        or { w = BODY_FRAME_W, h = BODY_FRAME_H }
    -- Body is drawn centered on self.y, so its top is at self.y - h/2 * SCALE.
    -- The collar sits ~15 native px below that top edge.
    local bodyTop = self.y - (size.h / 2) * SCALE
    x = x or self.x
    y = y or bodyTop + 15 * SCALE
    scale = scale or SCALE

    love.graphics.setColor(1, 1, 1, self.alpha)

    local headQuad = sprites.headQuads[self.expression]
    if headQuad then
        love.graphics.draw(
            sprites.head,
            headQuad,
            x, y,
            0,
            scale, scale,
            HEAD_FRAME_W / 2, HEAD_FRAME_H / 2
        )
    end
end

return Sans
