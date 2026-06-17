# Changelog

All notable changes to this project will be documented in this file.

## [2.2.0] - 2026-06-17

### Fidelity overhaul (tester round 1: R1-R9)

Each change is grounded in the original Construct 2 source (`Event sheets/Battle.xml`).
Full analysis in `docs/comparison/CATALOG.md`; plan in
`docs/superpowers/plans/2026-06-16-fidelity-tester-r1-r9.md`.

- **Damage / karma (R1):** per-frame contact damage (0.033s gate) with the KR "inertia"
  bar — karma accumulates on hits, is capped at `min(40, HP-1)`, and drains real HP on a
  5-tier curve (faster as KR grows). Fixes the HP bar that appeared to refill itself.
- **Blue-soul physics (R2):** original gravity curve (540/180/450/180 by fall speed),
  additive jump impulse 180, jump-hold cutoff 30, max-fall 750, perpendicular-axis control.
  Heavier, floatier arc matching the original.
- **Gravity direction + side-scroller (R3):** SansSlam now sets the soul's gravity
  direction; the soul rotates and falls toward it; the final side-scroller is supported.
- **Loop timing (R4):** verified (regression test) that the trailing `EndAttack` delay is
  honoured; the "cut short" feel is tracked to bone lifetime for round 2.
- **Gaster blasters (R5):** correct size scaling (2x/3x), screen-long beam with grow/hold/
  decay lifecycle and pulse, charge + fire sounds, recoil; beam damage routes through the
  karma model (dmg 1 / karma 10).
- **Blue / orange bones (R6):** blue bones only hurt while the soul moves; orange only while
  it is still — gated on real soul velocity, not button state.
- **Audio / music (R7):** Megalovania starts at the end of the intro, pauses at the break,
  resumes for the real battle.
- **Sans sprite (R8):** head stays attached on all poses; idle no longer clobbers held
  poses; scroll/pose state resets per attack (no more "falling apart" during gravity attacks).
- **Cosmetic / content (R9):** clean platform tiling; per-turn dialogue replaced with
  verbatim Bad Time Simulator text; Undertale-style final hit added.

## [2.1.1] - 2026-06-15

### Fixed (attack fidelity vs. the Construct 2 original)

Source-level audit of the port's opcode interpreter against the original
`Event sheets/Timeline.xml` + `Battle.xml`. The VM, sequencer and timing model were
confirmed faithful; the divergences below were in the opcode handlers and setup.
Full analysis in `docs/comparison/CATALOG.md`.

- BoneVRepeat / BoneHRepeat placement: repeated bones are now offset along their
  travel axis (`StartX - cos(dir*90)*spacing*i`, `StartY - sin(dir*90)*spacing*i`) as
  in the original, instead of always offsetting on +X. Affects every attack using
  BoneVRepeat (59 call sites).
- PlatformRepeat placement: same axis/sign fix.
- Platform reverse/bounce: a reverse platform now ping-pongs inside the combat zone
  (flipping 0<->2 / 1<->3 at the edges) instead of negating its speed once and flying
  off-screen. Restores the rideable platforms in the platform attacks.
- SineBones: reimplemented to the original formula (fixed 39px gap, sine amplitude 28
  at frequency i/3, columns entering from the zone edge by spacing*i).
- SansSlam: now forces the soul into blue (gravity) mode before slamming.
- Horizontal bones are no longer clipped to the combat zone (original keeps `BoneH` on
  the unclipped layer); vertical bones stay clipped.
- Combat-zone default is now the original menu box (33,251,608,391) instead of a small
  centered square, so attacks that skip their own resize play in the correct area.
