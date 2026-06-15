# Bad Time Simulator (Sans Fight) — Love2D port

A [LÖVE (Love2D)](https://love2d.org/) port of [jcw87's Construct 2 Sans fight](https://github.com/jcw87/c2-sans-fight),
packaged to run on **Knulli / Batocera handhelds via PortMaster**. The port aims to stay
faithful to the original: the 24 attack programs are the original's own CSV files, run by a
re-implementation of the Construct 2 attack VM. See
[`docs/comparison/CATALOG.md`](docs/comparison/CATALOG.md) for the fidelity audit.

---

## Play on a handheld (PortMaster) — recommended

### Prerequisites

- [Knulli](https://knulli.org/) or [Batocera](https://batocera.org/) on the device.
- [PortMaster](https://portmaster.games/) installed, including the **`love_11.5` runtime**
  (PortMaster fetches it automatically on first launch of a LÖVE port if missing).

### Install

A ready-to-install port lives in [`dist/release/`](dist/release/)
(`sansfight-port-<version>.zip`). It contains a `Sans Fight.sh` launcher and a
`sansfight/` folder, and installs into the device's ports directory.

```bash
# From your PC, copy the release zip to the device
scp dist/release/sansfight-port-v2.1.1.zip root@<device-ip>:/userdata/roms/ports/
#   default Knulli/Batocera SSH password: linux

# On the device, extract into the ports folder
ssh root@<device-ip>
cd /userdata/roms/ports
unzip -o sansfight-port-v2.1.1.zip && rm sansfight-port-v2.1.1.zip
```

Refresh the game list (or reboot). **Sans Fight** appears under **Ports**.

The launcher runs the game from `/userdata/roms/ports/sansfight/game` with the PortMaster
LÖVE 11.5 runtime — no extra files needed.

---

## Run locally (desktop, for development/testing)

Requires **LÖVE 11.5** (`love --version` should report `11.5`).

```bash
cd love2d
love .
```

### Dev visual autopilot

Drives a single attack without input so the rendered output can be captured (screenshots
land in the LÖVE save dir under `shots/`). Inert unless `SANS_AUTOPILOT` is set.

```bash
cd love2d
SANS_AUTOPILOT=sans_platforms4 SANS_AUTOPILOT_TIME=7 SANS_AUTOPILOT_HOLD=right love .
# env: SANS_AUTOPILOT (attack name) · _TIME (seconds) · _INTERVAL (shot interval)
#      _HOLD (held keys, e.g. "right,up") · _JUMP (z-pulse interval) · _MODE (normal|practice)
```

### Tests

Headless Lua test suite (pure-Lua VM/sequencer, no LÖVE needed):

```bash
cd love2d
lua5.4 tests/run_tests.lua    # or: lua tests/run_tests.lua
```

---

## Controls

| Input | Action |
|-------|--------|
| D-Pad / Left Stick / Arrow keys | Move the soul |
| A / `Z` / `Enter` | Confirm · jump (blue mode) |
| Up / `Z` | Jump in blue mode (hold longer = higher) |
| B / `X` | Cancel / back |
| Start / `Esc` | Pause / quit |

---

## Building from source

### Handheld port (PortMaster)

Released ports are pre-built in `dist/release/sansfight-port-<version>.zip`. A port bundles
the current `love2d/` source (`main.lua`, `conf.lua`, `src/`, `attacks/`, `assets/`) under
`sansfight/game/`, alongside the PortMaster launcher (`Sans Fight.sh`, `sansfight/launch.sh`,
`sansfight/port.json`, `sansfight/sansfight.gptk`). The dev-only `tools/autopilot.lua` and the
headless `tests/` are excluded.

### Desktop `.love`

```bash
./scripts/build.sh love      # -> dist/love/sans-fight.love
```

### Legacy JSGameLauncher (Construct 2) build

The original Construct 2 export in `c2-export/` can still be built for
[JSGameLauncher](https://github.com/monteslu/jsgamelauncher):

```bash
./scripts/build.sh knulli    # or: batocera | all
```

This path predates the Love2D port and is no longer the recommended way to play.

---

## Project layout

```
love2d/            LÖVE port (the game)
  main.lua conf.lua
  src/             core, systems (attack VM/sequencer), entities, states, ui
  attacks/         the 24 attack CSV programs (identical to the original)
  assets/          sprites, audio, fonts
  tests/           headless Lua test suite
  tools/           dev autopilot (excluded from builds)
c2-export/         original Construct 2 export (runtime + the same CSVs)
Event sheets/      original Construct 2 event sheets (Timeline.xml, Battle.xml, ...)
Layouts/           original Construct 2 layouts (BattleScreen.xml, ...)
docs/comparison/   fidelity catalog: port vs. original
scripts/build.sh   build helper (love / JSGameLauncher targets)
dist/release/      pre-built handheld ports and .love packages
```

---

## Credits

- **Original game**: [jcw87 — c2-sans-fight](https://github.com/jcw87/c2-sans-fight)
- **Undertale**: Toby Fox
- **PortMaster**: <https://portmaster.games/>
- **JSGameLauncher** (legacy port path): [monteslu](https://github.com/monteslu/jsgamelauncher)

Custom attacks guide (original): [`Documentation/README.MD`](Documentation/README.MD)
