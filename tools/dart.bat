@echo off
setlocal
set "DIR=%~dp0"
"%DIR%flutter\bin\dart.bat" %*
endlocal
