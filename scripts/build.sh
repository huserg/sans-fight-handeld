#!/bin/bash
# Build script for handheld releases
# Generates dist/<target>/ ready to copy to the device
#
# Usage: ./build.sh [knulli|batocera|all|love] [device-ip] [password]
# Default target: knulli
#
# Targets:
#   knulli|batocera|all  JSGameLauncher build from the Construct 2 export
#   love                 LOVE (.love) package of the Love2D port (love2d/)
#
# The optional device-ip (and password) only apply to the love target: when
# set, the freshly built .love is installed to the device over scp. They can
# also be supplied via the DEVICE_IP / DEVICE_PASS environment variables.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
# Path to exported C2 runtime files (c2runtime.js, data.js, images/, media/, *.csv)
BACKUP_DIR="${C2_EXPORT_DIR:-$ROOT_DIR/c2-export}"

TARGET="${1:-knulli}"
# Device install settings (love target only); args take precedence over env
DEVICE_IP="${2:-${DEVICE_IP:-}}"
DEVICE_PASS="${3:-${DEVICE_PASS:-}}"
# Roms folder of the LOVE system on the device (Batocera/Knulli default)
LOVE_ROMS_DIR="${LOVE_ROMS_DIR:-/userdata/roms/love}"

build_target() {
    local target="$1"
    local OUTPUT_DIR="$ROOT_DIR/dist/$target/sans-fight-handeld"

    echo "================================================"
    echo "Building Sans Fight for $target..."
    echo "Output: $OUTPUT_DIR"
    echo "================================================"

    # Clean and create output directory
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"

    # Copy runtime files from backup (not in C2 source repo)
    echo "Copying runtime files..."
    cp "$BACKUP_DIR/c2runtime.js" "$OUTPUT_DIR/"
    cp "$BACKUP_DIR/data.js" "$OUTPUT_DIR/"
    cp "$BACKUP_DIR/jquery-3.4.1.min.js" "$OUTPUT_DIR/"
    cp "$BACKUP_DIR/loading-logo.png" "$OUTPUT_DIR/"

    # Copy CSV files (attack patterns)
    echo "Copying CSV files..."
    cp "$BACKUP_DIR/"*.csv "$OUTPUT_DIR/"

    # Copy images and media
    echo "Copying images..."
    cp -r "$BACKUP_DIR/images" "$OUTPUT_DIR/"

    echo "Copying media..."
    cp -r "$BACKUP_DIR/media" "$OUTPUT_DIR/"

    # Copy JSG shim files
    echo "Copying JSG shims..."
    cp "$ROOT_DIR/jsgamelauncher/game.js" "$OUTPUT_DIR/"
    cp "$ROOT_DIR/jsgamelauncher/gamepad-mapper.js" "$OUTPUT_DIR/"
    cp "$ROOT_DIR/jsgamelauncher/sans-fight.jsg" "$OUTPUT_DIR/"

    echo ""
    echo "Build complete for $target!"
    echo ""
}

# Package the Love2D port (love2d/) into a single .love archive.
# main.lua/conf.lua sit at the love2d/ root, so zipping its contents puts them
# at the archive root as LOVE requires. Dev-only files are excluded.
build_love() {
    local src="$ROOT_DIR/love2d"
    local output="$ROOT_DIR/dist/love/sans-fight.love"

    echo "================================================"
    echo "Building Sans Fight for love (.love package)..."
    echo "Output: $output"
    echo "================================================"

    mkdir -p "$(dirname "$output")"
    rm -f "$output"

    ( cd "$src" && zip -9 -r -q "$output" . \
        -x 'tests/*' 'screenshots/*' 'TODO.md' )

    echo ""
    echo "Build complete for love!"
    echo ""
}

# Copy a built artifact to the device over scp. No-op (prints a hint) when no
# device IP is configured; uses sshpass for non-interactive password auth.
install_to_device() {
    local src="$1"
    local remote_dir="$2"

    if [ -z "$DEVICE_IP" ]; then
        echo "To install, copy it to the device's LOVE roms folder:"
        echo "  scp \"$src\" root@<device-ip>:$remote_dir/"
        echo "Or re-run with: $0 love <device-ip> [password]"
        return
    fi

    echo "Installing to root@$DEVICE_IP:$remote_dir/ ..."
    if [ -n "$DEVICE_PASS" ]; then
        if command -v sshpass >/dev/null; then
            sshpass -p "$DEVICE_PASS" \
                scp -o StrictHostKeyChecking=no "$src" "root@$DEVICE_IP:$remote_dir/"
        else
            echo "sshpass not found (needed for password auth)."
            echo "Install it (sudo apt-get install -y sshpass) or use an SSH key."
            echo "Falling back to interactive scp:"
            scp "$src" "root@$DEVICE_IP:$remote_dir/"
        fi
    else
        scp "$src" "root@$DEVICE_IP:$remote_dir/"
    fi

    echo "Installed. Refresh the game list on the device (or reboot)."
}

case "$TARGET" in
    knulli)
        build_target "knulli"
        echo "To install on Knulli:"
        echo "  scp -r $ROOT_DIR/dist/knulli/sans-fight-handeld root@<device-ip>:/userdata/roms/jsgames/"
        ;;
    batocera)
        build_target "batocera"
        echo "To install on Batocera:"
        echo "  scp -r $ROOT_DIR/dist/batocera/sans-fight-handeld root@<device-ip>:/userdata/roms/jsgames/"
        ;;
    all)
        build_target "knulli"
        build_target "batocera"
        echo "Both builds complete!"
        ;;
    love)
        build_love
        install_to_device "$ROOT_DIR/dist/love/sans-fight.love" "$LOVE_ROMS_DIR"
        ;;
    *)
        echo "Usage: $0 [knulli|batocera|all|love] [device-ip] [password]"
        exit 1
        ;;
esac
