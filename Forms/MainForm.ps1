# MainForm.ps1

# Показать главную форму
function Show-MainForm {
    $rowHeight = 20
    $size = $script:config.WindowSize.Main
    $mainForm = New-Form -Width $size.Width -Height $size.Height -Title "Мониторинг серверов"
    $table = New-Table
    $panel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $script:mainDrawPanel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $diagnosticButton = New-Button -X 0 -Y 20 -Width 100 -Text "Диагностика"
    $script:pingButton = New-Button -X 110 -Y 20 -Width 100 -Text "Пинг"
    $settingsButton = New-Button -X 220 -Y 20 -Width 100 -Text "Настройки"
    $toolTip = New-ToolTip
    $mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $mainForm.MinimumSize = New-Object System.Drawing.Size(356, 200)
    $dbProp = [System.Windows.Forms.Control].GetProperty("DoubleBuffered",
        [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $dbProp.SetValue($script:mainDrawPanel, $true, $null)
    [void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $table.Controls.Add($script:mainDrawPanel, 0, 0)
    $table.Controls.Add($panel, 0, 1)
    $panel.Height = 50
    $panel.Controls.Add($diagnosticButton)
    $panel.Controls.Add($script:pingButton)
    $panel.Controls.Add($settingsButton)
    $script:mainDrawPanel.BackColor = [System.Drawing.Color]::Black
    $script:mainDrawPanel.AutoScroll = $true
    $mainForm.Controls.Add($table)
    $mainForm.Add_FormClosing({
            $script:config.WindowSize.Main.Width = $mainForm.Width
            $script:config.WindowSize.Main.Height = $mainForm.Height
            Stop-Timer
            Export-Config
        })
    $mainForm.AcceptButton = $script:pingButton
    $diagnosticButton.Add_Click({ Show-DiagnosticForm })
    $script:pingButton.Add_Click({ Start-PingJob })
    $settingsButton.Add_Click({ Show-SettingsForm })
    $script:mainDrawPanel.Add_Paint({
            param($s, $e)

            $serverList = Get-ServerList
            $script:mainDisplayRows = Initialize-HistoryDisplayRows -Servers $serverList
            $g = $e.Graphics
            $g.TranslateTransform($s.AutoScrollPosition.X, $s.AutoScrollPosition.Y)
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $rowCount = $script:mainDisplayRows.Count
            $iconSize = 16
            $iconX = 5
            $iconPad = 4
            $textX = $iconX + $iconSize + $iconPad
            $font = New-Object System.Drawing.Font("Consolas", $script:config.FontSize)
            $headerFont = New-Object System.Drawing.Font("Consolas", $script:config.FontSize, [System.Drawing.FontStyle]::Bold)
            $fontBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
            $headerBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Cyan)
            $okColor = [System.Drawing.Color]::LimeGreen
            $failColor = [System.Drawing.Color]::Red
            $maxLabelWidth = 0
            foreach ($row in $script:mainDisplayRows) {
                $text = if ($row.Type -eq "Header") {
                    $row.Title
                }
                else {
                    Get-ServerDisplayText -Server $row.Server
                }
                $measureFont = if ($row.Type -eq "Header") {
                    $headerFont
                }
                else {
                    $font
                }
                $w = $g.MeasureString($text, $measureFont).Width
                if ($w -gt $maxLabelWidth) {
                    $maxLabelWidth = $w
                }
            }
            $labelW = $textX + [int][math]::Ceiling($maxLabelWidth) + 10
            if ($labelW -lt 80) {
                $labelW = 80
            }
            $script:mainLabelWidth = $labelW
            $barWidth = $s.ClientSize.Width - $labelW - 20
            if ($barWidth -lt 50) {
                $barWidth = 50
            }
            $neededHeight = $rowCount * $rowHeight + 10
            if ($s.AutoScrollMinSize.Height -ne $neededHeight) {
                $s.AutoScrollMinSize = New-Object System.Drawing.Size(0, $neededHeight)
            }
            for ($i = 0; $i -lt $rowCount; $i++) {
                $row = $script:mainDisplayRows[$i]
                $rowY = $i * $rowHeight
                if ($row.Type -eq "Header") {
                    $textY = $rowY + ($rowHeight - $g.MeasureString($row.Title, $headerFont).Height) / 2
                    $g.DrawString($row.Title, $headerFont, $headerBrush, $iconX, $textY)

                    continue
                }
                $server = $row.Server
                $centerY = $rowY + ($rowHeight / 2)
                $dropY = $rowY + $rowHeight - 3
                $status = $script:serverStatuses[$server.IP]
                $iconY = $rowY + ($rowHeight - $iconSize) / 2    
                New-StatusIcon -Graphics $g -X $iconX -Y $iconY -Size $iconSize -Status $status
                $displayText = Get-ServerDisplayText -Server $server
                $textY = $rowY + ($rowHeight - $g.MeasureString($displayText, $font).Height) / 2
                $g.DrawString($displayText, $font, $fontBrush, $textX, $textY)
                $queue = $script:serverHistory[$server.IP]
                if ($null -ne $queue -and $queue.Count -gt 0) {
                    $arr = @($queue)
                    $count = $arr.Count
                    if ($count -gt $script:config.HistoryMaxSize) {
                        $startIdx = $count - $script:config.HistoryMaxSize
                        $arr = $arr[$startIdx..($count - 1)]
                        $count = $script:config.HistoryMaxSize
                    }
                    $script:mainServerWindowSizes[$server.IP] = $count
                    $segmentWidth = $barWidth / $count
                    $segMap = @{}
                    for ($j = 0; $j -lt $count; $j++) {
                        $segMap[$j] = $arr[$j]
                    }
                    $script:mainLastSegMaps[$server.IP] = $segMap
                    $lastY = $null
                    for ($j = 0; $j -lt $count; $j++) {
                        $entry = $arr[$j]
                        $x1 = $labelW + $j * $segmentWidth
                        $x2 = $labelW + ($j + 1) * $segmentWidth
                        $xMid = $x1 + ($x2 - $x1) * 0.5
                        $isPending = ($entry.Status -eq "[PENDING]")
                        $isFail = ($entry.Status -eq "[FAIL]" -or $entry.Status -eq "[ERR]")
                        $y = if ($isFail) {
                            $dropY
                        }
                        else {
                            $centerY
                        }
                        $color = if ($isPending) {
                            [System.Drawing.Color]::Black
                        }
                        elseif ($isFail) {
                            $failColor
                        }
                        else {
                            $okColor
                        }
                        $pen = New-Object System.Drawing.Pen $color, 2
                        if ($null -ne $lastY -and [math]::Abs($lastY - $y) -gt 0.5) {
                            $g.DrawLine($pen, $x1, $lastY, $xMid, $y)
                            $g.DrawLine($pen, $xMid, $y, $x2, $y)
                        }
                        else {
                            $g.DrawLine($pen, $x1, $y, $x2, $y)
                        }
                        $pen.Dispose()
                        $lastY = $y
                    }
                }
                else {
                    $script:mainServerWindowSizes[$server.IP] = 0
                }
                if ($script:mainHoverRow -eq $i -and $script:mainHoverSegment -ge 0) {
                    $count = $script:mainServerWindowSizes[$server.IP]
                    if ($null -ne $count -and $count -gt 0) {
                        $segmentWidth = $barWidth / $count
                        $segLeftF = $labelW + $script:mainHoverSegment * $segmentWidth
                        $segRightF = $labelW + ($script:mainHoverSegment + 1) * $segmentWidth
                        $hx = [int][math]::Round($segLeftF)
                        $hw = [int][math]::Round($segRightF) - $hx
                        if ($hw -lt 1) {
                            $hw = 1
                        }
                        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::LightGray), 1
                        $g.DrawRectangle($pen, $hx, $rowY + 1, $hw - 1, $rowHeight - 3)
                        $pen.Dispose()
                    }
                }
            }
            $font.Dispose()
            $headerFont.Dispose()
            $fontBrush.Dispose()
            $headerBrush.Dispose()
        })
    $script:mainDrawPanel.Add_MouseMove({
            param($s, $e)

            $mousePos = $s.PointToClient([System.Windows.Forms.Cursor]::Position)
            $contentX = $mousePos.X - $s.AutoScrollPosition.X
            $contentY = $mousePos.Y - $s.AutoScrollPosition.Y
            $labelW = $script:mainLabelWidth
            $barWidth = $s.ClientSize.Width - $labelW - 20
            if ($barWidth -lt 50) {
                $barWidth = 50
            }
            $newRow = -1
            $newSegment = -1
            if ($contentX -ge $labelW -and $contentX -lt ($labelW + $barWidth) -and $contentY -ge 0) {
                $rowIndex = -1
                for ($i = 0; $i -lt $script:mainDisplayRows.Count; $i++) {
                    $rowTop = $i * $rowHeight
                    $rowBottom = ($i + 1) * $rowHeight
                    if ($contentY -ge $rowTop -and $contentY -lt $rowBottom) {
                        $rowIndex = $i

                        break
                    }
                }
                if ($rowIndex -ge 0 -and $script:mainDisplayRows[$rowIndex].Type -eq "Server") {
                    $server = $script:mainDisplayRows[$rowIndex].Server
                    $count = $script:mainServerWindowSizes[$server.IP]
                    if ($null -ne $count -and $count -gt 0) {
                        $segmentWidth = $barWidth / $count
                        $segFloat = ($contentX - $labelW) / $segmentWidth
                        $segIdx = [int][math]::Floor($segFloat)
                        if ($segIdx -ge 0 -and $segIdx -lt $count) {
                            $newRow = $rowIndex
                            $newSegment = $segIdx
                        }
                    }
                }
            }
            if ($newRow -ne $script:mainHoverRow -or $newSegment -ne $script:mainHoverSegment) {
                $script:mainHoverRow = $newRow
                $script:mainHoverSegment = $newSegment
                $s.Invalidate()
            }
            if ($newRow -lt 0) {
                $toolTip.SetToolTip($s, "")

                return
            }
            $server = $script:mainDisplayRows[$newRow].Server
            $foundEntry = $null
            $segMap = $script:mainLastSegMaps[$server.IP]
            if ($null -ne $segMap -and $segMap.ContainsKey($newSegment)) {
                $foundEntry = $segMap[$newSegment]
            }
            if ($null -ne $foundEntry -and ($foundEntry.Status -eq "[FAIL]" -or $foundEntry.Status -eq "[ERR]")) {
                $statusText = if ($foundEntry.Status -eq "[FAIL]") {
                    "FAIL"
                }
                else {
                    "ERR"
                }
                $tipText = "$($server.Name) ($($server.IP))`nВремя: $($foundEntry.Time.ToString('dd.MM.yyyy HH:mm:ss'))`nСтатус: $statusText"
                $toolTip.SetToolTip($s, $tipText)
            }
            else {
                $toolTip.SetToolTip($s, "")
            }
        })
    $script:mainDrawPanel.Add_MouseLeave({
            $script:mainHoverRow = -1
            $script:mainHoverSegment = -1
            $script:mainDrawPanel.Invalidate()
        })
    Start-Timer
    [System.Windows.Forms.Application]::Run($mainForm)
}