@echo off
title Instalacao - Central de Investimentos

cd /d "%~dp0"

echo ========================================
echo     CENTRAL DE INVESTIMENTOS
echo     INSTALACAO PARA WINDOWS
echo ========================================
echo.
echo Verificando Python...
echo.

where python >nul 2>&1
if not errorlevel 1 goto PYTHON_OK

where py >nul 2>&1
if not errorlevel 1 goto PY_LAUNCHER

echo Python nao encontrado neste computador.
echo.
echo Instale o Python 3 pelo site oficial:
echo https://www.python.org/downloads/windows/
echo.
echo IMPORTANTE: durante a instalacao, marque:
echo Add Python to PATH
echo.
pause
exit /b 1

:PYTHON_OK
set "PYTHON=python"
goto INSTALAR

:PY_LAUNCHER
set "PYTHON=py"
goto INSTALAR

:INSTALAR
echo Python encontrado.
%PYTHON% --version
echo.
echo Instalando dependencias da Central...
echo.

%PYTHON% -m pip install -r requirements.txt

if errorlevel 1 (
    echo.
    echo ERRO: nao foi possivel instalar as dependencias.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo INSTALACAO CONCLUIDA COM SUCESSO
echo ========================================
echo.
echo A Central esta pronta.
echo.
echo Para abrir a Central, execute:
echo Iniciar-Central.bat
echo.
pause
