<#
.SYNOPSIS
  Despliegue Zero-Touch Altitude uCI / SIPPhone (campana Iber) desde USB o disco.

.DESCRIPTION
  - Origen dinamico: $PSScriptRoot (no requiere C:\Deploy Iber).
  - Instala Altitude.exe en silencio (InstallShield /s; usa setup.iss si existe).
  - Copia config, SIPPhoneSSO.exe, acceso directo y RegistrarSoftphone.bat.
  - Sin Read-Host / pausas interactivas.

.NOTES
  Ejecutar como Administrador (EJECUTAR-Iber.bat).
  Si /s falla, genera setup.iss grabando: Altitude.exe /r /f1".\setup.iss"
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param (
    [string]$DeployRoot = "",
    [string]$TargetFolder = "C:\Program Files (x86)\Altitude\Altitude uCI 8\Altitude SIPPhone",
    [string]$PublicDesktop = "C:\Users\Public\Desktop",
    [string]$AltitudeSilentArgs = "",
    [int]$InstallTimeoutMinutes = 45,
    [switch]$SkipInstall,
    [switch]$SkipShortcut
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($DeployRoot)) {
    if (-not $PSScriptRoot) {
        throw "No se pudo resolver la carpeta del script. Pasa -DeployRoot."
    }
    $DeployRoot = $PSScriptRoot
}
$DeployRoot = $DeployRoot.TrimEnd("\", "/")

function Write-L3Log {
    param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("Info", "Step", "Ok", "Warn", "Error", "Title")]
        [string]$Level = "Info"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{
        Title = "Magenta"; Step = "Yellow"; Ok = "Green"
        Warn = "DarkYellow"; Error = "Red"; Info = "Cyan"
    }
    Write-Host ("[{0}] [{1}] {2}" -f $ts, $Level.ToUpper(), $Message) -ForegroundColor $colors[$Level]

    $logDir = Join-Path $DeployRoot "Logs"
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir ("Instalar-Iber_{0:yyyyMMdd}.log" -f (Get-Date))
    Add-Content -LiteralPath $logFile -Value ("[{0}] [{1}] {2}" -f $ts, $Level.ToUpper(), $Message) -Encoding UTF8
}

function Assert-Path {
    param ([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontro $Label en: $Path"
    }
}

function Expand-PackagedAssets {
    param ([string]$Root)
    Get-ChildItem -LiteralPath $Root -Filter "*.zip" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = Join-Path $Root $_.BaseName
        Write-L3Log -Level Step -Message ("Extrayendo paquete: {0}" -f $_.Name)
        if (-not (Test-Path -LiteralPath $dest)) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        }
        Expand-Archive -LiteralPath $_.FullName -DestinationPath $dest -Force
        # Si el zip trae los binarios en raiz del extract, copiarlos a DeployRoot
        foreach ($name in @("Altitude.exe", "Altitude.SoftPhone.exe.config", "SIPPhoneSSO.exe", "RegistrarSoftphone.bat")) {
            $found = Get-ChildItem -LiteralPath $dest -Filter $name -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                Copy-Item -LiteralPath $found.FullName -Destination (Join-Path $Root $name) -Force
            }
        }
    }
}

