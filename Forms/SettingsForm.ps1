# Показать форму настроек
function Show-SettingsForm {
    $settingsForm = New-Form -Width 400 -Height 410 -Title "Настройки"

    $displayLabel = New-Label -X 10 -Y 200 -Width 80 -Height 20 -Text "Отображение:"
    $intervalLabel = New-Label -X 10 -Y 230 -Width 130 -Height 20 -Text "Интервал пинга (мин.):"
    $fontSizeLabel = New-Label -X 10 -Y 260 -Width 130 -Height 20 -Text "Размер шрифта:"
    $versionLabel = New-Label -X 10 -Y 341 -Width 80 -Height 20 -Text $script:version

    $okButton = New-Button -X 204 -Y 331 -Width 80 -Text "OK"
    $cancelButton = New-Button -X 294 -Y 331 -Width 80 -Text "Отмена"

    $displayComboBox = New-ComboBox

    $intervalNumericUpDown = New-NumericUpDown -X 140 -Y 230 -Min 1 -Max 999 -Value $script:config.Interval
    $fontSizeNumericUpDown = New-NumericUpDown -X 140 -Y 260 -Min 10 -Max 20 -Value $script:config.FontSize

    $groupingCheckBox = New-Checkbox -X 10 -Y 290 -Width 200 -Height 20 -Text "Группировать"
    $loggingCheckBox = New-CheckBox -X 10 -Y 310 -Width 200 -Height 20 -Text "Вести запись в журнал"

    $serverDataGridView = New-DataGridView

    $versionLabel.ForeColor = [System.Drawing.Color]::DarkGray

    $okButton.DialogResult = "OK"
    $cancelButton.DialogResult = "Cancel"

    $groupingCheckBox.Checked = $script:config.GroupingEnabled
    $loggingCheckBox.Checked = $script:config.LoggingEnabled

    $settingsForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $settingsForm.MinimizeBox = $false
    $settingsForm.Controls.Add($serverDataGridView)
    $settingsForm.Controls.Add($displayLabel)
    $settingsForm.Controls.Add($intervalLabel)
    $settingsForm.Controls.Add($fontSizeLabel)
    $settingsForm.Controls.Add($versionLabel)
    $settingsForm.Controls.Add($okButton)
    $settingsForm.Controls.Add($cancelButton)
    $settingsForm.Controls.Add($displayComboBox)
    $settingsForm.Controls.Add($intervalNumericUpDown)
    $settingsForm.Controls.Add($fontSizeNumericUpDown)
    $settingsForm.Controls.Add($groupingCheckBox)
    $settingsForm.Controls.Add($loggingCheckBox)
    $settingsForm.AcceptButton = $okButton
    $settingsForm.CancelButton = $cancelButton

    Add-ToDataGridView -DataGridView $serverDataGridView

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
        $script:config.GroupingEnabled = $groupingCheckBox.Checked
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