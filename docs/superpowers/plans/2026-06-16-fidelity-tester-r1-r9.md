# Sans Fight fidelity pass (tester round 1: R1–R9) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Love2D port's combat *feel* and missing mechanics in line with the original Construct 2 Sans fight, per the on-device tester report cataloged in `docs/comparison/CATALOG.md` (R1–R9).

**Architecture:** The port already runs the original CSV attack programs through a faithful VM/sequencer; the gaps are in the soul physics, the damage/karma model, gravity direction, entity behaviours (blasters, blue/orange bones), audio cues, and loop/turn timing. Each R is largely independent; fix in priority order R1→R9, commit per R, validate via the headless test suite (`love2d/tests/`) where logic is pure, and via the autopilot + on-device tester for physics/rendering.

**Tech Stack:** Lua 5.1 (LuaJIT) / LÖVE 11.5. Original spec source: `Event sheets/Battle.xml`, `Event sheets/Timeline.xml`, `Layouts/BattleScreen.xml`. Headless tests run with `lua5.4 tests/run_tests.lua` from `love2d/`.

**Decoded C2 conventions (reference):** `sin`/`cos` take degrees; angle 0=right,90=down,180=left,270=up (Y-down). Comparison enum `0 == · 1 != · 2 < · 3 <= · 4 > · 5 >=`. `Function.Param(n)` is 0-indexed.

**Validation note:** physics/rendering tasks can't be unit-tested headlessly; their "verify" step is an autopilot capture (`SANS_AUTOPILOT=<attack> love .` in `love2d/`, screenshots in the LÖVE save dir `shots/`) plus a device pass by the tester. Pure-logic tasks (damage/karma math, blue/orange gating, VM) get real headless tests.

---

## Task 1 — R1: Damage / karma model (per-frame contact + KR inertia)

**Why:** Highest impact; currently invincibility-chunk damage + karma that decays without removing HP → the HP bar visibly refills itself, and there's no genuine damage pressure.

**Original model (`Battle.xml` 7775–8307):**
- Contact gate: hitbox overlaps a bullet AND `now - lastDamageTime >= 0.033` → `HP -= dmg`, `KR += karma`, play `playerDamaged`, `lastDamageTime = now`. Bones dmg=1/karma=6; gaster beam dmg=1/karma=10.
- Each frame: `KR = min(KR, 40)`; if `KR >= HP` then `KR = HP-1`.
- KR drain (only when `KR > 0 and HP > 1`): accumulate `KR_T += dt`; first matching tier fires, subtracting 1 KR and 1 HP and resetting `KR_T`:
  `KR>=40 & KR_T>=0.033` · `KR>=30 & >=0.066` · `KR>=20 & >=0.166` · `KR>=10 & >=0.5` · `KR>=1 & >=1.0`.

**Files:**
- Modify: `love2d/src/entities/player_heart.lua` (karma fields + drain; remove invincibility-based damage gating)
- Modify: `love2d/src/states/battle.lua` (`checkCollisions` damage application)
- Modify: `love2d/src/entities/bone.lua` (karma value: bones karma=6) and `gaster_blaster.lua`/sequencer (beam dmg=1/karma=10 — coordinate with Task 5)
- Create test: `love2d/tests/test_karma.lua`

- [ ] **Step 1 — Failing test for the karma model.** Extract the karma logic into a pure function so it's testable. Add `PlayerHeart:applyContactDamage(dmg, karma)` (adds dmg/karma, no i-frames) and `PlayerHeart:updateKarma(dt)` (cap + clamp-to-HP + tiered drain, returning HP lost). Test in `tests/test_karma.lua`:

```lua
local PlayerHeart = require("src.entities.player_heart")
-- a headless constructor path may be needed; if PlayerHeart.new requires LÖVE,
-- factor the karma math into a pure module src/systems/karma.lua and test that.
describe("karma", function()
  it("caps KR at 40 and at HP-1", function()
    local k = Karma.new(); k.hp = 20; k.kr = 99
    k:update(0)                      -- clamp pass
    assert_eq(k.kr, 19)              -- HP-1
    k.hp = 92; k.kr = 99; k:update(0); assert_eq(k.kr, 40)
  end)
  it("drains 1 KR + 1 HP per tier interval", function()
    local k = Karma.new(); k.hp = 92; k.kr = 40
    k:update(0.033)                  -- >=40 tier
    assert_eq(k.kr, 39); assert_eq(k.hp, 91)
  end)
  it("drains slower at low KR", function()
    local k = Karma.new(); k.hp = 92; k.kr = 5
    k:update(0.5); assert_eq(k.kr, 5)   -- below 1.0s threshold for KR<10
    k:update(0.6); assert_eq(k.kr, 4); assert_eq(k.hp, 91)
  end)
end)
```

