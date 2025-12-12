-- Gaster Blaster Test
-- Test Gaster Blaster animation and beam

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local GasterBlaster = require("src.entities.gaster_blaster")

local TestBlaster = {}

function TestBlaster:enter(game)
    self.game = game
    Fonts:load()

    self.blasters = {}
    self.spawnTimer = 0
end

function TestBlaster:spawnBlaster()
    -- Random position and angle
    local x = math.random(100, 540)
    local y = math.random(100, 300)

    -- Aim towards center-bottom (where player usually is)
    local targetX = 320
    local targetY = 350
    local angle = math.atan2(targetY - y, targetX - x)

    local blaster = GasterBlaster.new(x, y, angle, 1)
    table.insert(self.blasters, blaster)
end

function TestBlaster:update(dt, game)
    -- Spawn blaster on confirm
    if Input:justPressed("confirm") then
        self:spawnBlaster()
    end

    -- Auto spawn
    if Input:justPressed("up") then
        self.autoSpawn = not self.autoSpawn
    end

    if self.autoSpawn then
        self.spawnTimer = self.spawnTimer + dt
        if self.spawnTimer >= 1.5 then
            self.spawnTimer = 0
            self:spawnBlaster()
        end
    end

    -- Clear all
    if Input:justPressed("down") then
        self.blasters = {}
    end

    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    -- Update blasters
    for i = #self.blasters, 1, -1 do
        local blaster = self.blasters[i]
        blaster:update(dt)
        if blaster.dead then
            table.remove(self.blasters, i)
        end
    end
end

function TestBlaster:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Gaster Blaster Test", 320, 20, "center")

    -- Draw target area
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.circle("line", 320, 350, 20)
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Target", 320, 380, "center")

    -- Draw blasters
    for _, blaster in ipairs(self.blasters) do
        blaster:draw()
    end

    -- Info
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Active blasters: " .. #self.blasters, 320, 420, "center")
    Fonts.default:draw("Auto spawn: " .. (self.autoSpawn and "ON" or "OFF"), 320, 436, "center")

    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Z: Spawn | Up: Auto | Down: Clear", 320, 456, "center")
    Fonts.default:draw("X/Esc: Back", 320, 472, "center")
end

function TestBlaster:exit()
    self.blasters = {}
end

return TestBlaster
