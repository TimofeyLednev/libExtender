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

GC_SRC=""
if [[ -f "$SCRIPT_DIR/GameController.dylib" ]]; then
  GC_SRC="$SCRIPT_DIR/GameController.dylib"
elif [[ -f "$SCRIPT_DIR/.theos/obj/debug/GameController.dylib" ]]; then
  GC_SRC="$SCRIPT_DIR/.theos/obj/debug/GameController.dylib"
elif [[ -f ".theos/obj/debug/GameController.dylib" ]]; then
  GC_SRC=".theos/obj/debug/GameController.dylib"
fi

RE_SRC=""
if [[ -f "$SCRIPT_DIR/ReExtendioDylib.dylib" ]]; then
  RE_SRC="$SCRIPT_DIR/ReExtendioDylib.dylib"
elif [[ -f "ReExtendioDylib.dylib" ]]; then
  RE_SRC="ReExtendioDylib.dylib"
fi

if [[ -z "$GC_SRC" ]]; then
  echo "error: GameController.dylib not found" >&2
  exit 1
fi
if [[ -z "$RE_SRC" ]]; then
  echo "error: ReExtendioDylib.dylib not found" >&2
  exit 1
fi

cp "$GC_SRC" "$DYLIB_DIR/GameController.dylib"
echo "Copied GameController.dylib to $DYLIB_DIR/"

cp "$RE_SRC" "$DYLIB_DIR/ReExtendioDylib.dylib"
echo "Copied ReExtendioDylib.dylib to $DYLIB_DIR/"

"$INT" \
  -change /System/Library/Frameworks/GameController.framework/GameController @executable_path/dylib/GameController.dylib \
  -change /usr/lib/libSystem.B.dylib @executable_path/dylib/ReExtendioDylib.dylib \
  -change /System/Library/Frameworks/Foundation.framework/Foundation @executable_path/dylib/ReExtendioDylib.dylib \
  "$EXECUTABLE"

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
