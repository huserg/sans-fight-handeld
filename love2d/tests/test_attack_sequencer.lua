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

describe("AttackSequencer VM integration", function()
    it("substitutes $vars into spawn handler params", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,SET,X,250\n" ..
            "0,SET,Speed,180\n" ..
            "0,BoneV,$X,300,30,0,$Speed\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 1)
        assert_eq(Stubs.FakeBone.spawned[1].x, 250)
        assert_eq(Stubs.FakeBone.spawned[1].vx, 180)
    end)

    it("runs a counted loop to completion (Loops.csv pattern)", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,SET,LoopVar,5\n" ..
            "0,:StartLoop,,\n" ..
            "0,JMPZ,EndLoop,$LoopVar\n" ..
            "0,SUB,LoopVar,$LoopVar,1\n" ..
            "0,BoneV,100,300,30,0,180\n" ..
            "0,JMPABS,StartLoop,\n" ..
            "0,:EndLoop,,\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 5, "loop body ran 5 times")
        assert_true(sequencer:isFinished())
    end)

    it("respects delays on lines reached by backward jumps", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,SET,LoopVar,2\n" ..
            "0,:StartLoop,,\n" ..
            "0,JMPZ,EndLoop,$LoopVar\n" ..
            "0,SUB,LoopVar,$LoopVar,1\n" ..
            "0.5,BoneV,100,300,30,0,180\n" ..
            "0,JMPABS,StartLoop,\n" ..
            "0,:EndLoop,,\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 0, "first bone waits its delay")
        sequencer:update(0.5)
        assert_eq(#Stubs.FakeBone.spawned, 1)
        sequencer:update(0.5)
        assert_eq(#Stubs.FakeBone.spawned, 2)
        assert_true(sequencer:isFinished())
    end)

    it("jumps to absolute numeric line targets", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,JMPABS,3,\n" ..
            "0,BoneV,100,300,30,0,180\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 0, "line 2 skipped by jump to line 3")
        assert_true(sequencer:isFinished())
    end)

    it("GetHeartPos stores the heart position into named vars", function()
        local sequencer, battle = makeSequencer(
            "0,GetHeartPos,HX,HY\n" ..
            "0,SansText,$HX,\n" ..
            "0,SansText,$HY,\n" ..
            "0,EndAttack,,\n")
        battle.playerHeart.x = 123
        battle.playerHeart.y = 456
        sequencer:update(0.016)
        assert_eq(battle.sansTexts[1], 123)
        assert_eq(battle.sansTexts[2], 456)
    end)
end)

describe("Real attack files", function()
    it("VM-based attacks now report ready status", function()
        -- Run from love2d/ so attacks/ resolves
        assert_eq(AttackParser.getAttackStatus("sans_bonegap2"), "ready")
        assert_eq(AttackParser.getAttackStatus("sans_randomblaster1"), "ready")
        assert_eq(AttackParser.getAttackStatus("sans_multi1"), "ready")
        assert_eq(AttackParser.getAttackStatus("sans_platforms1"), "ready")
    end)

    it("attacks needing unimplemented commands stay partial", function()
        assert_eq(AttackParser.getAttackStatus("sans_bonestab1"), "partial")
        assert_eq(AttackParser.getAttackStatus("sans_final"), "partial")
    end)

    it("sans_bonegap2 runs to completion without unknown commands", function()
        Stubs.FakeBone.spawned = {}
        local battle = Stubs.makeBattle()
        local sequencer = AttackSequencer.new(battle)
        assert_true(sequencer:loadAttack("sans_bonegap2"), "load")

        -- The attack starts with CombatZoneResize which sets resizing=true.
        -- Clear it each frame to simulate the resize animation completing,
        -- matching real game-engine behaviour (zone:update eventually sets
        -- resizing=false and TLResume fires via pendingResumeOnResize).
        local elapsed = 0
        while not sequencer:isFinished() and elapsed < 120 do
            battle.combatZone.resizing = false
            sequencer:update(0.016)
            elapsed = elapsed + 0.016
        end
        assert_true(sequencer:isFinished(), "attack ended within 120s")
        assert_true(#Stubs.FakeBone.spawned > 0, "bones were spawned")
    end)
end)

describe("Bone anchoring", function()
    it("anchors vertical bones by their top edge (CSV y is the top, x stays center)", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,BoneV,200,300,30,0,180\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 1)
        assert_eq(Stubs.FakeBone.spawned[1].x, 200, "x stays the center")
        assert_eq(Stubs.FakeBone.spawned[1].y, 315, "center y = top 300 + length/2")
    end)
end)

describe("Bone repeat", function()
    it("BoneVRepeat spawns Count vertical bones spaced by Spacing", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,BoneVRepeat,100,200,30,0,120,4,50\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 4, "four bones")
        assert_eq(Stubs.FakeBone.spawned[1].x, 100, "first at startX")
        assert_eq(Stubs.FakeBone.spawned[4].x, 250, "fourth at startX + 3*spacing")
        assert_eq(Stubs.FakeBone.spawned[1].y, 215, "y is top edge + height/2")
    end)

    it("BoneHRepeat spawns Count horizontal bones spaced down Y", function()
        Stubs.FakeBone.spawned = {}
        local sequencer = makeSequencer(
            "0,BoneHRepeat,130,-10,200,1,300,3,183\n" ..
            "0,EndAttack,,\n")
        sequencer:update(0.016)
        assert_eq(#Stubs.FakeBone.spawned, 3, "three bones")
        assert_eq(Stubs.FakeBone.spawned[1].y, -10, "first at startY (center)")
        assert_eq(Stubs.FakeBone.spawned[3].y, 356, "third at startY + 2*spacing")
        assert_eq(Stubs.FakeBone.spawned[1].x, 230, "x is left edge + width/2")
    end)
end)
