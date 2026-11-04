# Instalador do Clawd
#
# Jeito 1: baixe o projeto e de dois cliques em instalar.bat
# Jeito 2: cole no PowerShell:
#   irm https://raw.githubusercontent.com/JoaoVictorCoder/clawd-desktop-pet/main/install.ps1 | iex
#
# Opcoes (variaveis de ambiente): CLAWD_NO_STARTUP=1 nao inicia junto com o Windows

$ErrorActionPreference = 'Stop'
$Repo = 'JoaoVictorCoder/clawd-desktop-pet'
$Branch = 'main'
$dest = Join-Path $env:LOCALAPPDATA 'Clawd'
$files = 'clawd.ps1', 'atividades.ps1', 'truques.ps1', 'falas.json', 'persona.txt', 'iniciar.vbs', 'desinstalar.ps1'

Write-Host ''
Write-Host '  Instalando o Clawd...' -ForegroundColor Yellow

# fecha uma versao que ja esteja rodando
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*clawd.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

$src = $PSScriptRoot
if (-not $src -or -not (Test-Path (Join-Path $src 'clawd.ps1'))) {
    # rodando via "irm | iex": baixa o projeto do GitHub
    $tmp = Join-Path $env:TEMP ('clawd-' + [guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'clawd.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "  Baixando de github.com/$Repo..."
    Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive $zip $tmp
    $src = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
}

# copia os arquivos (config e memoria de quem ja usava ficam intactas)
New-Item -ItemType Directory -Force $dest | Out-Null
foreach ($f in $files) { Copy-Item (Join-Path $src $f) $dest -Force }
Get-ChildItem $dest | Unblock-File

# atalhos: menu Iniciar (abrir e desinstalar) e inicializacao do Windows
$wsh = New-Object -ComObject WScript.Shell
$vbs = Join-Path $dest 'iniciar.vbs'
function New-Shortcut([string]$path, [string]$target, [string]$arguments) {
    $lnk = $wsh.CreateShortcut($path)
    $lnk.TargetPath = $target; $lnk.Arguments = $arguments; $lnk.WorkingDirectory = $dest
    $lnk.Save()
}
$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'
$programs = [Environment]::GetFolderPath('Programs')
New-Shortcut (Join-Path $programs 'Clawd.lnk') $wscript ('"' + $vbs + '"')
New-Shortcut (Join-Path $programs 'Desinstalar Clawd.lnk') (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') ('-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dest 'desinstalar.ps1') + '"')
if ($env:CLAWD_NO_STARTUP -ne '1') {
    New-Shortcut (Join-Path ([Environment]::GetFolderPath('Startup')) 'Clawd.lnk') $wscript ('"' + $vbs + '"')
}

Start-Process $wscript -ArgumentList ('"' + $vbs + '"')

Write-Host '  Pronto! O Clawd ja esta na sua barra de tarefas.' -ForegroundColor Green
Write-Host '  Ele tambem fica no menu Iniciar e abre junto com o Windows.'
if (-not (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Host ''
    Write-Host '  Pra ele conversar e ver a tela, instale o Claude Code e faca login:' -ForegroundColor Cyan
    Write-Host '    winget install Anthropic.ClaudeCode'
    Write-Host '    claude'
    Write-Host '  Ou use outra IA (ChatGPT, Gemini, Ollama...): veja "Usar outra IA" no README.'
}
Write-Host ''
