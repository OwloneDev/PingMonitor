# Gui.ps1

# Создать форму
function New-Form {
    param($Width, $Height, $Title)

    $form = New-Object System.Windows.Forms.Form
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.Text = $Title
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.MaximizeBox = $false

    return $form
}

# Создать таблицу
function New-Table {
    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.Padding = New-Object System.Windows.Forms.Padding(7)
    $table.Dock = [System.Windows.Forms.DockStyle]::Fill
    $table.ColumnCount = 1
    $table.RowCount = 2

    return $table
}

# Создать панель
function New-Panel {
    param($Dock)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = $Dock

    return $panel
}

# Создать текст
function New-Label {
    param($X, $Y, $Width, $Height, $Text)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.Text = $Text

    return $label
}

# Создать расширенное текстовое поле
function New-RichTextBox {
    $richTextBox = New-Object System.Windows.Forms.RichTextBox
    $richTextBox.Font = New-Object System.Drawing.Font("Consolas", $script:config.FontSize)
    $richTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $richTextBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $richTextBox.BackColor = [System.Drawing.Color]::Black
    $richTextBox.ForeColor = [System.Drawing.Color]::White
    $richTextBox.ReadOnly = $true
    $richTextBox.WordWrap = $false
    $richTextBox.AutoSize = $false

    return $richTextBox
}

# Создать кнопку
function New-Button {
    param($X, $Y, $Width, $Text)

    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, 30)
    $button.Text = $Text

    return $button
}

# Создать комбинированный список
function New-ComboBox {
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(100, 20)
    $comboBox.Size = New-Object System.Drawing.Size(100, 20)
    $comboBox.DropDownStyle = "DropDownList"
    $comboBox.Items.AddRange(@("Полное", "IP-адрес", "Имя сервера"))
    switch ($script:config.DisplayMode) {
        'Full' { $comboBox.SelectedIndex = 0 }
        'IP' { $comboBox.SelectedIndex = 1 }
        'Name' { $comboBox.SelectedIndex = 2 }
    }

    return $comboBox
}

# Создать числовой счётчик
function New-NumericUpDown {
    param($X, $Y, $Min, $Max, $Value)

    $numericUpDown = New-Object System.Windows.Forms.NumericUpDown
    $numericUpDown.Location = New-Object System.Drawing.Point($X, $Y)
    $numericUpDown.Size = New-Object System.Drawing.Size(50, 20)
    $numericUpDown.Minimum = $Min
    $numericUpDown.Maximum = $Max
    $numericUpDown.Value = $Value

    return $numericUpDown
}

# Создать групповой контейнер
function New-GroupBox {
    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Location = New-Object System.Drawing.Point(10, 200)
    $groupBox.Size = New-Object System.Drawing.Size(364, 170)
    $groupBox.Text = "Дополнительные настройки"

    return $groupBox
}

# Создать чекбокс
function New-CheckBox {
    param($X, $Y, $Width, $Height, $Text)

    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Location = New-Object System.Drawing.Point($X, $Y)
    $checkBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $checkBox.Text = $Text

    return $checkBox
}

# Создать дерево
function New-TreeView {
    $treeView = New-Object System.Windows.Forms.TreeView
    $treeView.Font = New-Object System.Drawing.Font("Consolas", 10)
    $treeView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $treeView.BackColor = [System.Drawing.Color]::Black
    $treeView.ForeColor = [System.Drawing.Color]::White
    $treeView.HideSelection = $false
    $treeView.ShowRootLines = $false
    $treeView.ShowLines = $true
    $treeView.ShowPlusMinus = $true
    $treeView.FullRowSelect = $true

    return $treeView
}

# Создать таблицу данных
function New-DataGridView {
    param($Width)

    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Location = New-Object System.Drawing.Point(10, 10)
    $dataGridView.Size = New-Object System.Drawing.Size($Width, 180)
    $dataGridView.AllowUserToResizeRows = $false
    $dataGridView.AllowUserToResizeColumns = $false
    $dataGridView.MultiSelect = $false
    $dataGridView.SelectionMode = "FullRowSelect"
    $dataGridView.AutoSizeColumnsMode = "Fill"
    
    return $dataGridView
}

# Создать подсказку
function New-ToolTip {
    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.AutoPopDelay = 10000
    $toolTip.InitialDelay = 300
    $toolTip.ReshowDelay = 100

    return $toolTip
}

# Создать ручку
function New-Pen {
    param($Color, $Width)

    $pen = New-Object System.Drawing.Pen $Color, $Width

    return $pen
}

# Создать иконку статуса
function New-StatusIcon {
    param($Graphics, $X, $Y, $Size, $Status)

    $colors = @{
        "[OK]"   = [System.Drawing.Color]::LimeGreen
        "[FAIL]" = [System.Drawing.Color]::Red
        "[ERR]"  = [System.Drawing.Color]::Crimson
    }
    $color = if (-not [string]::IsNullOrEmpty($Status) -and $colors.ContainsKey($Status)) {
        $colors[$Status]
    }
    else {
        [System.Drawing.Color]::Gray
    }
    $brush = [System.Drawing.SolidBrush]::new($color)
    $m = $Size * 0.25
    $Graphics.FillEllipse($brush, $X + $m, $Y + $m, $Size - 2 * $m, $Size - 2 * $m)
    $brush.Dispose()
}

# Выбрать начало консоли
function Select-StartOfConsole {
    param($Console)

    $Console.SelectionStart = $Console.TextLength
}

# Читать таблицу даных
function Read-DataGridView {
    param($Row, $Index)

    $value = $Row.Cells[$Index].Value
    if ($value) {
        return $value.ToString()
    }
    else {
        return $null
    }
}