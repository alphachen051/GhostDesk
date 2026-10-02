@echo off
setlocal
set "EXE=%LOCALAPPDATA%\Programs\GhostDeck\GhostDeck-win-x64.exe"
if not exist "%EXE%" set "EXE=%~dp0bin\GhostDeck-win-x64.exe"

if not exist "%EXE%" (
    echo [ERROR] 找不到 GhostDeck 執行檔！請先執行 install.bat
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%EXE%' -Verb RunAs"
