#!/usr/bin/env bash
# Repoint ReExtendioDylib's reexport from the placeholder empty.dylib to the
# real libSystem so the stub symbols (__sincos_stret, __exp10) get layered on
# top of the system library at runtime.
#
# Works on macOS (system install_name_tool) and Linux (Theos toolchain's
# install_name_tool). Pass the dylib path as $1, or it defaults to
# ./ReExtendioDylib.dylib.
set -e

DYLIB="${1:-ReExtendioDylib.dylib}"

# Find an install_name_tool: prefer one on PATH, then the Theos Linux toolchain.
INT="$(command -v install_name_tool || true)"
if [[ -z "$INT" && -n "$THEOS" ]]; then
  for c in \
    "$THEOS/toolchain/linux/iphone/bin/install_name_tool" \
    "$THEOS/toolchain/linux/iphone/bin/llvm-install-name-tool"; do
    [[ -x "$c" ]] && INT="$c" && break
  done
fi

if [[ -z "$INT" ]]; then
  echo "error: install_name_tool not found (set \$THEOS or add it to PATH)" >&2
  exit 1
fi

if [[ ! -f "$DYLIB" ]]; then
  echo "error: dylib not found: $DYLIB" >&2
  echo "usage: $0 [path/to/ReExtendioDylib.dylib]" >&2
  exit 1
fi

"$INT" \
  -change /usr/local/lib/empty.dylib /usr/lib/libSystem.B.dylib \
  "$DYLIB"

echo "Patched $DYLIB -> reexports /usr/lib/libSystem.B.dylib"
