# Показать форму настроек
function Show-SettingsForm {
    # Добавить данные серверов
    function Add-ServersData {
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