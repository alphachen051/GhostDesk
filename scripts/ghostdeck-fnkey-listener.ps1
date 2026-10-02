# Fn+F7 -> GhostDeck 常駐監聽器
# 以一般使用者 (i374) 身分執行，不需提權 — MSI_Event 訂閱實測不需系管。
#
# 代碼 0x22001D 為本機實測 (Stealth 14 Studio A13VF, 2026-10-02)：
#   Fn+F7 專屬；Fn+F8 / F9 / 背光鍵只送通用的 0x22000B，不會誤觸發。
$ErrorActionPreference = 'Continue'

$CODE     = 2228253   # 0x22001D
$DEBOUNCE = 3         # 秒 — 一次按鍵可能連噴多個事件
$exe      = Join-Path $PSScriptRoot 'GhostDeck-win-x64.exe'
$logDir   = Join-Path $env:LOCALAPPDATA 'GhostDeck'
$log      = Join-Path $logDir 'fnkey.log'

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Log($m) {
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 1MB) { Clear-Content $log }
    "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $m | Add-Content $log
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class GdWin {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@

Log ("listener 啟動 — 身分 {0}, 監聽 0x{1:X}" -f $env:USERNAME, $CODE)
if (-not (Test-Path $exe)) { Log "致命錯誤: 找不到 $exe，結束"; exit 1 }

try {
    Register-CimIndicationEvent -Namespace 'root\WMI' -Query 'SELECT * FROM MSI_Event' `
        -SourceIdentifier 'GDFn' -ErrorAction Stop
} catch {
    Log "致命錯誤: 無法訂閱 MSI_Event — $($_.Exception.Message)"
    exit 1
}

$last = [datetime]::MinValue
while ($true) {
    $evt = Wait-Event -SourceIdentifier 'GDFn'
    $code = $evt.SourceEventArgs.NewEvent.MSIEvt
    Remove-Event -EventIdentifier $evt.EventIdentifier

    if ($code -ne $CODE) { continue }
    if (((Get-Date) - $last).TotalSeconds -lt $DEBOUNCE) { continue }
    $last = Get-Date

    $p = Get-Process -Name 'GhostDeck*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero) {
        # 已在執行 — 叫到前景。實測中完整性行程可以啟用高完整性視窗。
        Log "Fn+F7 -> 已在執行 (PID $($p.Id))，帶到前景"
        [GdWin]::ShowWindow($p.MainWindowHandle, 9) | Out-Null   # SW_RESTORE
        [GdWin]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
    }
    elseif ($p) {
        Log "Fn+F7 -> 已在執行 (PID $($p.Id)) 但沒有視窗，略過"
    }
    else {
        # 沒在跑 — GhostDeck 需要系管才能存取 EC，所以必須提權，會跳 UAC。
        Log "Fn+F7 -> 啟動 GhostDeck (需提權，會跳 UAC)"
        try { Start-Process $exe -Verb RunAs -ErrorAction Stop }
        catch { Log "  啟動失敗 (可能是 UAC 被取消): $($_.Exception.Message)" }
    }
}
