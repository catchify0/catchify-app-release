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
  or run directly:
  ```powershell
  & "tools\flutter\bin\flutter.bat" <command>
  & "tools\flutter\bin\dart.bat" <command>
  & "tools\android-sdk\platform-tools\adb.exe" <command>
  ```
- **Bash / Git Bash**:
  ```bash
  source tools/env.sh
  flutter --version
  ```

### Agent Skills
Agent skills are organized under `.agents/skills/`. All skills utilize this local toolchain.
