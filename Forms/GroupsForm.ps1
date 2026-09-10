# Показать форму групп
function Show-GroupsForm {
    # Добавить данные групп
    function Add-GroupsData {
        $groupDataGridView.Columns.Add("Group", "Название группы")

        foreach ($group in @($script:config.Groups)) {
            [void]$groupDataGridView.Rows.Add($group)
        }

    }

    $groupsForm = New-Form -Width 320 -Height 340 -Title "Группы"

    $groupDataGridView = New-DataGridView -Width 284

    $okButton = New-Button -X 124 -Y 261 -Width 80 -Text "OK"
    $cancelButton = New-Button -X 214 -Y 261 -Width 80 -Text "Отмена"

    $groupingCheckBox = New-Checkbox -X 10 -Y 220 -Width 180 -Height 20 -Text "Группировать"

    $okButton.DialogResult = "OK"
    $cancelButton.DialogResult = "Cancel"

    $groupingCheckBox.Checked = $script:config.GroupingEnabled

    $groupsForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $groupsForm.MinimizeBox = $false
    $groupsForm.Controls.Add($groupDataGridView)
    $groupsForm.Controls.Add($okButton)
    $groupsForm.Controls.Add($cancelButton)
    $groupsForm.Controls.Add($groupingCheckBox)
    $groupsForm.AcceptButton = $okButton
    $groupsForm.CancelButton = $cancelButton

    Add-GroupsData

    if ($groupsForm.ShowDialog() -eq "OK") {
        $newGroups = @()

        foreach ($row in $groupDataGridView.Rows) {
            if ($row.Cells[0].Value -and $row.Cells[0].Value.ToString().Trim() -ne "") {
                $newGroups += $row.Cells[0].Value.ToString().Trim()
            }
        }

        $script:config.Groups = $newGroups
        $script:config.GroupingEnabled = $groupingCheckBox.Checked
        
        Export-Config
    }
}