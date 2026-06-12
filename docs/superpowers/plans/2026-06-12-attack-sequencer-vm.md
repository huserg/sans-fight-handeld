# Attack Sequencer VM Implementation Plan (Plan 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the attack sequencer execute the CSV programming layer (variables, labels, jumps, math, GetHeartPos) with correct delay-based timing, so VM-based attacks like sans_bonegap2 and sans_randomblaster1 become playable.

**Architecture:** A new pure-Lua `AttackVM` module owns variables, `$` substitution and opcodes; the parser preserves CSV line numbers and collects labels; the sequencer is rewritten from absolute-time event polling to a program counter with per-line delays, delegating opcodes to the VM. Headless unit tests run with plain `lua5.4` using stubs for LÖVE-dependent modules.

**Tech Stack:** Love2D 11.4 (LuaJIT) for the game, plain Lua 5.4 for headless tests (no framework, minimal custom runner).

**Spec:** `docs/superpowers/specs/2026-06-12-battle-menu-fight-sequence-design.md` (Revision 1 section)

**Prerequisite:** `lua5.4` must be installed (`sudo apt-get install -y lua5.4`). All test commands run from `love2d/`.

**Key semantics (verified against `Documentation/Jumps.md`, `Math.md`, `Combat.md` and the CSVs):**
- Column 1 is a delay in seconds relative to the previous executed line (NOT absolute time).
- Absolute jump targets are 1-based CSV line numbers, or label names written without `:`.
- `JMPREL,N` means `pc = pc + N`.
- Any parameter may be `$Var` (read of variable Var, default 0 when unset). The first parameter of math opcodes and both parameters of GetHeartPos are variable NAMES (raw, no `$`).
- A label line (`:Name` in column 2) is a no-op but its delay is respected.
- `RND,Var,N` stores a uniform integer in [0, N-1].
- SIN/COS take degrees. `ANGLE,Var,X1,Y1,X2,Y2` stores the angle in degrees from point 1 to point 2.
- `TLPause` stops both the clock and execution. `CombatZoneResize(..., "TLResume")` resumes the timeline when the resize animation completes (`combatZone:isResizing()` becomes false).

---

### Task 1: Headless test harness and LÖVE stubs

**Files:**
- Create: `love2d/tests/run_tests.lua`
- Create: `love2d/tests/stubs.lua`

- [ ] **Step 1: Write the test runner**

`love2d/tests/run_tests.lua`:

```lua
-- Minimal headless test runner.
-- Usage from love2d/: lua5.4 tests/run_tests.lua

package.path = "./?.lua;" .. package.path

local suites = {
    "tests.test_attack_vm",
    "tests.test_attack_parser",
    "tests.test_attack_sequencer",
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
```

- [ ] **Step 2: Write the LÖVE stubs**

`love2d/tests/stubs.lua`:

```lua
-- Fake implementations of LÖVE-dependent modules so systems under test
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
```

- [ ] **Step 3: Run the runner to verify it reports missing suites**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `FAIL loading tests.test_attack_vm` (and the two others), `0 passed, 3 failed`, exit code 1.

- [ ] **Step 4: Commit**

```bash
git add love2d/tests/run_tests.lua love2d/tests/stubs.lua
git commit -m "Add headless test runner and LOVE stubs"
```

---

### Task 2: AttackVM module — variables and math opcodes

**Files:**
- Create: `love2d/src/systems/attack_vm.lua`
- Create: `love2d/tests/test_attack_vm.lua`

- [ ] **Step 1: Write the failing tests**

`love2d/tests/test_attack_vm.lua`:

