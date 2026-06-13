# Full Fight Sequence (Turn-Based Normal Mode) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Love2D port's Normal/Practice mode into the full turn-based Sans fight: intro, then for each turn a player menu (FIGHT/ACT/ITEM/MERCY), Sans dialogue, and the next scripted attack — through all 25 turns, with damage numbers and the three endings.

**Architecture:** A phase machine lives inside `battle.lua`. `battle:setPhase(name)` swaps small phase modules (`player_turn`, `action_resolve`, `sans_dialogue`, `attack`), each with `enter(battle)/update(dt)/draw()/keypressed(key)`. A `turn_manager` walks an ordered `fight_script` and decides the next phase. Single/Endless modes never enter the turn phases (current behavior kept). New UI: `battle_menu` (4-button nav + sub-menus) and `damage_number`.

**Tech Stack:** Love2D 11.x (LuaJIT) for the game; plain Lua 5.4 for headless tests (existing `love2d/tests/` runner). The autopilot harness (`SANS_AUTOPILOT*` env, `love2d/tools/autopilot.lua`) is used for visual verification.

**Spec:** `docs/superpowers/specs/2026-06-12-battle-menu-fight-sequence-design.md` (this is Plan 3; the VM and entity/command plans are already implemented and merged).

**Prerequisites already in place:** all 24 attack CSVs run (`lua5.4 tests/run_tests.lua` → 41 passed), `dialogue.lua` (typewriter), `hp_bar.lua`, `battle_ui.lua`, Constants (MODE_NORMAL=0, MODE_ENDLESS=1, MODE_SINGLE=2, MODE_PRACTICE=3), sprites `target`/`targetchoice`/`strike`/`menuitem`/`speechbubble`/`heartshard`.

**Conventions:** comments in English, no emoji, no inline duplication; follow existing module patterns. Run all test commands from `love2d/`. Commit after each task.

**Before writing code touching an existing module, the implementer must read it** (`dialogue.lua`, `hp_bar.lua`, `battle_ui.lua`, `battle.lua`, `player_heart.lua`, `fonts.lua`, `audio.lua`) to use its real API. Where this plan calls a method on an existing module, verify the exact name/signature in that module first.

---

### Task 1: Fight script data + turn manager

**Files:**
- Create: `love2d/src/data/fight_script.lua`
- Create: `love2d/src/systems/turn_manager.lua`
- Create: `love2d/tests/test_turn_manager.lua`

The fight script is pure data: the ordered turns. The turn manager is pure logic (no LÖVE) so it is headless-testable: given a current turn index it reports the attack, dialogue and event, and advances.

- [ ] **Step 1: Write `fight_script.lua`** (attack order from the spec; dialogue uses the real narration lines, empty string when a turn has none)

```lua
-- Ordered fight script: one entry per turn.
-- event: nil | "spare_offer" | "final"
return {
    { attack = "sans_intro",            dialogue = "" },
    { attack = "sans_bonegap1",         dialogue = "* You felt your sins crawling\n  on your back." },
    { attack = "sans_bluebone",         dialogue = "" },
    { attack = "sans_bonegap2",         dialogue = "" },
    { attack = "sans_platforms1",       dialogue = "" },
    { attack = "sans_platforms2",       dialogue = "" },
    { attack = "sans_platforms3",       dialogue = "" },
    { attack = "sans_platforms4",       dialogue = "" },
    { attack = "sans_platformblaster",  dialogue = "" },
    { attack = "sans_platforms4hard",   dialogue = "" },
    { attack = "sans_bonegap1fast",     dialogue = "" },
    { attack = "sans_boneslideh",       dialogue = "" },
    { attack = "sans_bonegap2",         dialogue = "" },
    { attack = "sans_platformblasterfast", dialogue = "" },
    { attack = "sans_spare",            dialogue = "* Sans is taking a break.", event = "spare_offer" },
    { attack = "sans_multi1",           dialogue = "* The REAL battle finally begins." },
    { attack = "sans_randomblaster1",   dialogue = "" },
    { attack = "sans_multi2",           dialogue = "" },
    { attack = "sans_bonestab1",        dialogue = "" },
    { attack = "sans_bonestab2",        dialogue = "" },
    { attack = "sans_randomblaster2",   dialogue = "" },
    { attack = "sans_boneslidev",       dialogue = "" },
    { attack = "sans_multi3",           dialogue = "* Sans is starting to look\n  really tired." },
    { attack = "sans_bonestab3",        dialogue = "* Sans is preparing something." },
    { attack = "sans_final",            dialogue = "* Sans is getting ready to\n  use his special attack.", event = "final" },
}
```

