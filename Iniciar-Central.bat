@echo off
title Central de Investimentos

cd /d "%~dp0"

echo ========================================
echo       CENTRAL DE INVESTIMENTOS
echo ========================================
echo.
echo Iniciando a Central...
echo.

where python >nul 2>&1
if not errorlevel 1 goto PYTHON_OK

where py >nul 2>&1
if not errorlevel 1 goto PY_LAUNCHER

echo.
echo ERRO: Python nao encontrado.
echo Execute primeiro o Instalar-Central.bat
echo.
pause
exit /b 1

:PYTHON_OK
start "" http://127.0.0.1:8765
python servidor.py
goto FIM

:PY_LAUNCHER
start "" http://127.0.0.1:8765
py servidor.py

:FIM
pause
