#!/bin/bash
# PortMaster launcher for Sans Fight (Love2D port).
# Portable across PortMaster CFWs (Knulli/Batocera/muOS/ArkOS/...) and CPU
# architectures: resolves the control folder, sources control.txt for
# $directory / $DEVICE_ARCH / $ESUDO / $GPTOKEYB, and runs the PortMaster
# love_11.5 runtime for the device's architecture.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

# Resolve the PortMaster control folder across firmwares
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
get_controls

GAMEDIR="/$directory/ports/sansfight"
cd "$GAMEDIR" || exit 1

# Capture everything for debugging
exec > "$GAMEDIR/run.log" 2>&1

ARCH="${DEVICE_ARCH:-aarch64}"
RUNTIME="$controlfolder/runtimes/love_11.5"
LOVE="$RUNTIME/love.$ARCH"
LIBS="$RUNTIME/libs.$ARCH"

if [ ! -x "$LOVE" ]; then
  echo "ERROR: Love2D 11.5 runtime not found for arch '$ARCH' at:"
  echo "  $LOVE"
  echo
  echo "Install the love_11.5 runtime via PortMaster, or install this port"
  echo "through PortMaster (not by hand-copying) so the runtime is fetched."
  exit 1
fi

export LD_LIBRARY_PATH="$LIBS:$LD_LIBRARY_PATH"
export HOME="$GAMEDIR"

$ESUDO chmod +x "$LOVE" 2>/dev/null

# Gamepad-to-keyboard mapping (LÖVE also reads the pad directly via SDL,
# so this is best-effort and must not block launch).
if [ -n "$GPTOKEYB" ] && [ -f "$GAMEDIR/sansfight.gptk" ]; then
  $GPTOKEYB "love" -c "$GAMEDIR/sansfight.gptk" &
fi

"$LOVE" ./game

# Cleanup
$ESUDO kill -9 "$(pgrep -f gptokeyb)" 2>/dev/null
