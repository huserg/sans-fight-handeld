-- Loading State
-- Loads all game assets before showing the menu

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

local Loading = {
    game = nil,
    loadingDone = false,
    loadingText = "LOADING...",
    assetsLoaded = false,

    -- Attack list (same as original)
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

function Loading:enter(game)
    self.game = game
    self.loadingDone = false
    self.assetsLoaded = false
end

function Loading:loadAssets()
    -- Load fonts
    Fonts:load()

    -- TODO: Load sprites, sounds, attack data

    self.assetsLoaded = true
    self.loadingDone = true
    self.loadingText = ""
end

function Loading:update(dt, game)
    if not self.assetsLoaded then
        self:loadAssets()
        return
    end

    -- Wait for any input to go to menu
    if self.loadingDone then
        if Input:justPressed("confirm") or Input:justPressed("cancel") or Input:justPressed("menu") then
            game:setState("menu")
        end
    end
end

function Loading:draw(game)
    love.graphics.setColor(1, 1, 1)

    if not self.loadingDone then
        love.graphics.printf(self.loadingText, 0, 230, 640, "center")
    else
        if Fonts.loaded then
            Fonts.default:setScale(2)
            Fonts.default:draw("Press Z to start", 320, 240, "center")
        else
            love.graphics.printf("PRESS Z TO START", 0, 230, 640, "center")
        end
    end
end

function Loading:exit()
    -- Cleanup if needed
end

return Loading
