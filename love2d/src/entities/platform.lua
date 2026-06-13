-- Platform Entity
-- A moving surface the player heart can stand on in blue (gravity) mode.
-- Built by tiling a small sprite across the requested width.

local Platform = {}
Platform.__index = Platform

local sprites = { loaded = false }

local function loadSprites()
    if sprites.loaded then return end
    sprites.tile = love.graphics.newImage("assets/sprites/platform1.png")
    sprites.tile:setFilter("nearest", "nearest")
    sprites.tileW, sprites.tileH = sprites.tile:getDimensions()
    sprites.loaded = true
end

-- x = left edge, y = top surface
function Platform.new(x, y, width, direction, speed, reverse)
    loadSprites()

    local self = setmetatable({}, Platform)
    self.x = x
    self.y = y
    self.width = math.max(width or 0, sprites.tileW)
    self.height = sprites.tileH
    self.isPlatform = true
    self.dead = false

    direction = direction or 0
    speed = speed or 0
    if reverse and reverse ~= 0 then speed = -speed end

    local vx, vy = 0, 0
    if direction == 0 then vx = speed
    elseif direction == 1 then vy = speed
    elseif direction == 2 then vx = -speed
    elseif direction == 3 then vy = -speed end
    self.vx, self.vy = vx, vy

    return self
end

function Platform:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    if self.x + self.width < -200 or self.x > 840
        or self.y < -200 or self.y > 680 then
        self.dead = true
    end
end

function Platform:draw()
    love.graphics.setColor(1, 1, 1)
    local tw = sprites.tileW
    local drawn = 0
    while drawn < self.width do
        local segment = math.min(tw, self.width - drawn)
        if segment >= tw then
            love.graphics.draw(sprites.tile, self.x + drawn, self.y)
        else
            local quad = love.graphics.newQuad(0, 0, segment, sprites.tileH,
                sprites.tile:getDimensions())
            love.graphics.draw(sprites.tile, quad, self.x + drawn, self.y)
        end
        drawn = drawn + tw
    end
end

return Platform
