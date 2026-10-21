# PingMonitor.ps1
# by Owlone Dev

# Библиотеки
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Глобальные переменные
$script:timer = $null
$script:config = $null
$script:logFile = $null
$script:gfxFont = $null
$script:gfxPenOk = $null
$script:configFile = $null
$script:pingButton = $null
$script:gfxPenFail = $null
$script:progressBar = $null
$script:mainSnapper = $null
$script:gfxPenHover = $null
$script:gfxFontBrush = $null
$script:diagnosticCts = $null
$script:mainDrawPanel = $null
$script:gfxHeaderFont = $null
$script:gfxHeaderBrush = $null
$script:mainLastBounds = $null
$script:settingsButton = $null
$script:diagnosticButton = $null
$script:historyReferenceTime = $null
$script:serverHistory = @{}
$script:serverStatuses = @{}
$script:mainLastSegMaps = @{}
$script:mainDisplayRows = @()
$script:mainServerWindowSizes = @{}
$script:root = $PSScriptRoot
$script:isPinging = $false
$script:isDiagnosticPinging = $false
$script:mainDisplayRowsDirty = $true
$script:mainHoverRow = -1
$script:dragRowIndex = -1
$script:mainLabelWidth = 200
$script:dragInsertIndex = -1
$script:mainHoverSegment = -1
$script:dragInsertSide = "Top"
$script:version = "v1.1.6"

# Скрипты
. "$PSScriptRoot\Forms\DiagnosticForm.ps1"
. "$PSScriptRoot\Forms\GroupsForm.ps1"
. "$PSScriptRoot\Forms\MainForm.ps1"
. "$PSScriptRoot\Forms\SettingsForm.ps1"
. "$PSScriptRoot\Scripts\Async.ps1"
. "$PSScriptRoot\Scripts\Config.ps1"
. "$PSScriptRoot\Scripts\Gui.ps1"
. "$PSScriptRoot\Scripts\History.ps1"
. "$PSScriptRoot\Scripts\Log.ps1"
. "$PSScriptRoot\Scripts\Network.ps1"
. "$PSScriptRoot\Scripts\Snapper.ps1"
. "$PSScriptRoot\Scripts\Timer.ps1"

# Запустить программу
function Start-App {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    Read-ConfigFile
    Read-LogFile
    Import-Config
    Read-HistoryFile
    Update-HistoryReferenceTime
    Show-MainForm
}

Start-App