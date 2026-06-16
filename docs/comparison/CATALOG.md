# Fidelity catalog: Love2D port vs. Construct 2 original

Authoritative comparison of the port against the original Construct 2 project that
ships in this repo (`c2-export/`, `Event sheets/`). This is primarily a **source-level**
audit (deterministic and complete), supplemented by visual notes from running both games.

## Method & ground truth

- The 24 attack programs (`*.csv`) are **byte-identical** between `c2-export/` and
  `love2d/attacks/`. Attack *data* is therefore not a source of divergence.
- Fidelity is determined entirely by the **interpreter** (VM + sequencer + opcode
  handlers) and by **global battle setup**.
- Original interpreter: `Event sheets/Timeline.xml` (VM core) + `Event sheets/Battle.xml`
  (opcode handlers, ~9k lines). Port interpreter: `love2d/src/systems/attack_vm.lua`,
  `attack_sequencer.lua`, `attack_parser.lua`.
- Visual reference: jcw87.github.io/c2-sans-fight attack tester; port via autopilot.

### Decoded Construct 2 conventions (reference for all entries below)

- `sin`/`cos` take **degrees**.
- Entity motion per tick: `X += cos(Direction*90)*dt*Speed`, `Y += sin(Direction*90)*dt*Speed`.
  Direction `0=right, 1=down, 2=left, 3=up`.
- `*Repeat` placement: `X = StartX - cos(Direction*90)*Spacing*i`,
  `Y = StartY - sin(Direction*90)*Spacing*i` for `i in 0..Count-1`
  (offset runs **along the travel axis**, negative sign).
- CSV column 0 = **delay**; a line runs once accumulated `T >= delay`; all `delay=0`
  lines run in the **same tick**.
- Comparison enum: `0 ==`, `1 !=`, `2 <`, `3 <=`, `4 >`, `5 >=`.

## Verdict on the engine (good news)

The VM, the sequencer, and the timing model are **faithful**:

- Math/jump opcodes (`SET/ADD/SUB/MUL/DIV/MOD/FLOOR/DEG/RAD/SIN/COS/ANGLE/RND`,
  `JMP*`) match `Timeline.xml` semantics, including comparison directions and the
  `RND v,n -> 0..n-1` range.
- `JMPREL n` and `JMPABS`/label arithmetic land on the same lines as the original
  (the original's `Line-1` then `+1` per-tick increment nets to the port's direct `pc`).
- The sequencer runs **all `delay=0` lines in one frame** and accumulates `dt` exactly
  like the `Timeline` `While` loop. No per-frame throttling bug.

So "timing faux" is **not** an engine problem — it lives in the handlers and setup below.

## Status (v2.1.1)

Fixed: S1 `BoneVRepeat`/`BoneHRepeat`, S1 `PlatformRepeat`, S1 `Platform` reverse/bounce,
S2 `SineBones`, S2 `SansSlam` blue mode, S3 horizontal-bone clipping, G1 `LV 19`,
G2 Sans idle pose, G3 HP/KR readout (persistent KR label, 110px bar, zero-padded value),
G4 combat-zone default (now the original menu box 33,251,608,391; menu phase already
matched; the bottom buttons were already correct).

Kept by design: S3 culling — the port uses `lifetime(10)` + offscreen bounds instead of
the original's layout-edge destruction; functionally equivalent and safer, entities are
also cleared on attack end. Revisit only if a specific attack shows lingering bones.

Verified by source comparison + the headless test suite (52/52). Visual spot-check on
device/local still recommended for the platform and sine attacks.

---

## Discrepancies (severity-ranked)

### S1 — `BoneVRepeat` placement is wrong (HIGH; 59 uses across attacks) — FIXED v2.1.1

- **Original** (`Battle.xml` ~4667): each repeated bone is offset **along its travel
  axis** with a negative sign: `X = StartX - cos(Dir*90)*Spacing*i`,
  `Y = StartY - sin(Dir*90)*Spacing*i`.
- **Port** (`attack_sequencer.lua:175` `BoneVRepeat`): always offsets on **X only**
  (`x + n*spacing`), ignoring `Direction`, with the **opposite sign**.
