# History.ps1

# Получить опорное время истории
function Get-HistoryReferenceTime {
    $maxTime = $null
    foreach ($key in $script:serverHistory.Keys) {
        $queue = $script:serverHistory[$key]
        if ($null -eq $queue) { continue }
        foreach ($entry in $queue) {
            if ($null -eq $maxTime -or $entry.Time -gt $maxTime) {
                $maxTime = $entry.Time
            }
        }
    }
    if ($null -ne $maxTime) {
        return $maxTime
    }
    
    return (Get-Date)
}

# Инициализировать структуру отображения истории с группами
function Initialize-HistoryDisplayRows {
    param([array]$Servers)

    $rows = @()
    $grouped = @{}
    $ungrouped = @()
    $groupOrder = @()
    foreach ($server in $Servers) {
        $g = $server.Group
        if ([string]::IsNullOrWhiteSpace($g)) {
            $ungrouped += $server
        }
        else {
            if (-not $grouped.ContainsKey($g)) {
                $grouped[$g] = @()
                $groupOrder += $g
            }
            $grouped[$g] += $server
        }
    }
    foreach ($g in $groupOrder) {
        $rows += [PSCustomObject]@{ Type = "Header"; Title = $g; Server = $null }
        foreach ($s in $grouped[$g]) {
            $rows += [PSCustomObject]@{ Type = "Server"; Title = $null; Server = $s }
        }
    }
    if ($ungrouped.Count -gt 0) {
        $rows += [PSCustomObject]@{ Type = "Header"; Title = "Без группы"; Server = $null }
        foreach ($s in $ungrouped) {
            $rows += [PSCustomObject]@{ Type = "Server"; Title = $null; Server = $s }
        }
    }

    return , $rows
}

# Прочитать историю из файла
function Read-HistoryFile {
    $file = Join-Path $script:root "history.json"
    if (-not (Test-Path $file)) { return }
    try {
        $data = Get-Content $file -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log -Message "Ошибка чтения истории: $($_.Exception.Message)"

        return
    }
    if ($null -eq $data) { return }
    $maxAgeSeconds = $script:config.HistoryMaxSize * $script:config.Interval * 60
    $cutoff = (Get-Date).AddSeconds(-$maxAgeSeconds)
    $currentIPs = @{}
    foreach ($server in $script:config.Servers) {
        $currentIPs[$server.IP] = $true
    }
    $grouped = @{}
    foreach ($entry in $data) {
        $ip = $entry.IP
        if (-not $currentIPs.ContainsKey($ip)) { continue }
        try {
            $time = [DateTime]::Parse($entry.Time)
        }
        catch {
            continue
        }
        if ($time -lt $cutoff) { continue }
        if (-not $grouped.ContainsKey($ip)) {
            $grouped[$ip] = @()
        }
        $grouped[$ip] += [PSCustomObject]@{
            Time   = $time
            Status = $entry.Status
        }
    }
    foreach ($ip in $grouped.Keys) {
        $sorted = $grouped[$ip] | Sort-Object -Property Time
        $queue = New-Object System.Collections.Generic.Queue[object]
        $lastStatus = $null
        foreach ($entry in $sorted) {
            $queue.Enqueue($entry)
            $lastStatus = $entry.Status
        }
        while ($queue.Count -gt $script:config.HistoryMaxSize) {
            [void]$queue.Dequeue()
        }
        $script:serverHistory[$ip] = $queue
        if ($null -ne $lastStatus) {
            $script:serverStatuses[$ip] = $lastStatus
        }
    }
}

# Записать историю в файл
function Write-HistoryFile {
    $file = Join-Path $script:root "history.json"
    $currentIPs = @{}
    foreach ($server in $script:config.Servers) {
        $currentIPs[$server.IP] = $true
    }
    $data = @()
    foreach ($ip in $script:serverHistory.Keys) {
        if (-not $currentIPs.ContainsKey($ip)) { continue }
        $queue = $script:serverHistory[$ip]
        if ($null -eq $queue) { continue }
        foreach ($entry in $queue) {
            $data += [PSCustomObject]@{
                IP     = $ip
                Time   = $entry.Time.ToString("o")
                Status = $entry.Status
            }
        }
    }
    try {
        $saveRs = [runspacefactory]::CreateRunspace()
        $saveRs.Open()
        $savePs = [powershell]::Create()
        $savePs.Runspace = $saveRs
        $savePs.AddScript({
                param($Data, $FilePath)
                try {
                    if ($Data.Count -eq 0) {
                        $json = "[]"
                    }
                    elseif ($Data.Count -eq 1) {
                        $json = "[" + (ConvertTo-Json -InputObject $Data[0] -Depth 3) + "]"
                    }
                    else {
                        $json = ConvertTo-Json -InputObject $Data -Depth 3
                    }
                    [System.IO.File]::WriteAllText($FilePath, $json, [System.Text.Encoding]::UTF8)
                }
                catch { }
            })
        $savePs.AddArgument($data) | Out-Null
        $savePs.AddArgument($file) | Out-Null
        $savePs.BeginInvoke() | Out-Null
    }
    catch {
        Write-Log -Message "Ошибка записи истории"
    }
}

# Обновить опорное время истории
function Update-HistoryReferenceTime {
    if ($null -eq $script:historyReferenceTime) {
        $script:historyReferenceTime = Get-HistoryReferenceTime
    }
}