- [ ] **Step 2: Write the failing test** `love2d/tests/test_turn_manager.lua`

```lua
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
        tm:advance()                 -- turn 1: intro
        local t2 = tm:advance()      -- turn 2
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
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `cd love2d && lua5.4 tests/run_tests.lua`
Expected: load failure for `tests.test_turn_manager` (module not found). Add `"tests.test_turn_manager"` to the `suites` list in `tests/run_tests.lua` first.

- [ ] **Step 4: Implement `turn_manager.lua`**

```lua
-- Turn manager: walks the ordered fight script and reports per-turn data.
-- Pure logic, no LOVE dependency.

local script = require("src.data.fight_script")

local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new()
    return setmetatable({ index = 0 }, TurnManager)
end

function TurnManager:currentTurn()
    return self.index
end

-- Advance to the next turn and return its entry, or nil past the end
function TurnManager:advance()
    if self.index >= #script then
        self.index = #script + 1
        return nil
    end
    self.index = self.index + 1
    return script[self.index]
end

function TurnManager:current()
    return script[self.index]
end

function TurnManager:isLastTurn()
    return self.index >= #script
end

-- The intro turn (turn 1) runs without a preceding player menu
function TurnManager:isIntro(turn)
    return turn ~= nil and turn.attack == "sans_intro"
end

return TurnManager
```

- [ ] **Step 5: Run tests** — Expected: all `test_turn_manager` tests pass; existing suites unchanged.

- [ ] **Step 6: Commit**

```bash
git add love2d/src/data/fight_script.lua love2d/src/systems/turn_manager.lua love2d/tests/test_turn_manager.lua love2d/tests/run_tests.lua
git commit -m "Add fight script data and turn manager"
```

---

### Task 2: Battle phase machine + extract the attack phase

Introduce `battle:setPhase(name)` and move the existing per-frame attack logic (sequencer update, entity updates, collisions, heart update, slam damage) into a new `attack` phase module, leaving `battle.lua` as the orchestrator. Single/Endless keep going straight to the attack phase; Normal/Practice will (in later tasks) route through the turn phases.

**Files:**
- Modify: `love2d/src/states/battle.lua`
- Create: `love2d/src/states/battle_phases/attack.lua`

- [ ] **Step 1: Read `battle.lua` fully** and identify the update body (sequencer update + isFinished handling, combatZone update, heart update + slam damage, sans update, updateEntities, checkCollisions, game-over check) and the draw body (sans, combat zone, clipped/unclipped entities, heart, battleUI, sansText).

- [ ] **Step 2: Add the phase machine to `battle.lua`**

In `Battle` add a `phase` field and:

```lua
function Battle:setPhase(name)
    if self.phase and self.phase.exit then self.phase:exit(self) end
    self.phaseName = name
    self.phase = self.phases[name]
    if self.phase and self.phase.enter then self.phase:enter(self) end
end
```

Register phases in `Battle:enter` (after creating sequencer/heart/etc.), before `startBattle`:

```lua
self.phases = {
    attack = require("src.states.battle_phases.attack"),
    player_turn = require("src.states.battle_phases.player_turn"),
    action_resolve = require("src.states.battle_phases.action_resolve"),
    sans_dialogue = require("src.states.battle_phases.sans_dialogue"),
}
```

(For this task only `attack` exists; add the other three requires in their tasks. To keep this task self-contained, require only `attack` now and add the rest later.)

- [ ] **Step 3: Create `battle_phases/attack.lua`** — move the gameplay update/draw here. The phase calls back into `battle` for shared objects.

```lua
-- Attack phase: runs the current attack CSV via the sequencer, updates
-- entities and collisions. On EndAttack it asks the battle what comes next.

