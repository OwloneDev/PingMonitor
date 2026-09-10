# Показать форму настроек
function Show-SettingsForm {
    # Добавить данные серверов
    function Add-ServersData {
        $doubleBufferedProp = [System.Windows.Forms.Control].GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)
        $doubleBufferedProp.SetValue($serverDataGridView, $true, $null)
        $groupColumn = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
        $groupColumn.Name = "Group"
        $groupColumn.HeaderText = "Группа"
        $groupColumn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $groupColumn.Items.Add("") | Out-Null

        foreach ($group in $groups) {
            $groupColumn.Items.Add($group) | Out-Null
        }

        $serverDataGridView.Columns.Add("Name", "Имя сервера")
        $serverDataGridView.Columns.Add("IP", "IP-адрес")
        $serverDataGridView.Columns.Add($groupColumn) | Out-Null
        $script:settingsGroupColumn = $groupColumn

        foreach ($column in $serverDataGridView.Columns) {
            $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
        }
        Update-GroupColumn
        foreach ($server in $script:config.Servers) {
            $groupValue = $server.Group

            if ([string]::IsNullOrWhiteSpace($groupValue) -or -not $groupColumn.Items.Contains($groupValue)) {
                $groupValue = ""
            }

            $serverDataGridView.Rows.Add($server.Name, $server.IP, $groupValue) | Out-Null
        }
    }

    # Обновить выпадающий список групп в столбце «Группа»
    function Update-GroupColumn {
        if ($null -eq $script:settingsGroupColumn) { return }

        $currentValues = @()

        foreach ($row in $serverDataGridView.Rows) {
            $value = $row.Cells[2].Value

            if ($value) {
                $currentValues += $value.ToString()
            }
            else {
                $currentValues += ""
            }
        }

        $script:settingsGroupColumn.Items.Clear()
        $script:settingsGroupColumn.Items.Add("") | Out-Null

        foreach ($group in @($script:config.Groups)) {
            $script:settingsGroupColumn.Items.Add($group) | Out-Null
        }
        for ($i = 0; $i -lt $serverDataGridView.Rows.Count; $i++) {
            $val = $currentValues[$i]
            
            if ([string]::IsNullOrWhiteSpace($val) -or -not $script:settingsGroupColumn.Items.Contains($val)) {
                $serverDataGridView.Rows[$i].Cells[2].Value = ""
            }
            else {
                $serverDataGridView.Rows[$i].Cells[2].Value = $val
            }
        }
    }

    # Включить перетаскивание
    function Enable-Drag {
        $script:dragRowIndex = -1
        $script:dragInsertIndex = -1
        $script:dragInsertSide = "Top"
        $serverDataGridView.AllowDrop = $true
        $serverDataGridView.RowHeadersVisible = $true
        $serverDataGridView.Add_MouseDown({
                param($s, $e)

                if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                    $hit = $s.HitTest($e.X, $e.Y)

                    if ($hit.Type -eq [System.Windows.Forms.DataGridViewHitTestType]::RowHeader) {
                        $script:dragRowIndex = $hit.RowIndex
                    }
                    else {
                        $script:dragRowIndex = -1
                    }
                }
            })
        $serverDataGridView.Add_MouseMove({
                param($s, $e)

                if (($e.Button -band [System.Windows.Forms.MouseButtons]::Left) -and $script:dragRowIndex -ge 0) {
                    [void]$s.DoDragDrop($script:dragRowIndex, [System.Windows.Forms.DragDropEffects]::Move)
                }
            })
        $serverDataGridView.Add_MouseUp({
                param($s, $e)

                $script:dragRowIndex = -1
            })
        $serverDataGridView.Add_DragEnter({
                param($s, $e)

                $e.Effect = [System.Windows.Forms.DragDropEffects]::Move
            })
        $serverDataGridView.Add_DragOver({
                param($s, $e)

                $e.Effect = [System.Windows.Forms.DragDropEffects]::Move
                $clientPoint = $s.PointToClient((New-Object System.Drawing.Point($e.X, $e.Y)))
                $hit = $s.HitTest($clientPoint.X, $clientPoint.Y)
                $targetIndex = $hit.RowIndex
                $newSide = $script:dragInsertSide

                if ($targetIndex -lt 0) {
                    $newIndex = -1
                }
                else {
                    $rowRect = $s.GetRowDisplayRectangle($targetIndex, $true)
                    $middle = $rowRect.Top + ($rowRect.Height / 2)
                    $newSide = if ($clientPoint.Y -lt $middle) {
                        "Top"
                    }
                    else {
                        "Bottom"
                    }
                    $newIndex = $targetIndex
                }

                if ($newIndex -ne $script:dragInsertIndex -or $newSide -ne $script:dragInsertSide) {
                    $script:dragInsertIndex = $newIndex
                    $script:dragInsertSide = $newSide
                    $s.Invalidate()
                }
            })
        $serverDataGridView.Add_DragDrop({
                param($s, $e)

                $script:dragInsertIndex = -1
                $s.Invalidate()
                $clientPoint = $s.PointToClient((New-Object System.Drawing.Point($e.X, $e.Y)))
                $hit = $s.HitTest($clientPoint.X, $clientPoint.Y)
                $targetIndex = $hit.RowIndex
                $sourceIndex = $script:dragRowIndex

                if ($sourceIndex -lt 0 -or $targetIndex -lt 0 -or $sourceIndex -eq $targetIndex) { return }

                $row = $s.Rows[$sourceIndex]
                $name = $row.Cells[0].Value
                $ip = $row.Cells[1].Value
                $group = $row.Cells[2].Value
                $s.Rows.RemoveAt($sourceIndex)

                if ($sourceIndex -lt $targetIndex) {
                    $targetIndex--
                }

                [void]$s.Rows.Insert($targetIndex, $name, $ip, $group)
                $s.ClearSelection()
                $s.Rows[$targetIndex].Selected = $true
                $s.CurrentCell = $s.Rows[$targetIndex].Cells[0]
            })
        $serverDataGridView.Add_DragLeave({
                $script:dragInsertIndex = -1
                $serverDataGridView.Invalidate()
            })
        $serverDataGridView.Add_CellPainting({
                param($s, $e)

                if ($script:dragInsertIndex -ge 0 -and $e.RowIndex -eq $script:dragInsertIndex) {
                    $graphics = $e.Graphics
                    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::DodgerBlue), 6
                    $y = if ($script:dragInsertSide -eq "Top") {
                        $e.CellBounds.Top + 1
                    }
                    else {
                        $e.CellBounds.Bottom - 2
                    }
                    $graphics.DrawLine($pen, $e.CellBounds.Left, $y, $e.CellBounds.Right, $y)
                    $pen.Dispose()
                }
            })
    }
    
    $settingsForm = New-Form -Width 400 -Height 410 -Title "Настройки"

    $displayLabel = New-Label -X 10 -Y 200 -Width 80 -Height 20 -Text "Отображение:"
    $intervalLabel = New-Label -X 10 -Y 230 -Width 130 -Height 20 -Text "Интервал пинга (мин.):"
    $fontSizeLabel = New-Label -X 10 -Y 260 -Width 130 -Height 20 -Text "Размер шрифта:"
    $versionLabel = New-Label -X 130 -Y 341 -Width 60 -Height 20 -Text $script:version

    $groupsButton = New-Button -X 10 -Y 331 -Width 100 -Text "Группы"
    $okButton = New-Button -X 204 -Y 331 -Width 80 -Text "OK"
    $cancelButton = New-Button -X 294 -Y 331 -Width 80 -Text "Отмена"

    $displayComboBox = New-ComboBox

    $intervalNumericUpDown = New-NumericUpDown -X 140 -Y 230 -Min 1 -Max 999 -Value $script:config.Interval
    $fontSizeNumericUpDown = New-NumericUpDown -X 140 -Y 260 -Min 10 -Max 20 -Value $script:config.FontSize

    $loggingCheckBox = New-CheckBox -X 10 -Y 290 -Width 180 -Height 20 -Text "Вести запись в журнал"

    $serverDataGridView = New-DataGridView -Width 364

    $displayLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $intervalLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $fontSizeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $versionLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $versionLabel.ForeColor = [System.Drawing.Color]::DarkGray

    $okButton.DialogResult = "OK"
    $cancelButton.DialogResult = "Cancel"

    $loggingCheckBox.Checked = $script:config.LoggingEnabled

    $settingsForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $settingsForm.MinimizeBox = $false
    $settingsForm.Controls.Add($serverDataGridView)
    $settingsForm.Controls.Add($displayLabel)
    $settingsForm.Controls.Add($intervalLabel)
    $settingsForm.Controls.Add($fontSizeLabel)
    $settingsForm.Controls.Add($versionLabel)
    $settingsForm.Controls.Add($groupsButton)
    $settingsForm.Controls.Add($okButton)
    $settingsForm.Controls.Add($cancelButton)
    $settingsForm.Controls.Add($displayComboBox)
    $settingsForm.Controls.Add($intervalNumericUpDown)
    $settingsForm.Controls.Add($fontSizeNumericUpDown)
    $settingsForm.Controls.Add($loggingCheckBox)
    $settingsForm.AcceptButton = $okButton
    $settingsForm.CancelButton = $cancelButton
    
    $groupsButton.Add_Click({
            Show-GroupsForm
            Update-GroupColumn
        })

    Add-ServersData
    Enable-Drag

    if ($settingsForm.ShowDialog() -eq "OK") {
        $newServers = @()

        foreach ($row in $serverDataGridView.Rows) {
            $name = Read-DataGridView -Row $row -Index 0
            $ip = Read-DataGridView -Row $row -Index 1
            $group = Read-DataGridView -Row $row -Index 2

            if ($null -ne $ip) {
                $newServers += [PSCustomObject]@{
                    Name  = $name
                    IP    = $ip
                    Group = $group
                }
            }
        }

        $script:config.Servers = $newServers
        $script:config.Interval = [int]$intervalNumericUpDown.Value
        $script:config.FontSize = [int]$fontSizeNumericUpDown.Value
        $script:config.LoggingEnabled = $loggingCheckBox.Checked
        $script:timer.Interval = Get-Interval
        $script:console.Font = New-Object System.Drawing.Font("Consolas", $script:config.FontSize)

        switch ($displayComboBox.SelectedIndex) {
            0 { $script:config.DisplayMode = 'Full' }
            1 { $script:config.DisplayMode = 'IP' }
            2 { $script:config.DisplayMode = 'Name' }
        }
        Export-Config
        Start-PingJob
    }
}