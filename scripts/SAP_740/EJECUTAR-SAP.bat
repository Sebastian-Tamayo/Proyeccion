@echo off
REM Ejecutar desde el lapiz USB. Clic derecho -> Ejecutar como administrador.
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Solicitando elevacion de administrador...
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo Origen USB/paquete: %~dp0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-SAP740.ps1"
set ERR=%ERRORLEVEL%
echo ExitCode=%ERR%
if %ERR% neq 0 pause
exit /b %ERR%