- **Effect**: for right/left-moving walls the spacing mirrors; for up/down-moving
  walls the bones spread sideways instead of stacking along travel — the wall shape
  is wrong on every attack that uses `BoneVRepeat`.
- **Fix**: replicate `StartX - cos(d*90)*spacing*i`, `StartY - sin(d*90)*spacing*i`.

### S1 — `PlatformRepeat` placement is wrong (HIGH; 6 uses)

- Same bug as `BoneVRepeat`. **Original** (`Battle.xml` ~2822) offsets along the
  travel axis with negative sign; **port** (`attack_sequencer.lua:345`) does
  `x + n*spacing` on X only.
- **Fix**: same as S1 above (shared helper).

### S1 — `Platform` `reverse` does not bounce (HIGH; platform attacks)

- **Original** (`Battle.xml` ~2752): `reverse` (Param5 > 0) sets a `Reverse` flag that
  makes the platform **ping-pong inside the combat zone** — on reaching the zone edge
  matching its direction it flips `0<->2` / `1<->3` and keeps moving. The platform
  stays in play as a rideable surface.
- **Port** (`platform.lua:32`): treats `reverse` as a one-shot **speed negation**
  (`speed = -speed`); the platform then travels straight off-screen and is culled at
  `-200/840/680`. No bounce, no edge detection.
- **Effect**: platform attacks (`platforms1-4`, `platformblaster*`) lose their rideable
  oscillating platforms — a direct cause of "not playable".
- **Fix**: implement zone-edge bounce in `Platform:update` when `reverse` is set,
  using the combat zone bounds and the `Dir 0<->2 / 1<->3` flip.

### S2 — `SineBones` shape is invented, not the original (MED; 5 uses)

- **Original** (`Battle.xml` ~4759): fixed **gap = 39px**, vertical sine
  `Sine = floor(sin(i/3 rad)*28)` (**amplitude 28**, **frequency i/3**), columns enter
  from `BBoxRight`/`BBoxLeft + Spacing*i`, top bone height `Height + Sine`, bottom bone
  height `BBoxBottom - 5 - Y`. `Spacing > 0` -> direction 2 (left); `< 0` -> direction 0.
- **Port** (`attack_sequencer.lua:23` `spawnSineBones`): different gap
  (`max(height,24)`), different amplitude (`(zoneH-gap)/2-6`), different frequency
  (`sin(n*0.5)`), different entry math, lifetime instead of bounds.
- **Effect**: the sine corridor looks and plays differently from the original.
- **Fix**: reimplement to the original formula above.

### S2 — `SansSlam` does not switch the soul to blue (MED; sans_final etc.)

- **Original** (`Battle.xml` ~3160): `SansSlam` first calls `HeartMode BLUE`, sets
  `Slammed`, then drives the heart at `MaxFallSpeed` along `floor(dir)*90`.
- **Port** (`attack_sequencer.lua:293`): only calls `playerHeart:slam(dir)`; never
  forces blue mode.
- **Effect**: during slam sequences the soul can remain red (free movement) when it
  should be gravity-locked, changing how the slam plays.
- **Fix**: set `HEARTMODE_BLUE` at the start of the `SansSlam` handler.

### S3 — Horizontal bones are clipped, original leaves them unclipped (LOW)

- **Original**: `BoneV` spawns on layer `CombatZoneClipped` (clipped), `BoneH` on
  `CombatZone` (**not** clipped).
- **Port**: every `Bone` has `clipToZone = true` (`bone.lua:77`), so horizontal bones
  are clipped too.
- **Effect**: minor visual difference where horizontal bones should overhang the box.
- **Fix**: set `clipToZone = (orientation == "vertical")` (verify per attack first).

### S3 — Bone/platform culling uses lifetime, not layout bounds (LOW)

- **Original**: bones are destroyed when they exit the **layout** (640x480) in their
  travel direction; platforms persist (bounce) or are cleared on attack end.
- **Port**: `Bone:setLifetime(10)` + offscreen `-200/840/680`. Functionally close but
  can keep near-zero-speed bones alive longer than the original.
- **Fix**: low priority; revisit if specific attacks show lingering bones.

