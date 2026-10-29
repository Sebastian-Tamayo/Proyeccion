@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title Santander Sace - Instalar todo

net session >nul 2>&1
if not %errorlevel%==0 (
  echo.
  echo === Administrador local requerido ===
  echo Acepte el aviso UAC ^(usuario y clave de admin del PC^).
  echo Esta ventana esperara hasta que termine la instalacion.
  echo.
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%~1' -WorkingDirectory '%CD%' -Verb RunAs -Wait"
  set "ELEV=!errorlevel!"
  echo Proceso elevado finalizado con codigo !ELEV!
  if not "!ELEV!"=="0" pause
  exit /b !ELEV!
)

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"
set "DEPLOY=C:\Deploy\Santander Sace"
set "SACE_ROOT=%SRC%"

echo.
echo Origen: %SRC%
echo.

if /I not "%SRC%"=="%DEPLOY%" (
  echo Copiando paquete a disco local ^(recomendado desde USB^)...
  echo Destino: %DEPLOY%
  if not exist "C:\Deploy" mkdir "C:\Deploy"
  robocopy "%SRC%" "%DEPLOY%" /E /R:2 /W:2 /XD Logs /NFL /NDL /NJH /NJS /NC /NS
  set "RC=!errorlevel!"
  if !RC! GEQ 8 (
    echo AVISO: robocopy devolvio !RC!. Se intenta instalar desde el origen USB.
    set "SACE_ROOT=%SRC%"
  ) else (
    set "SACE_ROOT=%DEPLOY%"
    powershell.exe -NoProfile -Command "Get-ChildItem -LiteralPath '%DEPLOY%' -Recurse -Force -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"
  )
)

if not exist "%SACE_ROOT%\Instalar-Todo-SantanderSace.ps1" (
  echo.
  echo ERROR: No se encuentra Instalar-Todo-SantanderSace.ps1
  echo Ruta: %SACE_ROOT%
  echo Compruebe que el USB tiene la carpeta Santander Sace completa.
  pause
  exit /b 1
)

cd /d "%SACE_ROOT%"
echo Instalando desde: %SACE_ROOT%
echo.

if /I "%~1"=="permisos" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SACE_ROOT%\Instalar-Todo-SantanderSace.ps1" -SoloPermisosDominio
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SACE_ROOT%\Instalar-Todo-SantanderSace.ps1" -SantanderRoot "%SACE_ROOT%"
)
set "ERR=!errorlevel!"

echo.
if "!ERR!"=="0" (
  echo === Instalacion terminada OK ===
  cd /d "%TEMP%"
  if /I exist "C:\Deploy" (
    echo Eliminando copia temporal en C:\Deploy ^(no queda rastro del paquete^)...
    powershell.exe -NoProfile -Command "Set-Location $env:TEMP; $ok=$false; 1..6 | ForEach-Object { if (Test-Path 'C:\Deploy') { Remove-Item -LiteralPath 'C:\Deploy' -Recurse -Force -ErrorAction SilentlyContinue }; if (-not (Test-Path 'C:\Deploy')) { $ok=$true; break }; Start-Sleep -Seconds 2 }; if ($ok) { exit 0 } else { exit 1 }"
    if exist "C:\Deploy" (
      echo AVISO: no se pudo borrar C:\Deploy ^(cierre programas y borre a mano^).
    ) else (
      echo C:\Deploy eliminado. Los programas siguen en C:\BANESNET8 y Supernet.
    )
  )
) else (
  echo === Instalacion termino con codigo !ERR! ===
  echo Revise log: %TEMP%\SantanderSace\
  echo Se conserva C:\Deploy para reintentar o revisar.
)
echo.
pause
exit /b !ERR!
