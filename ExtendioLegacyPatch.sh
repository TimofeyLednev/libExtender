#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <app-name|path-to-.app|Payload>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${1%/}"

resolve_app_dir() {
  local arg="$1"

  if [[ -d "$arg" && "$arg" == *.app ]]; then
    echo "$arg"
    return 0
  fi

  if [[ -d "$arg" && "$(basename "$arg")" == "Payload" ]]; then
    local apps=("$arg"/*.app)
    if [[ ${#apps[@]} -eq 1 && -e "${apps[0]}" ]]; then
      echo "${apps[0]}"
      return 0
    fi
  fi

  if [[ -d "$arg" ]]; then
    local apps=("$arg"/*.app)
    if [[ ${#apps[@]} -eq 1 && -e "${apps[0]}" ]]; then
      echo "${apps[0]}"
      return 0
    fi
  fi

  if [[ -d "Payload/$arg.app" ]]; then
    echo "Payload/$arg.app"
    return 0
  fi

  if [[ -d "Payload/$arg" ]]; then
    echo "Payload/$arg"
    return 0
  fi

  if [[ -d "$arg.app" ]]; then
    echo "$arg.app"
    return 0
  fi

  local apps=(./*.app Payload/*.app)
  local found=()
  for app in "${apps[@]}"; do
    [[ -d "$app" ]] && found+=("${app#./}")
  done
  if [[ "$arg" == "Payload" && ${#found[@]} -eq 1 ]]; then
    echo "${found[0]}"
    return 0
  fi

  echo "error: could not find an app bundle for: $arg" >&2
  echo "       examples: ./ExtendioLegacyPatch.sh RedBall4_Paid.app" >&2
  echo "                 ./ExtendioLegacyPatch.sh Payload/" >&2
  exit 1
}

APP_DIR="$(resolve_app_dir "$INPUT")"
APP_BUNDLE_NAME="$(basename "$APP_DIR")"
APP_NAME="${APP_BUNDLE_NAME%.app}"
INFO_PLIST="$APP_DIR/Info.plist"
DYLIB_DIR="$APP_DIR/dylib"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "error: missing Info.plist at $INFO_PLIST" >&2
  exit 1
fi

EXECUTABLE_NAME="$(python3 - "$INFO_PLIST" <<'PY'
from plistlib import load
from pathlib import Path
import sys

path = Path(sys.argv[1])
with path.open('rb') as f:
    plist = load(f)
name = plist.get('CFBundleExecutable')
if not name:
    raise SystemExit(1)
print(name)
PY
)"

if [[ -z "$EXECUTABLE_NAME" ]]; then
  EXECUTABLE_NAME="$APP_NAME"
fi

EXECUTABLE="$APP_DIR/$EXECUTABLE_NAME"

if [[ ! -f "$EXECUTABLE" ]]; then
  echo "error: executable not found at $EXECUTABLE" >&2
  exit 1
fi

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
  echo "error: install_name_tool not found (put it on PATH, keep tools/install_name_tool next to this script, or set THEOS)" >&2
  exit 1
fi

python3 - "$INFO_PLIST" <<'PY'
from plistlib import load, dump, FMT_BINARY
from pathlib import Path
import sys

path = Path(sys.argv[1])
with path.open('rb') as f:
    plist = load(f)
plist['MinimumOSVersion'] = '6.0'
with path.open('wb') as f:
    dump(plist, f, fmt=FMT_BINARY)
PY

mkdir -p "$DYLIB_DIR"

# Resolve a built dylib by name, checking (in order): next to this script,
# the script's .theos build dir, and the local .theos build dir.
resolve_dylib() {
  local name="$1"
  for c in \
    "$SCRIPT_DIR/$name" \
    "$SCRIPT_DIR/.theos/obj/debug/$name" \
    ".theos/obj/debug/$name"; do
    [[ -f "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

# Find an otool to detect what the executable actually links. Optional —
# if missing we fall back to applying every known framework change (which
# install_name_tool treats as a no-op when the load command is absent).
OTOOL="$(command -v otool || true)"
if [[ -z "$OTOOL" ]]; then
  for c in \
    "$SCRIPT_DIR/tools/otool" \
    "${THEOS:-}/toolchain/linux/iphone/bin/otool" \
    "${THEOS:-}/toolchain/linux/iphone/bin/llvm-otool"; do
    [[ -x "$c" ]] && OTOOL="$c" && break
  done
fi

links_framework() {
  # $1 = framework load-command path; returns 0 if the executable links it
  local path="$1"
  if [[ -n "$OTOOL" ]]; then
    "$OTOOL" -L "$EXECUTABLE" 2>/dev/null | grep -qF "$path"
  else
    # No otool available — assume it links so we apply the change anyway.
    return 0
  fi
}

# --- ReExtendioDylib: always required (missing-symbol stubs + libSystem reexport) ---
RE_SRC=""
if [[ -f "$SCRIPT_DIR/ReExtendioDylib.dylib" ]]; then
  RE_SRC="$SCRIPT_DIR/ReExtendioDylib.dylib"
elif [[ -f "ReExtendioDylib.dylib" ]]; then
  RE_SRC="ReExtendioDylib.dylib"
fi
if [[ -z "$RE_SRC" ]]; then
  echo "error: ReExtendioDylib.dylib not found" >&2
  exit 1
fi
cp "$RE_SRC" "$DYLIB_DIR/ReExtendioDylib.dylib"
echo "Copied ReExtendioDylib.dylib to $DYLIB_DIR/"

# install_name_tool args, built up as needed.
INT_ARGS=(-change /usr/lib/libSystem.B.dylib @executable_path/dylib/ReExtendioDylib.dylib)

# Repoint Foundation/AVFoundation/UIKit to the shim as well so iOS 7/8-only
# symbols (NSURLSession, NSProgress, UIAlertController, AVSpeechSynthesizer, ...)
# resolve on iOS 6. Everything else falls through to the real framework via the
# shim's reexports.
SHIM_FRAMEWORKS=(
  "/System/Library/Frameworks/Foundation.framework/Foundation"
  "/System/Library/Frameworks/AVFoundation.framework/AVFoundation"
  "/System/Library/Frameworks/UIKit.framework/UIKit"
)
for fwpath in "${SHIM_FRAMEWORKS[@]}"; do
  INT_ARGS+=(-change "$fwpath" @executable_path/dylib/ReExtendioDylib.dylib)
done

# --- Stub frameworks: only repoint the ones this executable actually links. ---
# name|dylib|framework-load-command-path
STUBS=(
  "GameController|GameController.dylib|/System/Library/Frameworks/GameController.framework/GameController"
  "Photos|Photos.dylib|/System/Library/Frameworks/Photos.framework/Photos"
)

for entry in "${STUBS[@]}"; do
  IFS='|' read -r sname sdylib spath <<<"$entry"
  if ! links_framework "$spath"; then
    echo "Skipping $sname (executable does not link $spath)"
    continue
  fi
  if ! src="$(resolve_dylib "$sdylib")"; then
    echo "error: $sdylib not found (needed for $spath)" >&2
    exit 1
  fi
  cp "$src" "$DYLIB_DIR/$sdylib"
  echo "Copied $sdylib to $DYLIB_DIR/"
  INT_ARGS+=(-change "$spath" "@executable_path/dylib/$sdylib")
done

"$INT" "${INT_ARGS[@]}" "$EXECUTABLE"

# --- Nested Mach-O binaries (frameworks, dylibs) -------------------------------
# iOS uses a two-level namespace, so a nested framework (e.g. XSAPITCUI) that
# references iOS 7/8-only symbols looks them up in *its own* framework load
# command, not the app's. Repoint Foundation/AVFoundation/UIKit -> the shim in
# every bundled Mach-O that links them so those symbols resolve from the shim
# while everything else falls through to the real framework via reexport.
# @executable_path always resolves to the main executable's directory, even for
# nested binaries, so the relative path stays valid.
SHIM_REL="@executable_path/dylib/ReExtendioDylib.dylib"

is_macho() {
  # crude Mach-O sniff: read 4-byte magic
  local f="$1"
  local magic
  magic="$(od -An -tx1 -N4 "$f" 2>/dev/null | tr -d ' \n')"
  case "$magic" in
    cffaedfe|feedface|feedfacf|cefaedfe|cafebabe|bebafeca) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r -d '' bin; do
  # Skip the main executable (already handled) and our injected dylib/ folder.
  [[ "$bin" == "$EXECUTABLE" ]] && continue
  [[ "$bin" == "$DYLIB_DIR/"* ]] && continue
  is_macho "$bin" || continue

  for fwpath in "${SHIM_FRAMEWORKS[@]}"; do
    if [[ -n "$OTOOL" ]]; then
      if "$OTOOL" -L "$bin" 2>/dev/null | grep -qF "$fwpath"; then
        "$INT" -change "$fwpath" "$SHIM_REL" "$bin" 2>/dev/null \
          && echo "Repointed ${fwpath##*/} -> shim in ${bin#$APP_DIR/}"
      fi
    else
      "$INT" -change "$fwpath" "$SHIM_REL" "$bin" 2>/dev/null \
        && echo "Repointed ${fwpath##*/} -> shim in ${bin#$APP_DIR/}"
    fi
  done
done < <(find "$APP_DIR" -type f -print0)

# Stage into a proper IPA layout (Payload/<App>.app) and zip it up, no matter
# where the .app currently lives.
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/Payload"
cp -a "$APP_DIR" "$STAGE/Payload/$APP_BUNDLE_NAME"
OUT="$PWD/$APP_NAME.ipa"
rm -f "$OUT"
( cd "$STAGE" && zip -qr "$OUT" Payload )
rm -rf "$STAGE"
echo "Created $OUT"