```lua
local AttackVM = require("src.systems.attack_vm")

describe("AttackVM variables and math", function()
    it("SET stores a value and $ resolves it", function()
        local vm = AttackVM.new()
        vm:execute("SET", { "Speed", 200 })
        assert_eq(vm:resolve("$Speed"), 200)
    end)

    it("resolve passes plain values through", function()
        local vm = AttackVM.new()
        assert_eq(vm:resolve(42), 42)
        assert_eq(vm:resolve("hello"), "hello")
    end)

    it("unset variables resolve to 0", function()
        local vm = AttackVM.new()
        assert_eq(vm:resolve("$Nothing"), 0)
    end)

    it("SET copies another variable through $", function()
        local vm = AttackVM.new()
        vm:execute("SET", { "A", 7 })
        vm:execute("SET", { "B", "$A" })
        assert_eq(vm:resolve("$B"), 7)
    end)

    it("ADD SUB MUL DIV MOD compute and store", function()
        local vm = AttackVM.new()
        vm:execute("ADD", { "R", 2, 3 })
        assert_eq(vm:resolve("$R"), 5)
        vm:execute("SUB", { "R", "$R", 1 })
        assert_eq(vm:resolve("$R"), 4)
        vm:execute("MUL", { "R", "$R", 3 })
        assert_eq(vm:resolve("$R"), 12)
        vm:execute("DIV", { "R", "$R", 5 })
        assert_near(vm:resolve("$R"), 2.4)
        vm:execute("MOD", { "R", 7, 3 })
        assert_eq(vm:resolve("$R"), 1)
    end)

    it("FLOOR truncates down", function()
        local vm = AttackVM.new()
        vm:execute("FLOOR", { "F", 3.9 })
        assert_eq(vm:resolve("$F"), 3)
    end)

    it("DEG and RAD convert angles", function()
        local vm = AttackVM.new()
        vm:execute("RAD", { "R", 180 })
        assert_near(vm:resolve("$R"), math.pi)
        vm:execute("DEG", { "D", math.pi })
        assert_near(vm:resolve("$D"), 180)
    end)

    it("SIN and COS take degrees", function()
        local vm = AttackVM.new()
        vm:execute("SIN", { "S", 90 })
        assert_near(vm:resolve("$S"), 1)
        vm:execute("COS", { "C", 0 })
        assert_near(vm:resolve("$C"), 1)
    end)

    it("ANGLE stores degrees from point 1 to point 2", function()
        local vm = AttackVM.new()
        vm:execute("ANGLE", { "A", 0, 0, 10, 0 })
        assert_near(vm:resolve("$A"), 0)
        vm:execute("ANGLE", { "A", 0, 0, 0, 10 })
        assert_near(vm:resolve("$A"), 90)
        vm:execute("ANGLE", { "A", 5, 5, 0, 5 })
        assert_near(math.abs(vm:resolve("$A")), 180)
    end)

    it("RND stays within 0 to n-1", function()
        local vm = AttackVM.new()
        for _ = 1, 100 do
            vm:execute("RND", { "V", 4 })
            local v = vm:resolve("$V")
            assert_true(v >= 0 and v <= 3 and v == math.floor(v), "RND range")
        end
    end)

    it("isOp recognizes opcodes and rejects commands", function()
        local vm = AttackVM.new()
        assert_true(vm:isOp("ADD"))
        assert_true(vm:isOp("JMPABS"))
        assert_true(not vm:isOp("BoneV"))
        assert_true(not vm:isOp("EndAttack"))
    end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `FAIL loading tests.test_attack_vm` with "module 'src.systems.attack_vm' not found". The other two suites also fail to load (their files come in later tasks).

- [ ] **Step 3: Write the AttackVM module (math part + jump part skeleton)**

`love2d/src/systems/attack_vm.lua`:

```lua
-- Attack VM
-- Executes the programming layer of attack CSV files: named variables
-- (read back with the $ prefix), math opcodes, and jump opcodes.
-- Pure Lua on purpose: no LOVE dependency, fully unit-testable.

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local AttackVM = {}
AttackVM.__index = AttackVM

function AttackVM.new()
    local self = setmetatable({}, AttackVM)
    self.vars = {}
    return self
end

-- "$Name" reads variable Name (0 when unset); anything else passes through
function AttackVM:resolve(param)
    if type(param) == "string" and param:sub(1, 1) == "$" then
        local value = self.vars[param:sub(2)]
        if value == nil then
            return 0
        end
        return value
    end
    return param
