@echo off
setlocal
cd /d "%~dp0"
echo ==========================================================
echo                 GhostDeck 移除程式
echo ==========================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1" %*
echo.
pause