- [ ] **Step 2 — Run, confirm fail.** `cd love2d && lua5.4 tests/run_tests.lua` → the new cases fail (module/methods missing).

- [ ] **Step 3 — Implement `src/systems/karma.lua`** (pure module: `hp`, `kr`, `krT`; `:hit(dmg,karma)`; `:update(dt)` doing cap→clamp→tiered drain with the 5 tiers above). Keep it LÖVE-free.

- [ ] **Step 4 — Wire into the heart/battle.** In `player_heart.lua`: hold a `Karma` instance (or expose `hp` via battle and karma here); remove the invincibility-frame model from `damage()` (delete `invincible` gating for *contact* — keep any brief flash only if desired but do NOT block damage). In `battle.lua:checkCollisions`: replace the chunk-damage block with a per-frame gate `if now - self.lastDamageTime >= 0.033 and overlapping then karma:hit(entity.damage, entity.karma); Audio:playSfx("playerDamaged"); self.lastDamageTime = now end`, and each frame call `local lost = karma:update(dt)` applying HP loss; sync `self.game.hp`. Set `bone.karma = 6` in `bone.lua`.

- [ ] **Step 5 — Run tests, confirm pass.** `lua5.4 tests/run_tests.lua` → all pass (incl. existing 52).

- [ ] **Step 6 — Visual verify.** `SANS_AUTOPILOT=sans_bonegap1 SANS_AUTOPILOT_TIME=6 love .`; confirm HP bar only ever decreases, purple KR segment grows on hits and bleeds HP down over time (no self-refill).

- [ ] **Step 7 — Commit.** `git add -A && git commit -m "R1: per-frame contact damage + KR karma inertia (match original)"`

---

## Task 2 — R2: Blue-soul physics (heavier, original gravity curve)

**Why:** Jump/fall feel too fast and light on every blue attack.

**Original (`Battle.xml` PlayerMovement 3037–4481), CustomMovement dx/dy:**
- Gravity unit vector each tick: `X=cos(Angle)`, `Y=sin(Angle)`.
- Jump (only when grounded in gravity dir): impulse **additive** `dx -= X*180`, `dy -= Y*180` (`HEART_JUMP_STRENGTH=180`).
- Variable jump cut: on jump-release while rising, **clamp** the away-from-gravity speed to magnitude **30** (`HEART_JUMPHOLD_CUTOFF`), not a multiply.
- Gravity magnitude is a **curve** of `downSpeed` (signed along-gravity speed): `downSpeed<240 & >15 →540` · `<=15 & >-30 →180` · `<=-30 & >-120 →450` · `<=-120 →180`. Applied as `dx += X*Gravity*dt`, `dy += Y*Gravity*dt`, only while not grounded (`HeartCheckSolid(X*0.2,Y*0.2)==0`).
- Max fall speed clamp **750** along the gravity axis.
- Perpendicular axis: zeroed each tick and driven by player input at `HeartSpeed=150`.

**Files:** Modify `love2d/src/entities/player_heart.lua` (constants 13–19, `updateBlueMode` 215–281, `resetForAttack` 100).

- [ ] **Step 1 — Replace constants.** `GRAVITY` (single) → remove; add `JUMP_STRENGTH=180`, `JUMP_HOLD_CUTOFF=30`, `MAX_FALL_SPEED=750`. Update `resetForAttack` maxFallSpeed default to 750.
- [ ] **Step 2 — Gravity curve helper.** Add `local function gravityFor(downSpeed)` returning 540/180/450/180 per the table.
- [ ] **Step 3 — Rework `updateBlueMode`.** Compute gravity unit vector from `gravityDirection` (down/up/left/right → the same X/Y signs). Apply `v += grav*gravityFor(downSpeed)*dt`; clamp along-axis to 750; jump = additive `-180` along the away axis; jump-cut = clamp rising speed to 30. Route player input to the **perpendicular** axis (X for up/down gravity, Y for left/right gravity).
- [ ] **Step 4 — Verify.** `SANS_AUTOPILOT=sans_platforms1 SANS_AUTOPILOT_HOLD=right SANS_AUTOPILOT_JUMP=1.2 love .`; the jump arc should feel floaty/heavier (slow apex, faster fall), not snappy.
- [ ] **Step 5 — Commit.** `git commit -am "R2: match original blue-soul gravity curve, jump impulse, max-fall"`

