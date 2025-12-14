-- Audio System
-- Centralized audio management for SFX and music

local AssetsConfig = require("src.core.assets_config")

local Audio = {
    loaded = false,
    sfx = {},
    music = {},
    currentMusic = nil,
    musicVolume = 0.7,
    sfxVolume = 0.8,
    muted = false
}

function Audio:load()
    if self.loaded then return end

    -- Load all SFX
    for name, cfg in pairs(AssetsConfig.audio.sfx) do
        local success, source = pcall(function()
            return love.audio.newSource(cfg.path, cfg.type)
        end)
        if success then
            self.sfx[name] = source
        else
            print("Failed to load SFX: " .. name)
        end
    end

    -- Load all music
    for name, cfg in pairs(AssetsConfig.audio.music) do
        local success, source = pcall(function()
            return love.audio.newSource(cfg.path, cfg.type)
        end)
        if success then
            self.music[name] = source
        else
            print("Failed to load music: " .. name)
        end
    end

    self.loaded = true
end

function Audio:playSfx(name, volume, pitch)
    if self.muted then return end
    if not self.loaded then self:load() end

    local sound = self.sfx[name]
    if sound then
        -- Clone for overlapping sounds
        local clone = sound:clone()
        clone:setVolume((volume or 1) * self.sfxVolume)
        if pitch then
            clone:setPitch(pitch)
        end
        clone:play()
        return clone
    end
end

function Audio:stopSfx(name)
    local sound = self.sfx[name]
    if sound then
        sound:stop()
    end
end

function Audio:playMusic(name, loop, volume)
    if not self.loaded then self:load() end

    -- Stop current music
    if self.currentMusic then
        self.currentMusic:stop()
    end

    local music = self.music[name]
    if music then
        music:setLooping(loop ~= false)
        music:setVolume((volume or 1) * self.musicVolume)
        if not self.muted then
            music:play()
        end
        self.currentMusic = music
        return music
    end
end

function Audio:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
    end
end

function Audio:pauseMusic()
    if self.currentMusic then
        self.currentMusic:pause()
    end
end

function Audio:resumeMusic()
    if self.currentMusic and not self.muted then
        self.currentMusic:play()
    end
end

function Audio:isMusicPlaying()
    return self.currentMusic and self.currentMusic:isPlaying()
end

function Audio:setMusicVolume(volume)
    self.musicVolume = volume
    if self.currentMusic then
        self.currentMusic:setVolume(volume)
    end
end

function Audio:setSfxVolume(volume)
    self.sfxVolume = volume
end

function Audio:setMuted(muted)
    self.muted = muted
    if muted then
        if self.currentMusic then
            self.currentMusic:pause()
        end
    else
        if self.currentMusic then
            self.currentMusic:play()
        end
    end
end

function Audio:toggleMute()
    self:setMuted(not self.muted)
end

return Audio