local Audio = require("src.systems.audio")

local AttackPhase = {}

function AttackPhase:enter(battle)
    -- The attack to run was set on the battle before switching here
end

function AttackPhase:update(dt, battle)
    local game = battle.game

    if battle.sequencer then
        battle.sequencer:update(dt)
        if battle.sequencer:isFinished() then
            battle:onAttackFinished()   -- battle decides: menu (turn) or menu-exit (single)
            return
        end
    end

    battle.combatZone:update(dt)

    battle.playerHeart.platforms = battle:getPlatforms()
    battle.playerHeart:update(dt)
    if battle.playerHeart.pendingSlamDamage then
        battle.playerHeart.pendingSlamDamage = false
        if battle.playerHeart:damage(3) then
            game.hp = game.hp - 3
            Audio:playSfx("playerDamaged")
        end
    end

    battle.sans:update(dt)
    battle:updateEntities(dt)
    battle:checkCollisions(game)

    if battle.sansText and battle.sansTextTimer then
        battle.sansTextTimer = battle.sansTextTimer - dt
        if battle.sansTextTimer <= 0 then battle.sansText = nil end
    end

    battle:checkGameOver()
end

function AttackPhase:draw(battle)
    battle:drawArena()   -- sans, combat zone, clipped/unclipped entities, heart, sansText
end

return AttackPhase
```

- [ ] **Step 4: Refactor `battle.lua`** so:
  - `Battle:update(dt, game)` stores `self.game = game` then delegates: `if self.phase and self.phase.update then self.phase:update(dt, self) end`. Keep invincibility/karma timers (heart-owned) where they are, or move them into the heart update — do NOT change heart gameplay logic.
  - `Battle:draw(game)` delegates to `self.phase:draw(self)` (keep the black-screen overlay check at the top).
  - Extract the arena drawing into `Battle:drawArena()` (the sans/zone/entities/heart/sansText block that previously lived in `draw`).
  - Add `Battle:checkGameOver()` (the `if game.hp <= 0` block) and `Battle:onAttackFinished()`. For now `onAttackFinished` keeps current behavior: if `simulatorMode == MODE_SINGLE` return to menu; else (normal/endless) do nothing (turn routing comes in Task 9).
  - `startBattle` sets the chosen attack then calls `self:setPhase("attack")` instead of relying on update.

- [ ] **Step 5: Verify nothing regressed** — single-attack still works.

Run (visual): `cd love2d && SANS_AUTOPILOT=sans_bonegap2 SANS_AUTOPILOT_TIME=6 SANS_AUTOPILOT_INTERVAL=1 love .`
Expected: bones spawn, attack ends, returns to menu (a screenshot in `~/.local/share/love/sans-fight/shots/` shows the gapped bones inside the zone). Headless: `lua5.4 tests/run_tests.lua` still 41+ passed.

- [ ] **Step 6: Commit**

```bash
git add love2d/src/states/battle.lua love2d/src/states/battle_phases/attack.lua
git commit -m "Extract battle attack phase behind a phase machine"
```

---

### Task 3: Damage number component

**Files:**
- Create: `love2d/src/ui/damage_number.lua`
- Create: `love2d/tests/test_damage_number.lua`
- Create stub: `love2d/tests/stubs.lua` gains a `love.graphics` shim if needed (see Step 1).

Damage numbers float up with a small bounce above a target and disappear after ~1s. The timing/lifetime logic is headless-testable; rendering uses DamageFont.

- [ ] **Step 1: Ensure the test harness can construct a DamageNumber headlessly.** The component must not touch `love.graphics` at construction — only in `:draw()`. Position/lifetime live in plain fields so tests need no LÖVE.

- [ ] **Step 2: Write the failing test** `love2d/tests/test_damage_number.lua`

```lua
local DamageNumber = require("src.ui.damage_number")

