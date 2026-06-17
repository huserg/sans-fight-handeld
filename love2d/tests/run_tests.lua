-- Minimal headless test runner.
-- Usage from love2d/: lua5.4 tests/run_tests.lua

package.path = "./?.lua;" .. package.path

local suites = {
    "tests.test_attack_vm",
    "tests.test_attack_parser",
    "tests.test_attack_sequencer",
    "tests.test_turn_manager",
    "tests.test_damage_number",
    "tests.test_battle_menu",
    "tests.test_karma",
    "tests.test_bone_color",
}

local passed, failed = 0, 0
local currentSuite = "?"

function describe(name, fn)
    currentSuite = name
    fn()
end

function it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL [%s] %s\n     %s", currentSuite, name, tostring(err)))
    end
end

function assert_eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            label or "assert_eq", tostring(expected), tostring(actual)), 2)
    end
end

function assert_near(actual, expected, epsilon, label)
    if math.abs(actual - expected) > (epsilon or 1e-9) then
        error(string.format("%s: expected %s +/- %s, got %s",
            label or "assert_near", tostring(expected), tostring(epsilon), tostring(actual)), 2)
    end
end

function assert_true(value, label)
    if not value then
        error(string.format("%s: expected truthy, got %s", label or "assert_true", tostring(value)), 2)
    end
end

for _, suite in ipairs(suites) do
    local ok, err = pcall(require, suite)
    if not ok then
        failed = failed + 1
        print(string.format("FAIL loading %s\n     %s", suite, tostring(err)))
    end
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
