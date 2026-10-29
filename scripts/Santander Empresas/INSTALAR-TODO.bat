@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title Santander Empresas - Citrix BCR + IronChip

net session >nul 2>&1
if not %errorlevel%==0 (
  echo.
  echo === Administrador local requerido ===
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%~1' -WorkingDirectory '%CD%' -Verb RunAs -Wait"
  exit /b !errorlevel!
)

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"
set "DEPLOY=C:\Deploy\Santander Empresas"
set "EMP_ROOT=%SRC%"

echo Origen ^(lapiz/USB^): %SRC%

if /I not "%SRC%"=="%DEPLOY%" (
  echo Copiando a %DEPLOY% ...
  if not exist "C:\Deploy" mkdir "C:\Deploy"
  robocopy "%SRC%" "%DEPLOY%" /E /R:2 /W:2 /NFL /NDL /NJH /NJS /NC /NS
  if !errorlevel! GEQ 8 (
    set "EMP_ROOT=%SRC%"
  ) else (
    set "EMP_ROOT=%DEPLOY%"
    powershell.exe -NoProfile -Command "Get-ChildItem -LiteralPath '%DEPLOY%' -Recurse -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"
  )
)

if not exist "%EMP_ROOT%\Instalar-SantanderEmpresas.ps1" (
  echo ERROR: Falta Instalar-SantanderEmpresas.ps1 en %EMP_ROOT%
  pause
  exit /b 1
)

cd /d "%EMP_ROOT%"
if /I "%~1"=="solo-citrix" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%EMP_ROOT%\Instalar-SantanderEmpresas.ps1" -EmpresasRoot "%EMP_ROOT%" -LogCopyRoot "%SRC%" -SoloCitrix
) else if /I "%~1"=="solo-acceso-citrix" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%EMP_ROOT%\Instalar-SantanderEmpresas.ps1" -EmpresasRoot "%EMP_ROOT%" -LogCopyRoot "%SRC%" -SoloAccesoCitrix
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%EMP_ROOT%\Instalar-SantanderEmpresas.ps1" -EmpresasRoot "%EMP_ROOT%" -LogCopyRoot "%SRC%"
)

set "ERR=!errorlevel!"
cd /d "%TEMP%"
if "!ERR!"=="0" (
  if exist "C:\Deploy" (
    powershell.exe -NoProfile -Command "Set-Location $env:TEMP; 1..6 | ForEach-Object { if (Test-Path 'C:\Deploy') { Remove-Item -LiteralPath 'C:\Deploy' -Recurse -Force -ErrorAction SilentlyContinue }; if (-not (Test-Path 'C:\Deploy')) { exit 0 }; Start-Sleep 2 }; exit 1"
  )
  echo === Completado ===
) else (
  echo === Avisos codigo !ERR! - Log: %TEMP%\SantanderEmpresas\ ===
)
pause
exit /b !ERR!