end

function AttackVM:num(param)
    return tonumber(self:resolve(param)) or 0
end

local function jumpAbs(target) return { type = "abs", target = target } end
local function jumpRel(offset) return { type = "rel", offset = offset } end

-- Math opcodes store into the variable named by raw params[1].
-- Jump opcodes return a descriptor consumed by the sequencer (nil = no jump).
local ops = {}

ops["SET"] = function(self, p) self.vars[p[1]] = self:resolve(p[2]) end
ops["ADD"] = function(self, p) self.vars[p[1]] = self:num(p[2]) + self:num(p[3]) end
ops["SUB"] = function(self, p) self.vars[p[1]] = self:num(p[2]) - self:num(p[3]) end
ops["MUL"] = function(self, p) self.vars[p[1]] = self:num(p[2]) * self:num(p[3]) end
ops["DIV"] = function(self, p) self.vars[p[1]] = self:num(p[2]) / self:num(p[3]) end
ops["MOD"] = function(self, p) self.vars[p[1]] = self:num(p[2]) % self:num(p[3]) end
ops["FLOOR"] = function(self, p) self.vars[p[1]] = math.floor(self:num(p[2])) end
ops["DEG"] = function(self, p) self.vars[p[1]] = math.deg(self:num(p[2])) end
ops["RAD"] = function(self, p) self.vars[p[1]] = math.rad(self:num(p[2])) end
ops["SIN"] = function(self, p) self.vars[p[1]] = math.sin(math.rad(self:num(p[2]))) end
ops["COS"] = function(self, p) self.vars[p[1]] = math.cos(math.rad(self:num(p[2]))) end

ops["ANGLE"] = function(self, p)
    local x1, y1 = self:num(p[2]), self:num(p[3])
    local x2, y2 = self:num(p[4]), self:num(p[5])
    self.vars[p[1]] = math.deg(atan2(y2 - y1, x2 - x1))
end

ops["RND"] = function(self, p)
    self.vars[p[1]] = math.random(0, math.max(0, self:num(p[2]) - 1))
end

ops["JMPABS"] = function(self, p) return jumpAbs(self:resolve(p[1])) end
ops["JMPREL"] = function(self, p) return jumpRel(self:num(p[1])) end

ops["JMPZ"] = function(self, p)
    if self:num(p[2]) == 0 then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNZ"] = function(self, p)
    if self:num(p[2]) ~= 0 then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPE"] = function(self, p)
    if self:num(p[2]) == self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNE"] = function(self, p)
    if self:num(p[2]) ~= self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPL"] = function(self, p)
    if self:num(p[2]) < self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNL"] = function(self, p)
    if self:num(p[2]) >= self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPG"] = function(self, p)
    if self:num(p[2]) > self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

ops["JMPNG"] = function(self, p)
    if self:num(p[2]) <= self:num(p[3]) then return jumpAbs(self:resolve(p[1])) end
end

function AttackVM:isOp(command)
    return ops[command] ~= nil
end

function AttackVM:execute(command, params)
    return ops[command](self, params)
end