function Get-SilentArguments {
    param ([string]$Root, [string]$Override)
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        return $Override
    }
    $iss = Join-Path $Root "setup.iss"
    if (Test-Path -LiteralPath $iss) {
        # InstallShield: /s + fichero de respuesta
        return ("/s /f1`"{0}`"" -f $iss)
    }
    # Intento generico InstallShield silencioso
    return "/s"
}

function Wait-TargetFolder {
    param ([string]$Folder, [int]$TimeoutMinutes)
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    Write-L3Log -Level Info -Message ("Esperando carpeta de instalacion: {0}" -f $Folder)
    do {
        if (Test-Path -LiteralPath $Folder) { return }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    throw ("Timeout: no aparecio la carpeta destino tras la instalacion: {0}" -f $Folder)
}

function New-PublicShortcut {
    param ([string]$TargetPath, [string]$ShortcutPath, [string]$WorkingDirectory)
    Assert-Path -Path $TargetPath -Label "destino del acceso directo"
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($ShortcutPath)
    $sc.TargetPath = $TargetPath
    $sc.WorkingDirectory = $WorkingDirectory
    $sc.IconLocation = "$TargetPath,0"
    $sc.Save()
}

try {
    Write-L3Log -Level Title -Message "===== DESPLIEGUE ZERO-TOUCH IBER / ALTITUDE SIPPHONE ====="
    Write-L3Log -Level Info -Message ("Origen: {0}" -f $DeployRoot)

    Expand-PackagedAssets -Root $DeployRoot

    $altitudeInstaller = Join-Path $DeployRoot "Altitude.exe"
    $configSource = Join-Path $DeployRoot "Altitude.SoftPhone.exe.config"
    $ssoSource = Join-Path $DeployRoot "SIPPhoneSSO.exe"
    $batSource = Join-Path $DeployRoot "RegistrarSoftphone.bat"
    $ssoTarget = Join-Path $TargetFolder "SIPPhoneSSO.exe"
    $shortcutPath = Join-Path $PublicDesktop "SIPPhoneSSO.lnk"

    Assert-Path -Path $altitudeInstaller -Label "Altitude.exe"
    Assert-Path -Path $configSource -Label "Altitude.SoftPhone.exe.config"
    Assert-Path -Path $ssoSource -Label "SIPPhoneSSO.exe"
    Assert-Path -Path $batSource -Label "RegistrarSoftphone.bat"

    if (-not $SkipInstall) {
        $argsSilent = Get-SilentArguments -Root $DeployRoot -Override $AltitudeSilentArgs
        Write-L3Log -Level Step -Message ("Instalando Altitude en silencio: {0} {1}" -f $altitudeInstaller, $argsSilent)
        $proc = Start-Process -FilePath $altitudeInstaller -ArgumentList $argsSilent -Wait -PassThru -WindowStyle Hidden
        Write-L3Log -Level Info -Message ("Altitude ExitCode: {0}" -f $proc.ExitCode)

        # Algunos paquetes InstallShield devuelven 0 con /s incompleto; validamos carpeta.
        Wait-TargetFolder -Folder $TargetFolder -TimeoutMinutes $InstallTimeoutMinutes
        Write-L3Log -Level Ok -Message "Altitude instalado (carpeta destino detectada)."
    }
    else {
        Write-L3Log -Level Warn -Message "SkipInstall: se omite Altitude.exe"
        Assert-Path -Path $TargetFolder -Label "carpeta Altitude SIPPhone"
    }

    Write-L3Log -Level Step -Message "Copiando configuracion SoftPhone..."
    Copy-Item -LiteralPath $configSource -Destination $TargetFolder -Force

    Write-L3Log -Level Step -Message "Copiando SIPPhoneSSO.exe..."
    Copy-Item -LiteralPath $ssoSource -Destination $ssoTarget -Force

    if (-not $SkipShortcut) {
        Write-L3Log -Level Step -Message "Creando acceso directo en escritorio publico..."
        New-PublicShortcut -TargetPath $ssoTarget -ShortcutPath $shortcutPath -WorkingDirectory $TargetFolder
    }

    Write-L3Log -Level Step -Message "Copiando RegistrarSoftphone.bat al escritorio publico..."
    Copy-Item -LiteralPath $batSource -Destination $PublicDesktop -Force

    Write-L3Log -Level Title -Message "===== IBER / ALTITUDE COMPLETADO ====="
    exit 0
}
catch {
    Write-L3Log -Level Error -Message ("CRITICO: {0}" -f $_.Exception.Message)
    Write-L3Log -Level Warn -Message "Si el silencio fallo, graba respuesta InstallShield: Altitude.exe /r /f1`"setup.iss`" y vuelve a ejecutar."
    exit 1
}