---

## Task 3 — R3: Gravity direction + side-scroller (unblocks P2 A4/A5/A9 + final)

**Why:** Sans rotates gravity in phase 2 and the final is a left-gravity side-scroller; the port always falls down and never rotates the soul.

**Original:** gravity direction = `PlayerHeart.Angle`, set by `SansSlam(dir)` → `Angle = floor(dir)*90` (0=right,1=down,2=left,3=up), plus an immediate slam impulse along that angle. The sprite is rotated to `Angle`. Side-scroller (gravity left/right): vertical axis is the player-controlled one; horizontal is gravity-driven; soul pinned to the wall.

**Files:** Modify `love2d/src/systems/attack_sequencer.lua` (`SansSlam` handler ~308) and `love2d/src/entities/player_heart.lua` (`setGravityDirection`, sprite rotation in `draw`, `updateSlam`).

- [ ] **Step 1 — SansSlam sets gravity + angle.** In the `SansSlam` handler map `params[1]` (0/1/2/3) → `setGravityDirection("right"/"down"/"left"/"up")`; keep the slam impulse. In `updateSlam`, set `gravityDirection` for all four dirs (not just dir==1).
- [ ] **Step 2 — Rotate sprite.** In `PlayerHeart:draw`, base the rotation on `gravityDirection` (down=baseline; the soul "points" along gravity) so it visually matches.
- [ ] **Step 3 — Side-scroller verified by R2 Step 3** (perpendicular-axis input already routes Y for left/right gravity). Add the "pinned to wall" landing for left/right.
- [ ] **Step 4 — Verify.** `SANS_AUTOPILOT=sans_final SANS_AUTOPILOT_TIME=10 love .`; on the side-scroller section the soul should sit on the left, point right, move up/down only, gravity pulling left.
- [ ] **Step 5 — Commit.** `git commit -am "R3: gravity direction from slam angle + side-scroller soul"`

---

## Task 4 — R4: Loop / trailing-delay timing (attacks ending too early)

**Why:** Looping/long attacks (P1 A2,A3,A4,A7,A8,A9,A11,A12,A13; P2 A7) cut short. Hypothesis: the trailing `EndAttack` delay (during which the spawned wall flies across, e.g. `7,EndAttack` in `bonegap2`) isn't being honoured, so the attack ends right after spawning.

**Files:** Investigate `love2d/src/systems/attack_sequencer.lua` (`update` waitTimer/EndAttack), `love2d/src/states/battle.lua` (`onAttackFinished`, attack phase end).

- [ ] **Step 1 — Instrument.** Temporarily log in the sequencer: on each executed line print `command, event.time, waitTimer`; on EndAttack print total elapsed. Run `SANS_AUTOPILOT=sans_bonegap2 SANS_AUTOPILOT_TIME=10 love . 2>&1 | tee /tmp/seq.log`.
- [ ] **Step 2 — Compare.** Confirm whether the `7,EndAttack` line waits ~7 s (correct) or fires near t≈0 (bug). Check that `waitTimer` accumulates and the `if self.waitTimer < event.time then break` actually gates EndAttack.
- [ ] **Step 3 — Fix the found cause.** Likely candidates: (a) `EndAttack` delay not respected because `waitTimer` resets/`event.time` parsed wrong; (b) `onAttackFinished` triggered by an empty-entities check rather than the sequencer's `finished`. Implement the minimal fix so the attack lasts spawn-time + trailing delay.
- [ ] **Step 4 — Headless test.** Add a sequencer test: feed `"0,BoneV,...\n7,EndAttack,,"`; advance 6.9 s → not finished; advance 0.2 s → finished. `lua5.4 tests/run_tests.lua`.
- [ ] **Step 5 — Remove instrumentation; commit.** `git commit -am "R4: honour trailing EndAttack delay so long attacks aren't cut short"`

---

## Task 5 — R5: Gaster blasters (size, beam, sound, lifecycle)

**Why:** Too small, silent, beam lasts a few frames, sometimes invisible/offscreen.

