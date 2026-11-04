# Remove o Clawd: fecha, apaga os atalhos e a pasta de instalacao (incluindo memoria e config)

$dest = Join-Path $env:LOCALAPPDATA 'Clawd'

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*clawd.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

$programs = [Environment]::GetFolderPath('Programs')
foreach ($lnk in (Join-Path $programs 'Clawd.lnk'), (Join-Path $programs 'Desinstalar Clawd.lnk'), (Join-Path ([Environment]::GetFolderPath('Startup')) 'Clawd.lnk')) {
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
}
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }

Write-Host 'Clawd desinstalado. Tchau!'
Start-Sleep 2