describe("DamageNumber", function()
    it("rises over time and dies after its lifetime", function()
        local n = DamageNumber.new("MISS", 100, 100)
        assert_true(not n.dead)
        local y0 = n.y
        n:update(0.1)
        assert_true(n.y < y0, "rises")
        n:update(1.0)
        assert_true(n.dead, "gone after ~1s")
    end)

    it("keeps its text and gray flag for MISS", function()
        local n = DamageNumber.new("MISS", 0, 0)
        assert_eq(n.text, "MISS")
        assert_true(n.isMiss)
        local hit = DamageNumber.new("9", 0, 0)
        assert_true(not hit.isMiss)
    end)
end)
```

- [ ] **Step 3: Run to confirm failure** (add `"tests.test_damage_number"` to the suites list). Expected: module not found.

- [ ] **Step 4: Implement `damage_number.lua`**

```lua
-- Floating damage number (MISS or a hit value) that rises and fades.
local Fonts = require("src.ui.fonts")

local DamageNumber = {}
DamageNumber.__index = DamageNumber

local LIFETIME = 1.0
local RISE_SPEED = 40

function DamageNumber.new(text, x, y)
    return setmetatable({
        text = tostring(text),
        isMiss = (tostring(text) == "MISS"),
        x = x, y = y,
        timer = 0,
        dead = false,
    }, DamageNumber)
end

function DamageNumber:update(dt)
    self.timer = self.timer + dt
    self.y = self.y - RISE_SPEED * dt
    if self.timer >= LIFETIME then self.dead = true end
end

function DamageNumber:draw()
    if self.isMiss then
        love.graphics.setColor(0.6, 0.6, 0.6)
    else
        love.graphics.setColor(1, 0, 0)
    end
    Fonts.damage:setScale(1)
    Fonts.damage:draw(self.text, self.x, self.y, "center")
    love.graphics.setColor(1, 1, 1)
end

return DamageNumber
```

(Verify `Fonts.damage` exists and `:draw(text, x, y, align)` signature matches `fonts.lua`; adapt the draw call to the real API.)

- [ ] **Step 5: Run tests** — Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add love2d/src/ui/damage_number.lua love2d/tests/test_damage_number.lua love2d/tests/run_tests.lua
git commit -m "Add floating damage number component"
```

---

### Task 4: Battle menu navigation and sub-menus

**Files:**
- Create: `love2d/src/ui/battle_menu.lua`
- Create: `love2d/tests/test_battle_menu.lua`

`battle_menu` owns the 4-button selection and the open sub-menu state. Navigation logic (which button is selected, which sub-menu level is open) is plain state → headless-testable. Rendering reuses `battle_ui`'s button sprites and `dialogue.lua` box text.

- [ ] **Step 1: Write the failing test** `love2d/tests/test_battle_menu.lua`

```lua
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
        local m = BattleMenu.new()           -- FIGHT selected
        m:confirm()
        assert_eq(m.level, "fight")
        m:cancel()
        assert_eq(m.level, "root")
    end)

    it("ACT/Check yields the check description action", function()
        local m = BattleMenu.new()
        m.selected = 2                        -- ACT
        m:confirm()                           -- act sub-menu
        local action = m:confirm()            -- choose Check
        assert_eq(action.kind, "act_check")
    end)

    it("MERCY exposes Spare and Flee", function()
        local m = BattleMenu.new()
        m.selected = 4                        -- MERCY
        m:confirm()
        assert_eq(m.level, "mercy")
        local a = m:confirm()                 -- first option = Spare
        assert_eq(a.kind, "spare")
    end)
end)
```

- [ ] **Step 2: Run to confirm failure** (register the suite). Expected: module not found.

- [ ] **Step 3: Implement `battle_menu.lua`** — root selection + sub-menu levels (`root`, `fight`, `act`, `item`, `mercy`). `confirm()` returns an action descriptor when a leaf is chosen (e.g. `{kind="act_check"}`, `{kind="item", index=n}`, `{kind="spare"}`, `{kind="flee"}`, `{kind="fight_start"}`), else returns nil after opening a sub-menu. `move(dir)` moves within the current level (clamped). `cancel()` pops one level. Items list comes from a constant table (Butterscotch Pie +99, Instant Noodles +90, Face Steak +60, Legendary Hero +40), each consumable once (track `used`).

The implementer writes this module to satisfy the tests above; keep the action `kind` strings exactly as asserted. Draw method: highlight the selected root button (reuse `battle_ui` selected quad) or list sub-menu options as `dialogue.lua` box text — rendering verified visually in Task 5/6, not unit-tested.

