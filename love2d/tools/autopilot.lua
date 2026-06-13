-- Visual autopilot (dev-only, excluded from device/.love builds)
-- Drives the game without human input so the rendered output can be captured
-- for verification. Activated only when the SANS_AUTOPILOT env var is set, so
-- it is inert in normal play. Loaded at the end of love.load in main.lua.
--
-- Usage from love2d/:
--   SANS_AUTOPILOT=sans_bonegap2 love .
--   SANS_AUTOPILOT=sans_platforms1 SANS_AUTOPILOT_HOLD=right SANS_AUTOPILOT_JUMP=0.9 love .
-- Env:
--   SANS_AUTOPILOT          attack name (default sans_bonegap2)
--   SANS_AUTOPILOT_TIME     total seconds (default 12)
--   SANS_AUTOPILOT_INTERVAL screenshot interval seconds (default 0.75)
--   SANS_AUTOPILOT_HOLD     comma-separated keys held down (e.g. "right,up")
--   SANS_AUTOPILOT_JUMP     jump (z) pulse interval seconds, 0/unset = no jumps
-- Screenshots land in the LOVE save dir: <save>/shots/<attack>_NN.png

local Game = require("src.core.game")
local Constants = require("src.core.constants")

local attack = os.getenv("SANS_AUTOPILOT") or "sans_bonegap2"
local totalTime = tonumber(os.getenv("SANS_AUTOPILOT_TIME")) or 12
local shotInterval = tonumber(os.getenv("SANS_AUTOPILOT_INTERVAL")) or 0.75
local jumpInterval = tonumber(os.getenv("SANS_AUTOPILOT_JUMP")) or 0

-- Scripted input: a held-key set the game polls through love.keyboard.isDown
local heldKeys = {}
for key in (os.getenv("SANS_AUTOPILOT_HOLD") or ""):gmatch("[^,]+") do
    heldKeys[key] = true
end

local origIsDown = love.keyboard.isDown
love.keyboard.isDown = function(...)
    for _, k in ipairs({ ... }) do
        if heldKeys[k] then return true end
    end
    return false
end

love.filesystem.createDirectory("shots")

local origUpdate = love.update

-- Fixed timestep so captures are reproducible regardless of host vsync
local FIXED_DT = 1 / 60
local JUMP_HOLD = 0.08

local started = false
local elapsed = 0
local nextShot = 0
local shotIndex = 0

function love.update(_)
    -- Pulse the jump key at the start of each jump interval (z down briefly,
    -- so the game sees a fresh justPressed each time)
    if jumpInterval > 0 and started then
        local phase = elapsed % jumpInterval
        heldKeys["z"] = phase < JUMP_HOLD
    end

    if origUpdate then origUpdate(FIXED_DT) end

    -- Jump straight into the chosen single attack once loading reaches the menu
    if not started and Game.state == "menu" then
        Game.simulatorMode = Constants.MODE_SINGLE
        Game.singleAttack = attack
        Game:setState("battle")
        started = true
    end

    if not started then return end

    elapsed = elapsed + FIXED_DT
    if elapsed >= nextShot then
        shotIndex = shotIndex + 1
        love.graphics.captureScreenshot(
            string.format("shots/%s_%02d.png", attack, shotIndex))
        nextShot = nextShot + shotInterval
    end

    if elapsed >= totalTime then
        love.event.quit()
    end
end
