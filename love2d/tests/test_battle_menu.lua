local BattleMenu = require("src.ui.battle_menu")

describe("BattleMenu", function()
    it("moves selection left/right across 4 buttons, clamped", function()
        local m = BattleMenu.new()
        assert_eq(m.selected, 1)
        m:move(1); assert_eq(m.selected, 2)
        m:move(1); m:move(1); m:move(1); assert_eq(m.selected, 4) -- clamped
        m:move(-1); assert_eq(m.selected, 3)
    end)

    it("confirm opens the matching sub-menu; cancel closes it", function()
        local m = BattleMenu.new()
        m:confirm()
        assert_eq(m.level, "fight")
        m:cancel()
        assert_eq(m.level, "root")
    end)

    it("ACT/Check yields the check description action", function()
        local m = BattleMenu.new()
        m.selected = 2
        m:confirm()
        local action = m:confirm()
        assert_eq(action.kind, "act_check")
    end)

    it("MERCY exposes Spare and Flee", function()
        local m = BattleMenu.new()
        m.selected = 4
        m:confirm()
        assert_eq(m.level, "mercy")
        local a = m:confirm()
        assert_eq(a.kind, "spare")
    end)
end)
