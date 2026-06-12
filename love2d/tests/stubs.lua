-- Fake implementations of LOVE-dependent modules so systems under test
-- can be required from plain Lua. Install BEFORE requiring any src module.

local Stubs = {}

local FakeBone = {}
FakeBone.__index = FakeBone
FakeBone.spawned = {}

function FakeBone.new(x, y, length, orientation, color)
    local bone = setmetatable({
        x = x, y = y, length = length,
        orientation = orientation, color = color
    }, FakeBone)
    table.insert(FakeBone.spawned, bone)
    return bone
end

function FakeBone:setVelocity(vx, vy) self.vx, self.vy = vx, vy end
function FakeBone:setLifetime(t) self.lifetime = t end
function FakeBone:setGap(position, size) self.gapPosition, self.gapSize = position, size end

local FakeBlaster = {}
FakeBlaster.__index = FakeBlaster
FakeBlaster.spawned = {}

function FakeBlaster.new(startX, startY, targetX, targetY, angle, size)
    local blaster = setmetatable({
        startX = startX, startY = startY,
        targetX = targetX, targetY = targetY,
        angle = angle, size = size
    }, FakeBlaster)
    table.insert(FakeBlaster.spawned, blaster)
    return blaster
end

function FakeBlaster:setTiming(chargeTime, fireTime)
    self.chargeTime, self.fireTime = chargeTime, fireTime
end

function Stubs.install()
    FakeBone.spawned = {}
    FakeBlaster.spawned = {}

    package.loaded["src.systems.audio"] = {
        playSfx = function() end,
        playMusic = function() end,
        stopMusic = function() end,
    }
    package.loaded["src.entities.bone"] = FakeBone
    package.loaded["src.entities.gaster_blaster"] = FakeBlaster

    -- love.filesystem.read backed by io, relative to the love2d/ directory
    love = {
        filesystem = {
            read = function(path)
                local file = io.open(path, "rb")
                if not file then return nil end
                local content = file:read("*a")
                file:close()
                return content
            end
        }
    }
end

Stubs.FakeBone = FakeBone
Stubs.FakeBlaster = FakeBlaster

-- Battle object with just enough surface for the sequencer
function Stubs.makeBattle()
    local zone = { resizing = false }
    function zone:isResizing() return self.resizing end
    function zone:resizeTo(x1, y1, x2, y2) self.resizing = true end
    function zone:setSize(x1, y1, x2, y2) end

    local battle = {
        combatZone = zone,
        playerHeart = {
            x = 320, y = 376, mode = 0,
            setMode = function(self, m) self.mode = m end,
            teleport = function(self, x, y) self.x, self.y = x, y end,
        },
        entities = {},
        sansTexts = {},
    }
    function battle:addEntity(entity) table.insert(self.entities, entity) end
    function battle:setBlackScreen(enabled) self.blackScreen = enabled end
    function battle:showSansText(text) table.insert(self.sansTexts, text) end
    return battle
end

return Stubs
