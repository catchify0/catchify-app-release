---
name: local-toolchain
description: Orchestrates and runs commands using the repository's bundled local toolchain in tools/ (Flutter SDK, Dart SDK, Android SDK, and ADB). Use whenever running flutter, dart, adb, static analysis, unit tests, or app builds in Catchify without relying on system-wide PATH.
---

# Local Toolchain

This repository bundles its own dedicated, isolated toolchain in `tools/`. All agents, subagents, and skills must strictly use this local toolchain for all Flutter, Dart, and Android operations.

## Tool Locations

| Tool | Relative Path | Windows Executable | Unix / Bash Executable |
| :--- | :--- | :--- | :--- |
| **Flutter SDK** | `tools/flutter` | `tools\flutter\bin\flutter.bat` or `tools\flutter.bat` | `tools/flutter/bin/flutter` or `tools/flutter.sh` |
| **Dart SDK** | `tools/flutter/bin/cache/dart-sdk` | `tools\flutter\bin\dart.bat` or `tools\dart.bat` | `tools/flutter/bin/dart` or `tools/dart.sh` |
| **Android SDK** | `tools/android-sdk` | `tools\android-sdk` | `tools/android-sdk` |
| **ADB** | `tools/android-sdk/platform-tools` | `tools\android-sdk\platform-tools\adb.exe` or `tools\adb.bat` | `tools/android-sdk/platform-tools/adb` or `tools/adb.sh` |

## Environment Variables

When running builds or commands, the following environment variables are set by the toolchain:
- `ANDROID_HOME`: `<repo_root>/tools/android-sdk`
- `ANDROID_SDK_ROOT`: `<repo_root>/tools/android-sdk`
- `FLUTTER_ROOT`: `<repo_root>/tools/flutter`

## Activating the Toolchain

### In PowerShell
```powershell
. .\tools\env.ps1
flutter --version
dart --version
adb version
```

### In Bash / Git Bash
```bash
source tools/env.sh
flutter --version
dart --version
adb version
```

## Direct Command Invocation

You can also directly invoke the root wrappers without modifying your shell's global session:

### Windows PowerShell / CMD
```powershell
# Run Flutter commands
& ".\tools\flutter.bat" test
& ".\tools\flutter.bat" build apk --release --flavor github

# Run Dart analysis or scripts
& ".\tools\dart.bat" analyze
& ".\tools\dart.bat" format --set-exit-if-changed lib/

# Run ADB commands
& ".\tools\adb.bat" devices
```

### Bash / Linux / macOS
```bash
./tools/flutter.sh test
./tools/dart.sh analyze
./tools/adb.sh devices
```

## Integration with other Agent Skills
When using other `.agents/skills/` (such as `flutter-build-release`, `flutter-testing`, `flutter-device-testing`, `flutter-dependency-upgrades`):
1. **Never** assume `flutter` or `dart` is in the machine's global system `PATH`.
2. Always prepend `tools\flutter\bin` and `tools\android-sdk\platform-tools` or dot-source `tools\env.ps1` before executing any workflow steps.
3. For device testing, use `tools\android-sdk\platform-tools\adb.exe` or `tools\adb.bat` to detect and control attached physical or virtual Android devices.
