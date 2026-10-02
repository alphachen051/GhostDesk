# 決定性分鍵探測 — 每鍵連按多次，階段間留靜默區
# 不需系管，用一般視窗跑。已知: 完全不按鍵時 120 秒內零事件。
$ErrorActionPreference = 'Stop'
$d   = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = "$d\fnkeys-log3.txt"

Register-CimIndicationEvent -Namespace 'root\WMI' -Query 'SELECT * FROM MSI_Event' -SourceIdentifier 'P3' -ErrorAction Stop

$phases = @(
    @{ L='靜默 A — 手離開鍵盤';       S=6 }
    @{ L='Fn+F7 慢慢按 5 次';         S=20 }
    @{ L='靜默 B — 手離開鍵盤';       S=6 }
    @{ L='Fn+F8 慢慢按 5 次';         S=20 }
    @{ L='靜默 C — 手離開鍵盤';       S=6 }
)

$all = @()
Write-Host "`n每個按鍵階段請「慢慢按 5 次」，大約每 3 秒一次。" -ForegroundColor Cyan
Write-Host "靜默階段請完全不要碰鍵盤。總共約 1 分鐘。`n" -ForegroundColor Cyan

foreach ($ph in $phases) {
    Get-Event -SourceIdentifier 'P3' -EA SilentlyContinue | ForEach-Object { Remove-Event -EventIdentifier $_.EventIdentifier }
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ">>> $($ph.L)" -ForegroundColor Yellow
    [console]::Beep(880,150)

    $end = (Get-Date).AddSeconds($ph.S)
    while ((Get-Date) -lt $end) {
        foreach ($evt in @(Get-Event -SourceIdentifier 'P3' -EA SilentlyContinue)) {
            if (-not $evt) { continue }
            $c = $evt.SourceEventArgs.NewEvent.MSIEvt
            $all += [pscustomobject]@{ Phase=$ph.L; Code=$c }
            Write-Host ("    0x{0:X}" -f $c) -ForegroundColor Green
            Remove-Event -EventIdentifier $evt.EventIdentifier
        }
        Write-Host ("`r    剩 {0} 秒   " -f [math]::Ceiling(($end-(Get-Date)).TotalSeconds)) -NoNewline
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r                    "
    [console]::Beep(440,100)
}
Unregister-Event -SourceIdentifier 'P3' -EA SilentlyContinue

$out = @("=== 決定性分鍵結果 $(Get-Date -Format s) ===")
foreach ($ph in $phases) {
    $rows = $all | Where-Object { $_.Phase -eq $ph.L }
    if (-not $rows) { $out += "{0,-24} : (無事件)" -f $ph.L }
    else {
        $sum = ($rows | Group-Object Code | Sort-Object Count -Descending |
                ForEach-Object { "0x{0:X} x{1}" -f [uint32]$_.Name, $_.Count }) -join ', '
        $out += "{0,-24} : {1}" -f $ph.L, $sum
    }
}
$out | Tee-Object -FilePath $log -Append | Out-Null
Write-Host ""
$out | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
Write-Host "`n紀錄: $log" -ForegroundColor DarkGray
