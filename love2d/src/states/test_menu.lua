-- Test Menu State
-- Hidden debug menu for testing all features

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

local TestMenu = {
    items = {
        { id = "fonts", text = "Font Test" },
        { id = "heart", text = "Heart Modes Test" },
        { id = "bones", text = "Bone Rendering Test" },
        { id = "combat", text = "Combat Zone Test" },
        { id = "hp", text = "HP Bar Test" },
        { id = "sans", text = "Sans Character Test" },
        { id = "blaster", text = "Gaster Blaster Test" },
        { id = "audio", text = "Audio Test" },
        { id = "back", text = "Back to Menu" }
    },
    selected = 1
}

function TestMenu:enter(game)
    self.game = game
    self.selected = 1
end

function TestMenu:update(dt, game)
    if Input:justPressed("up") then
        self.selected = self.selected - 1
        if self.selected < 1 then
            self.selected = #self.items
        end
    elseif Input:justPressed("down") then
        self.selected = self.selected + 1
        if self.selected > #self.items then
            self.selected = 1
        end
    end

    if Input:justPressed("confirm") then
        local item = self.items[self.selected]
        if item.id == "fonts" then
            game:setState("fonttest")
        elseif item.id == "heart" then
            game:setState("test_heart")
        elseif item.id == "bones" then
            game:setState("test_bones")
        elseif item.id == "combat" then
            game:setState("test_combat")
        elseif item.id == "hp" then
            game:setState("test_hp")
        elseif item.id == "sans" then
            game:setState("test_sans")
        elseif item.id == "blaster" then
            game:setState("test_blaster")
        elseif item.id == "audio" then
            game:setState("test_audio")
        elseif item.id == "back" then
            game:setState("menu")
        end
    end

    if Input:justPressed("cancel") or Input:justPressed("menu") then
        game:setState("menu")
    end
end

function TestMenu:draw(game)
    love.graphics.setColor(1, 1, 1)

    Fonts.default:setScale(2)
    Fonts.default:draw("Test Menu", 320, 40, "center")

    Fonts.default:setScale(1)
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("(Hidden debug menu)", 320, 72, "center")

    local y = 120
    for i, item in ipairs(self.items) do
        if i == self.selected then
            love.graphics.setColor(1, 1, 0)
            Fonts.default:draw("> " .. item.text, 320, y, "center")
        else
            love.graphics.setColor(1, 1, 1)
            Fonts.default:draw(item.text, 320, y, "center")
        end
        y = y + 28
    end

    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Z: Select | X: Back", 320, 440, "center")
end

function TestMenu:exit()
end

return TestMenu
