@echo off
setlocal
cd /d "%~dp0"
echo ==========================================================
echo           GhostDeck 一鍵安裝與設定程式
echo ==========================================================
echo 正在啟動 PowerShell 安裝精靈...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" %*
echo.
pause
