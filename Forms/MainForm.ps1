# Показать главную форму
function Show-MainForm {
    # Запустить таймер
    function Start-Timer {
        $script:timer = New-Object System.Windows.Forms.Timer
        $script:timer.Interval = Get-Interval
        $script:timer.Add_Tick({ Start-PingJob })
        $script:timer.Start()
    }

    $size = $script:config.WindowSize.Main

    $mainForm = New-Form -Width $size.Width -Height $size.Height -Title "Мониторинг серверов"

    $table = New-Table

    $panel = New-Panel -Dock ([System.Windows.Forms.DockStyle]::Fill)

    $script:console = New-RichTextBox

    $diagnosticButton = New-Button -X 0 -Y 20 -Width 100 -Text "Диагностика"
    $script:pingButton = New-Button -X 110 -Y 20 -Width 100 -Text "Пинг"
    $settingsButton = New-Button -X 220 -Y 20 -Width 100 -Text "Настройки"

    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $table.Controls.Add($script:console, 0, 0)
    $table.Controls.Add($panel, 0, 1)

    $panel.Height = 50
    $panel.Controls.Add($diagnosticButton)
    $panel.Controls.Add($script:pingButton)
    $panel.Controls.Add($settingsButton)

    $mainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $mainForm.MinimumSize = New-Object System.Drawing.Size(356, 200)
    $mainForm.Controls.Add($table)
    $mainForm.Add_FormClosing({
        $script:config.WindowSize.Main.Width = $mainForm.Width
        $script:config.WindowSize.Main.Height = $mainForm.Height
        $script:timer.Stop()
        
        Export-Config
    })
    $mainForm.AcceptButton = $script:pingButton
    
    $diagnosticButton.Add_Click({ Show-DiagnosticForm })
    $script:pingButton.Add_Click({ Start-PingJob })
    $settingsButton.Add_Click({ Show-SettingsForm })

    Start-Timer

    [System.Windows.Forms.Application]::Run($mainForm)
}