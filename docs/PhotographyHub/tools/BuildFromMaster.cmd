@echo off
setlocal
set SCRIPT=%~dp0BuildAllFromMaster.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
echo.
pause
endlocal
