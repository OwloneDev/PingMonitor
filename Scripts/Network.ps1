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
    $startTime = Get-Date
    $script:currentPingStartTime = $startTime
    foreach ($server in $serverList) {
        if (-not $script:serverHistory.ContainsKey($server.IP)) {
            $script:serverHistory[$server.IP] = New-Object System.Collections.Generic.Queue[object]
        }
        $queue = $script:serverHistory[$server.IP]
        $queue.Enqueue([PSCustomObject]@{
                Time   = $startTime
                Status = "[PENDING]"
            })
        while ($queue.Count -gt $script:config.HistoryMaxSize) {
            [void]$queue.Dequeue()
        }
    }
    $script:historyReferenceTime = $startTime
    if ($null -ne $script:mainDrawPanel -and -not $script:mainDrawPanel.IsDisposed) {
        $script:mainDrawPanel.Invalidate()
        $script:mainDrawPanel.Update()
    }
    $pingCallback = {
        param($IP, $Status, $Time)

        $script:serverStatuses[$IP] = $Status
        if ($script:serverHistory.ContainsKey($IP)) {
            $queue = $script:serverHistory[$IP]
            $arr = @($queue)
            for ($k = $arr.Count - 1; $k -ge 0; $k--) {
                if ($arr[$k].Status -eq "[PENDING]" -and $arr[$k].Time -eq $script:currentPingStartTime) {
                    $arr[$k] = [PSCustomObject]@{
                        Time   = $arr[$k].Time
                        Status = $Status
                    }

                    break
                }
            }
            $newQueue = New-Object System.Collections.Generic.Queue[object]
            foreach ($item in $arr) {
                $newQueue.Enqueue($item)
            }
            $script:serverHistory[$IP] = $newQueue
        }
        $server = $script:config.Servers | Where-Object { $_.IP -eq $IP } | Select-Object -First 1
        if ($null -ne $server) {
            $displayText = Get-ServerDisplayText -Server $server
            Write-Log -Message "$displayText $Status"
        }
        if ($null -ne $script:mainDrawPanel -and -not $script:mainDrawPanel.IsDisposed) {
            $script:mainDrawPanel.Invalidate()
        }
    }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
            param($Servers, $DrawPanel, $PingCallback)

            $ping = New-Object System.Net.NetworkInformation.Ping
            foreach ($server in $Servers) {
                try {
                    $reply = $ping.Send($server.IP, 3000)
                    $status = if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        "[OK]"
                    }
                    else {
                        "[FAIL]"
                    }
                }
                catch {
                    $status = "[ERR]"
                }
                $ip = $server.IP
                $time = Get-Date
                $DrawPanel.BeginInvoke([Action[string, string, System.DateTime]] {
                        param($Ip, $St, $Tm)
                        & $PingCallback $Ip $St $Tm
                    }, $ip, $status, $time) | Out-Null
            }
            $ping.Dispose()
        })
    $ps.AddParameter('Servers', $serverList)
    $ps.AddParameter('DrawPanel', $script:mainDrawPanel)
    $ps.AddParameter('PingCallback', $pingCallback)
    $async = Invoke-Async -Ps $ps
    try {
        $ps.EndInvoke($async) | Out-Null
    }
    catch {
        Write-Log -Message "Ошибка пинга: $($_.Exception.Message)"
    }
    finally {
        Update-PingButton -IsPinging $false
        Write-Log -Message ""
        Write-HistoryFile
        $rs.Dispose()
        $ps.Dispose()
        $script:currentPingStartTime = $null
    }
}