-- Menu State
-- Main menu with mode selection

local Constants = require("src.core.constants")
local AssetsConfig = require("src.core.assets_config")
local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local Audio = require("src.systems.audio")
local AttackParser = require("src.systems.attack_parser")

local Menu = {
    game = nil,

    -- Menu structure
    currentMenu = "main",
    menuStack = {},
    selectedIndex = 0,
    menuItems = {},

    -- Heart cursor
    heartImage = nil,
    heartX = 0,
    heartY = 0,

    -- Scroll for long lists
    scrollOffset = 0,
    maxVisible = 8,

    -- Attack list for single attack menu
    attackFiles = {
        "sans_intro",
        "sans_bluebone",
        "sans_bonegap1",
        "sans_bonegap1fast",
        "sans_bonegap2",
        "sans_boneslideh",
        "sans_boneslidev",
        "sans_bonestab1",
        "sans_bonestab2",
        "sans_bonestab3",
        "sans_multi1",
        "sans_multi2",
        "sans_multi3",
        "sans_platformblaster",
        "sans_platformblasterfast",
        "sans_platforms1",
        "sans_platforms2",
        "sans_platforms3",
        "sans_platforms4",
        "sans_platforms4hard",
        "sans_randomblaster1",
        "sans_randomblaster2",
        "sans_spare",
        "sans_final"
    }
}

function Menu:enter(game)
    self.game = game

    -- Load heart sprite from config
    local heartCfg = AssetsConfig.sprites.playerHeart
    self.heartImage = love.graphics.newImage(heartCfg.path)
    self.heartImage:setFilter("nearest", "nearest")
    self.heartOriginX = heartCfg.originX
    self.heartOriginY = heartCfg.originY

    -- Reset HP
    game.hp = game.maxHp

    -- Show main menu
    self:showMainMenu()
end

function Menu:showMainMenu()
    self.currentMenu = "main"
    self.selectedIndex = 0
    self.scrollOffset = 0
    self.menuItems = {
        { text = "Normal", action = "startNormal" },
        { text = "Practice", action = "startPractice" },
        { text = "Endless", action = "showEndless" },
        { text = "Single attack", action = "showSingleAttack" },
        { text = "Custom attack", action = "showCustom" }
    }
    self.menuStack = {}
end

function Menu:showEndlessMenu()
    table.insert(self.menuStack, { menu = "main", index = self.selectedIndex })
    self.currentMenu = "endless"
    self.selectedIndex = 0
    self.scrollOffset = 0
    self.menuItems = {
        { text = "Phase 1", action = "startEndless", data = 0 },
        { text = "Phase 2", action = "startEndless", data = 1 }
    }
end

function Menu:showSingleAttackMenu()
    table.insert(self.menuStack, { menu = "main", index = self.selectedIndex })
    self.currentMenu = "single"
    self.selectedIndex = 0
    self.scrollOffset = 0
    self.menuItems = {}

    -- Analyze each attack status
    for i, attack in ipairs(self.attackFiles) do
        local status = AttackParser.getAttackStatus(attack)
        local displayText = attack
        local ready = false

        if status == "ready" then
            ready = true
        elseif status == "partial" then
            displayText = attack .. " - partial"
        else
            displayText = attack .. " - not ready"
        end

        table.insert(self.menuItems, {
            text = displayText,
            action = "startSingle",
            data = attack,
            status = status,
            ready = ready
        })
    end
end

function Menu:goBack()
    if #self.menuStack > 0 then
        local prev = table.remove(self.menuStack)
        if prev.menu == "main" then
            self:showMainMenu()
        end
        self.selectedIndex = prev.index
    end
end

function Menu:selectItem()
    local item = self.menuItems[self.selectedIndex + 1]
    if not item then return end

    if item.action == "startNormal" then
        self.game.simulatorMode = Constants.MODE_NORMAL
        self.game:setState("battle")
    elseif item.action == "startPractice" then
        self.game.simulatorMode = Constants.MODE_PRACTICE
        self.game:setState("battle")
    elseif item.action == "showEndless" then
        self:showEndlessMenu()
    elseif item.action == "startEndless" then
        self.game.simulatorMode = Constants.MODE_ENDLESS
        self.game.endlessStage = item.data
        self.game:setState("battle")
    elseif item.action == "showSingleAttack" then
        self:showSingleAttackMenu()
    elseif item.action == "startSingle" then
        self.game.simulatorMode = Constants.MODE_SINGLE
        self.game.singleAttack = item.data
        self.game:setState("battle")
    elseif item.action == "showCustom" then
        -- Custom attack not implemented yet
    end