return AttackVM
```

- [ ] **Step 4: Run tests to verify the VM suite passes**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: all `test_attack_vm` tests pass; only the parser and sequencer suites fail to load. Output ends with `11 passed, 2 failed`.

- [ ] **Step 5: Commit**

```bash
git add love2d/src/systems/attack_vm.lua love2d/tests/test_attack_vm.lua
git commit -m "Add attack VM with variables, math and jump opcodes"
```

---

### Task 3: AttackVM jump opcode tests

**Files:**
- Modify: `love2d/tests/test_attack_vm.lua` (append a describe block)

The jump opcodes were implemented in Task 2 (one table, one commit); this task locks their truth table with tests.

- [ ] **Step 1: Append the failing-if-wrong tests**

Append to `love2d/tests/test_attack_vm.lua`:

```lua
describe("AttackVM jumps", function()
    it("JMPABS returns an absolute jump with label or number target", function()
        local vm = AttackVM.new()
        local jump = vm:execute("JMPABS", { "StartLoop" })
        assert_eq(jump.type, "abs")
        assert_eq(jump.target, "StartLoop")
        jump = vm:execute("JMPABS", { 6 })
        assert_eq(jump.target, 6)
    end)

    it("JMPABS resolves $var targets", function()
        local vm = AttackVM.new()
        vm:execute("SET", { "Where", 14 })
        local jump = vm:execute("JMPABS", { "$Where" })
        assert_eq(jump.target, 14)
    end)

    it("JMPREL returns a relative offset, $var allowed", function()
        local vm = AttackVM.new()
        local jump = vm:execute("JMPREL", { 4 })
        assert_eq(jump.type, "rel")
        assert_eq(jump.offset, 4)
        vm:execute("SET", { "Jump", -3 })
        jump = vm:execute("JMPREL", { "$Jump" })
        assert_eq(jump.offset, -3)
    end)

    it("JMPZ jumps only when the value is zero", function()
        local vm = AttackVM.new()
        assert_true(vm:execute("JMPZ", { "End", 0 }) ~= nil)
        assert_true(vm:execute("JMPZ", { "End", 5 }) == nil)
    end)

    it("JMPNZ jumps only when the value is not zero", function()
        local vm = AttackVM.new()
        assert_true(vm:execute("JMPNZ", { "End", 5 }) ~= nil)
        assert_true(vm:execute("JMPNZ", { "End", 0 }) == nil)
    end)

    it("JMPE and JMPNE compare two values", function()
        local vm = AttackVM.new()
        assert_true(vm:execute("JMPE", { 10, 3, 3 }) ~= nil)
        assert_true(vm:execute("JMPE", { 10, 3, 4 }) == nil)
        assert_true(vm:execute("JMPNE", { 10, 3, 4 }) ~= nil)
        assert_true(vm:execute("JMPNE", { 10, 3, 3 }) == nil)
    end)

    it("JMPL JMPNL JMPG JMPNG ordering comparisons", function()
        local vm = AttackVM.new()
        assert_true(vm:execute("JMPL", { 10, 1, 2 }) ~= nil)
        assert_true(vm:execute("JMPL", { 10, 2, 2 }) == nil)
        assert_true(vm:execute("JMPNL", { 10, 2, 2 }) ~= nil)
        assert_true(vm:execute("JMPNL", { 10, 1, 2 }) == nil)
        assert_true(vm:execute("JMPG", { 10, 3, 2 }) ~= nil)
        assert_true(vm:execute("JMPG", { 10, 2, 2 }) == nil)
        assert_true(vm:execute("JMPNG", { 10, 2, 2 }) ~= nil)
        assert_true(vm:execute("JMPNG", { 10, 3, 2 }) == nil)
    end)
end)
```

- [ ] **Step 2: Run tests**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `18 passed, 2 failed` (the 2 failures are still the missing parser/sequencer suites).

- [ ] **Step 3: Commit**

```bash
git add love2d/tests/test_attack_vm.lua
git commit -m "Add jump opcode truth-table tests"
```

---

### Task 4: Parser — preserve line numbers, collect labels, honest status lists

**Files:**
- Modify: `love2d/src/systems/attack_parser.lua`
- Create: `love2d/tests/test_attack_parser.lua`

Jump targets are 1-based CSV line numbers, so every physical line must become exactly one event (malformed/empty lines become NOP placeholders). The implemented/not-implemented command lists are also wrong today (Sound, GasterBlaster, BlackScreen, SansText ARE handled) — fix them so the Single Attack menu status indicators tell the truth.

- [ ] **Step 1: Write the failing tests**

`love2d/tests/test_attack_parser.lua`:

```lua
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
        local csv = "0,Platform,100,200,60,0,120,0\n0,EndAttack,,\n"
        local events = AttackParser.parseCSV(csv)
        local analysis = AttackParser.analyzeAttack(events)
        assert_true(not analysis.isReady)
        assert_true(analysis.notImplemented["Platform"])
    end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: parser suite fails (`parseCSV` returns no labels, skips empty lines, wrong status lists). VM suite still green.

