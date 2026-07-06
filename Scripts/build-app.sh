#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/.build/DeskTodoBuddy.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/DeskTodoBuddy" "$MACOS/DeskTodoBuddy"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp -R "$ROOT/Resources/." "$RESOURCES/"

echo "$APP_DIR"
