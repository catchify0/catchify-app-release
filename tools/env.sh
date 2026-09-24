#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

export ANDROID_HOME="$REPO_ROOT/tools/android-sdk"
export ANDROID_SDK_ROOT="$REPO_ROOT/tools/android-sdk"
export FLUTTER_ROOT="$REPO_ROOT/tools/flutter"

FLUTTER_BIN="$REPO_ROOT/tools/flutter/bin"
DART_BIN="$FLUTTER_BIN/cache/dart-sdk/bin"
ADB_BIN="$REPO_ROOT/tools/android-sdk/platform-tools"

export PATH="$FLUTTER_BIN:$DART_BIN:$ADB_BIN:$PATH"

echo "Catchify local environment configured:"
echo "  Flutter SDK : $FLUTTER_BIN"
echo "  Dart SDK    : $DART_BIN"
echo "  Android SDK : $ANDROID_HOME"