---

## Global / UI discrepancies

### G1 — Player level shows `LV 1`, should be `LV 19` (MED)

- The genocide Sans fight uses **LV 19** (confirmed against the live original).
- **Port**: `battle_ui.lua:50` `self.playerLV = 1`.
- **Fix**: set `playerLV = 19`. (HP/MaxHP = 92 is already correct,
  `constants.lua:19-20`.)

### G2 — Sans default idle pose: port arm raised, original arms down (MED)

- **Port**: `sans.lua` idles by alternating body frames `{0,1}` (HandDown/HandUp),
  so Sans appears to keep an arm raised / gesturing.
- **Original**: default is a still standing pose, arms down; an arm raises only for
  specific attacks (e.g. gaster-blaster summons).
- **Fix**: confirm the original idle frame set, then stop the idle arm cycle (idle
  should hold the arms-down frame).

### G3 — HP / KR readout styling (LOW-MED)

- **Original**: shows a `KR` label with colored HP numbers; bar positioned further
  left.
- **Port**: plain white HP, no `KR` label.
- **Fix**: add the `KR` label and match number coloring / bar position to the C2 layout.

### G4 — combat-zone default size / menu calibration (VERIFY)

- Re-validate the default combat-zone rect and bottom-menu sizing against
  `Layouts/*.xml` once S1-S3 are fixed, since several attacks resize the zone and the
  defaults affect every screen.

---

## Suggested fix order

1. S1 `BoneVRepeat` + `PlatformRepeat` placement (shared helper) — broadest impact.
2. S1 `Platform` reverse/bounce — unblocks platform attacks.
3. S2 `SineBones` formula, `SansSlam` blue mode.
4. G1 `LV 19`, G2 Sans idle, G3 KR readout.
5. S3 clipping/culling, G4 layout re-validation.

After each fix, re-run the attack(s) that use the opcode and compare to the live
original (jcw87.github.io/c2-sans-fight attack tester) for the affected attack only.

---

# Tester feedback — round 1 (2026-06-16)

Played on-device (RG35XX-SP / Knulli) by a tester who knows the original well.
**Positive baseline:** bone/platform *timing and placement* are good (the v2.1.1 `*Repeat`
fix landed), and Phase-2 attack chaining feels properly random. The remaining issues are
mostly **soul physics, the damage model, gravity, gaster blasters, audio, and loop length** —
several are cross-cutting root causes that each explain many per-attack complaints.

## Cross-cutting root causes (fix first — each affects many attacks)

### R1 — Damage / karma model is wrong (HIGH; every attack; visible HP bug)
- **Original:** contact deals ~**1 HP per frame** while the soul overlaps a bullet; a second
  **purple KR (karma) bar** accumulates from hits and then **drains real HP over time** (the
  "inertia"). 
- **Port:** invincibility-frame **chunk** damage (`battle.lua:490, 525-528`) and karma that
  merely **decays without removing HP** (`player_heart.lua:186-192`) — so `hp - karma` rises
  and the **HP bar appears to refill by itself**.
- **Fix:** per-frame contact damage; karma adds on hit and drains `game.hp` over time; the
  purple bar shows pending karma as inertia.

### R2 — Blue-soul physics too fast / too light (HIGH; all blue attacks)
- **Original** (`Battle.xml` PlayerMovement): `HEART_JUMP_STRENGTH=180`,
  `HEART_JUMPHOLD_CUTOFF=30`, `MaxFallSpeed=750`, gravity via the Platform/CustomMovement model.
- **Port:** `JUMP_SPEED=-350`, `GRAVITY=800`, `MAX_FALL_SPEED=400` (`player_heart.lua`) — jump
  and fall feel too quick and weightless.
- **Fix:** retune jump/gravity/max-fall to the original feel (heavier, matching the C2 values).

### R3 — Gravity-direction changes not implemented (HIGH; P2 A4/A5/A9 + final)
- **Original:** Sans rotates gravity (up/down/left/right); the soul **rotates** and falls toward
  the new direction; the **final** is a **left-gravity side-scroller** (soul pinned to the left,
  point facing right, moving only up/down). Logic at `Battle.xml:3822-4350` ("Handle gravity",
  "Sideways movement when gravity is left/right"), driven by the heart **angle** (not a CSV opcode).
