-- Audio Test
-- Test sound effects and music

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")
local Audio = require("src.systems.audio")

local TestAudio = {
    items = {
        { id = "megalovania", text = "Megalovania", type = "music" },
        { id = "ding", text = "Ding", type = "sfx" },
        { id = "playerDamaged", text = "Player Damaged", type = "sfx" },
        { id = "menuSelect", text = "Menu Select", type = "sfx" },
        { id = "menuCursor", text = "Menu Cursor", type = "sfx" },
        { id = "boneStab", text = "Bone Stab", type = "sfx" },
        { id = "gasterBlaster", text = "Gaster Blaster", type = "sfx" },
        { id = "gasterBlast", text = "Gaster Blast", type = "sfx" },
        { id = "slam", text = "Slam", type = "sfx" },
        { id = "warning", text = "Warning", type = "sfx" },
        { id = "flash", text = "Flash", type = "sfx" },
        { id = "sansSpeak", text = "Sans Speak", type = "sfx" },
        { id = "battleText", text = "Battle Text", type = "sfx" },
        { id = "heartShatter", text = "Heart Shatter", type = "sfx" },
        { id = "heartSplit", text = "Heart Split", type = "sfx" },
        { id = "playerHeal", text = "Player Heal", type = "sfx" },
        { id = "playerFight", text = "Player Fight", type = "sfx" },
    },
    selected = 1,
    scrollOffset = 0,
    maxVisible = 12
}

function TestAudio:enter(game)
    self.game = game
    Fonts:load()
    self.selected = 1
    self.scrollOffset = 0
end

function TestAudio:update(dt, game)
    if Input:justPressed("up") then
        self.selected = self.selected - 1
        if self.selected < 1 then
            self.selected = #self.items
            self.scrollOffset = math.max(0, #self.items - self.maxVisible)
        end
        -- Adjust scroll
        if self.selected <= self.scrollOffset then
            self.scrollOffset = self.selected - 1
        end
    elseif Input:justPressed("down") then
        self.selected = self.selected + 1
        if self.selected > #self.items then
            self.selected = 1
            self.scrollOffset = 0
        end
        -- Adjust scroll
        if self.selected > self.scrollOffset + self.maxVisible then
            self.scrollOffset = self.selected - self.maxVisible
        end
    end

    if Input:justPressed("confirm") then
        local item = self.items[self.selected]
        if item.type == "music" then
            -- Toggle music
            if Audio:isMusicPlaying() then
                Audio:stopMusic()
            else
                Audio:playMusic(item.id, true)
            end
        else
            -- Play SFX
            Audio:playSfx(item.id)
        end
    end

    -- Mute toggle
    if Input:justPressed("cancel") then
        Audio:toggleMute()
    end

    if Input:justPressed("menu") then
        Audio:stopMusic()
        game:setState("test_menu")
    end
end

function TestAudio:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Audio Test", 320, 20, "center")

    -- Mute status
    if Audio.muted then
        love.graphics.setColor(1, 0.3, 0.3)
        Fonts.default:draw("[MUTED]", 320, 40, "center")
    end

    local y = 70
    for i = 1 + self.scrollOffset, math.min(#self.items, self.scrollOffset + self.maxVisible) do
        local item = self.items[i]
        local status = ""
        local isPlaying = false

        if item.type == "music" then
            isPlaying = Audio:isMusicPlaying() and Audio.currentMusic == Audio.music[item.id]
            if isPlaying then
                status = " [PLAYING]"
            end
        end

        -- Check if sound exists
        local exists = (item.type == "music" and Audio.music[item.id]) or (item.type == "sfx" and Audio.sfx[item.id])

        if not exists then
            status = " [NOT FOUND]"
            love.graphics.setColor(0.5, 0.5, 0.5)
        elseif isPlaying then
            love.graphics.setColor(0, 1, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end

        if i == self.selected then
            love.graphics.setColor(1, 1, 0)
            Fonts.default:draw("> " .. item.text .. status, 320, y, "center")
        else
            Fonts.default:draw(item.text .. status, 320, y, "center")
        end
        y = y + 24
    end

    -- Scroll indicators
    love.graphics.setColor(0.5, 0.5, 0.5)
    if self.scrollOffset > 0 then
        Fonts.default:draw("^ more ^", 320, 58, "center")
    end
    if self.scrollOffset + self.maxVisible < #self.items then
        Fonts.default:draw("v more v", 320, 70 + self.maxVisible * 24, "center")
    end

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Z: Play | X: Mute | Esc: Back", 320, 460, "center")
end

function TestAudio:exit()
    -- Keep music playing if user wants
end

return TestAudio
