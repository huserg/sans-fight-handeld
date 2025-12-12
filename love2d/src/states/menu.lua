-- Menu State
-- Main menu with mode selection

local Constants = require("src.core.constants")
local AssetsConfig = require("src.core.assets_config")
local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

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

    -- Scroll
    scrollY = 0,
    targetScrollY = 0,

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
    self.menuItems = {
        { text = "Phase 1", action = "startEndless", data = 0 },
        { text = "Phase 2", action = "startEndless", data = 1 }
    }
end

function Menu:showSingleAttackMenu()
    table.insert(self.menuStack, { menu = "main", index = self.selectedIndex })
    self.currentMenu = "single"
    self.selectedIndex = 0
    self.menuItems = {}
    for i, attack in ipairs(self.attackFiles) do
        table.insert(self.menuItems, {
            text = attack,
            action = "startSingle",
            data = attack
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
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 0 then
            self.selectedIndex = #self.menuItems - 1
        end
    elseif Input:justPressed("down") then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex >= #self.menuItems then
            self.selectedIndex = 0
        end
    end

    -- Selection
    if Input:justPressed("confirm") then
        self:selectItem()
    end

    -- Back
    if Input:justPressed("cancel") then
        self:goBack()
    end

    -- Hidden test menu (T key)
    if love.keyboard.isDown("t") and not self.tPressed then
        self.tPressed = true
        game:setState("test_menu")
    elseif not love.keyboard.isDown("t") then
        self.tPressed = false
    end

    -- Update heart cursor position
    local item = self.menuItems[self.selectedIndex + 1]
    local uiCfg = AssetsConfig.ui.menu
    if item then
        self.heartX = uiCfg.itemX + uiCfg.heartOffsetX
        self.heartY = uiCfg.itemStartY + self.selectedIndex * uiCfg.itemSpacing + uiCfg.heartOffsetY
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

    -- Menu items
    Fonts.default:setScale(2)
    for i, item in ipairs(self.menuItems) do
        local y = uiCfg.itemStartY + (i - 1) * uiCfg.itemSpacing
        Fonts.default:draw(item.text, uiCfg.itemX, y, "left")
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
