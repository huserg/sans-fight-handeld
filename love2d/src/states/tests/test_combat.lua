-- Combat Zone Test
-- Test combat zone resize and animation

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local CombatZone = require("src.entities.combat_zone")

local TestCombat = {}

local presets = {
    { name = "Default", x1 = 239, y1 = 226, x2 = 404, y2 = 391 },
    { name = "Wide", x1 = 133, y1 = 251, x2 = 508, y2 = 391 },
    { name = "Tall", x1 = 241, y1 = 186, x2 = 406, y2 = 391 },
    { name = "Small", x1 = 270, y1 = 280, x2 = 370, y2 = 360 },
    { name = "Full", x1 = 33, y1 = 186, x2 = 608, y2 = 391 },
}

function TestCombat:enter(game)
    self.game = game
    Fonts:load()

    self.combatZone = CombatZone.new()
    self.currentPreset = 1
    self.instantMode = false
end

function TestCombat:update(dt, game)
    if Input:justPressed("left") then
        self.currentPreset = self.currentPreset - 1
        if self.currentPreset < 1 then
            self.currentPreset = #presets
        end
        self:applyPreset()
    elseif Input:justPressed("right") then
        self.currentPreset = self.currentPreset + 1
        if self.currentPreset > #presets then
            self.currentPreset = 1
        end
        self:applyPreset()
    end

    if Input:justPressed("confirm") then
        self.instantMode = not self.instantMode
    end

    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    self.combatZone:update(dt)
end

function TestCombat:applyPreset()
    local p = presets[self.currentPreset]
    self.combatZone:resize(p.x1, p.y1, p.x2, p.y2, self.instantMode)
end

function TestCombat:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Combat Zone Test", 320, 20, "center")

    self.combatZone:draw()

    -- Info
    local p = presets[self.currentPreset]
    love.graphics.setColor(1, 1, 1)
    Fonts.default:draw("Preset: " .. p.name, 320, 410, "center")

    local modeText = self.instantMode and "INSTANT" or "ANIMATED"
    Fonts.default:draw("Resize mode: " .. modeText, 320, 426, "center")

    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Left/Right: Change preset | Z: Toggle instant", 320, 446, "center")
    Fonts.default:draw("X/Esc: Back", 320, 462, "center")
end

function TestCombat:exit()
    self.combatZone = nil
end

return TestCombat
