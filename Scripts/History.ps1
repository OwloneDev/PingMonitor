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

# Обновить опорное время истории
function Update-HistoryReferenceTime {
    if ($null -eq $script:historyReferenceTime) {
        $script:historyReferenceTime = Get-HistoryReferenceTime
    }
}