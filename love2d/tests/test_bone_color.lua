-- Tests for the bone color motion gating helper (R6).
-- Rule (Battle.xml 8028-8106): bullet Color 0=white, 1=blue, 2=orange.
--   white  (0): always damages.
--   blue   (1): damages only when the soul IS moving.
--   orange (2): damages only when the soul is NOT moving.

local shouldDamage = require("src.systems.bone_color")

describe("bone_color.shouldDamage", function()
    it("white always damages while moving", function()
        assert_eq(shouldDamage(0, true), true, "white moving")
    end)

    it("white always damages while still", function()
        assert_eq(shouldDamage(0, false), true, "white still")
    end)

    it("blue damages while moving", function()
        assert_eq(shouldDamage(1, true), true, "blue moving")
    end)

    it("blue does not damage while still", function()
        assert_eq(shouldDamage(1, false), false, "blue still")
    end)

    it("orange does not damage while moving", function()
        assert_eq(shouldDamage(2, true), false, "orange moving")
    end)

    it("orange damages while still", function()
        assert_eq(shouldDamage(2, false), true, "orange still")
    end)
end)
