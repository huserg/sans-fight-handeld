# Changelog

All notable changes to this project will be documented in this file.

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
