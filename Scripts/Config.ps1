# Импортировать конфигурацию
function Import-Config {
    $defaults = @{
        Groups          = @()
        WindowSize      = [PSCustomObject]@{
            Main       = [PSCustomObject]@{ Width = 360; Height = 200 }
            Diagnostic = [PSCustomObject]@{ Width = 640; Height = 320 }
        }
        DisplayMode     = "Full"
        Interval        = 60
        FontSize        = 10
        GroupingEnabled = $true
        LoggingEnabled  = $false
    }
            
    if (Test-Path $script:configFile) {
        try {
            $script:config = Get-Content $script:configFile -Raw | ConvertFrom-Json

            foreach ($key in $defaults.Keys) {
                if ($null -eq $script:config.$key) {
                    $script:config | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]
                }
            }
        }
        catch {
            $script:config = $null
        }
    }
    if (-not $script:config) {
        $script:config = [PSCustomObject]@{
            Servers         = @(
                [PSCustomObject]@{ Name = "Локальный"; IP = "127.0.0.1" }
            )
            Groups          = $defaults.Groups
            WindowSize      = $defaults.WindowSize
            DisplayMode     = $defaults.DisplayMode
            Interval        = $defaults.Interval
            FontSize        = $defaults.FontSize
            GroupingEnabled = $defaults.GroupingEnabled
            LoggingEnabled  = $defaults.LoggingEnabled
        }

        Export-Config
    }
}

# Экспортировать конфигурацию
function Export-Config {
    $script:config | ConvertTo-Json -Depth 3 | Set-Content $script:configFile -Encoding UTF8
}