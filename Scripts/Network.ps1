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

# Обновить статус пинга
function Update-PingingStatus {
    param($IsPinging)

    $script:isPinging = $IsPinging
    $script:diagnosticButton.Enabled = !$IsPinging
    $script:pingButton.Enabled = !$IsPinging
    $script:settingsButton.Enabled = !$IsPinging
}

# Запустить пинг
function Start-PingJob {
    if ($script:isPinging) { return }
    Update-PingingStatus -IsPinging $true
    [array]$serverList = Get-ServerList
    if ($serverList.Count -eq 0) {
        Update-PingingStatus -IsPinging $false

        return
    }
    if ($null -ne $script:progressBar) {
        $script:progressBar.Maximum = $serverList.Count
        $script:progressBar.Value = 0
        $script:progressBar.Visible = $true
    }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
            param($Servers, $ProgressBar)

            $results = @()
            $index = 0
            foreach ($server in $Servers) {
                $status = "[ERR]"
                $ping = $null
                try {
                    $ping = New-Object System.Net.NetworkInformation.Ping
                    $task = $ping.SendPingAsync($server.IP, 3000)
                    $completed = $task.Wait(3200)
                    if ($completed) {
                        $reply = $task.Result
                        if ($null -ne $reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                            $status = "[OK]"
                        }
                        else {
                            $status = "[FAIL]"
                        }
                    }
                    else {
                        $status = "[FAIL]"
                    }
                }
                catch {
                    $status = "[ERR]"
                }
                finally {
                    if ($null -ne $ping) {
                        try {
                            $ping.Dispose()
                        }
                        catch { }
                    }
                }
                $results += [PSCustomObject]@{
                    IP     = $server.IP
                    Status = $status
                    Time   = Get-Date
                }
                $index++
                if ($null -ne $ProgressBar) {
                    $val = $index
                    try {
                        $ProgressBar.BeginInvoke([Action[int]] {
                                param($v)
                                $ProgressBar.Value = $v
                            }, $val) | Out-Null
                    }
                    catch { }
                }
                Start-Sleep -Milliseconds 100
            }

            return $results
        })
    $ps.AddParameter('Servers', $serverList)
    $ps.AddParameter('ProgressBar', $script:progressBar)
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
            while ($queue.Count -gt $script:config.HistoryMaxSize) {
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
        Update-PingingStatus -IsPinging $false
        Write-Log -Message ""
        Write-HistoryFile
        $ps.Dispose()
        $rs.Dispose()
        $script:historyReferenceTime = Get-HistoryReferenceTime
        $script:mainDisplayRowsDirty = $true
        if ($null -ne $script:progressBar) {
            $script:progressBar.Visible = $false
            $script:progressBar.Value = 0
        }
        if ($null -ne $script:mainDrawPanel -and -not $script:mainDrawPanel.IsDisposed) {
            $script:mainDrawPanel.Invalidate()
        }
    }
}