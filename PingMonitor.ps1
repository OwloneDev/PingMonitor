# PingMonitor.ps1
# by Owlone Dev

# Библиотеки
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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

# Глобальные переменные
$script:root = $PSScriptRoot
$script:mainServerWindowSizes = @{}
$script:serverStatuses = @{}
$script:serverHistory = @{}
$script:mainLastSegMaps = @{}
$script:mainDisplayRows = @()
$script:configFile = $null
$script:logFile = $null
$script:config = $null
$script:diagnosticCts = $null
$script:timer = $null
$script:mainDrawPanel = $null
$script:pingButton = $null
$script:historyReferenceTime = $null
$script:currentPingStartTime = $null
$script:isPinging = $false
$script:isDiagnosticPinging = $false
$script:mainLabelWidth = 200
$script:dragRowIndex = -1
$script:dragInsertIndex = -1
$script:mainHoverRow = -1
$script:mainHoverSegment = -1
$script:dragInsertSide = "Top"
$script:version = "v1.1.2"

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
. "$PSScriptRoot\Scripts\Timer.ps1"

Start-App