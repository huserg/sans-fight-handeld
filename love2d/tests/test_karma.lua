-- Tests for the pure KR/karma model (src/systems/karma.lua).
-- Mirrors the original Sans-fight behaviour decoded from Battle.xml.

local Karma = require("src.systems.karma")

describe("Karma contact hits", function()
    it("adds damage to HP loss and karma to KR with no i-frames", function()
        local k = Karma.new(50)
        k:hit(1, 6)
        assert_eq(k.hp, 49, "hp dropped by damage")
        assert_eq(k.kr, 6, "kr rose by karma")
        k:hit(1, 6)
        assert_eq(k.hp, 48, "second consecutive hit lands (no i-frames)")
        assert_eq(k.kr, 12)
    end)
end)

describe("Karma per-frame clamps", function()
    it("caps KR at 40", function()
        local k = Karma.new(92)
        k.kr = 60
        k:update(0)
        assert_eq(k.kr, 40, "KR capped to 40")
    end)

    it("clamps KR to HP-1 so karma never kills", function()
        local k = Karma.new(20)
        k.kr = 40
        k:update(0)
        assert_eq(k.kr, 19, "KR clamped to HP-1")
        assert_eq(k.hp, 20, "HP untouched by the clamp")
    end)
end)

describe("Karma drain inertia", function()
    it("drains 1 KR and 1 HP at the 0.033s tier when KR >= 40", function()
        local k = Karma.new(92)
        k.kr = 40
        local lost = k:update(0.033)
        assert_eq(lost, 1, "one HP lost this frame")
        assert_eq(k.kr, 39, "one KR drained")
        assert_eq(k.hp, 91, "one HP drained")
    end)

    it("does not drain before the tier time elapses", function()
        local k = Karma.new(92)
        k.kr = 40
        local lost = k:update(0.02)
        assert_eq(lost, 0, "below 0.033s, no drain yet")
        assert_eq(k.kr, 40)
        assert_eq(k.hp, 92)
    end)

    it("drains slowly at low KR (KR=5 needs ~1.0s)", function()
        local k = Karma.new(92)
        k.kr = 5
        -- Below 1.0s accumulated: no drain.
        assert_eq(k:update(0.5), 0, "0.5s not enough for KR=5")
        assert_eq(k:update(0.4), 0, "0.9s still not enough")
        -- Crossing 1.0s: one drain fires.
        assert_eq(k:update(0.1), 1, "1.0s reached, drain fires")
        assert_eq(k.kr, 4)
        assert_eq(k.hp, 91)
    end)

    it("does not drain when HP <= 1", function()
        local k = Karma.new(1)
        k.kr = 0  -- clamp would force kr to 0 anyway at hp=1
        local lost = k:update(1.0)
        assert_eq(lost, 0, "no drain at 1 HP")
        assert_eq(k.hp, 1, "HP never drops below 1 via drain")
    end)

    it("stops draining once KR reaches 0", function()
        local k = Karma.new(92)
        k.kr = 1
        assert_eq(k:update(1.0), 1, "last KR drains")
        assert_eq(k.kr, 0)
        assert_eq(k:update(1.0), 0, "no further drain with KR=0")
        assert_eq(k.hp, 91, "HP unchanged after KR exhausted")
    end)
end)