end

function Menu:update(dt, game)
    -- Navigation
    if Input:justPressed("up") then
        Audio:playSfx("menuCursor")
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 0 then
            self.selectedIndex = #self.menuItems - 1
            -- Jump to end of list
            if #self.menuItems > self.maxVisible then
                self.scrollOffset = #self.menuItems - self.maxVisible
            end
        end
        -- Adjust scroll up
        if self.selectedIndex < self.scrollOffset then
            self.scrollOffset = self.selectedIndex
        end
    elseif Input:justPressed("down") then
        Audio:playSfx("menuCursor")
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex >= #self.menuItems then
            self.selectedIndex = 0
            self.scrollOffset = 0
        end
        -- Adjust scroll down
        if self.selectedIndex >= self.scrollOffset + self.maxVisible then
            self.scrollOffset = self.selectedIndex - self.maxVisible + 1
        end
    end

    -- Selection
    if Input:justPressed("confirm") then
        Audio:playSfx("menuSelect")
        self:selectItem()
    end

    -- Back
    if Input:justPressed("cancel") then
        Audio:playSfx("menuCursor")
        self:goBack()
    end

    -- Hidden test menu (T key)
    if love.keyboard.isDown("t") and not self.tPressed then
        self.tPressed = true
        game:setState("test_menu")
    elseif not love.keyboard.isDown("t") then
        self.tPressed = false
    end

    -- Update heart cursor position (accounting for scroll)
    local item = self.menuItems[self.selectedIndex + 1]
    local uiCfg = AssetsConfig.ui.menu
    if item then
        local displayIndex = self.selectedIndex - self.scrollOffset
        self.heartX = uiCfg.itemX + uiCfg.heartOffsetX
        self.heartY = uiCfg.itemStartY + displayIndex * uiCfg.itemSpacing + uiCfg.heartOffsetY
    end

end

function Menu:draw(game)

    love.graphics.setColor(1, 1, 1)

    local uiCfg = AssetsConfig.ui.menu

    -- Title
    local title = "Select your bad time"
    if self.currentMenu == "endless" then
        title = "Select phase"
    elseif self.currentMenu == "single" then
        title = "Choose an attack"
    end

    Fonts.default:setScale(2)
    Fonts.default:draw(title, 320, uiCfg.titleY, "center")

    -- Menu items (with scroll support)
    Fonts.default:setScale(2)
    local visibleCount = math.min(#self.menuItems, self.maxVisible)
    for displayIdx = 0, visibleCount - 1 do
        local itemIdx = self.scrollOffset + displayIdx + 1
        local item = self.menuItems[itemIdx]
        if item then
            local y = uiCfg.itemStartY + displayIdx * uiCfg.itemSpacing

            -- Color based on status
            if item.status == "ready" then
                love.graphics.setColor(1, 1, 1)
            elseif item.status == "partial" then
                love.graphics.setColor(1, 0.8, 0.4)
            elseif item.status == "missing" or item.status == "not ready" then
                love.graphics.setColor(0.5, 0.5, 0.5)
            else
                love.graphics.setColor(1, 1, 1)
            end

            Fonts.default:draw(item.text, uiCfg.itemX, y, "left")
        end
    end

    -- Scroll indicators
    if #self.menuItems > self.maxVisible then
        love.graphics.setColor(0.5, 0.5, 0.5)
        Fonts.default:setScale(1)
        if self.scrollOffset > 0 then
            Fonts.default:draw("^ more", 550, uiCfg.itemStartY, "center")
        end
        if self.scrollOffset + self.maxVisible < #self.menuItems then
            local bottomY = uiCfg.itemStartY + (self.maxVisible - 1) * uiCfg.itemSpacing
            Fonts.default:draw("v more", 550, bottomY + 16, "center")
        end
    end

    -- Heart cursor (rotated 90 degrees so point faces down)
    if self.heartImage then
        love.graphics.setColor(1, 0, 0)
        love.graphics.draw(self.heartImage, self.heartX, self.heartY, math.pi/2, 1, 1, self.heartOriginX, self.heartOriginY)
    end
end

function Menu:exit()
    -- Cleanup
end

return Menu
