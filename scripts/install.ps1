#requires -Version 5.1
<#
.SYNOPSIS
    GhostDeck 一鍵安裝與設定腳本 (針對 MSI 筆電，特別是 Stealth 14 Studio A13VF)
.DESCRIPTION
    1. 從 GitHub Releases 下載最新版（或指定版本）GhostDeck-win-x64.exe
    2. 檢查並自動安裝 .NET 8.0 Desktop Runtime (若未安裝)
    3. 安裝 GhostDeck-win-x64.exe 與 ghostdeck-fnkey-listener.ps1 至 %LOCALAPPDATA%\Programs\GhostDeck
    4. 註冊登入時自動啟動的排程工作 (以目前登入使用者一般權限執行，無視窗常駐)
    5. 停用衝突的 MSI_Center_Service (避免與 GhostDeck 爭奪 EC 控制權)
    6. 建立桌面捷徑並立即啟動常駐監聽器
#>

[CmdletBinding()]
param(
    # 指定 GhostDeck 版本號 (例如 'v1.36.0')；留空則自動抓最新版
    [string]$GhostDeckVersion = '',
    [switch]$SkipMsiServiceDisable,
    [switch]$SkipRuntimeCheck
)

$ErrorActionPreference = 'Stop'
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$destDir     = Join-Path $env:LOCALAPPDATA 'Programs\GhostDeck'
$logDir      = Join-Path $env:LOCALAPPDATA 'GhostDeck'
$taskName    = 'GhostDeck Fn+F7'
$currentUser = "$env:USERDOMAIN\$env:USERNAME"
$githubRepo  = 'wygodad/ghostdeck'

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         GhostDeck 一鍵安裝與環境配置精靈                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "目標使用者: $currentUser" -ForegroundColor Yellow

# 檢查避免在 SYSTEM 或提權的服務帳號下直接註冊排程 (會導致排程工作進錯使用者環境)
if ($env:USERNAME -in @('SYSTEM', 'tp_endpoint', 'LOCAL SERVICE', 'NETWORK SERVICE')) {
    Write-Host "[錯誤] 偵測到提權或服務帳號 ($env:USERNAME)。" -ForegroundColor Red
    Write-Host "排程工作與使用者設定檔必須在一般登入使用者的工作階段中執行。" -ForegroundColor Yellow
    Write-Host "請使用一般使用者身分重新執行此腳本。" -ForegroundColor Yellow
    exit 1
}

# ─── 1. 從 GitHub Releases 下載 GhostDeck 主程式 ──────────────────────────────
Write-Host "`n[1/6] 下載 GhostDeck 主程式..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $destDir -Force | Out-Null
New-Item -ItemType Directory -Path $logDir  -Force | Out-Null

$destExe = Join-Path $destDir 'GhostDeck-win-x64.exe'

try {
    $apiHeaders = @{ "User-Agent" = "PowerShell-GhostDeckInstaller" }

    if ($GhostDeckVersion) {
        $releaseUrl = "https://api.github.com/repos/$githubRepo/releases/tags/$GhostDeckVersion"
    } else {
        $releaseUrl = "https://api.github.com/repos/$githubRepo/releases/latest"
    }

    Write-Host "  -> 查詢 GitHub Releases: $releaseUrl" -ForegroundColor Gray
    $release    = Invoke-RestMethod -Uri $releaseUrl -Headers $apiHeaders
    $assetUrl   = ($release.assets | Where-Object { $_.name -eq 'GhostDeck-win-x64.exe' }).browser_download_url
    $tagVersion = $release.tag_name

    if (-not $assetUrl) { throw "在 Release $tagVersion 中找不到 GhostDeck-win-x64.exe" }

    Write-Host "  -> 版本: $tagVersion" -ForegroundColor Green
    Write-Host "  -> 下載: $assetUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $assetUrl -OutFile $destExe -UseBasicParsing
    $sz = (Get-Item $destExe).Length
    Write-Host "  -> 已下載至: $destExe ($([math]::Round($sz/1MB,1)) MB)" -ForegroundColor Green
} catch {
    Write-Host "  [錯誤] 無法從 GitHub 下載: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  請確認網路連線正常，或手動下載並放至: $destExe" -ForegroundColor Yellow
    exit 1
}

# ─── 2. 檢查 / 安裝 .NET 8 Desktop Runtime ────────────────────────────────────
if (-not $SkipRuntimeCheck) {
    Write-Host "`n[2/6] 檢查 .NET 8 Desktop Runtime..." -ForegroundColor Cyan
    $hasDotNet8 = $false
    $runtimeFolder = 'C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App'
    if (Test-Path $runtimeFolder) {
        $v8 = Get-ChildItem $runtimeFolder -Directory -Filter '8.*' -ErrorAction SilentlyContinue
        if ($v8) {
            $hasDotNet8 = $true
            Write-Host "  -> 已安裝 .NET Desktop Runtime: $($v8.Name -join ', ')" -ForegroundColor Green
        }
    }

    if (-not $hasDotNet8) {
        Write-Host "  -> 未偵測到 .NET 8 Desktop Runtime，正在從微軟官方下載..." -ForegroundColor Yellow
        $dotnetInstaller = Join-Path $env:TEMP 'windowsdesktop-runtime-8.0-win-x64.exe'
        # 使用微軟官方 aka.ms 穩定連結，自動導向最新 8.x 版本
        $dotnetUrl = 'https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe'
        Write-Host "  -> 下載中: $dotnetUrl" -ForegroundColor Gray
        Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller -UseBasicParsing
        Write-Host "  -> 執行安裝程式 (需管理員權限確認)..." -ForegroundColor Yellow
        $proc = Start-Process -FilePath $dotnetInstaller -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru -Verb RunAs
        if ($proc.ExitCode -in @(0, 3010)) {
            Write-Host "  -> .NET 8 Desktop Runtime 安裝成功！" -ForegroundColor Green
        } else {
            Write-Host "  [警告] 安裝程式回傳代碼: $($proc.ExitCode)" -ForegroundColor Red
        }
        Remove-Item $dotnetInstaller -Force -ErrorAction SilentlyContinue
    }
}

