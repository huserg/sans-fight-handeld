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
    self.idleFrames = {0, 1}
    self.currentIdleIndex = 1

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

function Sans:update(dt)
    -- Idle animation
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

function Sans:draw()
    if not self.visible then return end

    love.graphics.setColor(1, 1, 1, self.alpha)

    -- Draw body
    local bodyQuad = sprites.bodyQuads[self.bodyFrame]
    if bodyQuad then
        love.graphics.draw(
            sprites.body,
            bodyQuad,
            self.x, self.y,
            0,
            1, 1,
            BODY_FRAME_W / 2, BODY_FRAME_H / 2
        )
    end

    -- Draw sweat effect if active
    if self.showSweat then
        love.graphics.draw(
            sprites.sweat,
            self.x - 20, self.y - 30,
            0,
            1, 1
        )
    end
end

function Sans:drawHead(x, y, scale)
    -- Head position: body top - half head height
    -- Body center is at self.y, body is 70px tall, so top is at self.y - 35
    -- Head is 32px tall, center it just above body top
    x = x or self.x
    y = y or self.y - BODY_FRAME_H / 2 - HEAD_FRAME_H / 2 + 8
    scale = scale or 1

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
