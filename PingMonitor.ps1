# Ping Monitor by Owlone Dev

# Библиотеки
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Получить файл конфигурации
function Get-ConfigFile {
    return Join-Path $PSScriptRoot "config.json"
}

# Получить файл лога
function Get-LogFile {
    $logDir = Join-Path -Path $PSScriptRoot -ChildPath "Logs"

    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    
    return Join-Path -Path $logDir -ChildPath "log_$timestamp.txt"
}

# Получить текущую дату
function Get-CurrentDate {
    return Get-Date -Format "dd.MM.yyyy HH:mm:ss"
}

# Получить интервал
function Get-Interval {
    return $script:config.Interval * 60000
}

# Установить лог
function Set-Log {
    param($Message)

    $script:currentLog = $Message
}

# Записать лог
function Write-Log {
    param([string]$Message)

    if (-not $script:config.LoggingEnabled) { return }
    if ($Message -eq "") {
        $logLine = ""
    }
    else {
        $currentDate = Get-CurrentDate
        $logLine = "$currentDate $Message"
    }

    Add-Content -Path $script:logFile -Value $logLine -Encoding UTF8
}

# Вызвать асинхронно
function Invoke-Async {
    param($Ps)

    $async = $Ps.BeginInvoke()

    while (-not $async.IsCompleted) {
        Start-Sleep -Milliseconds 50
        [System.Windows.Forms.Application]::DoEvents()
    }

    return $async
}

# Запустить программу
function Start-App {
    Import-Config
    Show-MainForm
}

# Глобальные переменные
$script:configFile = Get-ConfigFile
$script:logFile = Get-LogFile
$script:config = $null
$script:diagnosticCts = $null
$script:console = $null
$script:timer = $null
$script:pingButton = $null
$script:isPinging = $false
$script:isDiagnosticPinging = $false
$script:currentLog = ""
$script:version = "v1.0.2"

# Cкрипты
. "$PSScriptRoot\Forms\DiagnosticForm.ps1"
. "$PSScriptRoot\Forms\GroupsForm.ps1"
. "$PSScriptRoot\Forms\MainForm.ps1"
. "$PSScriptRoot\Forms\SettingsForm.ps1"
. "$PSScriptRoot\Scripts\Config.ps1"
. "$PSScriptRoot\Scripts\Gui.ps1"
. "$PSScriptRoot\Scripts\Network.ps1"

Start-App