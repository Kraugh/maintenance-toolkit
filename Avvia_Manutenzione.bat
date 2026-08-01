@echo off
setlocal EnableExtensions
title Maintenance Toolkit 3.7.2

set "ROOT=%~dp0"

fltmc >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Richiesta privilegi amministrativi...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%ROOT%'"
    exit /b
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass ^
  -File "%ROOT%MaintenanceToolkit.ps1" %*

set "RC=%errorlevel%"

if not "%RC%"=="0" (
    echo.
    echo ============================================================
    echo Maintenance Toolkit terminato con codice di errore: %RC%
    echo.
    echo Controllare i log in:
    echo %ROOT%logs
    echo ============================================================
    echo.
    pause
)

exit /b %RC%