**Original (`Battle.xml` 5434–6135):** 4 objects (skull + 3 beam layers + hitbox). Size enum scales the skull: 0→w×2/h×1, 1→×2, 2→×3. ENTER lerps to target (`+(End-pos)*dt*10`, snap at <3). WAIT = Param6 (charge). FIRE = hardcoded 0.1 s, then beams become visible, hit dmg=1/karma=10. Beam: length fixed **1000**, thickness `BaseSize=35*scale` (scale=`skullHeight/ImageHeight/2`) with sine pulse; lifecycle grow over 4/30 s → hold **Param7 (BlastTime)** → decay `BaseSize*=0.8^(dt*30)` until <2 then destroy; beam outlives skull (LEAVE recoil `LeaveSpeed+=30`). Sounds: `GasterBlaster` (rate 1.2) at creation; `GasterBlast`+`GasterBlast2` at fire; `SansShake(5)` on fire.

**Files:** Modify `love2d/src/entities/gaster_blaster.lua` (full rewrite of size/beam/lifecycle) and `love2d/src/systems/attack_sequencer.lua` (`GasterBlaster` handler ~233: pass size enum + chargeTime=Param6 + blastTime=Param7; play charge SFX).

- [ ] **Step 1 — Fix size mapping.** Stop using the size param as a draw scale. size 0→(w 2x,h 1x), 1→2x, 2→3x of the skull frame; derive `beamScale = skullHeight/FRAME_H/2`. (Fixes "size 0 → invisible".)
- [ ] **Step 2 — Beam model.** Length ~1000 (screen-spanning), thickness `35*beamScale` + sine pulse; grow 4/30 s → hold `blastTime` → decay `0.8^(dt*30)` → destroy <2; anchor `70*beamScale` in front along angle; visible only from fire start; outlive the skull's FIRE/LEAVE.
- [ ] **Step 3 — Timing + damage.** WAIT=chargeTime(Param6); FIRE=0.1 s; hit dmg=1/karma=10 (coordinate with Task 1). Add LEAVE recoil.
- [ ] **Step 4 — Sound.** In the sequencer handler, `Audio:playSfx("gasterBlaster")` at spawn; at fire start play `gasterBlast`/`gasterBlast2` (entity callback or a scheduled call). Verify keys exist in `assets_config.lua` (`gasterBlaster`, `gasterBlast`).
- [ ] **Step 5 — Verify.** `SANS_AUTOPILOT=sans_randomblaster1 SANS_AUTOPILOT_TIME=8 love .`; blasters large, beam thick and persists ~`blastTime`, audible, on-screen.
- [ ] **Step 6 — Commit.** `git commit -am "R5: faithful gaster blaster size, beam lifecycle, sound"`

---

## Task 6 — R6: Blue / orange bones (safe-when-still / safe-when-moving)

**Why:** Blue bones must not hurt a still soul; orange must not hurt a moving soul. Port ignores motion (blue uses button-state; orange unhandled).

**Original (`Battle.xml` 8028–8106):** white (Color 0) always damages; blue (Color 1) damages only if the soul `Is moving` (CustomMovement velocity != 0); orange (Color 2) damages only if NOT moving. "Moving" = actual velocity from any source (input, gravity, slam, platform).

**Files:** Modify `love2d/src/entities/player_heart.lua` (add a per-frame `moved` flag from real position delta) and `love2d/src/states/battle.lua` (`checkCollisions` color gating). Test: `love2d/tests/test_bone_color.lua`.

- [ ] **Step 1 — Failing test.** Pure helper `shouldDamage(color, moved)` → white:true; blue: `moved`; orange: `not moved`. Test all 6 combos.
- [ ] **Step 2 — Run, fail.**
- [ ] **Step 3 — Movement flag.** In `player_heart.lua:update`, capture `prevX/prevY` at top; after clamp set `self.moved = (dx*dx+dy*dy) > 0.01`. Init in `new`.
- [ ] **Step 4 — Gate damage.** In `checkCollisions`, replace the blue-only `Input:isMoving()` block with `shouldDamage(color, self.playerHeart.moved)` covering blue AND orange.
- [ ] **Step 5 — Run tests, pass.**
- [ ] **Step 6 — Verify + commit.** `SANS_AUTOPILOT=sans_bluebone SANS_AUTOPILOT_TIME=6 love .` (still soul takes no damage from blue bones). `git commit -am "R6: blue/orange bone motion gating via real soul velocity"`

---

## Task 7 — R7: Audio / music cues

**Why:** Blasters silent; music should start at the END of P1 A1 and pause when Sans is tired (turn 15, `sans_spare`).

**Original:** blaster SFX come from CSV `Sound,GasterBlaster` rows (already handled) and/or the spawn; Megalovania (`mus_zz_megalovania`, tag "Music") starts after the intro attack finishes and is paused at the tired phase (`HitAttempts` ~13–15).

