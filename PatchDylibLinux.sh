#!/usr/bin/env bash
# Deprecated: kept for backwards compatibility.
#
# The old flow shipped a prebuilt `arm-apple-darwin11-install_name_tool` binary
# because there was no working iOS toolchain on Linux. With the Theos Linux
# toolchain (clang + cctools, including install_name_tool) this is no longer
# needed -- PatchDylib.sh now works identically on macOS and Linux.
#
# This wrapper just forwards to PatchDylib.sh.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "PatchDylibLinux.sh is deprecated; use PatchDylib.sh (works on Linux too)." >&2
exec "$DIR/PatchDylib.sh" "$@"
