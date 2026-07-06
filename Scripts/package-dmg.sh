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
ENTITLEMENTS="$ROOT_DIR/Packaging/entitlements.plist"
SKIP_SIGNING="${SKIP_SIGNING:-0}"
DEVELOPER_ID="${DEVELOPER_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

log_info() {
  printf '[Info] %s\n' "$*"
}

log_error() {
  printf '[Error] %s\n' "$*" >&2
}

log_info_block() {
  sed 's/^/[Info] /'
}

log_error_block() {
  sed 's/^/[Error] /' >&2
}

detect_developer_id() {
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p'
}

detach_existing_volume() {
  local volume_path="/Volumes/$VOLUME_NAME"
  if [[ -e "$volume_path" ]]; then
    log_info "Detaching existing mounted volume: $volume_path"
    /usr/bin/hdiutil detach "$volume_path" -quiet >/dev/null 2>&1 || \
      /usr/sbin/diskutil unmount force "$volume_path" >/dev/null 2>&1 || true
  fi
}

if [[ "$SKIP_SIGNING" != "1" && -z "$DEVELOPER_ID" ]]; then
  developer_ids=("${(@f)$(detect_developer_id)}")
  if [[ "${#developer_ids[@]}" == "1" && -n "${developer_ids[1]}" ]]; then
    DEVELOPER_ID="${developer_ids[1]}"
    log_info "Using detected Developer ID: $DEVELOPER_ID"
  elif [[ "${#developer_ids[@]}" == "0" || -z "${developer_ids[1]:-}" ]]; then
    log_error "No Developer ID Application certificate found in your keychain."
    log_error "Create one in Xcode: Settings -> Accounts -> Manage Certificates -> + -> Developer ID Application"
    log_error 'Then run: DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE="btt-notary" Scripts/package-dmg.sh'
    exit 1
  else
    log_error "Multiple Developer ID Application certificates found:"
    for developer_id in "${developer_ids[@]}"; do
      log_error "  $developer_id"
    done
    log_error 'Set the one to use explicitly, for example:'
    log_error 'DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE="btt-notary" Scripts/package-dmg.sh'
    exit 1
  fi
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

"$ROOT_DIR/Scripts/build-app.sh" >/dev/null

if [[ ! -d "$BUILT_APP" ]]; then
  log_error "App bundle was not built: $BUILT_APP"
  exit 1
fi

if [[ "$SKIP_SIGNING" != "1" ]]; then
  /usr/bin/codesign --force \
    --deep \
    --sign "$DEVELOPER_ID" \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    "$BUILT_APP"

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$BUILT_APP"
else
  log_info "Built unsigned app for local testing."
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

if [[ "$SKIP_SIGNING" != "1" ]]; then
  /usr/bin/codesign --force \
    --sign "$DEVELOPER_ID" \
    --timestamp \
    "$DMG_PATH"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    if ! notary_output=$(/usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait 2>&1); then
      echo "$notary_output" | log_error_block
      submission_id=$(echo "$notary_output" | awk '/id:/ {print $2; exit}')
      if [[ -n "$submission_id" ]]; then
        /usr/bin/xcrun notarytool log "$submission_id" \
          --keychain-profile "$NOTARY_PROFILE" || true
      fi
      exit 1
    fi

    echo "$notary_output" | log_info_block
    if echo "$notary_output" | grep -q "status: Invalid"; then
      submission_id=$(echo "$notary_output" | awk '/id:/ {print $2; exit}')
      if [[ -n "$submission_id" ]]; then
        /usr/bin/xcrun notarytool log "$submission_id" \
          --keychain-profile "$NOTARY_PROFILE" || true
      fi
      exit 1
    fi

    /usr/bin/xcrun stapler staple "$DMG_PATH"
    /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
  else
    log_info "NOTARY_PROFILE not set; skipping notarization."
  fi
fi

log_info "Built: $DMG_PATH"
