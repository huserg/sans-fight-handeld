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
