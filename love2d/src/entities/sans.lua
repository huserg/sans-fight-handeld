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

-- Body animation frames: 4x4 grid, 64x64 each
local BODY_FRAME_SIZE = 64
local BODY_COLS = 4
local BODY_ROWS = 4

-- Head expressions: 3x3 grid, ~42x42 each
local HEAD_FRAME_SIZE = 42
local HEAD_COLS = 3
local HEAD_ROWS = 3

-- Expression names mapped to grid positions
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

    -- Create body quads
    local bodyW, bodyH = sprites.body:getDimensions()
    for row = 0, BODY_ROWS - 1 do
        for col = 0, BODY_COLS - 1 do
            local idx = row * BODY_COLS + col
            sprites.bodyQuads[idx] = love.graphics.newQuad(
                col * BODY_FRAME_SIZE,
                row * BODY_FRAME_SIZE,
                BODY_FRAME_SIZE, BODY_FRAME_SIZE,
                bodyW, bodyH
            )
        end
    end

    -- Create head quads
    local headW, headH = sprites.head:getDimensions()
    for name, pos in pairs(EXPRESSIONS) do
        sprites.headQuads[name] = love.graphics.newQuad(
            pos[1] * HEAD_FRAME_SIZE,
            pos[2] * HEAD_FRAME_SIZE,
            HEAD_FRAME_SIZE, HEAD_FRAME_SIZE,
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
            BODY_FRAME_SIZE / 2, BODY_FRAME_SIZE / 2
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
    x = x or self.x
    y = y or self.y - 40
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
            HEAD_FRAME_SIZE / 2, HEAD_FRAME_SIZE / 2
        )
    end
end

return Sans