- **Port:** no gravity opcode/handler; the soul always falls **down** and stays **vertical**.
  `player_heart` has a `gravityDirection` field but nothing sets it.
- **Fix:** derive gravity direction from the heart angle / slam per `Battle.xml`; rotate the
  sprite; implement the side-scroller for the final.

### R4 — "Loop" attacks end too early (HIGH/MED; many attacks)
- Looping bone/platform attacks stop sooner than the original. The VM + timing engine were
  verified faithful, so investigate **EndAttack delay vs. turn fill-time** and whether the loop
  should run for the whole turn duration.

### R5 — Gaster blasters broken (MED; P1 A1, P2 A2/A6, final ring)
- Too **small** (original scales by size 0/1/2 → `ImageWidth*2` or `*3`), **no sound**, **beam
  lasts only a few frames** (should charge ~0.5s then fire), sometimes **invisible / off-screen**.

### R6 — Blue/orange bone mechanic missing (MED; P1 A3)
- A **blue bone** must deal **no damage when the soul is still**, and behave like a normal bone
  when **moving** (blue "stop sign"). Port damages regardless of motion.

### R7 — Audio / music cues (MED)
- Blaster SFX missing; per-frame damage SFX; **music should START at the end of P1 A1**; **music
  should CUT at A15** (Sans is tired).

### R8 — Sans sprite glitches during gravity attacks (MED/cosmetic)
- Sprite "falls apart" when Sans plays with gravity — tied to R3 + SansX/scroll/animation.

### R9 — Cosmetic / artistic (LOW)
- Platform texture looks odd (P1 A5/A6). Dialogue is a hybrid of Undertale / Bad Time Simulator
  (artistic choice to settle).

## Per-attack notes

**Phase 1**
- A1 — gaster intro: blasters too small, no sound [R5,R7]; music should start at attack end [R7].
- A2 — [R2][R4].
- A3 — blue bones don't work (should be safe when still) [R6]; [R2][R4].
- A4 — [R2][R4]; bones should arrive **2 by 2**; port sends 2 then 1 then stops (spawn/loop bug).
- A5 — platform texture weird [R9]; [R2].
- A6 — as A5 [R9][R2].
- A7 — [R4] (more noticeable on platforms).
- A8 — [R4]; must also dodge bones on the **return** trip (missing).
- A9 — missing **side blasters** (alternate L/R, random among 3 heights) [R5]; [R4] on platforms.
- A10 — as A8.
- A11/A12/A13 — [R2][R4].
- A14 — as A9.
- A15 — **not an attack**: Sans is tired, music should cut [R7].

**Phase 2 ("the REAL battle")**
- A1 — clean, random chaining; most faithful; [R2] but no [R4] (too fast to loop).
- A2 — blasters invisible + no sound [R5,R7].
- A3 — as A1.
- A4 — gravity change: soul still falls down + stays vertical; missing SFX [R3,R7].
- A5 — as A4 [R3].
- A6 — blasters too small, sometimes off-screen, no sound, beam only a few frames [R5,R7].
- A7 — [R4], else correct.
- A8 — as A1.
- A9 — as A4 [R3].
- **Final** — chains A4 then A7 (same issues); the long line should be a **left-gravity
  side-scroller** (soul pinned left, point right, up/down only) but stays down; soul teleports
  left and there are **no obstacles** (too easy); then an A4-like section; the **blaster ring is
  missing**; the **final gravity-slam animation** doesn't work (depends on R3); the final hit
  exists in Undertale but not Bad Time Simulator (artistic choice).

## Next-pass priority
1. **R1** damage/karma model (affects everything; fixes the HP-refill bug).
2. **R2** blue-soul physics (affects all blue attacks).
3. **R3** gravity direction + side-scroller (unblocks P2 A4/A5/A9 + final).
4. **R4** loop duration.
5. **R5** blasters · **R6** blue bones · **R7** audio/music.
6. **R8** sprite glitches · **R9** cosmetic/artistic.
