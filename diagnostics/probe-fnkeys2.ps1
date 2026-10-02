#requires -RunAsAdministrator
# 分階段探測 — 找出 Fn+F7 專屬的 MSIEvt 代碼
# 唯讀：只訂閱 WMI 事件，不改任何設定。
$ErrorActionPreference = 'Stop'
$d = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = "$d\fnkeys-log2.txt"

Register-CimIndicationEvent -Namespace 'root\WMI' -Query 'SELECT * FROM MSI_Event' -SourceIdentifier 'MSIEvt2' -ErrorAction Stop

$phases = @(
    @{ Label = '基線 — 手不要碰鍵盤'; Sec = 6 }
    @{ Label = 'Fn+F7  按「一次」就好';  Sec = 8 }
    @{ Label = 'Fn+F8  按「一次」就好';  Sec = 8 }
    @{ Label = 'Fn+F9  按「一次」就好';  Sec = 8 }
    @{ Label = '鍵盤背光鍵 按「一次」';  Sec = 8 }
)

$all = @()

Write-Host ""
Write-Host "每個階段只按一次，按完就把手移開等倒數結束。" -ForegroundColor Cyan
Write-Host ""

foreach ($ph in $phases) {
    # 清掉上一階段殘留
    Get-Event -SourceIdentifier 'MSIEvt2' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Event -EventIdentifier $_.EventIdentifier }

    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ">>> $($ph.Label)" -ForegroundColor Yellow
    [console]::Beep(880, 150)

    $end = (Get-Date).AddSeconds($ph.Sec)
    while ((Get-Date) -lt $end) {
        foreach ($evt in @(Get-Event -SourceIdentifier 'MSIEvt2' -ErrorAction SilentlyContinue)) {
            if (-not $evt) { continue }
            $code = $evt.SourceEventArgs.NewEvent.MSIEvt
            $all += [pscustomobject]@{ Phase = $ph.Label; Code = $code }
            Write-Host ("    0x{0:X}" -f $code) -ForegroundColor Green
            Remove-Event -EventIdentifier $evt.EventIdentifier
        }
        Write-Host ("`r    剩 {0} 秒   " -f [math]::Ceiling(($end - (Get-Date)).TotalSeconds)) -NoNewline
        Start-Sleep -Milliseconds 150
    }
    Write-Host "`r                    "
    [console]::Beep(440, 100)
}

Unregister-Event -SourceIdentifier 'MSIEvt2' -ErrorAction SilentlyContinue

$out = @()
$out += "=== 分階段結果 $(Get-Date -Format s) ==="
foreach ($ph in $phases) {
    $rows = $all | Where-Object { $_.Phase -eq $ph.Label }
    if (-not $rows) {
        $out += "{0,-26} : (無事件)" -f $ph.Label
    } else {
        $sum = ($rows | Group-Object Code | Sort-Object Count -Descending |
                ForEach-Object { "0x{0:X} x{1}" -f [uint32]$_.Name, $_.Count }) -join ', '
        $out += "{0,-26} : {1}" -f $ph.Label, $sum
    }
}

$out | Tee-Object -FilePath $log -Append
Write-Host ""
Write-Host ("=" * 60) -ForegroundColor DarkGray
$out | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
Write-Host ""
Write-Host "紀錄: $log" -ForegroundColor DarkGray
