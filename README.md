# GhostDeck (GhostDesk) 配置與一鍵安裝備份

本儲存庫備份了 **MSI Stealth 14 Studio A13VF** 上 GhostDeck 的當前運作設定、熱鍵喚回監聽器、系統基線診斷工具與一鍵安裝機制。

---

## 專案簡介

[GhostDeck](https://github.com/wygodad/ghostdeck) 是一套針對 MSI 微星筆電設計的開源、輕量級獨立風扇與效能控制程式。它透過 WMI / ACPI 與筆電的內嵌控制器 (Embedded Controller, EC) 直接溝通，擺脫原廠 MSI Center 笨重且常有背景衝突的困擾。

### 本機驗證環境 (當前設定)

* **電腦名稱**: `I374-NB01`
* **筆電機型**: MSI Stealth 14 Studio A13VF (`MS-14K1`)
* **BIOS 版本**: `E14K1IMS.10E`
* **GhostDeck 版本**: `v1.36.0` (以 .NET 8.0 Desktop Runtime 執行)
* **專屬熱鍵機制**: `Fn + F7`
  * WMI 命名空間: `root\WMI`
  * WMI 類別: `MSI_Event`
  * 事件代碼: `0x22001D` (十進位 `2228253`)
  * 行為: 若 GhostDeck 已在背景/最小化，則以 Win32 API 叫到前景還原；若未啟動，則自動提權 (RunAs) 啟動。
* **服務管理**:
  * 停用 `MSI_Center_Service`（防止 MSI Center 與 GhostDeck 爭奪風扇與電源模式控制權）
  * 保留鍵盤驅動與 SCM，不影響一般 Fn 組合鍵（亮度、音量、鍵盤背光）

---

## 目錄結構

```text
GhostDesk/
├── install.bat                     # [根目錄] 一鍵安裝批次檔 (呼叫 scripts/install.ps1)
├── uninstall.bat                   # [根目錄] 一鍵移除批次檔 (呼叫 scripts/uninstall.ps1)
├── start-ghostdeck.bat             # [根目錄] 快速提權啟動 GhostDeck
├── .gitignore
├── README.md
├── bin/
│   └── GhostDeck-win-x64.exe       # GhostDeck 主程式 (v1.36.0, 64-bit)
├── scripts/
│   ├── install.ps1                 # 一鍵安裝與排程註冊核心腳本
│   ├── uninstall.ps1               # 移除排程工作與清理腳本
│   └── ghostdeck-fnkey-listener.ps1# Fn+F7 (MSIEvt 0x22001D) 常駐監聽器
├── config/
│   ├── machine-info.json           # 本機硬體規格、BIOS 與事件代碼完整紀錄
│   └── GhostDeck-FnF7-Task.xml     # Windows 工作排程器 XML 定義備份
└── diagnostics/                    # 實測基線與熱鍵探測工具
    ├── probe-baseline.ps1          # 被動 WMI 事件基線監聽 (確認靜態無漏噴代碼)
    ├── probe-fnkeys.ps1            # 第一階段熱鍵事件探測
    ├── probe-fnkeys2.ps1           # 第二階段分組熱鍵探測
    ├── probe-fnkeys3.ps1           # 第三階段決定性分鍵探測
    ├── test-ghostdeck.ps1          # 整合測試腳本 (含系統還原點與服務基線)
    ├── rollback-msi.ps1            # MSI Center 服務還原腳本
    └── data/
        ├── baseline-events.csv     # 靜態事件紀錄
        ├── services.csv            # 服務狀態紀錄
        ├── fnkeys-log.txt          # 熱鍵探測紀錄 1
        ├── fnkeys-log2.txt         # 熱鍵探測紀錄 2
        └── test-log.txt            # 實測執行紀錄
```

---

## 一鍵安裝方式

> **主程式不隨專案發佈。** 安裝腳本會在執行時自動從 [wygodad/ghostdeck GitHub Releases](https://github.com/wygodad/ghostdeck/releases) 下載最新版本。

### 方式 1：直接執行批次檔（最簡單）
在檔案總管中對 `install.bat` 點擊兩下直接執行。

### 方式 2：使用 PowerShell 執行
以目前登入之一般使用者身分開啟 PowerShell，執行：
```powershell
.\scripts\install.ps1
```

### 方式 3：指定特定版本
```powershell
.\scripts\install.ps1 -GhostDeckVersion v1.36.0
```

> **重要注意事項**：
> 1. 請在**一般使用者視窗**下執行（不要用右鍵「以系統管理員身分執行」開啟安裝視窗），因為 Windows 排程工作必須註冊在當前互動式登入使用者（例如 `i374`）的工作階段下，否則視窗無法正常彈出至使用者桌面。
> 2. 停用 `MSI_Center_Service` 或是安裝 .NET 8 Runtime 時，安裝腳本會自動彈出 UAC 提權請求，點擊「是」即可。
> 3. 安裝時需要網路連線以從 GitHub 下載主程式。

### 安裝腳本自動完成的項目：
1. **從 GitHub Releases 下載 GhostDeck 主程式**：自動取得最新版（或指定版本）`GhostDeck-win-x64.exe`。
2. **檢查 .NET 8.0 Desktop Runtime**：若本機缺少則自動從微軟官方 `aka.ms` 連結下載並安裝。
3. **部署監聽腳本**：複製 `ghostdeck-fnkey-listener.ps1` 至 `%LOCALAPPDATA%\Programs\GhostDeck`。
4. **停用 MSI Center 衝突服務**：將 `MSI_Center_Service` 設為 Disabled 並停止。
5. **註冊 Windows 工作排程器 (`GhostDeck Fn+F7`)**：
   * 觸發條件：使用者登入時自動啟動
   * 權限：一般使用者權限（無需提權即可監聽 WMI `MSI_Event`）
   * 形式：隱藏視窗、支援電池模式運作、常駐監聽
6. **建立桌面捷徑**：於桌面建立 `GhostDeck.lnk`，並預先設定管理員提權屬性。
7. **立即啟動**：排程工作於安裝完成時立即啟動生效。

---

## 使用方式

1. **熱鍵喚回**：按筆電鍵盤的 **`Fn + F7`**：
   * 若 GhostDeck 尚未執行：自動提權開啟 GhostDeck（會跳出 UAC 視窗）。
   * 若 GhostDeck 已在背景或最小化：立即還原並帶到最前景。
2. **手動啟動**：
   * 點擊桌面的 `GhostDeck` 捷徑，或執行專案根目錄的 `start-ghostdeck.bat`。
3. **查看監聽紀錄**：
   * 紀錄檔位於 `%LOCALAPPDATA%\GhostDeck\fnkey.log`。

---

## 移除與還原

### 移除 GhostDeck 與監聽工作
執行根目錄的 `uninstall.bat` 或在 PowerShell 執行：
```powershell
.\scripts\uninstall.ps1
```

### 若需同時還原 MSI Center 服務
```powershell
.\scripts\uninstall.ps1 -RestoreMsiService
```
或直接執行 `diagnostics/rollback-msi.ps1`。

---

## 技術細節備忘

* **為什麼 GhostDeck 需要系統管理員權限？**
  GhostDeck 需透過 WMI 存取 `root\WMI:MSI_ACPI` 讀寫 EC 暫存器（風扇轉速曲線、電源設定檔檔位）。Windows 要求管理員身分才允許此類底層 ACPI 操作。
* **為什麼常駐監聽器不需要系統管理員權限？**
  訂閱 `root\WMI:MSI_Event` 屬於一般事件通知，Windows 允許中完整性等級（一般使用者）訂閱。因此監聽器以登入使用者常駐，完全不需要常駐提權，僅在需要打開主程式時觸發 `RunAs`。
* **為什麼需要停用 `MSI_Center_Service`？**
  MSI Center Service 會在背景持續輪詢並將風扇設定重置為其內部預設值，停用該服務可防止與 GhostDeck 設定互相干擾。Fn 快捷鍵由 `msihid.sys` 驅動處理，停用 MSI Center 不會影響亮度與音量調整。
