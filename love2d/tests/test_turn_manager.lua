local TurnManager = require("src.systems.turn_manager")

describe("TurnManager", function()
    it("starts before the first turn and advances to it", function()
        local tm = TurnManager.new()
        assert_eq(tm:currentTurn(), 0)
        local t = tm:advance()
        assert_eq(tm:currentTurn(), 1)
        assert_eq(t.attack, "sans_intro")
    end)

    it("returns each turn's attack in script order", function()
        local tm = TurnManager.new()
        tm:advance()
        local t2 = tm:advance()
        assert_eq(t2.attack, "sans_bonegap1")
        assert_eq(t2.dialogue:find("sins") ~= nil, true)
    end)

    it("flags the spare offer and final turns by event", function()
        local tm = TurnManager.new()
        local spare, final
        for _ = 1, 25 do
            local t = tm:advance()
            if t and t.event == "spare_offer" then spare = t end
            if t and t.event == "final" then final = t end
        end
        assert_eq(spare.attack, "sans_spare")
        assert_eq(final.attack, "sans_final")
    end)

    it("reports finished after the last turn", function()
        local tm = TurnManager.new()
        for _ = 1, 25 do tm:advance() end
        assert_true(tm:isLastTurn())
        assert_true(tm:advance() == nil)
    end)

    it("the intro turn has no player menu before it", function()
        local tm = TurnManager.new()
        local t = tm:advance()
        assert_true(tm:isIntro(t))
    end)
end)
