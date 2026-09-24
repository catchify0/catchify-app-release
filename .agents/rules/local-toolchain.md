# Local Toolchain Configuration

This repository contains its own bundled Flutter SDK and Android SDK inside the `tools/` directory. All agent executions, terminal commands, builds, tests, and skills must use these local tools.

## Tool Locations
- **Flutter SDK**: `D:\.claude\catchify-app-release\tools\flutter`
  - Flutter executable: `tools\flutter\bin\flutter.bat` or `tools\flutter.bat` (Bash: `tools/flutter.sh`)
  - Dart executable: `tools\flutter\bin\dart.bat` or `tools\dart.bat` (Bash: `tools/dart.sh`)
- **Android SDK**: `D:\.claude\catchify-app-release\tools\android-sdk`
  - ADB executable: `tools\android-sdk\platform-tools\adb.exe` or `tools\adb.bat` (Bash: `tools/adb.sh`)
  - Platform tools: `tools\android-sdk\platform-tools`

## Environment Setup for Commands
Whenever running terminal commands for Flutter, Dart, or Android:
1. Ensure the following paths are prepended to `PATH` in PowerShell / Bash:
   - `D:\.claude\catchify-app-release\tools\flutter\bin`
   - `D:\.claude\catchify-app-release\tools\flutter\bin\cache\dart-sdk\bin`
   - `D:\.claude\catchify-app-release\tools\android-sdk\platform-tools`
2. Ensure environment variables are set:
   - `ANDROID_HOME = "D:\.claude\catchify-app-release\tools\android-sdk"`
   - `ANDROID_SDK_ROOT = "D:\.claude\catchify-app-release\tools\android-sdk"`
   - `FLUTTER_ROOT = "D:\.claude\catchify-app-release\tools\flutter"`

Alternatively, run commands directly referencing the root convenience wrappers or binaries, e.g.:
```powershell
& ".\tools\flutter.bat" test
& ".\tools\dart.bat" analyze
& ".\tools\adb.bat" devices
```
or dot-source `tools\env.ps1`:
```powershell
. .\tools\env.ps1
flutter --version
```

## Agent Skills
The `.agents/skills/local-toolchain` skill documents the toolchain orchestration for all automated workflows.
