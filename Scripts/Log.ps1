# Log.ps1

# Прочитать файл лога
function Read-LogFile {
    $logDir = Join-Path -Path $script:root -ChildPath "Logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    $script:logFile = Join-Path -Path $logDir -ChildPath "log_$timestamp.txt"
}

# Записать лог
function Write-Log {
    param([string]$Message)

    if (-not $script:config.LoggingEnabled) { return }
    if ($Message -eq "") {
        $logLine = ""
    }
    else {
        $currentDate = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        $logLine = "$currentDate $Message"
    }
    Add-Content -Path $script:logFile -Value $logLine -Encoding UTF8
}