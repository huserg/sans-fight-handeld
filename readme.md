# Bad Time Simulator (Sans Fight)

This project is a clone of the sans fight from [Undertale](http://undertale.com/).
It was made with [Construct 2](https://www.scirra.com/construct2).

NOW AVAILABLE! [Custom attacks guide](Documentation/README.MD)

---

## JSGameLauncher Port

This fork adds support for running the game on **Knulli/Batocera** handheld devices via [JSGameLauncher](https://github.com/monteslu/jsgamelauncher).

### Tested Devices

| Device | GPU | Status |
|--------|-----|--------|
| Anbernic RG35xx SP | Mali G31 | Working |

### Prerequisites

- [Knulli](https://knulli.org/) or [Batocera](https://batocera.org/) installed on your device
- [JSGameLauncher](https://github.com/monteslu/jsgamelauncher) installed

### Installing JSGameLauncher on Knulli

1. Connect to your device via SSH:
   ```bash
   ssh root@<device-ip>
   # Default password: linux
   ```

2. Run the installer:
   ```bash
   curl -o- https://raw.githubusercontent.com/monteslu/jsgamelauncher/main/installers/install-batocera-knulli.sh | bash
   ```

3. Reboot your device

### Installing the Game

1. Download the latest release from the [Releases](../../releases) page
2. Extract the archive to get the `sans-fight/` folder
3. Copy to your device:
   ```bash
   scp -r sans-fight root@<device-ip>:/userdata/roms/jsgames/
   ```
4. Refresh your game list or reboot

### Controls

| Button | Action |
|--------|--------|
| D-Pad / Left Stick | Move |
| A (or Z key) | Confirm |
| B (or X key) | Cancel/Back |
| Start | Escape |

### Limitations

- **No audio**: Sound is disabled (stub implementation)
- Uses Canvas 2D rendering (WebGL disabled for Mali GPU compatibility)

---

## Building from Source

> **Note**: Building requires the exported Construct 2 runtime files (`c2runtime.js`, `data.js`, etc.) which are included in releases but not in this repository. Export the project from Construct 2 first, then update the `BACKUP_DIR` path in `scripts/build.sh`.

```bash
# Build for Knulli (default)
./scripts/build.sh

# Build for specific target
./scripts/build.sh knulli
./scripts/build.sh batocera
./scripts/build.sh all
```

Output: `dist/<target>/sans-fight/`

---

## Original Project

### Known Issues
- Heart hitbox is probably not accurate.
- On the sans_platforms4 and sans_platforms4hard attacks, the platform is supposed to accelerate from 0 to its full speed, but I was lazy and started it at full speed immediately.
- Sans dialog is missing.

### Contact (Original Author)
- ~~[Facepunch](https://facepunch.com/member.php?u=13155)~~ R.I.P. Facepunch
- [Steam](http://steamcommunity.com/id/Jcw87/)

---

## Credits

- **Original Game**: [jcw87](https://github.com/jcw87/c2-sans-fight)
- **Undertale**: Toby Fox
- **JSGameLauncher**: [monteslu](https://github.com/monteslu/jsgamelauncher)
