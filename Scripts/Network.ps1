# Network.ps1

# Получить отображаемый текст сервера
function Get-ServerDisplayText {
    param($Server)

    switch ($script:config.DisplayMode) {
        'IP' { return $Server.IP }
        'Name' { return $Server.Name }
        default { return "$($Server.Name) ($($Server.IP))" }
    }
}

# Получить список серверов
function Get-ServerList {
    return @($script:config.Servers) | ForEach-Object {
        [PSCustomObject]@{
            Name        = $_.Name
            IP          = $_.IP
            Group       = $_.Group
            DisplayText = Get-ServerDisplayText -Server $_
        }
    }
}

# Обновить кнопку пинга
function Update-PingButton {
    param($IsPinging)

    $script:isPinging = $IsPinging
    $script:pingButton.Enabled = !$IsPinging
}

# Запустить пинг
function Start-PingJob {
    if ($script:isPinging) { return }

    Update-PingButton -IsPinging $true

    $serverList = Get-ServerList

    if ($serverList.Count -eq 0) {
        Update-PingButton -IsPinging $false

        return
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
            param($Servers)

            $ping = New-Object System.Net.NetworkInformation.Ping
            foreach ($server in $Servers) {
                try {
                    $reply = $ping.Send($server.IP, 3000)
                    $status = if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        "[OK]"
                    } else {
                        "[FAIL]"
                    }
                }
                catch {
                    $status = "[ERR]"
                }

                # Каждый объект выводим отдельно — EndInvoke вернёт их потоком
                [PSCustomObject]@{
                    IP     = $server.IP
                    Status = $status
                    Time   = Get-Date
                }
            }
            $ping.Dispose()
        })

    $ps.AddParameter('Servers', $serverList)
    $async = Invoke-Async -Ps $ps

    try {
        $allResults = $ps.EndInvoke($async)

        foreach ($r in $allResults) {
            if ($null -eq $r) { continue }

            $script:serverStatuses[$r.IP] = $r.Status

            if (-not $script:serverHistory.ContainsKey($r.IP)) {
                $script:serverHistory[$r.IP] = New-Object System.Collections.Generic.Queue[object]
            }
            $queue = $script:serverHistory[$r.IP]
            $queue.Enqueue([PSCustomObject]@{
                    Time   = $r.Time
                    Status = $r.Status
                })
            while ($queue.Count -gt $script:historyMaxSize) {
                [void]$queue.Dequeue()
            }

            $server = $serverList | Where-Object { $_.IP -eq $r.IP } | Select-Object -First 1
            if ($null -ne $server) {
                $displayText = Get-ServerDisplayText -Server $server
                Write-Log -Message "$displayText $($r.Status)"
            }
        }
    }
    catch {
        Write-Log -Message "Ошибка пинга: $($_.Exception.Message)"
    }
    finally {
        Update-PingButton -IsPinging $false
        Write-Log -Message ""

        $rs.Dispose()
        $ps.Dispose()

        # Обновляем reference time и перерисовываем
        $script:historyReferenceTime = Get-HistoryReferenceTime

        if ($null -ne $script:mainDrawPanel -and -not $script:mainDrawPanel.IsDisposed) {
            $script:mainDrawPanel.Invalidate()
        }
    }
}