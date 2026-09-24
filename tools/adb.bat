@echo off
setlocal
set "DIR=%~dp0"
"%DIR%android-sdk\platform-tools\adb.exe" %*
endlocal
