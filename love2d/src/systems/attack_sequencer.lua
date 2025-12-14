-- Attack Sequencer
-- Executes attack timelines from CSV data

local AttackParser = require("src.systems.attack_parser")
local Constants = require("src.core.constants")
local Audio = require("src.systems.audio")
local Bone = require("src.entities.bone")
local GasterBlaster = require("src.entities.gaster_blaster")

local AttackSequencer = {}
AttackSequencer.__index = AttackSequencer

function AttackSequencer.new(battle)
    local self = setmetatable({}, AttackSequencer)

    self.battle = battle
    self.events = {}
    self.currentIndex = 1
    self.timer = 0
    self.paused = false
    self.tlPaused = false
    self.running = false
    self.finished = false

    -- Pending events (events waiting for their time)
    self.pendingEvents = {}

    -- Command handlers
    self.handlers = {}
    self:registerHandlers()

    return self
end

function AttackSequencer:registerHandlers()
    -- End attack
    self.handlers["EndAttack"] = function(params)
        self.finished = true
        self.running = false
    end

    -- Heart mode (0=red, 1=blue)
    self.handlers["HeartMode"] = function(params)
        local mode = params[1] or 0
        if self.battle.playerHeart then
            if mode == 0 then
                self.battle.playerHeart:setMode(Constants.HEARTMODE_RED)
            else
                self.battle.playerHeart:setMode(Constants.HEARTMODE_BLUE)
            end
        end
    end

    -- Heart teleport
    self.handlers["HeartTeleport"] = function(params)
        local x, y = params[1], params[2]
        if self.battle.playerHeart and x and y then
            self.battle.playerHeart:teleport(x, y)
        end
    end

    -- Combat zone resize (animated)
    self.handlers["CombatZoneResize"] = function(params)
        local x1, y1, x2, y2 = params[1], params[2], params[3], params[4]
        local mode = params[5] or ""
        if self.battle.combatZone and x1 and y1 and x2 and y2 then
            self.battle.combatZone:resizeTo(x1, y1, x2, y2)
            -- Handle TLResume flag
            if mode == "TLResume" then
                self.tlPaused = false
            end
        end
    end

    -- Combat zone resize instant
    self.handlers["CombatZoneResizeInstant"] = function(params)
        local x1, y1, x2, y2 = params[1], params[2], params[3], params[4]
        if self.battle.combatZone and x1 and y1 and x2 and y2 then
            self.battle.combatZone:setSize(x1, y1, x2, y2)
        end
    end

    -- Timeline pause/resume
    self.handlers["TLPause"] = function(params)
        self.tlPaused = true
    end

    self.handlers["TLResume"] = function(params)
        self.tlPaused = false
    end

    -- Vertical bone: x, y, height, direction, speed, color
    self.handlers["BoneV"] = function(params)
        local x, y, length, direction, speed, color =
            params[1], params[2], params[3], params[4], params[5], params[6]
        if x and y and length then
            local bone = Bone.new(x, y, length, "vertical", color or 0)
            local vx, vy = 0, 0
            direction = direction or 0
            speed = speed or 200

            if direction == 0 then
                vx = speed
            elseif direction == 1 then
                vy = speed
            elseif direction == 2 then
                vx = -speed
            elseif direction == 3 then
                vy = -speed
            end

            bone:setVelocity(vx, vy)
            bone:setLifetime(10)
            self.battle:addEntity(bone)
        end
    end

    -- Horizontal bone: x, y, width, direction, speed, color
    self.handlers["BoneH"] = function(params)
        local x, y, length, direction, speed, color =
            params[1], params[2], params[3], params[4], params[5], params[6]
        if x and y and length then
            local bone = Bone.new(x, y, length, "horizontal", color or 0)
            local vx, vy = 0, 0
            direction = direction or 0
            speed = speed or 200

            if direction == 0 then
                vx = speed
            elseif direction == 1 then
                vy = speed
            elseif direction == 2 then
                vx = -speed
            elseif direction == 3 then
                vy = -speed
            end

            bone:setVelocity(vx, vy)
            bone:setLifetime(10)
            self.battle:addEntity(bone)
        end
    end

    -- Vertical bone repeat
    self.handlers["BoneVRepeat"] = function(params)
        local x, y, length, direction, speed, gapSize, gapY =
            params[1], params[2], params[3], params[4], params[5], params[6], params[7]

        if x and y and length then
            -- Create bone with gap
            local bone = Bone.new(x, y, length, "vertical", false)

            if gapSize and gapY then
                bone:setGap(gapY, gapSize)
            end

            local vx, vy = 0, 0
            direction = direction or 0
            speed = speed or 200

            if direction == 0 then
                vx = speed
            elseif direction == 1 then
                vy = speed
            elseif direction == 2 then
                vx = -speed
            elseif direction == 3 then
                vy = -speed
            end

            bone:setVelocity(vx, vy)
            bone:setLifetime(10)
            self.battle:addEntity(bone)
        end
    end

    -- Horizontal bone repeat
    self.handlers["BoneHRepeat"] = function(params)
        local x, y, length, direction, speed, gapSize, gapX =
            params[1], params[2], params[3], params[4], params[5], params[6], params[7]

        if x and y and length then
            local bone = Bone.new(x, y, length, "horizontal", false)

            if gapSize and gapX then
                bone:setGap(gapX, gapSize)
            end

            local vx, vy = 0, 0
            direction = direction or 0
            speed = speed or 200

            if direction == 0 then
                vx = speed
            elseif direction == 1 then
                vy = speed
            elseif direction == 2 then
                vx = -speed
            elseif direction == 3 then
                vy = -speed
            end

            bone:setVelocity(vx, vy)
            bone:setLifetime(10)
            self.battle:addEntity(bone)
        end
    end

    -- Sound effects
    self.handlers["Sound"] = function(params)
        local soundName = params[1]
        if soundName then
            -- Map sound names to audio system names
            local soundMap = {
                ["Flash"] = "flash",
                ["Ding"] = "ding",
                ["GasterBlaster"] = "gasterBlaster",
                ["Slam"] = "slam",
                ["Warning"] = "warning",
                ["BoneStab"] = "boneStab",
            }
            local mappedName = soundMap[soundName]
            if mappedName then
                Audio:playSfx(mappedName)
            end
        end
    end

    -- Gaster Blaster
    self.handlers["GasterBlaster"] = function(params)
        local size, startX, startY, targetX, targetY, angle, chargeTime, fireTime =
            params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8]

        if targetX and targetY then
            local blaster = GasterBlaster.new(
                startX or targetX,
                startY or targetY,
                targetX,
                targetY,
                angle or 0,
                size or 1
            )
            blaster:setTiming(chargeTime or 0.5, fireTime or 0.3)
            self.battle:addEntity(blaster)
        end
    end

    -- Black screen (flash effect)
    self.handlers["BlackScreen"] = function(params)
        local state = params[1]
        if self.battle.setBlackScreen then
            self.battle:setBlackScreen(state == 1)
        end
    end

    -- Sans animations (stub for now)
    self.handlers["SansAnimation"] = function(params)
        -- Will be implemented with Sans entity
    end

    self.handlers["SansHead"] = function(params)
        -- Will be implemented with Sans entity
    end

    self.handlers["SansBody"] = function(params)
        -- Will be implemented with Sans entity
    end

    self.handlers["SansText"] = function(params)
        local text = params[1]
        if text and self.battle.showSansText then
            self.battle:showSansText(text)
        end
    end

    self.handlers["SansSlam"] = function(params)
        -- Will be implemented with Sans entity
    end

    -- Bone stab attack
    self.handlers["BoneStab"] = function(params)
        -- Complex attack, needs separate implementation
    end

    -- Sine wave bones
    self.handlers["SineBones"] = function(params)
        -- Complex attack, needs separate implementation
    end

    -- Platform (for blue soul mode)
    self.handlers["Platform"] = function(params)
        -- Needs platform entity implementation
    end