- [ ] **Step 4: Run tests** — Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add love2d/src/ui/battle_menu.lua love2d/tests/test_battle_menu.lua love2d/tests/run_tests.lua
git commit -m "Add battle menu navigation and sub-menus"
```

---

### Task 5: Player-turn phase with the FIGHT mini-game

**Files:**
- Create: `love2d/src/states/battle_phases/player_turn.lua`
- Modify: `love2d/src/states/battle.lua` (register the phase)

The player turn: the combat zone is wide (dialogue-box size), the heart is hidden, the bottom buttons are active. FIGHT runs the target-bar mini-game (`target` sprite fills the box, a cursor sweeps left→right, confirm stops it, `strike` slash plays, Sans dodges, a MISS damage number appears) — except the final turn where the hit connects (victory).

- [ ] **Step 1: Implement `player_turn.lua`** with `enter/update/draw/keypressed`:
  - `enter(battle)`: resize the combat zone to the dialogue-box bounds (use the standard wide size, e.g. the same bounds the CSVs use for dialogue, `33,251,608,391`), hide the heart (`battle.playerHeart` not drawn / a `battle.menuActive=true` flag), create a fresh `BattleMenu`, play no attack.
  - `keypressed`: left/right → `menu:move`; confirm/cancel → `menu:confirm/cancel`; when `menu:confirm()` returns an action, dispatch:
    - `fight_start` → enter the target-bar sub-state (cursor sweep). On a second confirm, stop the cursor, spawn a `strike` animation + a `DamageNumber("MISS", sansX, sansY-…)` (or connect on `battle.turnEvent == "final"`), then hand off to `battle:onPlayerActionDone(actionResult)`.
    - other actions → defer to Task 6 (`action_resolve`). For this task, FIGHT is enough to verify the loop; route ACT/ITEM/MERCY to `action_resolve` once it exists.
  - `update(dt)`: advance the cursor sweep and any strike animation/damage numbers.
  - `draw()`: draw the arena background + the active menu (buttons via `battle_ui`, sub-menu text via `dialogue.lua`), the target bar when active, damage numbers.
- [ ] **Step 2: Register** `player_turn` in `battle.lua` `self.phases` and add `Battle:onPlayerActionDone(result)` that transitions to `sans_dialogue` (Task 7) or, when that phase does not exist yet, directly to the next attack via `turn_manager` (temporary).
- [ ] **Step 3: Visual verification** (autopilot, normal mode reaches a player turn after the intro):

Run: `cd love2d && SANS_AUTOPILOT=normal SANS_AUTOPILOT_MODE=normal SANS_AUTOPILOT_TIME=16 SANS_AUTOPILOT_INTERVAL=1 love .`
Expected: after the intro the zone widens, buttons become active, and (with no input) the menu sits on FIGHT. Inspect the screenshots to confirm the wide dialogue box + active buttons. (The autopilot can press confirm via `SANS_AUTOPILOT_JUMP` mapping if needed to trigger FIGHT.)

- [ ] **Step 4: Commit**

```bash
git add love2d/src/states/battle_phases/player_turn.lua love2d/src/states/battle.lua
git commit -m "Add player-turn phase with FIGHT target mini-game"
```

---

### Task 6: Action resolve phase (ACT / ITEM / MERCY)

**Files:**
- Create: `love2d/src/states/battle_phases/action_resolve.lua`
- Modify: `love2d/src/states/battle.lua`, `love2d/src/states/battle_phases/player_turn.lua`

- [ ] **Step 1: Implement `action_resolve.lua`** — given an action descriptor from the menu, show the resulting box text via `dialogue.lua` and apply effects, then on confirm hand back to `battle:onPlayerActionDone(result)`:
  - `act_check`: box text `* SANS 1 ATK 1 DEF\n* The easiest enemy.\n* Can only deal 1 damage.`
  - `item` (index): heal by the item's amount (Pie +99, Noodles +90, Steak +60, Hero +40), cap HP at 92, play heal SFX, box text `* You ate the [name].\n* You recovered X HP!`; mark the item used (cannot be reused).
  - `spare`: outside the spare-offer turn → box text `* ...` (nothing happens), return to menu; on the spare-offer turn → set `result.ending = "dunked"`.
  - `flee`: `result.ending = "flee"` → exit to main menu.
- [ ] **Step 2: Route** ACT/ITEM/MERCY actions from `player_turn` into `action_resolve` (set `battle.pendingAction` and `setPhase("action_resolve")`).
- [ ] **Step 3: Visual verification** via autopilot pressing through the menu (use held/confirm scripting) on a normal-mode turn; confirm ACT/Check text renders and an item heals (HP changes). Headless tests already cover the menu action kinds (Task 4).
- [ ] **Step 4: Commit**

```bash
git add love2d/src/states/battle_phases/action_resolve.lua love2d/src/states/battle.lua love2d/src/states/battle_phases/player_turn.lua
git commit -m "Add action resolve phase for ACT/ITEM/MERCY"
```

---

### Task 7: Sans dialogue phase

**Files:**
- Create: `love2d/src/states/battle_phases/sans_dialogue.lua`
- Modify: `love2d/src/states/battle.lua`

- [ ] **Step 1: Implement `sans_dialogue.lua`** — shows the current turn's dialogue (from `turn_manager:current().dialogue`) in a speech bubble above Sans using `dialogue.lua`'s typewriter (reuse its API; render the `speechbubble` sprite behind the text). `keypressed` confirm dismisses it. Empty dialogue → skip immediately to the next phase. On exit, call `battle:onDialogueDone()` which loads the turn's attack and `setPhase("attack")`.
- [ ] **Step 2: Wire** `player_turn`/`action_resolve` to transition into `sans_dialogue` after the player's action (instead of going straight to the attack).
- [ ] **Step 3: Visual verification** — autopilot normal mode: after a turn, a speech bubble appears above Sans with the line; on the "sins crawling" turn the text shows. Confirm the bubble is positioned above Sans (not over his face).
- [ ] **Step 4: Commit**

```bash
git add love2d/src/states/battle_phases/sans_dialogue.lua love2d/src/states/battle.lua
git commit -m "Add Sans dialogue phase with speech bubble"
```

---

### Task 8: Endings (game over, get dunked on, victory) + Practice HP floor

**Files:**
- Create: `love2d/src/states/battle_phases/ending.lua` (or fold into battle, implementer's choice — keep it small)
- Modify: `love2d/src/states/battle.lua`, `love2d/src/entities/player_heart.lua`

- [ ] **Step 1: Practice HP floor** — in `Battle:checkGameOver`, if `game.simulatorMode == MODE_PRACTICE`, clamp `game.hp` to at least 1 and never trigger game over.
- [ ] **Step 2: Game over** — HP ≤ 0 (non-practice): stop music, play `heartShatter` SFX, show the `heartshard` shatter animation briefly, then `game:setState("menu")`. (Spec: no "stay determined" screen.)
- [ ] **Step 3: Get dunked on** — when `action_resolve` returns `ending = "dunked"` (Spare on the spare-offer turn): short dialogue, then a forced game over.
- [ ] **Step 4: Victory** — on the final turn, FIGHT connects: a hit `DamageNumber` over Sans, a victory line, Sans leaves, return to main menu.
- [ ] **Step 5: Verify** — Practice mode never game-overs (autopilot normal/practice already tops HP, so test the floor by NOT topping HP: run with `SANS_AUTOPILOT_MODE=practice` and confirm the run survives a hit without returning to menu). Game over: single-attack with no dodging eventually returns to menu with shatter.
- [ ] **Step 6: Commit**

```bash
git add love2d/src/states/battle_phases/ending.lua love2d/src/states/battle.lua love2d/src/entities/player_heart.lua
git commit -m "Add fight endings and practice HP floor"
```

---

### Task 9: Wire the full turn flow + HP bar unification

**Files:**
- Modify: `love2d/src/states/battle.lua`, `love2d/src/ui/battle_ui.lua`

- [ ] **Step 1: Turn routing** — in `Battle:startBattle`, for MODE_NORMAL/MODE_PRACTICE create a `TurnManager`, advance to turn 1 (intro), load `sans_intro`, `setPhase("attack")`. In `Battle:onAttackFinished`, for normal/practice: if the turn manager is finished → victory; else `turn:advance()` and `setPhase("player_turn")`. After the player action + Sans dialogue, `onDialogueDone` loads the (already-advanced) turn's attack and `setPhase("attack")`. Single/Endless keep their current non-turn behavior.
- [ ] **Step 2: HP bar unification** — `battle_ui.lua` delegates the HP bar to `hp_bar.lua` (read it for its API) instead of drawing its own rectangles, repositioned inside the bottom bar; the KR label blinks while karma drains. Keep the name/LV/buttons in `battle_ui`. Do not change `player_heart` karma logic.
- [ ] **Step 3: Full smoke test** — Normal/Practice reaches turn 25 with Practice HP:

Run: `cd love2d && SANS_AUTOPILOT=normal SANS_AUTOPILOT_MODE=practice SANS_AUTOPILOT_TIME=90 SANS_AUTOPILOT_INTERVAL=3 love .`
Expected: the run progresses through intro → player turn → dialogue → attack → ... without freezing or erroring; screenshots show different attacks over time. (Autopilot must press confirm to get through menus — drive it with `SANS_AUTOPILOT_JUMP` pulsing the confirm key; extend the autopilot if a dedicated confirm pulse is needed.)

- [ ] **Step 4: Headless suite green** — `lua5.4 tests/run_tests.lua` all pass.

- [ ] **Step 5: Commit**

```bash
git add love2d/src/states/battle.lua love2d/src/ui/battle_ui.lua
git commit -m "Wire full turn flow and unify the HP bar"
```

---

### Task 10: Test menu entries + changelog + wrap-up

**Files:**
- Modify: `love2d/src/states/test_menu.lua`, `love2d/src/core/game.lua`
- Create: `love2d/src/states/tests/test_battle_menu.lua` (in-game test state) — optional if the test menu pattern is heavy; otherwise skip with a note.
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add a test-menu entry** for "Battle menu" (and optionally "Damage numbers") following the existing `src/states/tests/` pattern (read `test_menu.lua` and one existing `tests/test_*.lua` state first). Register in `game.lua` like the other test states.
- [ ] **Step 2: Manual/autopilot confirmation** of the new test entries.
- [ ] **Step 3: Update `CHANGELOG.md`** under the unreleased section:

```markdown
### Added (Normal Mode)
- Turn-based fight: player menu (FIGHT/ACT/ITEM/MERCY), Sans dialogue per
  turn, the full 25-turn attack order, damage numbers
