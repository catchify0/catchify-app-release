# Local Toolchain Configuration

This repository contains its own bundled Flutter SDK and Android SDK inside the `tools/` directory. All agent executions, terminal commands, builds, tests, and skills must use these local tools.

## Tool Locations
- **Flutter SDK**: `D:\.claude\catchify-app-release\tools\flutter`
  - Flutter executable: `D:\.claude\catchify-app-release\tools\flutter\bin\flutter.bat` (or `tools\flutter\bin\flutter`)
  - Dart executable: `D:\.claude\catchify-app-release\tools\flutter\bin\dart.bat` (or `tools\flutter\bin\dart`)
- **Android SDK**: `D:\.claude\catchify-app-release\tools\android-sdk`
  - ADB executable: `D:\.claude\catchify-app-release\tools\android-sdk\platform-tools\adb.exe`
  - Command-line tools: `D:\.claude\catchify-app-release\tools\android-sdk\cmdline-tools`

## Environment Setup for Commands
Whenever running terminal commands for Flutter, Dart, or Android:
1. Ensure the following paths are prepended to `PATH` in PowerShell / Bash:
   - `D:\.claude\catchify-app-release\tools\flutter\bin`
   - `D:\.claude\catchify-app-release\tools\android-sdk\platform-tools`
2. Ensure environment variables are set:
   - `ANDROID_HOME = "D:\.claude\catchify-app-release\tools\android-sdk"`
   - `ANDROID_SDK_ROOT = "D:\.claude\catchify-app-release\tools\android-sdk"`

Alternatively, run commands directly referencing the binaries, e.g.:
```powershell
& "tools\flutter\bin\flutter.bat" test
& "tools\flutter\bin\dart.bat" analyze
& "tools\android-sdk\platform-tools\adb.exe" devices
```
or dot-source `tools\env.ps1`.