**Files:** Modify `love2d/src/states/battle.lua` (remove unconditional `playMusic` at ~155/183; start on intro-finish; pause at the spare/tired turn) and `love2d/src/systems/attack_sequencer.lua` (ensure blaster SFX — see Task 5 Step 4). `audio.lua` already has `playMusic/pauseMusic`.

- [ ] **Step 1 — Remove early music start** at `battle.lua:155` (and endless `:183`).
- [ ] **Step 2 — Start after intro.** In `onAttackFinished` (or turn advance), when the just-finished turn was turn 1 (`sans_intro`), call `Audio:playMusic("megalovania", true)`.
- [ ] **Step 3 — Pause when tired.** When advancing to the `sans_spare` turn (turn 15, `event == "spare_offer"`), call `Audio:pauseMusic()` (resume on the next real attack if the original does — check; otherwise leave paused through the break).
- [ ] **Step 4 — Blaster SFX** confirmed by Task 5 Step 4.
- [ ] **Step 5 — Verify on device** (audio can't be checked via screenshots): tester confirms music start/stop + blaster sound.
- [ ] **Step 6 — Commit.** `git commit -am "R7: music starts after intro, pauses at the break; blaster sfx"`

---

## Task 8 — R8: Sans sprite during gravity attacks

**Why:** Sans's sprite "falls apart" when he plays with gravity (tied to R3 + SansX/scroll/body-frame handling).

**Files:** Investigate `love2d/src/entities/sans.lua` (body/head frame + scroll) and the relevant attack CSVs' Sans commands during P2/final.

- [ ] **Step 1 — Reproduce after R3.** `SANS_AUTOPILOT=sans_final SANS_AUTOPILOT_TIME=12 love .`; capture frames where the sprite breaks.
- [ ] **Step 2 — Diagnose.** Check whether `SansX`/`SansRepeat`/`SansEndRepeat`/body-frame indices used by those attacks are handled (compare to the `SansBody`/`SansHead` frame maps in `sans.lua`); a missing/out-of-range frame or scroll-without-stop is the likely cause.
- [ ] **Step 3 — Fix** the unhandled/out-of-range case (clamp frame indices; honour scroll start/stop).
- [ ] **Step 4 — Verify + commit.** `git commit -am "R8: stabilise Sans sprite during gravity attacks"`

---

## Task 9 — R9: Cosmetic + dialogues (Bad Time Simulator) + final hit

**Decisions (user):** dialogues → **Bad Time Simulator** wording; **add** the Undertale-style final hit (not in BTS, but wanted).

**Files:** `love2d/src/data/fight_script.lua` (dialogue strings), `love2d/src/entities/platform.lua` (texture), `love2d/src/states/battle_phases/player_turn.lua` (final hit — `doSwing`/`isFinalTurn` already stub a "9999" hit).

- [ ] **Step 1 — Platform texture.** Inspect `platform.lua` tiling vs `assets/sprites/platform1.png`; fix the odd-looking tiling (Task references P1 A5/A6). Verify with `SANS_AUTOPILOT=sans_platforms1 love .`.
- [ ] **Step 2 — Dialogues → BTS.** Source the Bad Time Simulator turn dialogue (from `c2-export/` RPGText/data or the original project text) and replace the `dialogue` strings in `fight_script.lua` to match BTS exactly.
- [ ] **Step 3 — Final hit.** Confirm/finish the final-blow sequence in `player_turn.lua` (the connecting FIGHT after `sansAsleep`) so the Undertale-style final hit lands and triggers victory.
- [ ] **Step 4 — Verify + commit.** `git commit -am "R9: BTS dialogues, platform texture, final hit"`

---

## Wrap-up

- [ ] Run full headless suite: `cd love2d && lua5.4 tests/run_tests.lua` (all green).
- [ ] Rebuild the PortMaster port + `.love` (`dist/release/`), update the GitHub release, hand the build to the tester for round-2 validation.
- [ ] Fold round-2 feedback into `docs/comparison/CATALOG.md`.

## Self-review notes
- Spec coverage: R1–R9 each have a task; the catalog's per-attack notes all map to R1–R7 root causes (verified against the catalog).
- Method naming: `Karma:hit/update`, `PlayerHeart.moved`, `shouldDamage(color, moved)`, `gravityFor(downSpeed)` are used consistently across tasks.
- Known soft spots flagged honestly: R4 and R8 begin with a defined investigation step (genuine unknowns); R9 Step 2 depends on sourcing BTS dialogue text from `c2-export/`.