- Endings: game over (heart shatter), get dunked on, victory; Practice HP floor
```

- [ ] **Step 4: Commit**

```bash
git add love2d/src/states CHANGELOG.md
git commit -m "Add battle test-menu entries and update changelog"
```

---

## Self-review notes

- Spec coverage: turn flow (Tasks 2,5,6,7,9), battle menu + 4 actions (Tasks 4,5,6), damage numbers (Task 3), KR/HP unification (Task 9), fight script + order (Task 1), endings + practice floor (Task 8), test menu (Task 10). New sequencer commands (Platform/BoneStab/SineBones) and Sans-animation/slam are already implemented in the merged Plan 2 — out of scope here.
- Headless-testable logic (turn_manager, damage_number lifetime, battle_menu navigation) has unit tests; phases and rendering are verified visually via the autopilot, since they depend on a live LÖVE graphics/input context.
- Interface consistency: `battle:setPhase/onAttackFinished/onPlayerActionDone/onDialogueDone/checkGameOver/drawArena/getPlatforms`, phase modules `enter/update/draw/keypressed(/exit)`, menu action kinds `fight_start/act_check/item/spare/flee`, `TurnManager:advance/current/currentTurn/isLastTurn/isIntro`. These names are used consistently across tasks.
- Risk: the FIGHT mini-game and menu rendering are the least unit-testable; rely on autopilot screenshots and on-device review. The autopilot may need a dedicated "confirm pulse" env (mirroring the jump pulse) to drive menus — add it in Task 5 if required.
