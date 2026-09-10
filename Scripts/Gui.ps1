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
    $table.Dock = [System.Windows.Forms.DockStyle]::Fill
    $table.ColumnCount = 1
    $table.RowCount = 2
    $table.Padding = New-Object System.Windows.Forms.Padding(7)

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
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $label.Text = $Text

    return $label
}

# Создать расширенное текстовое поле
function New-RichTextBox {
    $richTextBox = New-Object System.Windows.Forms.RichTextBox
    $richTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $richTextBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $richTextBox.BackColor = [System.Drawing.Color]::Black
    $richTextBox.ForeColor = [System.Drawing.Color]::White
    $richTextBox.Font = New-Object System.Drawing.Font("Consolas", $script:config.FontSize)
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
    $comboBox.Location = New-Object System.Drawing.Point(90, 200)
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

# Создать чекбокс
function New-CheckBox {
    param($X, $Y, $Width, $Height, $Text)

    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Location = New-Object System.Drawing.Point($X, $Y)
    $checkBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $checkBox.Text = $Text

    return $checkBox
}

# Создать список
function New-ListBox {
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $listBox.Font = New-Object System.Drawing.Font("Consolas", 10)

    return $listBox
}

# Создать таблицу данных
function New-DataGridView {
    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Location = New-Object System.Drawing.Point(10, 10)
    $dataGridView.Size = New-Object System.Drawing.Size(364, 180)
    $dataGridView.AllowUserToResizeRows = $false
    $dataGridView.AllowUserToResizeColumns = $false
    $dataGridView.MultiSelect = $false
    $dataGridView.SelectionMode = "FullRowSelect"
    $dataGridView.AutoSizeColumnsMode = "Fill"
    
    return $dataGridView
}

# Установить цвет текста консоли
function Set-ConsoleColor {
    param($Color)
    
    Select-StartOfConsole -Console $script:console
    
    $script:console.SelectionLength = 0
    $script:console.SelectionColor = $Color
}

# Сбросить цвет текста консоли
function Reset-ConsoleColor {
    $script:console.SelectionColor = [System.Drawing.Color]::White
}

# Добавить текст в консоль
function Add-ToConsole {
    param($Text)

    $script:console.AppendText($Text)

    Select-StartOfConsole -Console $script:console

    $script:console.ScrollToCaret()
}

# Добавить данные в таблицу
function Add-ToDataGridView {
    param($DataGridView)

    $DataGridView.Columns.Add("Name", "Имя сервера")
    $DataGridView.Columns.Add("IP", "IP-адрес")

    foreach ($server in $script:config.Servers) {
        $DataGridView.Rows.Add($server.Name, $server.IP)
    }
}

# Выбрать начало консоли
function Select-StartOfConsole {
    param($Console)

    $Console.SelectionStart = $Console.TextLength
}