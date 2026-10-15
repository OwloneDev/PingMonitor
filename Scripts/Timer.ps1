# Timer.ps1

# Обновить интервал
function Update-Interval {
    $script:timer.Interval = $script:config.Interval * 60000
}

# Запустить таймер
function Start-Timer {
    $script:timer = New-Object System.Windows.Forms.Timer
    Update-Interval
    $script:timer.Add_Tick({ Start-PingJob })
    $script:timer.Start()
}

# Остановить таймер
function Stop-Timer {
    $script:timer.Stop()
}