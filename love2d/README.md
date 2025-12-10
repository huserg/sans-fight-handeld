# LÖVE2D rebuild

This folder contains a lightweight LÖVE2D reimplementation of **Bad Time Simulator (Sans Fight)** for handheld consoles that struggle with the Construct2 runtime.

## Running locally

Install [LÖVE](https://love2d.org) 11.x, then launch from the repository root:

```bash
love love2d
```

The engine reads the original CSV timelines from `c2-export/` to drive attack patterns and reuses the exported textures. Controls mirror the existing JSGameLauncher build (arrow keys/WASD to move, space/up to jump in blue mode, Esc to quit).

## Notes

- Audio is intentionally stubbed to keep the build lightweight.
- The interpreter focuses on `sans_final.csv`, which contains the full fight timeline.
