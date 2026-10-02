#requires -RunAsAdministrator
# 探測 MSI 熱鍵事件代碼 — 按鍵後看 MSIEvt 數值
# 唯讀：只訂閱事件，不改任何設定。Ctrl+C 或等 60 秒自動結束。
$ErrorActionPreference = 'Stop'
$d = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = "$d\fnkeys-log.txt"

"=== Fn 鍵事件探測 $(Get-Date -Format s) ===" | Tee-Object -FilePath $log -Append

try {
    Register-CimIndicationEvent -Namespace 'root\WMI' -Query 'SELECT * FROM MSI_Event' -SourceIdentifier 'MSIEvt' -ErrorAction Stop
    Write-Host "已訂閱 MSI_Event" -ForegroundColor Green
} catch {
    Write-Host "訂閱失敗: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "(表示這台機器的 Fn 鍵不走 MSI_Event，要改用別的攔截方式)" -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "請依序按下面這些鍵，每按一次停約 2 秒：" -ForegroundColor Cyan
Write-Host "  1) Fn+F7     <- 重點，這個要記下來"
Write-Host "  2) Fn+F8     (對照組)"
Write-Host "  3) Fn+F9     (對照組)"
Write-Host "  4) 鍵盤背光鍵 (對照組)"
Write-Host ""
Write-Host "60 秒後自動結束。沒有任何輸出 = Fn 鍵不經過 MSI_Event。" -ForegroundColor Yellow
Write-Host ("-" * 60)

$deadline = (Get-Date).AddSeconds(60)
$seen = 0
while ((Get-Date) -lt $deadline) {
    $e = Get-Event -SourceIdentifier 'MSIEvt' -ErrorAction SilentlyContinue
    foreach ($evt in @($e)) {
        if (-not $evt) { continue }
        $obj = $evt.SourceEventArgs.NewEvent
        $line = "  [{0:HH:mm:ss}] MSIEvt = {1}  (0x{1:X})  Instance={2}" -f (Get-Date), $obj.MSIEvt, $obj.InstanceName
        $line | Tee-Object -FilePath $log -Append
        Write-Host $line -ForegroundColor Green
        Remove-Event -EventIdentifier $evt.EventIdentifier
        $seen++
    }
    Start-Sleep -Milliseconds 150
}

Unregister-Event -SourceIdentifier 'MSIEvt' -ErrorAction SilentlyContinue
Write-Host ("-" * 60)
if ($seen -eq 0) {
    "結果: 完全沒收到事件 — Fn 鍵不走 MSI_Event，需改用別的方式" | Tee-Object -FilePath $log -Append
} else {
    "結果: 共收到 $seen 個事件，紀錄在 $log" | Tee-Object -FilePath $log -Append
}
