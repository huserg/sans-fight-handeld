local Stubs = require("tests.stubs")
Stubs.install()

local AttackParser = require("src.systems.attack_parser")
local AttackSequencer = require("src.systems.attack_sequencer")

local function makeSequencer(csv)
    local battle = Stubs.makeBattle()
    local sequencer = AttackSequencer.new(battle)
    local events, labels = AttackParser.parseCSV(csv)
    sequencer:loadProgram(events, labels)
    return sequencer, battle
end

describe("AttackSequencer delays", function()
    it("treats the time column as a delay after the previous line", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0.5,BoneV,100,300,30,0,180\n" ..
            "0.3,BoneV,200,300,30,0,180\n" ..
            "0,EndAttack,,\n")

        sequencer:update(0.5)
        assert_eq(#Stubs.FakeBone.spawned, 1, "first bone at 0.5s")
        sequencer:update(0.2)
        assert_eq(#Stubs.FakeBone.spawned, 1, "second bone not yet due")
        sequencer:update(0.1)
        assert_eq(#Stubs.FakeBone.spawned, 2, "second bone 0.3s after first")
        assert_true(sequencer:isFinished())
    end)

    it("executes several zero-delay lines in one frame", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,BoneV,100,300,30,0,180\n" ..
            "0,BoneV,120,300,30,0,180\n" ..
            "0,BoneV,140,300,30,0,180\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 3)
        assert_true(sequencer:isFinished())
    end)

    it("finishes when running past the last line without EndAttack", function()
        local sequencer = makeSequencer("0,SET,A,1\n")
        sequencer:update(0.016)
        assert_true(sequencer:isFinished())
    end)
end)

describe("AttackSequencer pause semantics", function()
    it("TLPause blocks execution until the zone resize completes", function()
        Stubs.FakeBone.spawned = {}
        local sequencer, battle = makeSequencer(
            "0,CombatZoneResize,133,251,508,391,TLResume\n" ..
            "0,TLPause,,\n" ..
            "0,BoneV,100,300,30,0,180\n" ..
            "0,EndAttack,,\n")

        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 0, "paused while resizing")

        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 0, "still paused")

        battle.combatZone.resizing = false
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 1, "resumed after resize finished")
        assert_true(sequencer:isFinished())
    end)
end)
