-- Dialogue System
-- Speech bubbles with typewriter effect for Sans dialogue

local Fonts = require("src.ui.fonts")

local Dialogue = {}
Dialogue.__index = Dialogue

-- Constants
local CHAR_DELAY = 0.03
local BUBBLE_PADDING_X = 8
local BUBBLE_PADDING_Y = 4
local BUBBLE_TAIL_OFFSET = 10

function Dialogue.new()
    local self = setmetatable({}, Dialogue)

    -- Load speech bubble sprite
    self.bubbleImage = love.graphics.newImage("assets/sprites/speechbubble-sheet0.png")
    self.bubbleImage:setFilter("nearest", "nearest")

    -- Get dimensions (2 frames: white top, black bottom)
    local imgW, imgH = self.bubbleImage:getDimensions()
    self.frameWidth = imgW
    self.frameHeight = imgH / 2

    -- Create quads for white and black bubbles
    self.whiteQuad = love.graphics.newQuad(0, 0, self.frameWidth, self.frameHeight, imgW, imgH)
    self.blackQuad = love.graphics.newQuad(0, self.frameHeight, self.frameWidth, self.frameHeight, imgW, imgH)

    -- Load speak sound
    self.speakSound = nil
    local success, sound = pcall(function()
        return love.audio.newSource("assets/audio/sansspeak.ogg", "static")
    end)
    if success then
        self.speakSound = sound
        self.speakSound:setVolume(0.6)
    end

    -- State
    self.active = false
    self.text = ""
    self.displayedChars = 0
    self.charTimer = 0
    self.complete = false

    -- Position (relative to Sans or absolute)
    self.x = 0
    self.y = 0
    self.anchorX = 0
    self.anchorY = 0

    -- Appearance
    self.style = "white"
    self.scale = 1

    -- Queue for multiple dialogue lines
    self.queue = {}

    return self
end

function Dialogue:show(text, x, y, style)
    self.text = text or ""
    self.x = x or self.x
    self.y = y or self.y
    self.style = style or "white"
    self.displayedChars = 0
    self.charTimer = 0
    self.complete = false
    self.active = true
end

function Dialogue:queueText(text, x, y, style)
    table.insert(self.queue, {
        text = text,
        x = x,
        y = y,
        style = style
    })

    -- Start showing if not active
    if not self.active and #self.queue > 0 then
        self:nextInQueue()
    end
end

function Dialogue:nextInQueue()
    if #self.queue > 0 then
        local next = table.remove(self.queue, 1)
        self:show(next.text, next.x, next.y, next.style)
    else
        self.active = false
    end
end

function Dialogue:skip()
    if self.active and not self.complete then
        -- Show all text immediately
        self.displayedChars = #self.text
        self.complete = true
    elseif self.complete then
        -- Move to next dialogue or close
        self:nextInQueue()
    end
end

function Dialogue:hide()
    self.active = false
    self.queue = {}
end

function Dialogue:isActive()
    return self.active
end

function Dialogue:isComplete()
    return self.complete
end

function Dialogue:update(dt)
    if not self.active or self.complete then
        return
    end

    self.charTimer = self.charTimer + dt

    while self.charTimer >= CHAR_DELAY and self.displayedChars < #self.text do
        self.charTimer = self.charTimer - CHAR_DELAY
        self.displayedChars = self.displayedChars + 1

        -- Get current character
        local char = self.text:sub(self.displayedChars, self.displayedChars)

        -- Play sound for non-space characters
        if char ~= " " and char ~= "\n" and self.speakSound then
            self.speakSound:stop()
            self.speakSound:play()
        end

        -- Pause on punctuation
        if char == "." or char == "!" or char == "?" then
            self.charTimer = self.charTimer - CHAR_DELAY * 5
        elseif char == "," then
            self.charTimer = self.charTimer - CHAR_DELAY * 2
        end
    end

    if self.displayedChars >= #self.text then
        self.complete = true
    end
end

function Dialogue:draw()
    if not self.active then
        return
    end

    -- Get displayed text
    local displayText = self.text:sub(1, self.displayedChars)

    -- Calculate text dimensions
    Fonts.sans:setScale(1)
    local lines = {}
    for line in (displayText .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end

    -- Calculate bubble size needed
    local maxLineWidth = 0
    for _, line in ipairs(lines) do
        local lineWidth = Fonts.sans:getWidth(line)
        if lineWidth > maxLineWidth then
            maxLineWidth = lineWidth
        end
    end

    local lineHeight = Fonts.sans:getHeight()
    local textHeight = #lines * lineHeight
    local bubbleWidth = math.max(maxLineWidth + BUBBLE_PADDING_X * 2, 40)
    local bubbleHeight = math.max(textHeight + BUBBLE_PADDING_Y * 2, 24)

    -- Bubble bottom sits at self.y and grows upward (tail points down at Sans)
    local bx = self.x - bubbleWidth / 2
    local by = self.y - bubbleHeight
    local black = (self.style == "black")
    local fill = black and { 0, 0, 0 } or { 1, 1, 1 }
    local edge = black and { 1, 1, 1 } or { 0, 0, 0 }
    local tailH = 8

    -- Filled box + downward tail (drawn cleanly instead of stretching a sprite)
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", bx, by, bubbleWidth, bubbleHeight)
    love.graphics.polygon("fill",
        self.x - 6, by + bubbleHeight - 1,
        self.x + 6, by + bubbleHeight - 1,
        self.x, by + bubbleHeight + tailH)

    -- Border around the box and along the tail edges
    love.graphics.setColor(edge)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bubbleWidth, bubbleHeight)
    love.graphics.line(self.x - 6, by + bubbleHeight, self.x, by + bubbleHeight + tailH)
    love.graphics.line(self.x + 6, by + bubbleHeight, self.x, by + bubbleHeight + tailH)
    love.graphics.setLineWidth(1)

    -- Draw text (same color as the border: black on white, white on black)
    love.graphics.setColor(edge)
    local textY = by + BUBBLE_PADDING_Y
    for _, line in ipairs(lines) do
        Fonts.sans:draw(line, self.x, textY, "center")
        textY = textY + lineHeight
    end
    love.graphics.setColor(1, 1, 1)

    -- Draw continue indicator if complete
    if self.complete and #self.queue > 0 then
        love.graphics.setColor(self.style == "black" and 1 or 0, self.style == "black" and 1 or 0, self.style == "black" and 1 or 0)
        local indicatorY = self.y - 8 + math.sin(love.timer.getTime() * 5) * 2
        love.graphics.polygon("fill",
            self.x - 4, indicatorY,
            self.x + 4, indicatorY,
            self.x, indicatorY + 6
        )
    end
end

return Dialogue
