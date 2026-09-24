#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/android-sdk/platform-tools/adb.exe" ]; then
  exec "$SCRIPT_DIR/android-sdk/platform-tools/adb.exe" "$@"
else
  exec "$SCRIPT_DIR/android-sdk/platform-tools/adb" "$@"
fi
