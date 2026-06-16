#!/bin/bash
# PortMaster launcher for Sans Fight (Love2D port).
# Portable across PortMaster firmwares/architectures. Logs from the very first
# line so a launch failure is always captured in run.log.

# GAMEDIR is the folder this script lives in (robust regardless of how it's run).
GAMEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$GAMEDIR" || exit 1

# Log everything from the start.
exec > "$GAMEDIR/run.log" 2>&1
echo "[launch] start; GAMEDIR=$GAMEDIR HOME=${HOME:-unset}"

# Some firmwares launch ports with HOME unset; default it for XDG resolution.
export HOME="${HOME:-/root}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# Resolve the PortMaster control folder across firmwares.
for cf in \
  "/opt/system/Tools/PortMaster" \
  "/opt/tools/PortMaster" \
  "$XDG_DATA_HOME/PortMaster" \
  "/userdata/system/.local/share/PortMaster" \
  "/storage/.config/PortMaster" \
  "/roms/ports/PortMaster" \
  "/roms2/ports/PortMaster" ; do
  if [ -d "$cf" ]; then controlfolder="$cf"; break; fi
done
echo "[launch] controlfolder=$controlfolder"

if [ -z "$controlfolder" ] || [ ! -f "$controlfolder/control.txt" ]; then
  echo "[launch] ERROR: PortMaster control folder not found."
  exit 1
fi

source "$controlfolder/control.txt"
get_controls

ARCH="${DEVICE_ARCH:-aarch64}"
RUNTIME="$controlfolder/runtimes/love_11.5"
LOVE="$RUNTIME/love.$ARCH"
LIBS="$RUNTIME/libs.$ARCH"
echo "[launch] ARCH=$ARCH LOVE=$LOVE"

if [ ! -x "$LOVE" ]; then
  echo "[launch] ERROR: Love2D 11.5 runtime not found for arch '$ARCH' at: $LOVE"
  echo "Install the love_11.5 runtime via PortMaster, or install this port through"
  echo "PortMaster (not by hand-copying) so the runtime is fetched."
  exit 1
fi

export LD_LIBRARY_PATH="$LIBS:$LD_LIBRARY_PATH"
$ESUDO chmod +x "$LOVE" 2>/dev/null

# Gamepad-to-keyboard mapping (LÖVE also reads the pad via SDL; best-effort).
if [ -n "$GPTOKEYB" ] && [ -f "$GAMEDIR/sansfight.gptk" ]; then
  $GPTOKEYB "love" -c "$GAMEDIR/sansfight.gptk" &
fi

echo "[launch] starting love..."
"$LOVE" ./game
echo "[launch] love exited with code $?"

$ESUDO kill -9 "$(pgrep -f gptokeyb)" 2>/dev/null
