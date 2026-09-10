# Показать форму диагностики
function Show-DiagnosticForm {
    # Добавить в список серверов
    function Add-ToServerList {
        # Добавить группу сервера
        function Add-ServerGroup {
            param($Title, $Servers, $Color)

            if ($Servers.Count -eq 0) { return }

            $groupNode = New-Object System.Windows.Forms.TreeNode($Title)
            $groupNode.ForeColor = $Color
            $groupNode.NodeFont = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
            [void]$serversTree.Nodes.Add($groupNode)

            foreach ($server in $Servers) {
                $childNode = New-Object System.Windows.Forms.TreeNode($server.DisplayText)
                $childNode.Tag = $server
                $childNode.ForeColor = $Color
                [void]$groupNode.Nodes.Add($childNode)
            }

            $groupNode.Expand()
        }

        $serversTree.Nodes.Clear()
        $errorServers = @()
        $failServers = @()
        $okServers = @()
        $unknownServers = @()

        foreach ($server in $serverList) {
            $status = $script:serverStatuses[$server.IP]

            switch ($status) {
                "[ERR]" { $errorServers += $server }
                "[FAIL]" { $failServers += $server }
                "[OK]" { $okServers += $server }
                default { $unknownServers += $server }
            }
        }

        Add-ServerGroup -Title "[ERROR]" -Servers $errorServers -Color ([System.Drawing.Color]::Crimson)
        Add-ServerGroup -Title "[FAIL]" -Servers $failServers -Color ([System.Drawing.Color]::Red)
        Add-ServerGroup -Title "[OK]" -Servers $okServers -Color ([System.Drawing.Color]::Chartreuse)
        Add-ServerGroup -Title "[UNKNOWN]" -Servers $unknownServers -Color ([System.Drawing.Color]::White)
    }

    # Добавить в консоль диагностики
    function Add-ToDiagnosticConsole {
        param($Text, $Color = [System.Drawing.Color]::White)
        
        Select-StartOfConsole -Console $diagnosticConsole
        
        $diagnosticConsole.SelectionLength = 0
        $diagnosticConsole.SelectionColor = $Color
        $diagnosticConsole.AppendText("$Text`n")
        $diagnosticConsole.ScrollToCaret()

        Write-Log -Message $Text
    }

    # Получить выбранный сервер
    function Get-SelectedServer {
        $node = $serversTree.SelectedNode

        if ($null -ne $node -and $null -ne $node.Tag) {
            return $node.Tag
        }

        return $null
    }

    # Запустить сбор информации о сервере
    function Start-ServerInfo {
        $server = Get-SelectedServer

        if ($null -eq $server) { return }

        $currentIP = $server.IP
        $diagnosticConsole.Clear()

        Add-ToDiagnosticConsole -Text "Имя: $($server.Name)"
        Add-ToDiagnosticConsole -Text "IP-адрес: $($server.IP)"

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = "STA"
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
                param($Ip)

                # Получить шлюз
                function Get-DefaultGateway {
                    try {
                        $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object -Property RouteMetric | Select-Object -First 1

                        if ($route) {
                            return $route.NextHop
                        }
                    }
                    catch {
                        $output = route print 0.0.0.0
                        $line = $output -split "`n" | Where-Object { $_ -match '0.0.0.0' } | Select-Object -First 1

                        if ($line) {
                            $parts = $line -split '\s+'

                            if ($parts.Count -ge 3) {
                                return $parts[3]
                            }
                        }
                    }
                    
                    return $null
                }

                # Получить MAC-адрес
                function Get-MacAddress {
                    param([string]$IpAddress)

                    try {
                        $output = arp -a 2>$null

                        foreach ($line in $output) {
                            $line = $line.Trim()

                            if ($line -match '^(\d+\.\d+\.\d+\.\d+)\s+(([0-9A-Fa-f]{2}[-:]{5}[0-9A-Fa-f]{2})\s+') {
                                if ($Matches[1] -eq $IpAddress) {
                                    return $Matches[2]
                                }
                            }
                        }
                    }
                    catch {
                        return $null
                    }
                }

                # Определить имя хоста
                function Resolve-HostName {
                    param([string]$HostName)

                    try {
                        $addresses = [System.Net.Dns]::GetHostAddresses($HostName)

                        return ($addresses | ForEach-Object { $_.IPAddressToString }) -join ', '
                    }
                    catch {
                        return $null
                    }
                }

                # Определить IP-адрес
                function Resolve-IpAddress {
                    param([string]$IpAddress)

                    try {
                        $hostEntry = [System.Net.Dns]::GetHostEntry($IpAddress)

                        return $hostEntry.HostName
                    }
                    catch {
                        return $null
                    }
                }

                $info = @()
                $gateway = Get-DefaultGateway

                if ($gateway) {
                    $info += "Шлюз: $gateway"
                }

                $mac = Get-MacAddress -IPAddress $Ip

                if ($mac) {
                    $info += "MAC-адрес: $mac"
                }

                if ($Ip -notmatch '^\d+\.\d+\.\d+\.\d+$') {
                    $dns = Resolve-HostName -HostName $Ip

                    if ($dns) {
                        $info += "DNS: $dns"
                    }
                }
                else {
                    $hostName = Resolve-IpAddress -IPAddress $Ip

                    if ($hostName) {
                        $info += "Имя хоста: $hostName"
                    }
                }

                return $info
            })

        $ps.AddParameter('Ip', $server.IP)
        $async = Invoke-Async -Ps $ps

        try {
            $infoLines = $ps.EndInvoke($async)
            $selected = Get-SelectedServer

            if ($null -ne $selected -and $selected.IP -eq $currentIP) {
                foreach ($line in $infoLines) {
                    Add-ToDiagnosticConsole -Text "$line"
                }
                Add-ToDiagnosticConsole -Text ""
            }
        }
        catch {
            Write-Log -Message "Ошибка сбора информации о сервере: $($_.Exception.Message)"
        }
        finally {
            $rs.Dispose()
            $ps.Dispose()
        }
    }

    # Запустить пинг диагностики
    function Start-DiagnosticPing {
        if ($script:isDiagnosticPinging) { return }

        $server = Get-SelectedServer

        if ($null -eq $server) { return }

        Add-ToDiagnosticConsole -Text "Обмен пакетами с $($server.IP) по с 32 байтами данных:"

        $pingButton.Text = "Стоп"
        $script:isDiagnosticPinging = $true
        $script:diagnosticCts = New-Object System.Threading.CancellationTokenSource

        $outputCallback = {
            param($Txt, $Clr)

            Add-ToDiagnosticConsole -Text $Txt -Color $Clr
        }

        $completedCallback = {
            Add-ToDiagnosticConsole -Text "`n"

            $pingButton.Text = "Пинг"
            $script:isDiagnosticPinging = $false
            $script:diagnosticCts = $null
        }

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = "STA"
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $ps.AddScript({
                param($Ip, $DiagnosticConsole, $OutputCallback, $CompletedCallback, $IsInfinity, $Token)

                $ping = New-Object System.Net.NetworkInformation.Ping
                $successCount = 0
                $totalCount = 0
                $cancelled = $false

                try {
                    while ($true) {
                        if ($Token.IsCancellationRequested) {
                            $cancelled = $true

                            break
                        }
                        try {
                            $reply = $ping.Send($Ip, 3000)
                            $totalCount++

                            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                                $successCount++
                                $rtt = $reply.RoundtripTime
                                $ttl = $reply.Options.Ttl
                                $line = "Ответ от $Ip`: число байт=32 время=${rtt}мс TTL=${ttl}"
                                $color = [System.Drawing.Color]::Chartreuse
                            }
                            else {
                                $line = "Превышен интервал ожидания для запроса."
                                $color = [System.Drawing.Color]::Red
                            }
                        }
                        catch {
                            $line = "Ошибка: $($_.Exception.Message)"
                            $color = [System.Drawing.Color]::Crimson
                        }

                        $DiagnosticConsole.BeginInvoke([Action[string, System.Drawing.Color]] {
                                param($Txt, $Clr)
                                & $OutputCallback $Txt $Clr
                            }, $line, $color) | Out-Null

                        if (-not $IsInfinity -and $totalCount -ge 4) { break }
                        for ($i = 0; $i -lt 10; $i++) {
                            Start-Sleep -Milliseconds 100
                            if ($Token.IsCancellationRequested) {
                                $cancelled = $true

                                break
                            }
                        }
                        if ($cancelled) { break }
                    }

                    if (-not $IsInfinity -and -not $cancelled) {
                        $lostCount = $totalCount - $successCount
                        $lossPercent = if ($totalCount -gt 0) {
                            [math]::Round(($lostCount / $totalCount) * 100)
                        }
                        else {
                            0
                        }
                        $stats = @(
                            "`Статистика Ping для $Ip`:",
                            "    Пакетов: отправлено = $totalCount, получено = $successCount, потеряно = $lostCount",
                            "    ($lossPercent% потерь)"
                        )

                        foreach ($text in $stats) {
                            $DiagnosticConsole.BeginInvoke([Action[string]] {
                                    param($Txt)
                                    & $OutputCallback $Txt ([System.Drawing.Color]::White)
                                }, $text) | Out-Null
                        }
                    }
                }
                finally {
                    $DiagnosticConsole.BeginInvoke([Action] {
                            & $CompletedCallback
                        }) | Out-Null
                    $ping.Dispose()
                    $rs.Dispose()
                    $ps.Dispose()
                }
            })

        $ps.AddParameter('Ip', $server.IP)
        $ps.AddParameter('DiagnosticConsole', $diagnosticConsole)
        $ps.AddParameter('OutputCallback', $outputCallback)
        $ps.AddParameter('CompletedCallback', $completedCallback)
        $ps.AddParameter('IsInfinity', $($infinityCheckBox.Checked))
        $ps.AddParameter('Token', $script:diagnosticCts.Token)
        $ps.BeginInvoke() | Out-Null
    }

    # Остановить пинг диагностики
    function Stop-DiagnosticPing {
        if ($null -ne $script:diagnosticCts) {
            $script:diagnosticCts.Cancel()
        }
    }

    [array]$serverList = Get-ServerList
    $size = $script:config.WindowSize.Diagnostic

    $diagnosticForm = New-Form -Width $size.Width -Height $size.Height -Title "Диагностика серверов"

    $diagnosticPanel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $serversPanel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Left)
    $bottomPanel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Bottom)

    $diagnosticConsole = New-RichTextBox

    $serversTree = New-TreeView

    $infinityCheckBox = New-CheckBox -X 10 -Y 10 -Width 100 -Height 30 -Text "Бесконечный"

    $pingButton = New-Button -X 115 -Y 10 -Width 90 -Text "Пинг"
    $clearButton = New-Button -X 210 -Y 10 -Width 90 -Text "Очистить"
    $closeButton = New-Button -X 305 -Y 10 -Width 90 -Text "Закрыть"

    $serversTree.Add_BeforeSelect({
            param($s, $e)

            if ($script:isDiagnosticPinging) {
                $e.Cancel = $true
            }
        })
    $serversTree.Add_AfterSelect({
            if ($null -ne $serversTree.SelectedNode -and $null -ne $serversTree.SelectedNode.Tag) {
                Start-ServerInfo
            }
        })

    $infinityCheckBox.Checked = $false

    $diagnosticPanel.Controls.Add($diagnosticConsole)
    $serversPanel.Width = 200
    $serversPanel.Controls.Add($serversTree)
    $bottomPanel.Height = 50
    $bottomPanel.Controls.Add($infinityCheckBox)
    $bottomPanel.Controls.Add($pingButton)
    $bottomPanel.Controls.Add($clearButton)
    $bottomPanel.Controls.Add($closeButton)

    $diagnosticForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $diagnosticForm.MinimumSize = New-Object System.Drawing.Size(640, 320)
    $diagnosticForm.MinimizeBox = $false
    $diagnosticForm.Controls.Add($diagnosticPanel)
    $diagnosticForm.Controls.Add($serversPanel)
    $diagnosticForm.Controls.Add($bottomPanel)
    $diagnosticForm.AcceptButton = $pingButton
    $diagnosticForm.CancelButton = $closeButton
    $diagnosticForm.Add_FormClosing({
            $script:config.WindowSize.Diagnostic.Width = $diagnosticForm.Width
            $script:config.WindowSize.Diagnostic.Height = $diagnosticForm.Height

            Export-Config
        })

    $pingButton.Add_Click({
            if ($script:isDiagnosticPinging) {
                Stop-DiagnosticPing
            }
            else {
                Start-DiagnosticPing
            }
        })
    $clearButton.Add_Click({
            $diagnosticConsole.Clear()
        })
    $closeButton.Add_Click({
            if ($script:isDiagnosticPinging) {
                Stop-DiagnosticPing
                Start-Sleep -Milliseconds 100
            }
            
            $diagnosticForm.Close()
        })

    Add-ToServerList

    [void]$diagnosticForm.ShowDialog()
}