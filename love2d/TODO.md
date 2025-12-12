# Sans Fight - Love2D Port

## Done

### Core
- [x] Project structure and configuration
- [x] State management system (loading, menu, battle)
- [x] Input system (keyboard + gamepad support)
- [x] Assets configuration centralization

### Fonts
- [x] Sprite font system with variable character widths
- [x] DefaultFont (10x16, lowercase support)
- [x] BattleFont (6x6, uppercase only)
- [x] SansFont (16x16, lowercase support)
- [x] DamageFont (33x32, lowercase support)
- [x] Font test state for debugging

### Menu
- [x] Main menu with mode selection
- [x] Heart cursor with correct orientation
- [x] Menu navigation (keyboard + gamepad)

### Battle - Core
- [x] Combat zone with white border
- [x] Combat zone resize support (instant + animated)
- [x] Player heart entity
- [x] Heart red mode (free movement)
- [x] Heart blue mode (gravity + jump)
- [x] Heart rotation (point down)
- [x] Invincibility frames with flashing
- [x] HP bar UI

### Entities
- [x] Bone entity with variable length
- [x] Bone 9-slice rendering (caps + middle repeat)
- [x] Blue bone support (only hurts when moving)
- [x] Test bone spawner
- [x] Gaster Blaster entity with animation states
- [x] Gaster Blaster beam rendering
- [x] Sans character entity
- [x] Sans expressions (9 facial expressions)
- [x] Sans idle animation

### Debug
- [x] Hidden test menu (press T in main menu)
- [x] Font test
- [x] Heart modes test
- [x] Bone rendering test
- [x] Combat zone test
- [x] HP bar test
- [x] Sans character test
- [x] Gaster Blaster test
- [x] Audio test

---

## In Progress

### Battle - Attacks
- [ ] Attack sequencer system
- [ ] Load attacks from Lua files

---

## Todo

### Battle - Attacks
- [ ] Bone stab attack
- [ ] Bone slide horizontal
- [ ] Bone slide vertical
- [ ] Bone gap patterns
- [ ] Platform bones
- [ ] Gaster blaster attack patterns
- [ ] Blue/orange bone attacks

### Battle - UI
- [ ] Sans positioning in battle
- [ ] Dialogue system with SansFont
- [ ] Speech bubble
- [ ] Battle menu (Fight/Act/Item/Mercy)
- [ ] Damage numbers with DamageFont
- [ ] KR (Karma) poison damage display

### Audio
- [ ] Music playback (Megalovania)
- [ ] Sound effects system
- [ ] Menu sounds
- [ ] Battle sounds (damage, bones, blasters)

### Game Modes
- [ ] Normal mode (full fight sequence)
- [ ] Practice mode (infinite HP)
- [ ] Endless mode (random attacks)
- [ ] Single attack mode (attack selector)
- [ ] Custom attack mode

### Polish
- [ ] Game over screen
- [ ] Victory screen
- [ ] Pause menu
- [ ] Settings menu
- [ ] Screen shake effects
- [ ] Particle effects

### Handheld Support
- [ ] Touch controls
- [ ] Screen scaling for different resolutions
- [ ] Performance optimization

---

## Notes

- BattleFont has no lowercase characters (ASCII 32-95 only)
- Original game uses Construct 2 with SpriteFont2 plugin
- Target resolution: 640x480
- Love2D version: 11.4+