- [ ] **Step 3: Update the parser**

In `love2d/src/systems/attack_parser.lua`, replace the two command lists at the top:

```lua
-- Commands the sequencer executes (keep in sync with attack_sequencer.lua
-- handlers and attack_vm.lua opcodes; labels/:Name and NOP are intrinsic)
AttackParser.implementedCommands = {
    "EndAttack",
    "HeartMode",
    "HeartTeleport",
    "CombatZoneResize",
    "CombatZoneResizeInstant",
    "TLPause",
    "TLResume",
    "BoneV",
    "BoneH",
    "BoneVRepeat",
    "BoneHRepeat",
    "GasterBlaster",
    "Sound",
    "BlackScreen",
    "SansText",
    "GetHeartPos",
    -- VM opcodes
    "SET", "ADD", "SUB", "MUL", "DIV", "MOD", "FLOOR",
    "DEG", "RAD", "SIN", "COS", "ANGLE", "RND",
    "JMPABS", "JMPREL", "JMPZ", "JMPNZ",
    "JMPE", "JMPNE", "JMPL", "JMPNL", "JMPG", "JMPNG",
}

-- Commands that still need implementation (Plans 2 and 3)
AttackParser.notImplementedCommands = {
    "SansAnimation",
    "SansHead",
    "SansBody",
    "SansTorso",
    "SansSweat",
    "SansX",
    "SansRepeat",
    "SansEndRepeat",
    "SansSlam",
    "SansSlamDamage",
    "HeartMaxFallSpeed",
    "CombatZoneSpeed",
    "BoneStab",
    "SineBones",
    "Platform",
    "PlatformRepeat",
    "BlueStop",
}
```

Replace `parseCSV` with a line-preserving version that also returns labels:

```lua
function AttackParser.parseCSV(content)
    local events = {}
    local labels = {}

    -- One event per physical line: absolute jump targets are line numbers
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local event = AttackParser.parseLine(line)
            or { time = 0, command = "NOP", params = {} }
        table.insert(events, event)

        if event.command:sub(1, 1) == ":" then
            labels[event.command:sub(2)] = #events
        end
    end

    -- Trailing blank lines would add dead frames after EndAttack
    while #events > 0 and events[#events].command == "NOP" do
        table.remove(events, #events)
    end

    return events, labels
end
```

In `analyzeAttack`, skip intrinsic no-ops when collecting used commands — replace the first loop:

```lua
    for _, event in ipairs(events) do
        local cmd = event.command
        if cmd ~= "NOP" and cmd:sub(1, 1) ~= ":" then
            usedCommands[cmd] = true
        end
    end
```

In `loadFromFile`, forward the labels:

```lua
function AttackParser.loadFromFile(path)
    local content = love.filesystem.read(path)
    if not content then
        print("Failed to load attack file: " .. path)
        return nil
    end
    return AttackParser.parseCSV(content)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `24 passed, 1 failed` (only the sequencer suite is still missing).

- [ ] **Step 5: Commit**

```bash
git add love2d/src/systems/attack_parser.lua love2d/tests/test_attack_parser.lua
git commit -m "Preserve CSV line numbers and labels in attack parser"
```

---

### Task 5: Sequencer — delay-based program counter execution

**Files:**
- Modify: `love2d/src/systems/attack_sequencer.lua`
- Create: `love2d/tests/test_attack_sequencer.lua`

This replaces the absolute-time model (`event.time <= self.timer`) with: wait `event.time` seconds after the previous executed line, then execute. This fixes the timing of ALL existing attacks (times decrease mid-file in sans_bluebone, sans_boneslideh, etc.).

- [ ] **Step 1: Write the failing tests**

`love2d/tests/test_attack_sequencer.lua`:

```lua
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: sequencer suite errors — `loadProgram` does not exist yet.

- [ ] **Step 3: Rewrite the sequencer execution core**

