# MainForm.ps1

# Показать главную форму
function Show-MainForm {
    Initialize-GraphicsCache
    $rowHeight = 20
    $size = $script:config.WindowSize.Main
    $mainForm = New-Form -Width $size.Width -Height $size.Height -Title "Мониторинг серверов"
    $table = New-Table
    $panel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Bottom)
    $buttonPanel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Bottom)
    $script:mainDrawPanel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $script:diagnosticButton = New-Button -X 0 -Y 0 -Width 100 -Text "Диагностика"
    $script:pingButton = New-Button -X 110 -Y 0 -Width 100 -Text "Пинг"
    $script:settingsButton = New-Button -X 220 -Y 0 -Width 100 -Text "Настройки"
    $script:progressBar = New-ProgressBar
    $toolTip = New-ToolTip
    $script:mainLastBounds = New-Object System.Drawing.Rectangle($mainForm.Location, $mainForm.Size)
    $mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $mainForm.MinimumSize = New-Object System.Drawing.Size(356, 200)
    $dbProp = [System.Windows.Forms.Control].GetProperty("DoubleBuffered",
        [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
    $dbProp.SetValue($script:mainDrawPanel, $true, $null)
    [void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $table.Controls.Add($script:mainDrawPanel, 0, 0)
    $table.Controls.Add($panel, 0, 1)
    $panel.Height = 60
    $panel.Controls.Add($buttonPanel)
    $panel.Controls.Add($script:progressBar)
    $buttonPanel.Height = 30
    $buttonPanel.Controls.Add($script:diagnosticButton)
    $buttonPanel.Controls.Add($script:pingButton)
    $buttonPanel.Controls.Add($script:settingsButton)
    $script:mainDrawPanel.BackColor = [System.Drawing.Color]::Black
    $script:mainDrawPanel.AutoScroll = $true
    $mainForm.Controls.Add($table)
    $mainForm.Add_Move({
            if ($mainForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
                $script:mainLastBounds = New-Object System.Drawing.Rectangle($mainForm.Location, $mainForm.Size)
            }
        })
    $mainForm.Add_Resize({
            if ($mainForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
                $script:mainLastBounds = New-Object System.Drawing.Rectangle($mainForm.Location, $mainForm.Size)
            }
        })
    $mainForm.Add_FormClosing({
            if ($null -ne $script:mainLastBounds) {
                $script:config.WindowSize.Main.Width = $script:mainLastBounds.Width
                $script:config.WindowSize.Main.Height = $script:mainLastBounds.Height
                $script:config.WindowSize.Main.X = $script:mainLastBounds.X
                $script:config.WindowSize.Main.Y = $script:mainLastBounds.Y
            }
            Stop-Timer
            Export-Config
        })
    $mainForm.Add_HandleCreated({
            $script:mainSnapper = [WindowSnapper]::new($mainForm.Handle)
        })
    $mainForm.AcceptButton = $script:pingButton
    $script:diagnosticButton.Add_Click({ Show-DiagnosticForm })
    $script:pingButton.Add_Click({ Start-PingJob })
    $script:settingsButton.Add_Click({ Show-SettingsForm })
    $script:mainDrawPanel.Add_Paint({
            param($s, $e)

            if ($script:mainDisplayRowsDirty) {
                [array]$serverList = Get-ServerList
                $script:mainDisplayRows = Initialize-HistoryDisplayRows -Servers $serverList
                $script:mainDisplayRowsDirty = $false
            }
            $g = $e.Graphics
            $g.TranslateTransform($s.AutoScrollPosition.X, $s.AutoScrollPosition.Y)
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $rowCount = $script:mainDisplayRows.Count
            $iconSize = 16
            $iconX = 5
            $iconPad = 4
            $textX = $iconX + $iconSize + $iconPad
            $font = $script:gfxFont
            $headerFont = $script:gfxHeaderFont
            $fontBrush = $script:gfxFontBrush
            $headerBrush = $script:gfxHeaderBrush
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
                    $textY = $rowY + ($rowHeight - $script:config.FontSize - 4) / 2
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
                $textY = $rowY + ($rowHeight - $script:config.FontSize - 4) / 2
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
                    $penList = @($script:gfxPenOk, $script:gfxPenFail)
                    $currentGroup = -1
                    $currentPoints = $null
                    $lastY = $null
                    for ($j = 0; $j -lt $count; $j++) {
                        $entry = $arr[$j]
                        $x1 = $labelW + $j * $segmentWidth
                        $x2 = $labelW + ($j + 1) * $segmentWidth
                        $xMid = $x1 + ($x2 - $x1) * 0.5
                        if ($entry.Status -eq "[FAIL]" -or $entry.Status -eq "[ERR]") {
                            $gidx = 1
                        }
                        else {
                            $gidx = 0
                        }
                        $isFail = ($gidx -eq 1)
                        $y = if ($isFail) {
                            $dropY
                        }
                        else {
                            $centerY
                        }
                        if ($null -ne $lastY -and [math]::Abs($lastY - $y) -gt 0.5) {
                            $pts = @(
                                (New-Object System.Drawing.PointF ($x1, $lastY)),
                                (New-Object System.Drawing.PointF ($xMid, $y)),
                                (New-Object System.Drawing.PointF ($x2, $y))
                            )
                        }
                        else {
                            $pts = @(
                                (New-Object System.Drawing.PointF ($x1, $y)),
                                (New-Object System.Drawing.PointF ($x2, $y))
                            )
                        }
                        if ($gidx -eq $currentGroup -and $null -ne $currentPoints) {
                            $lastPt = $currentPoints[$currentPoints.Count - 1]
                            $newPt = $pts[$pts.Count - 1]
                            if ($lastPt.X -ne $newPt.X -or $lastPt.Y -ne $newPt.Y) {
                                $currentPoints = $currentPoints + @($newPt)
                            }
                        }
                        else {
                            if ($null -ne $currentPoints -and $currentPoints.Count -ge 2) {
                                $g.DrawLines($penList[$currentGroup], [System.Drawing.PointF[]]$currentPoints)
                            }
                            $currentGroup = $gidx
                            $currentPoints = $pts
                        }
                        $lastY = $y
                    }
                    if ($null -ne $currentPoints -and $currentPoints.Count -ge 2) {
                        $g.DrawLines($penList[$currentGroup], [System.Drawing.PointF[]]$currentPoints)
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
                        $g.DrawRectangle($script:gfxPenHover, $hx, $rowY + 1, $hw - 1, $rowHeight - 3)
                    }
                }
            }
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
            $showTooltip = $true
            if ($null -ne $foundEntry) {
                if ($foundEntry.Status -eq "[OK]" -and $script:config.HideOkTooltip) {
                    $showTooltip = $false
                }
            }
            if ($null -ne $foundEntry -and $showTooltip) {
                $statusText = switch ($foundEntry.Status) {
                    "[OK]" { "OK" }
                    "[FAIL]" { "FAIL" }
                    "[ERR]" { "ERR" }
                    default { $foundEntry.Status }
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
    Move-Form -Form $mainForm -Size $size
    Start-Timer
    [System.Windows.Forms.Application]::Run($mainForm)
}