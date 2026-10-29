@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title Santander Empresas - Desinstalar todo

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

set "EMP_ROOT=%~dp0"
if "%EMP_ROOT:~-1%"=="\" set "EMP_ROOT=%EMP_ROOT:~0,-1%"

if not exist "%EMP_ROOT%\Desinstalar-Todo-SantanderEmpresas.ps1" (
  echo ERROR: no encuentra Desinstalar-Todo-SantanderEmpresas.ps1
  echo Ruta: %EMP_ROOT%
  pause
  exit /b 1
)

echo Desinstalando Santander Empresas en este PC...
echo Script: %EMP_ROOT%
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%EMP_ROOT%\Desinstalar-Todo-SantanderEmpresas.ps1" -EmpresasRoot "%EMP_ROOT%"
set "ERR=!errorlevel!"
echo.
if "!ERR!"=="0" (
  echo === Desinstalacion completada ===
) else (
  echo === Desinstalacion con avisos ^(codigo !ERR!^) ===
  echo Si quedaron programas, cierre Citrix/IronChip y repita.
)
echo Log: %TEMP%\SantanderEmpresas\  o  %EMP_ROOT%\Logs\
echo.
pause
exit /b !ERR!