In `love2d/src/systems/attack_sequencer.lua`:

Add the require at the top (after the existing ones):

```lua
local AttackVM = require("src.systems.attack_vm")
```

Add above `AttackSequencer.new`:

```lua
-- Safety net against malformed CSV programs (0-delay infinite loops)
local MAX_LINES_PER_FRAME = 2000
```

Replace the body of `AttackSequencer.new` state initialization (keep `self.battle`, `self.handlers`, `self:registerHandlers()`):

```lua
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
```

Replace `loadAttack` and add `loadProgram`:

```lua
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
```

Replace `update` and `executeEvent`, and add `applyJump`, `resolveParams` and `checkPendingResume` (delete the old `while self.currentIndex <= #self.events` loop entirely):

```lua
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
        return
    end

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

-- Handlers receive concrete values: $vars substituted, empty cells removed
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
```

In `registerHandlers`, replace the `CombatZoneResize` handler (deferred TLResume instead of instant):

```lua
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
```

Also delete the now-unused fields/methods from the old model: remove `self.pendingEvents` and the `start` method if nothing references it (`grep -rn "sequencer:start\|pendingEvents" love2d/src` must come back empty first).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: all suites pass. `28 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add love2d/src/systems/attack_sequencer.lua love2d/tests/test_attack_sequencer.lua
git commit -m "Rewrite sequencer with delay-based program counter execution"
```

---

### Task 6: Sequencer — VM program flow, $ params and GetHeartPos

**Files:**
- Modify: `love2d/src/systems/attack_sequencer.lua` (one handler)
- Modify: `love2d/tests/test_attack_sequencer.lua` (append tests)

- [ ] **Step 1: Append the failing tests**

Append to `love2d/tests/test_attack_sequencer.lua`:

```lua
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
            "0,EndAttack,,\n")
        battle.playerHeart.x = 123
        battle.playerHeart.y = 456
        sequencer:update(0.016)
        assert_eq(battle.sansTexts[1], 123)
    end)
end)
```

- [ ] **Step 2: Run tests to verify only GetHeartPos fails**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: the first four new tests pass already (Task 5 built the machinery); `GetHeartPos stores...` fails with "Unknown attack command: GetHeartPos". If any of the first four fails, fix Task 5 before continuing.

- [ ] **Step 3: Add the GetHeartPos handler**

GetHeartPos params are variable NAMES, so it must bypass `resolveParams`. Register it in `registerHandlers` and special-case it in `executeEvent`.

In `registerHandlers`, add after the `SansText` handler:

```lua
    -- Stores the heart position into two variables (raw names, no $)
    self.rawHandlers = self.rawHandlers or {}
    self.rawHandlers["GetHeartPos"] = function(params)
        local heart = self.battle.playerHeart
        if heart and params[1] and params[2] then
            self.vm.vars[params[1]] = heart.x
            self.vm.vars[params[2]] = heart.y
        end
    end
```

In `executeEvent`, add the raw-handler lookup between the VM-op branch and the regular-handler lookup:

```lua
    local rawHandler = self.rawHandlers and self.rawHandlers[command]
    if rawHandler then
        rawHandler(event.params)
        self.pc = self.pc + 1
        return
    end
```

- [ ] **Step 4: Run tests to verify everything passes**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `33 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add love2d/src/systems/attack_sequencer.lua love2d/tests/test_attack_sequencer.lua
git commit -m "Add GetHeartPos and VM program flow tests to sequencer"
```

---

### Task 7: Integration tests against the real attack CSVs

**Files:**
- Modify: `love2d/tests/test_attack_sequencer.lua` (append a describe block)

- [ ] **Step 1: Append the failing-if-wrong tests**

Append to `love2d/tests/test_attack_sequencer.lua`:

