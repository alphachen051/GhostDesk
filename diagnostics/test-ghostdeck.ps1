#requires -RunAsAdministrator
# GhostDeck 測試腳本 — Stealth 14 Studio A13VF (MS-14K1)
# 全程可逆。SCM (Fn 鍵) 不動。
$ErrorActionPreference = 'Continue'
$d = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = "$d\test-log.txt"
function Say($m) { $m | Tee-Object -FilePath $log -Append }

Say "=== GhostDeck test $(Get-Date -Format s) ==="

# --- 1. 還原點 ---
Say "`n[1] 建立系統還原點..."
try {
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop
    Checkpoint-Computer -Description 'Before GhostDeck test' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Say "    OK"
} catch {
    Say "    略過: $($_.Exception.Message)"
    Say "    (系統還原可能被停用，或 24 小時內已建立過還原點)"
}

# --- 2. EC / WMI 基線 ---
Say "`n[2] MSI WMI 基線 (唯讀)"
foreach ($c in 'MSI_ACPI','MSI_Power','MSI_CPU','MSI_VGA') {
    try {
        $o = Get-CimInstance -Namespace root\WMI -ClassName $c -ErrorAction Stop
        Say "  -- $c --"
        $o | Format-List * | Out-String -Width 200 | Tee-Object -FilePath $log -Append
    } catch { Say "  $c : $($_.Exception.Message)" }
}

# --- 3. 服務基線 ---
Say "`n[3] 服務狀態 (前)"
Get-Service | Where-Object { $_.Name -match '^(MSI|Micro Star)' -and $_.Name -notmatch 'MSiSCSI|msiserver' } |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $log -Append

# --- 4. 停用 MSI Center 堆疊 (保留 SCM) ---
Say "`n[4] 停用 MSI Center 相關服務 (保留 Micro Star SCM = Fn 鍵)"
$targets = @('MSI_Center_Service','MSI Foundation Service','MSI Sendevsvc')
foreach ($t in $targets) {
    try {
        Stop-Service -Name $t -Force -ErrorAction Stop
        Set-Service -Name $t -StartupType Disabled -ErrorAction Stop
        Say "    停用 $t"
    } catch { Say "    失敗 $t : $($_.Exception.Message)" }
}
# MSI Center UI 本體 (Store App) — 只關閉行程，不解除安裝
Get-Process -Name 'MSI Center*','MSI.CentralServer*' -ErrorAction SilentlyContinue |
    ForEach-Object { Say "    結束行程 $($_.ProcessName)"; $_ | Stop-Process -Force -ErrorAction SilentlyContinue }

Say "`n    服務狀態 (後)"
Get-Service | Where-Object { $_.Name -match '^(MSI|Micro Star)' -and $_.Name -notmatch 'MSiSCSI|msiserver' } |
    Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $log -Append

# --- 5. 安裝 .NET 8 Desktop Runtime ---
Say "`n[5] 安裝 .NET 8.0.31 Desktop Runtime..."
if (Test-Path 'C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\8.*') {
    Say "    已存在，略過"
} else {
    $p = Start-Process "$d\windowsdesktop-runtime-8.0.31-win-x64.exe" -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
    Say "    結束代碼: $($p.ExitCode)  (0 = 成功, 3010 = 需重開機)"
}
Say "    目前 Desktop runtimes:"
Get-ChildItem 'C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App' -EA SilentlyContinue |
    Select-Object -ExpandProperty Name | ForEach-Object { Say "      $_" }

# --- 6. 啟動 GhostDeck ---
Say "`n[6] 啟動 GhostDeck v1.36.0"
Say "    檔案: $d\GhostDeck-win-x64.exe"
Start-Process "$d\GhostDeck-win-x64.exe"
Start-Sleep -Seconds 8
$g = Get-Process -Name 'GhostDeck*' -ErrorAction SilentlyContinue
if ($g) { Say "    執行中 (PID $($g.Id), 記憶體 $([math]::Round($g.WorkingSet64/1MB,1)) MB)" }
else { Say "    未偵測到行程 — 可能啟動失敗，檢查畫面上的錯誤訊息" }

Say "`n=== 完成。紀錄: $log ==="
Say "接下來請在 GhostDeck 視窗確認:"
Say "  a) 是否正確辨識為 'MSI Stealth 14 Studio A13VF' (Tested)"
Say "  b) 是否出現 firmware-change guard 警告 (BIOS E14K1IMS.10E)"
Say "  c) 切到 Silent，記下切換前後的 CPU/GPU 風扇 RPM"
Say "  d) 測試 Fn 鍵 (亮度 / 鍵盤背光 / Fn+F7)"
