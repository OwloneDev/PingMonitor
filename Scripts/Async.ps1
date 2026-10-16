# Async.ps1

# Вызвать асинхронно
function Invoke-Async {
    param($Ps)

    $async = $Ps.BeginInvoke()
    while (-not $async.IsCompleted) {
        Start-Sleep -Milliseconds 50
        [System.Windows.Forms.Application]::DoEvents()
    }

    return $async
}