# 純被動基線 — 完全不按鍵，看哪些 MSIEvt 代碼會自己冒出來
# 不需系管。輸出 CSV 含毫秒時戳，供後續分析間隔。
$ErrorActionPreference = 'Stop'
$d   = Split-Path -Parent $MyInvocation.MyCommand.Path
$csv = "$d\baseline-events.csv"
$SEC = 120

Register-CimIndicationEvent -Namespace 'root\WMI' -Query 'SELECT * FROM MSI_Event' -SourceIdentifier 'BL' -ErrorAction Stop

$rows = @()
$end  = (Get-Date).AddSeconds($SEC)
while ((Get-Date) -lt $end) {
    foreach ($evt in @(Get-Event -SourceIdentifier 'BL' -ErrorAction SilentlyContinue)) {
        if (-not $evt) { continue }
        $rows += [pscustomobject]@{
            Time = (Get-Date).ToString('HH:mm:ss.fff')
            Code = '0x{0:X}' -f $evt.SourceEventArgs.NewEvent.MSIEvt
            Raw  = $evt.SourceEventArgs.NewEvent.MSIEvt
        }
        Remove-Event -EventIdentifier $evt.EventIdentifier
    }
    Start-Sleep -Milliseconds 100
}
Unregister-Event -SourceIdentifier 'BL' -EA SilentlyContinue

$rows | Export-Csv $csv -NoTypeInformation -Encoding UTF8
"收集 $($rows.Count) 個事件 -> $csv"
