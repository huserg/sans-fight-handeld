#!/bin/bash
# Build script for JSGameLauncher release
# Generates dist/<target>/sans-fight/ ready to copy to device
#
# Usage: ./build.sh [knulli|batocera|all]
# Default: knulli

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
# Path to exported C2 runtime files (c2runtime.js, data.js, images/, media/, *.csv)
BACKUP_DIR="${C2_EXPORT_DIR:-$ROOT_DIR/c2-export}"

TARGET="${1:-knulli}"

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
    *)
        echo "Usage: $0 [knulli|batocera|all]"
        exit 1
        ;;
esac