- PortMaster launcher (`sansfight/launch.sh`) is now portable across firmwares and CPU
  architectures: it resolves the control folder, reads `$DEVICE_ARCH`, runs
  `love.$DEVICE_ARCH` from the PortMaster `love_11.5` runtime, logs to `run.log`, and
  prints a clear message when the runtime is missing instead of crashing silently. (The
  previous launcher hardcoded the aarch64 path, which crashed on other devices / when the
  runtime wasn't installed.)

### Changed

- Player level now reads LV 19 (the genocide Sans fight), was LV 1.
- Sans's idle pose holds the arms-down frame instead of cycling to HandUp, so he no
  longer appears to gesture continuously while idle.
- HP/KR readout matches the original: persistent `KR` label before the value, bar width
  110 (`floor(MaxHP*1.2)`), and the HP value zero-padded to two digits ("92 / 92").

## [2.1.0] - 2026-06-14

### Added (Normal Mode)
- Turn-based fight: player menu (FIGHT/ACT/ITEM/MERCY), Sans dialogue per
  turn, the full 25-turn attack order, damage numbers
- Endings: game over (heart shatter), get dunked on, victory; Practice HP floor
- Variable jump height in blue mode (hold to jump higher)

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

### Fixed (Layout)
- Vertical bones are anchored by their top edge (matching the original
  CSV convention), so they no longer poke above the combat zone
- Bottom menu buttons use the correct 112x44 frames at the original
  positions (32/184/344/496), spanning the full width
- Sans is centered above the combat zone at the original 2x scale, with
  the head correctly attached to the jacket collar
- Bone bullets are clipped to the combat zone instead of spilling past it

### Added (Bones & Platforms)
- BoneVRepeat/BoneHRepeat now spawn Count bones spaced by Spacing (they
  previously crashed by calling a nonexistent setGap)
- Platform and PlatformRepeat: moving platforms the heart can land on and
  ride in blue mode
- Unlocked attacks: bonegap1(fast), boneslideh/v, multi1, platforms1-4(hard),
  platformblaster(fast) (17 of 24 attacks now fully playable)

### Added (Stab, Sine, Sans)
- BoneStab: wall of bones that pops from a side (warning, stab, retract)
- SineBones: moving wall of bones with a sine-wave gap
- Sans animation commands (Head/Body/Torso/Sweat/X/Animation/Repeat)
- SansSlam heart-slam mechanic with SansSlamDamage toggle
- HeartMaxFallSpeed and CombatZoneSpeed setters
- All 24 attacks now report ready and run without errors

### Unlocked Attacks
- sans_bonegap2, sans_multi1, sans_randomblaster1, sans_randomblaster2

## [2.0.0] - 2025-12-13

### Added (Love2D Port)
- Full Love2D game engine port for better performance
- Dialogue system with speech bubbles and typewriter effect
- Centralized audio system (SFX + music support)
- Attack sequencer for CSV-based attack patterns
- Attack status indicators in Single Attack menu (ready/partial/not ready)
- Scrollable menu for long attack lists
- Gaster Blaster with beam collision detection
- Combat zone resize animations
- Heart teleportation support
- Blue soul mode with gravity and jumping

### Core Systems
- `src/systems/audio.lua` - Centralized audio management
- `src/systems/attack_parser.lua` - CSV attack file parser
- `src/systems/attack_sequencer.lua` - Timeline-based attack execution
- `src/ui/dialogue.lua` - Speech bubble system

### Test States
- Dialogue Test - Test speech bubbles with Sans quotes
- Audio Test - Test all SFX and music

### Supported Attack Commands
- HeartMode, HeartTeleport
- CombatZoneResize, CombatZoneResizeInstant
- BoneV, BoneH, BoneVRepeat, BoneHRepeat
- GasterBlaster
- Sound effects
- TLPause, TLResume
- EndAttack

### Known Limitations
- Some attack commands not yet implemented (BoneStab, SineBones, Platform)
- Sans character animations not yet implemented

## [1.0.1] - 2025-12-09

### Added
- `c2-export/` folder with C2 runtime files for standalone builds
- Build script now works out of the box without external dependencies

### Changed
- Renamed project to `sans-fight-handeld`
- Updated build output folder to `sans-fight-handeld`
- Updated installation path to `/userdata/roms/jsgames/`
- Package name and repository URL updated

### Optimized
- Resolution reduced from 640x480 to 320x240 for better performance
- Removed all console.log statements
- Removed debug monitoring code

## [1.0.0] - 2025-12-09

### Added
- JSGameLauncher port for Knulli/Batocera handheld devices
- Canvas 2D rendering (WebGL disabled for Mali GPU compatibility)
- Gamepad support via keyboard mapping
- Build script for generating release packages

### Changed
- Initial resolution: 640x480
- Canvas 2D rendering for Mali GPU compatibility

### Known Limitations
- No audio (stub implementation)

---

## Original Project History

### Previous Updates (from jcw87/c2-sans-fight)

- Orange bones support
- Platform gravity improvements
- Practice mode
- Gaster Blaster hitbox accuracy
- Screen shake and final attack slam
- Touch controls (mobile)
- Custom attacks documentation
- Various bug fixes and accuracy improvements
