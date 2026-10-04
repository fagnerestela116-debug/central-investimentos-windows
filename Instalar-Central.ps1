$ErrorActionPreference = 'Stop'

$Pasta = Join-Path $env:USERPROFILE 'Central-Investimentos'
$Zip = Join-Path $env:TEMP 'Central-Windows.zip'
$UrlZip = 'https://github.com/fagnerestela116-debug/central-investimentos-windows/raw/refs/heads/main/Central-Windows.zip'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '   CENTRAL DE INVESTIMENTOS' -ForegroundColor Cyan
Write-Host '   INSTALACAO AUTOMATICA WINDOWS' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

New-Item -ItemType Directory -Force -Path $Pasta | Out-Null

Write-Host 'Baixando a Central...' -ForegroundColor Yellow
Invoke-WebRequest -Uri $UrlZip -OutFile $Zip -UseBasicParsing

Write-Host 'Extraindo arquivos...' -ForegroundColor Yellow
Expand-Archive -Path $Zip -DestinationPath $Pasta -Force

Remove-Item $Zip -Force -ErrorAction SilentlyContinue

$Python = $null

if (Get-Command python -ErrorAction SilentlyContinue) {
    $Python = 'python'
}
elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $Python = 'py'
}

if (-not $Python) {
    Write-Host 'Python nao encontrado. Tentando instalar automaticamente...' -ForegroundColor Yellow

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Nao foi possivel encontrar o Python nem o WinGet neste Windows.'
    }

    winget install --id Python.Python.3.13 -e --accept-source-agreements --accept-package-agreements

    if (Get-Command python -ErrorAction SilentlyContinue) {
        $Python = 'python'
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $Python = 'py'
    }
    else {
        throw 'Python foi instalado. Feche e abra o PowerShell e execute novamente.'
    }
}

Write-Host "Python encontrado: $Python" -ForegroundColor Green
Write-Host 'Instalando dependencias...' -ForegroundColor Yellow

& $Python -m pip install -r (Join-Path $Pasta 'requirements.txt')

Write-Host ''
Write-Host '========================================' -ForegroundColor Green
Write-Host 'CONFIGURACAO DO BRAPI' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Se voce possui um token BRAPI, cole-o abaixo.'
Write-Host 'O token sera salvo somente neste computador.'
Write-Host ''

$Token = Read-Host 'Token BRAPI (pressione Enter para pular)'

if ($Token.Trim()) {
    Set-Content -Path (Join-Path $Pasta 'brapi0token.txt') -Value $Token.Trim() -Encoding UTF8
}

Write-Host ''
Write-Host 'Instalacao concluida!' -ForegroundColor Green
Write-Host "Pasta: $Pasta"
Write-Host ''
Write-Host 'Iniciando a Central...' -ForegroundColor Cyan

Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',("Set-Location -LiteralPath '{0}'; & '{1}' servidor.py" -f $Pasta,$Python)

Start-Sleep -Seconds 4

Start-Process 'http://127.0.0.1:8765'

Write-Host ''
Write-Host 'Central iniciada.' -ForegroundColor Green
