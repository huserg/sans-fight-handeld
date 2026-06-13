-- Attack Sequencer
-- Executes attack timelines from CSV data using a delay-based program counter.
-- Each event's time column is a delay *after* the previous executed line,
-- not an absolute timestamp.

local AttackParser = require("src.systems.attack_parser")
local Constants = require("src.core.constants")
local Audio = require("src.systems.audio")
local Bone = require("src.entities.bone")
local GasterBlaster = require("src.entities.gaster_blaster")
local AttackVM = require("src.systems.attack_vm")

local AttackSequencer = {}
AttackSequencer.__index = AttackSequencer

-- Safety net against malformed CSV programs (0-delay infinite loops)
local MAX_LINES_PER_FRAME = 2000

function AttackSequencer.new(battle)
    local self = setmetatable({}, AttackSequencer)

    self.battle = battle
    self.events = {}
    self.labels = {}
    self.vm = AttackVM.new()
    self.pc = 1
    self.waitTimer = 0
    self.paused = false
    self.tlPaused = false
    self.pendingResumeOnResize = false
    self.running = false
    self.finished = false

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

    -- Combat zone resize (animated); "TLResume" resumes the timeline
    -- once the resize animation completes
    self.handlers["CombatZoneResize"] = function(params)
        local x1, y1, x2, y2 = params[1], params[2], params[3], params[4]
        local mode = params[5] or ""
        if self.battle.combatZone and x1 and y1 and x2 and y2 then
            self.battle.combatZone:resizeTo(x1, y1, x2, y2)
            if mode == "TLResume" then
                self.pendingResumeOnResize = true
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

function AttackSequencer:loadProgram(events, labels)
    self.events = events
    self.labels = labels or {}
    self.vm = AttackVM.new()
    self.pc = 1
    self.waitTimer = 0
    self.paused = false
    self.tlPaused = false
    self.pendingResumeOnResize = false
    self.running = true
    self.finished = false
end

function AttackSequencer:loadAttack(name)
    local path = "attacks/" .. name .. ".csv"
    local events, labels = AttackParser.loadFromFile(path)

    if not events then
        print("Failed to load attack: " .. name)
        return false
    end

    self:loadProgram(events, labels)
    return true
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

    self:checkPendingResume()

    if self.tlPaused then
        return
    end

    self.waitTimer = self.waitTimer + dt

    local executed = 0
    while self.running and not self.finished and not self.tlPaused do
        local event = self.events[self.pc]

        if not event then
            self.finished = true
            self.running = false
            break
        end

        if self.waitTimer < event.time then
            break
        end

        self.waitTimer = self.waitTimer - event.time
        self:executeEvent(event)

        executed = executed + 1
        if executed >= MAX_LINES_PER_FRAME then
            print("AttackSequencer: line budget exceeded, possible infinite loop")
            break
        end
    end
end

function AttackSequencer:checkPendingResume()
    if self.pendingResumeOnResize
        and self.battle.combatZone
        and not self.battle.combatZone:isResizing() then
        self.pendingResumeOnResize = false
        self.tlPaused = false
    end
end

function AttackSequencer:executeEvent(event)
    local command = event.command

    -- Labels and blank-line placeholders only consume their delay
    if command == "NOP" or command:sub(1, 1) == ":" then
        self.pc = self.pc + 1
        return
    end

    if self.vm:isOp(command) then
        local jump = self.vm:execute(command, event.params)
        if jump then
            self:applyJump(jump)
        else
            self.pc = self.pc + 1
        end
        return
    end

    local handler = self.handlers[command]
    if handler then
        handler(self:resolveParams(event.params))
    else
        print("Unknown attack command: " .. command)
    end
    self.pc = self.pc + 1
end

function AttackSequencer:applyJump(jump)
    if jump.type == "rel" then
        self.pc = self.pc + jump.offset
    else
        local target = jump.target
        if type(target) == "number" then
            self.pc = target
        else
            local line = self.labels[target]
            if line then
                self.pc = line
            else
                print("Unknown jump label: " .. tostring(target))
                self.pc = #self.events + 1
            end
        end
    end

    if self.pc < 1 then
        print("AttackSequencer: jump target out of range, stopping program")
        self.pc = #self.events + 1
    end
end

-- Handlers receive concrete values: $vars substituted, empty cells left
-- nil so positional indexing stays aligned with the CSV columns
function AttackSequencer:resolveParams(params)
    local resolved = {}
    for i = 1, #params do
        local value = params[i]
        if value ~= "" then
            resolved[i] = self.vm:resolve(value)
        end
    end
    return resolved
end

function AttackSequencer:isRunning()
    return self.running
end

function AttackSequencer:isFinished()
    return self.finished
end

return AttackSequencer
