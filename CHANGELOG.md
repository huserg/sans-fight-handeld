# Changelog

All notable changes to this project will be documented in this file.

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