# ─── 3. 部署監聽腳本 ──────────────────────────────────────────────────────────
Write-Host "`n[3/6] 部署 Fn+F7 監聽腳本..." -ForegroundColor Cyan
$srcListener = Join-Path $scriptDir 'ghostdeck-fnkey-listener.ps1'
if (-not (Test-Path $srcListener)) {
    throw "找不到監聽腳本: $srcListener"
}
Copy-Item $srcListener (Join-Path $destDir 'ghostdeck-fnkey-listener.ps1') -Force
Write-Host "  -> 已部署到: $destDir" -ForegroundColor Green

# ─── 4. 停用衝突的 MSI_Center_Service (若存在) ────────────────────────────────
if (-not $SkipMsiServiceDisable) {
    Write-Host "`n[4/6] 檢查 MSI Center 衝突服務..." -ForegroundColor Cyan
    $msiService = Get-Service -Name 'MSI_Center_Service' -ErrorAction SilentlyContinue
    if ($msiService -and $msiService.StartType -ne 'Disabled') {
        Write-Host "  -> 偵測到 MSI_Center_Service (狀態: $($msiService.Status), 啟動: $($msiService.StartType))" -ForegroundColor Yellow
        $disableCmd = "Stop-Service -Name 'MSI_Center_Service' -Force -EA SilentlyContinue; Set-Service -Name 'MSI_Center_Service' -StartupType Disabled -EA SilentlyContinue"
        try {
            Start-Process pwsh -ArgumentList "-NoProfile -Command `"$disableCmd`"" -Verb RunAs -Wait
            Write-Host "  -> MSI_Center_Service 已停用 (避免與 GhostDeck 爭奪 EC 控制權)" -ForegroundColor Green
        } catch {
            Write-Host "  [提示] 提權請求被取消，可稍後手動停用 MSI_Center_Service" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "  -> MSI_Center_Service 不存在或已 Disabled，略過" -ForegroundColor Green
    }
}

# ─── 5. 註冊 Windows 登入自動啟動排程工作 ────────────────────────────────────
Write-Host "`n[5/6] 設定 Windows 排程工作 ($taskName)..." -ForegroundColor Cyan
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Write-Host "  -> 移除舊的排程工作..." -ForegroundColor Gray
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$pwshCmd = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshCmd) { $pwshCmd = 'pwsh.exe' }

$targetScript = Join-Path $destDir 'ghostdeck-fnkey-listener.ps1'
$actionArg    = ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $targetScript)
$act = New-ScheduledTaskAction -Execute $pwshCmd -Argument $actionArg
$trg = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
$prn = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
                                    -DontStopIfGoingOnBatteries `
                                    -ExecutionTimeLimit ([TimeSpan]::Zero) `
                                    -MultipleInstances IgnoreNew `
                                    -RestartCount 3 `
                                    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $taskName `
                       -Action $act -Trigger $trg -Principal $prn -Settings $set `
                       -Description 'GhostDeck Fn+F7 (MSIEvt 0x22001D) 背景喚回與啟動監聽器' | Out-Null

Write-Host "  -> 排程工作註冊完成 (登入時啟動，使用者權限，背景執行)" -ForegroundColor Green

Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 2
$finalTask = Get-ScheduledTask -TaskName $taskName
Write-Host "  -> 排程狀態: $($finalTask.State)" -ForegroundColor Green

# ─── 6. 建立桌面捷徑 ──────────────────────────────────────────────────────────
Write-Host "`n[6/6] 建立桌面捷徑..." -ForegroundColor Cyan
$desktopDir   = [Environment]::GetFolderPath('Desktop')
$wsh          = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path $desktopDir 'GhostDeck.lnk'
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath     = $destExe
$shortcut.WorkingDirectory = $destDir
$shortcut.Description    = 'GhostDeck - MSI 風扇與效能控制'
$shortcut.Save()

# 設定捷徑「以系統管理員身分執行」旗標 (LNK byte 21, bit 5 = 0x20)
try {
    $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $bytes[21] = $bytes[21] -bor 0x20
    [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
    Write-Host "  -> GhostDeck.lnk 已建立 (已啟用以系統管理員身分執行)" -ForegroundColor Green
} catch {
    Write-Host "  -> GhostDeck.lnk 已建立" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "                 GhostDeck 安裝與配置成功！               " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "1. 按 [Fn + F7] 即可自動啟動或喚回 GhostDeck 視窗" -ForegroundColor Yellow
Write-Host "2. 監聽記錄檔: $logDir\fnkey.log" -ForegroundColor Yellow
Write-Host "3. 若需移除，請執行: .\scripts\uninstall.ps1" -ForegroundColor Yellow
Write-Host ""
