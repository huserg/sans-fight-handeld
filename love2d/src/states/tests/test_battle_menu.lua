-- Battle Menu Test
-- Showcase BattleMenu navigation and DamageNumber floating text

local Fonts       = require("src.ui.fonts")
local Input       = require("src.systems.input")
local BattleMenu  = require("src.ui.battle_menu")
local DamageNumber = require("src.ui.damage_number")

local TestBattleMenu = {
    menu          = nil,
    damageNumbers = nil,
    lastAction    = nil,
}

function TestBattleMenu:enter(game)
    self.game         = game
    Fonts:load()
    self.menu         = BattleMenu.new()
    self.damageNumbers = {}
    self.lastAction   = nil
end

function TestBattleMenu:update(dt, game)
    -- Navigate left/right within the active menu level
    if Input:justPressed("left") then
        self.menu:move(-1)
    elseif Input:justPressed("right") then
        self.menu:move(1)
    -- Up/down also useful in sub-menus with multiple entries
    elseif Input:justPressed("up") then
        self.menu:move(-1)
    elseif Input:justPressed("down") then
        self.menu:move(1)
    end

    if Input:justPressed("confirm") then
        local action = self.menu:confirm()
        if action then
            self.lastAction = action.kind
            -- Spawn a damage number to showcase DamageNumber
            local x = 160 + math.random(0, 160)
            local y = 200
            local text = (action.kind == "flee") and "MISS" or tostring(math.random(1, 30))
            table.insert(self.damageNumbers, DamageNumber.new(text, x, y))
        end
    end

    if Input:justPressed("cancel") then
        if self.menu.level ~= "root" then
            self.menu:cancel()
        end
    end

    -- Return to test menu
    if Input:justPressed("menu") then
        game:setState("test_menu")
        return
    end

    -- Update damage numbers, remove dead ones
    for i = #self.damageNumbers, 1, -1 do
        self.damageNumbers[i]:update(dt)
        if self.damageNumbers[i].dead then
            table.remove(self.damageNumbers, i)
        end
    end
end

function TestBattleMenu:draw(game)
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.rectangle("fill", 0, 0, 640, 480)

    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(2)
    Fonts.default:draw("Battle Menu Test", 320, 20, "center")

    Fonts.default:setScale(1)

    -- Root menu buttons
    local slots = { "FIGHT", "ACT", "ITEM", "MERCY" }
    local btnW, btnH = 100, 30
    local startX = 70
    local btnY   = 100
    for i, label in ipairs(slots) do
        local bx = startX + (i - 1) * 120
        local isSelected = (self.menu.level == "root") and (self.menu.selected == i)
        if isSelected then
            love.graphics.setColor(1, 1, 0)
            love.graphics.rectangle("line", bx - btnW / 2, btnY - btnH / 2, btnW, btnH)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", bx - btnW / 2, btnY - btnH / 2, btnW, btnH)
        end
        love.graphics.setColor(isSelected and 1 or 0.8, isSelected and 1 or 0.8, isSelected and 0 or 0.8)
        Fonts.default:draw(label, bx, btnY, "center")
    end

    -- Sub-menu
    if self.menu.level ~= "root" then
        love.graphics.setColor(1, 1, 1)
        Fonts.default:draw("[ " .. string.upper(self.menu.level) .. " ]", 320, 160, "center")

        local subY = 190
        local opts = {}
        if self.menu.level == "item" then
            for i, item in ipairs(self.menu.items) do
                opts[i] = item.name
            end
        elseif self.menu.level == "fight" then
            opts = { "Fight" }
        elseif self.menu.level == "act" then
            opts = { "Check" }
        elseif self.menu.level == "mercy" then
            opts = { "Spare", "Flee" }
        end

        for i, label in ipairs(opts) do
            if i == self.menu.subCursor then
                love.graphics.setColor(1, 1, 0)
                Fonts.default:draw("> " .. label, 320, subY, "center")
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
                Fonts.default:draw(label, 320, subY, "center")
            end
            subY = subY + 24
        end
    end

    -- Last resolved action
    if self.lastAction then
        love.graphics.setColor(0.6, 1, 0.6)
        Fonts.default:draw("Action: " .. self.lastAction, 320, 310, "center")
    end

    -- Draw floating damage numbers
    for _, dn in ipairs(self.damageNumbers) do
        dn:draw()
    end

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Left/Right: move | Z: confirm | X: cancel | Esc: back", 320, 440, "center")
end

function TestBattleMenu:exit()
    self.menu         = nil
    self.damageNumbers = nil
    self.lastAction   = nil
end

return TestBattleMenu
