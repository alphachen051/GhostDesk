#requires -RunAsAdministrator
# 回復腳本 — 把 MSI Center 還原成測試前的狀態
#
# 實測修正 (2026-10-02): 這台機器上只有 MSI_Center_Service 這一個服務。
# 原本以為存在的 'Micro Star SCM' / 'MSI Foundation Service' / 'MSI Sendevsvc'
# 在本機並不存在 (登錄檔 Services 下查無)，已移除。
# Fn 鍵是靠 msihid.sys 驅動程式運作，與 MSI Center 無關，全程未受影響。
$ErrorActionPreference = 'Continue'

Write-Host "=== 回復 MSI Center ===" -ForegroundColor Cyan

Get-Process -Name 'GhostDeck*' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  結束 GhostDeck (PID $($_.Id))"
    $_ | Stop-Process -Force -ErrorAction SilentlyContinue
}

$s = 'MSI_Center_Service'
try {
    Set-Service -Name $s -StartupType Automatic -ErrorAction Stop
    Start-Service -Name $s -ErrorAction Stop
    Write-Host "  還原 $s -> Automatic / Running" -ForegroundColor Green
} catch {
    Write-Host "  失敗 $s : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  (注意: C:\Program Files (x86)\MSI\MSI Center 目錄是空的，" -ForegroundColor Yellow
    Write-Host "   服務執行檔可能已不存在，啟動失敗屬預期)" -ForegroundColor Yellow
}

Write-Host "`n目前狀態:"
Get-Service -Name $s -EA SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize
Write-Host "Fn 鍵由 msihid 驅動程式提供，全程未被更動。" -ForegroundColor Yellow
Write-Host "若風扇仍停在 GhostDeck 設定的狀態，重開機即會回到 EC 預設。" -ForegroundColor Yellow
Write-Host "`n另外: Fn+F7 的對應請用 uninstall-fnkey.ps1 移除 (不需系管)。" -ForegroundColor Cyan
