# Получить отображаемый текст сервера
function Get-ServerDisplayText {
    param($Server)

    switch ($script:config.DisplayMode) {
        'Full' { return "$($Server.Name) ($($Server.IP))" }
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

    [array]$serverList = Get-ServerList
    $script:console.Clear()

    if ($serverList.Count -eq 0) {
        Add-ToConsole -Text "Нет серверов для пинга.`n"
        Update-PingButton -IsPinging $false
        
        return
    }

    $currentDate = Get-CurrentDate

    Add-ToConsole -Text "--- $currentDate ---`n`n"

    # Runspace
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
            param($Servers, $GroupingEnabled, $GroupCallback, $EmptyCallback, $NameCallback, $StatusCallback)

            # Измерить длину имени
            function Measure-NameLength {
                $max = 0

                foreach ($server in $Servers) {
                    $length = $server.DisplayText.Length

                    if ($length -gt $max) {
                        $max = $length
                    }
                }

                return $max + 4
            }

            # Пингануть сервер
            function Ping-Server {
                param([string]$ComputerName)

                try {
                    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
                        throw "Пустой адрес"
                    }

                    $ping = New-Object System.Net.NetworkInformation.Ping
                    $result = $ping.Send($ComputerName, 3000)

                    if ($result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        return @{ Success = $true; Color = [System.Drawing.Color]::Chartreuse; Status = "  [OK]" }
                    }
                    else {
                        return @{ Success = $false; Color = [System.Drawing.Color]::Red; Status = "[FAIL]" }
                    }
                }
                catch {
                    return @{ Success = $false; Color = [System.Drawing.Color]::Crimson; Status = " [ERR]" }
                }
            }

            # Отправить коллбэк
            function Send-Callback {
                $nameLength = Measure-NameLength
                $lastGroup = $null
                $isFirst = $true

                foreach ($server in $Servers) {
                    $group = $server.Group
                    $displayText = $server.DisplayText

                    if ($GroupingEnabled -and -not [string]::IsNullOrWhiteSpace($group)) {
                        if ($group -ne $lastGroup) {
                            if (-not $isFirst) {
                                $EmptyCallback.Invoke()
                            }
                            $GroupCallback.Invoke($group)
                            $lastGroup = $group
                        }
                        $displayText = "  " + $displayText
                    }
                    else {
                        if (-not $isFirst) {
                            $EmptyCallback.Invoke()
                            $lastGroup = $null
                        }
                    }
                
                    $isFirst = $false
                    $paddedName = $displayText.PadRight($nameLength, ' ')
                    $NameCallback.Invoke($paddedName)
                    $res = Ping-Server -ComputerName $server.IP
                    $StatusCallback.Invoke($res.Status, $res.Color)
                }
            }

            Send-Callback
        })

    $groupCallback = {
        param($GroupTitle)

        Set-ConsoleColor -Color ([System.Drawing.Color]::Cyan)
        Add-ToConsole -Text "$GroupTitle`n"
        Reset-ConsoleColor
        Write-Log -Message $GroupTitle
    }

    $EmptyCallback = {
        Add-ToConsole -Text "`n"
    }

    $nameCallback = {
        param($Name)

        Set-ConsoleColor -Color ([System.Drawing.Color]::White)
        Add-ToConsole -Text $Name
        Set-Log -Message $Name
    }

    $statusCallback = {
        param($Status, $Color)
        
        Set-ConsoleColor -Color $Color
        Add-ToConsole -Text "$Status`n"
        Reset-ConsoleColor
        Write-Log -Message "$($script:currentLog)$Status"
        Set-Log -Message ""
    }

    $ps.AddParameter('Servers', $serverList)
    $ps.AddParameter('GroupingEnabled', $script:config.GroupingEnabled)
    $ps.AddParameter('GroupCallback', $groupCallback)
    $ps.AddParameter('EmptyCallback', $emptyCallback)
    $ps.AddParameter('NameCallback', $nameCallback)
    $ps.AddParameter('StatusCallback', $statusCallback)
    $async = Invoke-Async -Ps $ps

    try {
        $ps.EndInvoke($async)
    }
    catch {
        Write-Log -Message "Ошибка пинга: $($_.Exception.Message)"
    }
    finally {
        Update-PingButton -IsPinging $false
        Write-Log -Message ""

        $rs.Dispose()
        $ps.Dispose()
    }
}