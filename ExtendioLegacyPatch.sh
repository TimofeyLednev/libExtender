#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 appname_payload_extracted"
  exit 1
fi

APP_NAME="$1"
APP_DIR="Payload/$APP_NAME.app"
DYLIB_DIR="$APP_DIR/dylib"
EXECUTABLE="$APP_DIR/$APP_NAME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the two dylibs: prefer copies next to this script (released zip
# bundle), then fall back to the Theos build tree.
find_dylib() {
  local name="$1"; shift
  for c in "$@"; do
    [[ -f "$c" ]] && { echo "$c"; return 0; }
  done
  echo "error: $name not found (looked in: $*)" >&2
  return 1
}

GC_SRC="$(find_dylib GameController.dylib \
  "$SCRIPT_DIR/GameController.dylib" \
  "$SCRIPT_DIR/.theos/obj/debug/GameController.dylib" \
  ".theos/obj/debug/GameController.dylib")"

RE_SRC="$(find_dylib ReExtendioDylib.dylib \
  "$SCRIPT_DIR/ReExtendioDylib.dylib" \
  "ReExtendioDylib.dylib")"

# Locate install_name_tool: PATH, then bundled tools/, then Theos toolchain.
INT="$(command -v install_name_tool || true)"
if [[ -z "$INT" ]]; then
  for c in \
    "$SCRIPT_DIR/tools/install_name_tool" \
    "${THEOS:-}/toolchain/linux/iphone/bin/install_name_tool" \
    "${THEOS:-}/toolchain/linux/iphone/bin/llvm-install-name-tool"; do
    [[ -x "$c" ]] && INT="$c" && break
  done
fi
if [[ -z "$INT" ]]; then
  echo "error: install_name_tool not found (add it to PATH, drop it in tools/, or set \$THEOS)" >&2
  exit 1
fi

# P.S: You are free to change the MinimumOSVersion to whatever you'd like.
# iOS 6 is supported though, so don't expect support beyond that.
INFO_PLIST="$APP_DIR/Info.plist"
if [[ -x /usr/libexec/PlistBuddy ]]; then
  /usr/libexec/PlistBuddy -c "set :MinimumOSVersion 6.0" "$INFO_PLIST"
elif command -v plutil >/dev/null 2>&1; then
  plutil -replace MinimumOSVersion -string 6.0 "$INFO_PLIST"
elif command -v plistutil >/dev/null 2>&1; then
  # plistutil reads binary or xml plists. Convert to xml, edit, write back as
  # binary (the format iOS Info.plists normally use).
  tmp_xml="$(mktemp)"
  plistutil -i "$INFO_PLIST" -f xml -o "$tmp_xml"
  if grep -q "<key>MinimumOSVersion</key>" "$tmp_xml"; then
    perl -0pi -e 's{(<key>MinimumOSVersion</key>\s*<string>)[^<]*(</string>)}{${1}6.0${2}}s' "$tmp_xml"
  else
    perl -0pi -e 's{</dict>\s*</plist>}{\t<key>MinimumOSVersion</key>\n\t<string>6.0</string>\n</dict>\n</plist>}s' "$tmp_xml"
  fi
  plistutil -i "$tmp_xml" -f bin -o "$INFO_PLIST"
  rm -f "$tmp_xml"
else
  echo "error: no plist editor found (need PlistBuddy, plutil, or plistutil)" >&2
  echo "       install libplist-utils:  sudo apt-get install -y libplist-utils" >&2
  exit 1
fi

mkdir -p "$DYLIB_DIR"

cp "$GC_SRC" "$DYLIB_DIR/GameController.dylib"
echo "Copied GameController.dylib to $DYLIB_DIR/"

cp "$RE_SRC" "$DYLIB_DIR/ReExtendioDylib.dylib"
echo "Copied ReExtendioDylib.dylib to $DYLIB_DIR/"

"$INT" \
  -change /System/Library/Frameworks/GameController.framework/GameController @executable_path/dylib/GameController.dylib \
  -change /usr/lib/libSystem.B.dylib @executable_path/dylib/ReExtendioDylib.dylib \
  "$EXECUTABLE"

zip -r "$APP_NAME" Payload
rm -rf Payload/
