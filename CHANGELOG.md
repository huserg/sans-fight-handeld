# Changelog

All notable changes to this project will be documented in this file.

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