end

function AttackSequencer:loadAttack(name)
    local path = "attacks/" .. name .. ".csv"
    local events = AttackParser.loadFromFile(path)

    if not events then
        print("Failed to load attack: " .. name)
        return false
    end

    self.events = events
    self.currentIndex = 1
    self.timer = 0
    self.paused = false
    self.tlPaused = false
    self.running = true
    self.finished = false

    return true
end

function AttackSequencer:start()
    self.running = true
    self.paused = false
end

function AttackSequencer:pause()
    self.paused = true
end

function AttackSequencer:resume()
    self.paused = false
end

function AttackSequencer:stop()
    self.running = false
    self.finished = true
end

function AttackSequencer:update(dt)
    if not self.running or self.paused or self.finished then
        return
    end

    -- Don't advance timer if TL is paused
    if not self.tlPaused then
        self.timer = self.timer + dt
    end

    -- Process events that are ready
    while self.currentIndex <= #self.events do
        local event = self.events[self.currentIndex]

        if event.time <= self.timer then
            self:executeEvent(event)
            self.currentIndex = self.currentIndex + 1

            -- Check if we need to stop
            if self.finished then
                break
            end
        else
            break
        end
    end

    -- Check if all events processed
    if self.currentIndex > #self.events and not self.finished then
        self.finished = true
        self.running = false
    end
end

function AttackSequencer:executeEvent(event)
    local handler = self.handlers[event.command]
    if handler then
        handler(event.params)
    else
        -- Unknown command
        print("Unknown attack command: " .. event.command)
    end
end

function AttackSequencer:isRunning()
    return self.running
end

function AttackSequencer:isFinished()
    return self.finished
end

return AttackSequencer
