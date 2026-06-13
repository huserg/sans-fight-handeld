local Stubs = require("tests.stubs")
Stubs.install()

local AttackParser = require("src.systems.attack_parser")

describe("AttackParser", function()
    it("keeps one event per physical line (CRLF and empty lines)", function()
        local csv = "0,SET,A,1\r\n\r\n0.5,BoneV,100,200,30,0,180\r\n"
        local events = AttackParser.parseCSV(csv)
        assert_eq(#events, 3, "event count")
        assert_eq(events[1].command, "SET")
        assert_eq(events[2].command, "NOP")
        assert_eq(events[3].command, "BoneV")
        assert_near(events[3].time, 0.5)
    end)

    it("collects labels with their 1-based line index", function()
        local csv = "0,SET,A,1\n0,:Begin,,\n0,ADD,A,$A,1\n0,JMPABS,Begin,\n"
        local events, labels = AttackParser.parseCSV(csv)
        assert_eq(#events, 4)
        assert_eq(labels["Begin"], 2)
    end)

    it("keeps $refs as strings and converts numbers", function()
        local csv = "0,BoneV,$X,376,30,0,$Speed\n"
        local events = AttackParser.parseCSV(csv)
        assert_eq(events[1].params[1], "$X")
        assert_eq(events[1].params[2], 376)
        assert_eq(events[1].params[5], "$Speed")
    end)

    it("drops trailing empty lines so they cannot delay EndAttack", function()
        local csv = "0,EndAttack,,\n\n\n"
        local events = AttackParser.parseCSV(csv)
        assert_eq(#events, 1)
    end)

    it("treats VM opcodes, labels and NOP as implemented in analyzeAttack", function()
        local csv = "0,SET,A,1\n0,:Loop,,\n0,JMPZ,4,$A\n0,SansText,hi,\n0,EndAttack,,\n"
        local events = AttackParser.parseCSV(csv)
        local analysis = AttackParser.analyzeAttack(events)
        assert_true(analysis.isReady, "all commands should be implemented")
    end)

    it("still reports genuinely missing commands", function()
        local csv = "0,BoneStab,100,200,60,0,120,0\n0,EndAttack,,\n"
        local events = AttackParser.parseCSV(csv)
        local analysis = AttackParser.analyzeAttack(events)
        assert_true(not analysis.isReady)
        assert_true(analysis.notImplemented["BoneStab"])
    end)
end)
