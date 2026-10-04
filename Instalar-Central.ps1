$ErrorActionPreference = 'Stop'

$Pasta = Join-Path $env:USERPROFILE 'Central-Investimentos'
$Zip = Join-Path $Pasta 'Central-Windows.zip'

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '   CENTRAL DE INVESTIMENTOS - INSTALADOR' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

New-Item -ItemType Directory -Force -Path $Pasta | Out-Null

$Origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$Pacote = Join-Path $Origem 'Central-Windows-DISTRIBUICAO.zip'

if (-not (Test-Path $Pacote)) {
    $Pacote = Join-Path $Origem 'Central-Windows.zip'
}

if (-not (Test-Path $Pacote)) {
    throw 'Pacote da Central nao encontrado.'
}

Copy-Item $Pacote $Zip -Force

Get-ChildItem $Pasta -Force |
    Where-Object { $_.Name -ne 'Central-Windows.zip' } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Expand-Archive -Path $Zip -DestinationPath $Pasta -Force

$Python = $null

if (Get-Command python -ErrorAction SilentlyContinue) {
    $Python = 'python'
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $Python = 'py'
}

if (-not $Python) {
    Write-Host 'Python nao encontrado. Tentando instalar pelo WinGet...' -ForegroundColor Yellow

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Python e WinGet nao encontrados.'
    }

    winget install --id Python.Python.3.13 -e --accept-source-agreements --accept-package-agreements

    if (Get-Command python -ErrorAction SilentlyContinue) {
        $Python = 'python'
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $Python = 'py'
    }
    else {
        throw 'Python instalado. Feche e abra o PowerShell e execute novamente.'
    }
}

Write-Host "Python encontrado: $Python" -ForegroundColor Green

& $Python -m pip install -r (Join-Path $Pasta 'requirements.txt')

Write-Host ''
$Token = Read-Host 'Cole o token BRAPI da Central'

if ($Token.Trim()) {
    Set-Content `
        -Path (Join-Path $Pasta 'brapi0token.txt') `
        -Value $Token.Trim() `
        -Encoding UTF8
}

Write-Host ''
Write-Host 'INSTALACAO CONCLUIDA!' -ForegroundColor Green
Write-Host "Pasta: $Pasta"
Write-Host ''
Write-Host 'Iniciando a Central...'

Start-Process powershell `
    -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',
    ("Set-Location -LiteralPath '{0}'; & '{1}' servidor.py" -f $Pasta,$Python)

Start-Sleep -Seconds 3

Start-Process 'http://127.0.0.1:8765'