```lua
describe("Real attack files", function()
    it("VM-based attacks now report ready status", function()
        -- Run from love2d/ so attacks/ resolves
        assert_eq(AttackParser.getAttackStatus("sans_bonegap2"), "ready")
        assert_eq(AttackParser.getAttackStatus("sans_randomblaster1"), "ready")
        assert_eq(AttackParser.getAttackStatus("sans_multi1"), "ready")
    end)

    it("attacks needing Plan 2 entities stay partial", function()
        assert_eq(AttackParser.getAttackStatus("sans_platforms1"), "partial")
        assert_eq(AttackParser.getAttackStatus("sans_bonestab1"), "partial")
    end)

    it("sans_bonegap2 runs to completion without unknown commands", function()
        local battle = Stubs.makeBattle()
        local sequencer = AttackSequencer.new(battle)
        assert_true(sequencer:loadAttack("sans_bonegap2"), "load")

        battle.combatZone.resizing = false
        local elapsed = 0
        while not sequencer:isFinished() and elapsed < 120 do
            sequencer:update(0.016)
            elapsed = elapsed + 0.016
        end
        assert_true(sequencer:isFinished(), "attack ended within 120s")
        assert_true(#Stubs.FakeBone.spawned > 0, "bones were spawned")
    end)
end)
```

- [ ] **Step 2: Run tests**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `36 passed, 0 failed`. If `sans_bonegap2 runs to completion` loops forever or reports unknown commands, debug with the systematic-debugging skill — do NOT relax the assertions.

- [ ] **Step 3: Commit**

```bash
git add love2d/tests/test_attack_sequencer.lua
git commit -m "Add integration tests running real attack programs"
```

---

### Task 8: In-game smoke test, changelog, wrap-up

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Full test suite green**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: `36 passed, 0 failed`.

- [ ] **Step 2: Manual smoke test (requires a machine with LÖVE installed — ask the user if love is not on PATH)**

Run the game (`love love2d` or the user's usual Windows launcher), then:
1. Main menu → Single attack mode → pick `sans_bonegap2`. Expected: bones spawn in randomized waves with varying gap heights, attack ends and returns to menu.
2. Pick `sans_randomblaster1`. Expected: Gaster Blasters aim near the heart position.
3. Pick `sans_bluebone`. Expected: timing feels staggered (bones no longer all spawn at once — delay model fix).
Report any anomaly to the user before continuing; this validates the delay-semantics rewrite against reality.

- [ ] **Step 3: Update CHANGELOG.md**

Add at the top of the file, under the header:

```markdown
## [2.1.0] - Unreleased

### Added (Attack VM)
- Attack CSV virtual machine: variables ($Name), labels, 10 jump opcodes,
  13 math opcodes, GetHeartPos
- `src/systems/attack_vm.lua` - Pure-Lua VM module
- Headless test suite (`love2d/tests/`, run with `lua5.4 tests/run_tests.lua`)

### Fixed
- Attack timing: the CSV time column is now treated as a relative delay
  (previously absolute, which broke multi-wave attacks)
- TLPause now blocks execution; TLResume fires when the combat zone
  resize completes instead of instantly
- Attack status indicators now reflect actually implemented commands

### Unlocked Attacks
- sans_bonegap2, sans_multi1, sans_randomblaster1, sans_randomblaster2
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "Update changelog for attack VM"
```

(The `v2.1.0` tag is created after Plan 3 completes, when Unreleased becomes a release.)

---

## Self-review notes

- Spec coverage: Revision 1 items all mapped — delay model (Task 5), TLPause/TLResume (Task 5), VM variables/math (Task 2), jumps/labels (Tasks 3-4), GetHeartPos (Task 6), honest status lists (Task 4). The BoneV/HRepeat Count/Spacing fix is deliberately Plan 2 (entity behavior, not VM).
- Type consistency: `parseCSV` returns `(events, labels)`; `loadFromFile` forwards both; `loadProgram(events, labels)` consumes them. Jump descriptors `{type="abs"|"rel", target|offset}` produced by attack_vm and consumed by `applyJump`.
- `math.atan2` does not exist in Lua 5.3+/5.4 (tests) but exists in LuaJIT (game): handled by the `atan2` fallback local in attack_vm.lua.
