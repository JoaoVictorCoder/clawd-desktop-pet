# Atualizacao automatica do Clawd: compara a versao instalada com a do GitHub e,
# se mudou, baixa e troca os arquivos. Roda toda vez antes do Clawd abrir (iniciar.vbs).
#
# -Checar: so diz se tem versao nova, sem instalar (sai com 10 = tem, 0 = nao tem, 1 = erro)
# -Reabrir: atualiza mesmo com "atualizar": false e abre o Clawd no fim (usado pelo menu)
# Pra desligar: "atualizar": false no config.json

param([switch]$Checar, [switch]$Reabrir)

$Repo = 'JoaoVictorCoder/clawd-desktop-pet'
$Branch = 'main'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$verPath = Join-Path $here 'versao.json'
$logPath = Join-Path $here 'clawd.log'
# arquivos do repo que nao fazem parte da instalacao
$SKIP = 'README.md', 'LICENSE', '.gitignore', 'instalar.bat', 'install.ps1', 'config.json', 'memoria.json', 'versao.json', 'clawd.log'
# arquivos que o usuario pode ter editado: se ele mexeu, a versao dele fica
$EDITAVEIS = 'falas.json', 'persona.txt'

function Write-Log([string]$m) { try { Add-Content -Path $logPath -Value ("[{0:HH:mm:ss}] atualizar: {1}" -f (Get-Date), $m) -Encoding UTF8 } catch {} }
function Get-Hash([string]$p) { (Get-FileHash $p -Algorithm SHA256).Hash }
function Exit-Upd([int]$code) {
    if ($Reabrir) { Start-Process powershell.exe -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $here 'clawd.ps1') + '"') }
    exit $code
}

$cfgPath = Join-Path $here 'config.json'
if (-not $Checar -and -not $Reabrir -and (Test-Path $cfgPath)) {
    try { if ((Get-Content $cfgPath -Raw | ConvertFrom-Json).atualizar -eq $false) { exit 0 } } catch {}
}

$ver = @{ sha = ''; hashes = @{} }
if (Test-Path $verPath) {
    try {
        $j = Get-Content $verPath -Raw | ConvertFrom-Json
        $ver.sha = [string]$j.sha
        foreach ($p in $j.hashes.PSObject.Properties) { $ver.hashes[$p.Name] = [string]$p.Value }
    } catch {}
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    # so o hash do ultimo commit: resposta minuscula, sem internet falha rapido
    $sha = ([string](Invoke-RestMethod "https://api.github.com/repos/$Repo/commits/$Branch" -Headers @{ Accept = 'application/vnd.github.sha'; 'User-Agent' = 'clawd-desktop-pet' } -TimeoutSec 6 -UseBasicParsing)).Trim()
} catch { Write-Log ("sem resposta do GitHub: " + $_.Exception.Message); Exit-Upd 1 }
if ($sha -notmatch '^[0-9a-f]{40}$') { Write-Log ("resposta estranha: " + $sha); Exit-Upd 1 }
if ($sha -eq $ver.sha) { Exit-Upd 0 }
if ($Checar) { Exit-Upd 10 }

$tmp = Join-Path $env:TEMP ('clawd-upd-' + [guid]::NewGuid())
try {
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'clawd.zip'
    Invoke-WebRequest "https://github.com/$Repo/archive/$sha.zip" -OutFile $zip -TimeoutSec 60 -UseBasicParsing
    Expand-Archive $zip $tmp
    $src = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
    if (-not (Test-Path (Join-Path $src 'clawd.ps1'))) { throw 'zip sem clawd.ps1' }

    $news = @(Get-ChildItem $src -File | Where-Object { $SKIP -notcontains $_.Name })
    foreach ($f in $news) {
        $dst = Join-Path $here $f.Name
        if ($EDITAVEIS -contains $f.Name -and (Test-Path $dst)) {
            $cur = Get-Hash $dst
            if ($ver.hashes[$f.Name]) {
                if ($cur -ne $ver.hashes[$f.Name]) { Write-Log ($f.Name + ' foi editado, mantendo o seu'); continue }
            } elseif ($cur -ne (Get-Hash $f.FullName)) {
                # instalacao antiga, sem como saber se foi editado: guarda uma copia
                Copy-Item $dst ($dst + '.bak') -Force
            }
        }
        Copy-Item $f.FullName $dst -Force
        $ver.hashes[$f.Name] = Get-Hash $dst
    }
    Get-ChildItem $here -File | Unblock-File
    $ver.sha = $sha
    $ver | ConvertTo-Json | Set-Content -Path $verPath -Encoding UTF8
    Write-Log ("atualizado para " + $sha.Substring(0, 7))
} catch {
    Write-Log ("falhou: " + $_.Exception.Message)
    Exit-Upd 1
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Exit-Upd 0
