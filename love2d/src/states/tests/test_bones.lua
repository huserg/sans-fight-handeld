-- Bone Rendering Test
-- Test bone entity with different sizes and orientations

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local Bone = require("src.entities.bone")

local TestBones = {}

function TestBones:enter(game)
    self.game = game
    Fonts:load()

    -- Create test bones with different sizes
    self.bones = {}

    -- Vertical bones at different sizes
    local x = 80
    for _, length in ipairs({20, 40, 60, 80, 100}) do
        table.insert(self.bones, {
            bone = Bone.new(x, 150, length, "vertical", false),
            label = length .. "px"
        })
        x = x + 60
    end

    -- Horizontal bones at different sizes
    local y = 280
    for _, length in ipairs({20, 40, 60, 80, 100}) do
        table.insert(self.bones, {
            bone = Bone.new(320, y, length, "horizontal", false),
            label = length .. "px"
        })
        y = y + 30
    end

    -- Blue bones
    self.blueBoneV = Bone.new(500, 150, 60, "vertical", true)
    self.blueBoneH = Bone.new(550, 150, 60, "horizontal", true)
end

function TestBones:update(dt, game)
    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
    end
end

function TestBones:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Bone Rendering Test", 320, 20, "center")

    -- Draw vertical bones section
    Fonts.default:draw("Vertical:", 10, 60, "left")
    local x = 80
    for i = 1, 5 do
        local item = self.bones[i]
        item.bone:draw()
        love.graphics.setColor(0.5, 0.5, 0.5)
        Fonts.default:draw(item.label, x, 210, "center")
        x = x + 60
    end

    -- Draw horizontal bones section
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Horizontal:", 10, 250, "left")
    for i = 6, 10 do
        local item = self.bones[i]
        item.bone:draw()
    end

    -- Draw blue bones
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Blue bones:", 480, 60, "left")
    self.blueBoneV:draw()
    self.blueBoneH:draw()

    love.graphics.setColor(0, 0.7, 1)
    Fonts.default:draw("(only hurt", 520, 220, "center")
    Fonts.default:draw("when moving)", 520, 236, "center")

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("X/Esc: Back to test menu", 320, 460, "center")
end

function TestBones:exit()
    self.bones = nil
    self.blueBoneV = nil
    self.blueBoneH = nil
end

return TestBones
