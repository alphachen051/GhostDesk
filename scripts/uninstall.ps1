#requires -Version 5.1
<#
.SYNOPSIS
    GhostDeck 移除腳本
.DESCRIPTION
    1. 停止並註銷排程工作 (GhostDeck Fn+F7)
    2. 結束背景監聽行程與 GhostDeck 主行程
    3. 可選還原 MSI Center 服務
    4. 移除桌面捷徑與部署檔案
#>

[CmdletBinding()]
param(
    [switch]$RestoreMsiService,
    [switch]$KeepFiles
)

$ErrorActionPreference = 'Continue'
$destDir   = Join-Path $env:LOCALAPPDATA 'Programs\GhostDeck'
$taskName  = 'GhostDeck Fn+F7'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                 GhostDeck 移除精靈                       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. 移除排程工作
Write-Host "`n[1/4] 檢查排程工作..." -ForegroundColor Cyan
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  -> 排程工作 '$taskName' 已停止並註銷" -ForegroundColor Green
} else {
    Write-Host "  -> 排程工作不存在，略過" -ForegroundColor Gray
}

# 2. 結束相關行程
Write-Host "`n[2/4] 關閉執行中的行程..." -ForegroundColor Cyan
# 結束監聽器 (比對含 ghostdeck-fnkey-listener.ps1 的 pwsh 行程，排除自己)
Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" |
    Where-Object { $_.CommandLine -match 'ghostdeck-fnkey-listener\.ps1' -and $_.ProcessId -ne $PID } |
    ForEach-Object {
        Write-Host "  -> 結束監聽程序 (PID $($_.ProcessId))" -ForegroundColor Yellow
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

# 結束 GhostDeck 主程式
Get-Process -Name 'GhostDeck*' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  -> 結束主程式 (PID $($_.Id))" -ForegroundColor Yellow
    $_ | Stop-Process -Force -ErrorAction SilentlyContinue
}

# 3. 移除桌面捷徑與安裝目錄檔案
Write-Host "`n[3/4] 清理檔案與捷徑..." -ForegroundColor Cyan
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'GhostDeck.lnk'
if (Test-Path $desktopShortcut) {
    Remove-Item $desktopShortcut -Force
    Write-Host "  -> 已移除桌面捷徑" -ForegroundColor Green
}

if (-not $KeepFiles -and (Test-Path $destDir)) {
    Remove-Item -Path $destDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  -> 已移除安裝目錄: $destDir" -ForegroundColor Green
} else {
    Write-Host "  -> 保留安裝目錄: $destDir" -ForegroundColor Gray
}

# 4. 還原 MSI Center 服務 (若指定)
if ($RestoreMsiService) {
    Write-Host "`n[4/4] 還原 MSI Center 服務..." -ForegroundColor Cyan
    $msiService = Get-Service -Name 'MSI_Center_Service' -ErrorAction SilentlyContinue
    if ($msiService) {
        $restoreCmd = "Set-Service -Name 'MSI_Center_Service' -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name 'MSI_Center_Service' -ErrorAction SilentlyContinue"
        try {
            Start-Process pwsh -ArgumentList "-NoProfile -Command `"$restoreCmd`"" -Verb RunAs -Wait
            Write-Host "  -> 已將 MSI_Center_Service 恢復為 Automatic 並啟動" -ForegroundColor Green
        } catch {
            Write-Host "  [提示] 提權請求被取消，請手動還原 MSI_Center_Service" -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host "`n[4/4] 略過 MSI Center 服務還原 (若要還原請加 -RestoreMsiService 參數)" -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                   移除完成！                             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
