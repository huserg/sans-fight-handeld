-- Visual autopilot (dev-only, excluded from device/.love builds)
-- Drives the game without human input so the rendered output can be captured
-- for verification. Activated only when the SANS_AUTOPILOT env var is set, so
-- it is inert in normal play. Loaded at the end of love.load in main.lua.
--
-- Usage from love2d/:
--   SANS_AUTOPILOT=sans_bonegap2 love .
--   SANS_AUTOPILOT=sans_bonegap2 SANS_AUTOPILOT_TIME=10 love .
-- Screenshots land in the LOVE save dir: <save>/shots/<attack>_NN.png

local Game = require("src.core.game")
local Constants = require("src.core.constants")

local attack = os.getenv("SANS_AUTOPILOT") or "sans_bonegap2"
local totalTime = tonumber(os.getenv("SANS_AUTOPILOT_TIME")) or 12
local shotInterval = tonumber(os.getenv("SANS_AUTOPILOT_INTERVAL")) or 0.75

local started = false
local elapsed = 0
local nextShot = 0
local shotIndex = 0

love.filesystem.createDirectory("shots")

local origUpdate = love.update

-- Force determinism-friendly timestep regardless of host vsync
local FIXED_DT = 1 / 60

function love.update(_)
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
