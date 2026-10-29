@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title Santander Sace - Desinstalar todo

net session >nul 2>&1
if not %errorlevel%==0 (
  echo.
  echo === Administrador local requerido ===
  echo Acepte el aviso UAC.
  echo.
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%CD%' -Verb RunAs -Wait"
  set "ELEV=!errorlevel!"
  if not "!ELEV!"=="0" pause
  exit /b !ELEV!
)

set "SACE_ROOT=%~dp0"
if "%SACE_ROOT:~-1%"=="\" set "SACE_ROOT=%SACE_ROOT:~0,-1%"

if not exist "%SACE_ROOT%\Desinstalar-Todo-SantanderSace.ps1" (
  echo ERROR: no encuentra Desinstalar-Todo-SantanderSace.ps1
  echo Ruta: %SACE_ROOT%
  pause
  exit /b 1
)

echo Desinstalando Santander Sace en este PC...
echo Script: %SACE_ROOT%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SACE_ROOT%\Desinstalar-Todo-SantanderSace.ps1" -SantanderRoot "%SACE_ROOT%"
set "ERR=!errorlevel!"
echo.
if "!ERR!"=="0" (
  echo === Desinstalacion completada ===
) else (
  echo === Desinstalacion con avisos ^(codigo !ERR!^) ===
  echo Si quedaron carpetas, cierre BanesNet/Supernet y repita.
)
echo Log: %TEMP%\SantanderSace\
echo.
pause
exit /b !ERR!
