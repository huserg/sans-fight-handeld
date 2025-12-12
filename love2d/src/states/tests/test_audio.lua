-- Audio Test
-- Test sound effects and music

local Fonts = require("src.ui.fonts")
local Input = require("src.systems.input")

local TestAudio = {
    sounds = {},
    items = {
        { id = "megalovania", text = "Megalovania", path = "assets/audio/mus_zz_megalovania.ogg", type = "stream" },
        { id = "ding", text = "Ding", path = "assets/audio/ding.ogg", type = "static" },
        { id = "damage", text = "Player Damaged", path = "assets/audio/playerdamaged.ogg", type = "static" },
        { id = "menuselect", text = "Menu Select", path = "assets/audio/menuselect.ogg", type = "static" },
        { id = "menucursor", text = "Menu Cursor", path = "assets/audio/menucursor.ogg", type = "static" },
        { id = "bonestab", text = "Bone Stab", path = "assets/audio/bonestab.ogg", type = "static" },
        { id = "blaster", text = "Gaster Blaster", path = "assets/audio/gasterblaster.ogg", type = "static" },
        { id = "slam", text = "Slam", path = "assets/audio/slam.ogg", type = "static" },
    },
    selected = 1,
    currentMusic = nil
}

function TestAudio:enter(game)
    self.game = game
    Fonts:load()
    self.selected = 1

    -- Load all sounds
    for _, item in ipairs(self.items) do
        local success, source = pcall(function()
            return love.audio.newSource(item.path, item.type)
        end)
        if success then
            self.sounds[item.id] = source
        end
    end
end

function TestAudio:update(dt, game)
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
        local sound = self.sounds[item.id]
        if sound then
            if item.type == "stream" then
                -- Music toggle
                if self.currentMusic and self.currentMusic:isPlaying() then
                    self.currentMusic:stop()
                    self.currentMusic = nil
                else
                    if self.currentMusic then
                        self.currentMusic:stop()
                    end
                    sound:setLooping(true)
                    sound:play()
                    self.currentMusic = sound
                end
            else
                -- Sound effect
                sound:stop()
                sound:play()
            end
        end
    end

    if Input:justPressed("cancel") or Input:justPressed("menu") then
        -- Stop music before leaving
        if self.currentMusic then
            self.currentMusic:stop()
        end
        game:setState("test_menu")
    end
end

function TestAudio:draw(game)
    love.graphics.setColor(1, 1, 1)
    Fonts.default:setScale(1)
    Fonts.default:draw("Audio Test", 320, 20, "center")

    local y = 80
    for i, item in ipairs(self.items) do
        local sound = self.sounds[item.id]
        local status = ""

        if not sound then
            status = " [NOT FOUND]"
            love.graphics.setColor(0.5, 0.5, 0.5)
        elseif sound:isPlaying() then
            status = " [PLAYING]"
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

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    Fonts.default:draw("Z: Play/Stop | X/Esc: Back", 320, 460, "center")
end

function TestAudio:exit()
    if self.currentMusic then
        self.currentMusic:stop()
    end
    self.sounds = {}
end

return TestAudio
