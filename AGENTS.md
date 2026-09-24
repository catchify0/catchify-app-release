# Project Agent Instructions

## Local Toolchain
This repository has its own local, bundled toolchain inside the `tools/` directory:
- **Flutter SDK**: `D:\.claude\catchify-app-release\tools\flutter`
- **Dart SDK**: `D:\.claude\catchify-app-release\tools\flutter\bin\cache\dart-sdk`
- **Android SDK**: `D:\.claude\catchify-app-release\tools\android-sdk`
- **ADB**: `D:\.claude\catchify-app-release\tools\android-sdk\platform-tools\adb.exe`

### Running Commands
Because the global system PATH may not include Flutter or Android tools, always activate the local environment or reference the tools directly:
- **PowerShell**:
  ```powershell
  . .\tools\env.ps1
  flutter --version
  ```
  or run directly via root convenience wrappers:
  ```powershell
  & ".\tools\flutter.bat" <command>
  & ".\tools\dart.bat" <command>
  & ".\tools\adb.bat" <command>
  ```
- **Bash / Git Bash**:
  ```bash
  source tools/env.sh
  flutter --version
  ```
  or run directly:
  ```bash
  ./tools/flutter.sh <command>
  ./tools/dart.sh <command>
  ./tools/adb.sh <command>
  ```

### Agent Skills
Agent skills are organized under `.agents/skills/`. The `.agents/skills/local-toolchain` skill provides full specification and orchestration instructions for this local toolchain.
