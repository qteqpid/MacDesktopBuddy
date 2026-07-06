#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DISPLAY_NAME="MacDesktopBuddy"
VOLUME_NAME="MacDesktopBuddy"
BUILT_APP="$ROOT_DIR/.build/MacDesktopBuddy.app"
DMG_ROOT="$DIST_DIR/dmg-root"
RW_DMG_PATH="$DIST_DIR/MacDesktopBuddy-rw.dmg"
DMG_PATH="$DIST_DIR/MacDesktopBuddy.dmg"

log_info() {
  printf '[Info] %s\n' "$*"
}

log_error() {
  printf '[Error] %s\n' "$*" >&2
}

detach_existing_volume() {
  local volume_path="/Volumes/$VOLUME_NAME"
  if [[ -e "$volume_path" ]]; then
    log_info "Detaching existing mounted volume: $volume_path"
    /usr/bin/hdiutil detach "$volume_path" -quiet >/dev/null 2>&1 || \
      /usr/sbin/diskutil unmount force "$volume_path" >/dev/null 2>&1 || true
  fi
}

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

"$ROOT_DIR/Scripts/build-app.sh" >/dev/null

if [[ ! -d "$BUILT_APP" ]]; then
  log_error "App bundle was not built: $BUILT_APP"
  exit 1
fi

detach_existing_volume

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -size 128m \
  -type UDIF \
  -fs HFS+ \
  -ov \
  "$RW_DMG_PATH" >/dev/null

attach_output=$(/usr/bin/hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen)
device=$(echo "$attach_output" | awk '/^\/dev\// {print $1; exit}')
volume=$(echo "$attach_output" | awk 'index($0, "/Volumes/") {print substr($0, index($0, "/Volumes/")); exit}')

if [[ -z "$device" || -z "$volume" ]]; then
  log_error "Could not determine mounted DMG device or volume."
  exit 1
fi

cleanup_dmg_mount() {
  if [[ -n "${device:-}" ]]; then
    /usr/bin/hdiutil detach "$device" -quiet >/dev/null 2>&1 || true
  fi
}
trap cleanup_dmg_mount EXIT

/usr/bin/ditto "$BUILT_APP" "$volume/$APP_DISPLAY_NAME.app"
/bin/ln -s /Applications "$volume/Applications"
/usr/bin/touch "$volume/$APP_DISPLAY_NAME.app"
/usr/bin/touch "$volume"

if layout_output=$(/usr/bin/osascript <<APPLESCRIPT 2>&1
tell application "Finder"
  set dmgDisk to disk "$VOLUME_NAME"
  open dmgDisk
  delay 1

  try
    set dmgWindow to container window of dmgDisk
    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set bounds of dmgWindow to {120, 120, 760, 500}
    set viewOptions to the icon view options of dmgWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set position of item "$APP_DISPLAY_NAME.app" of dmgWindow to {180, 190}
    set position of item "Applications" of dmgWindow to {460, 190}
    update dmgDisk without registering applications
    delay 2
    close dmgWindow
  on error errorMessage
    return "Skipped Finder layout: " & errorMessage
  end try
end tell
APPLESCRIPT
); then
  if [[ -n "$layout_output" ]]; then
    log_info "$layout_output"
  else
    log_info "Configured Finder DMG window layout."
  fi
else
  log_info "Warning: Finder DMG window layout step failed; continuing. $layout_output"
fi

/bin/sync
/usr/bin/hdiutil detach "$device" -quiet
device=""

/usr/bin/hdiutil convert "$RW_DMG_PATH" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

rm -f "$RW_DMG_PATH"
rm -rf "$DMG_ROOT"

log_info "Built: $DMG_PATH"
