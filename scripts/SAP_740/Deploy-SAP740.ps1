<#
.SYNOPSIS
  Despliegue Zero-Touch SAP GUI 7.40 desde lapiz USB - EDR-Safe.

.DESCRIPTION
  Ejecutable directamente desde el USB (no requiere copiar a C:\Deploy).
  Fases: SNC -> VC++ -> SAP Base -> Parche -> perfiles/services ->
         pide nombre de equipo + union a corp.ejemplo.local -> reinicio.
  Sin Add-Type/PInvoke, sin cmd.exe ofuscado.

.NOTES
  Click derecho en EJECUTAR SAP.bat -> Ejecutar como administrador.
  DeployRoot por defecto = carpeta del script ($PSScriptRoot).
#>
[CmdletBinding()]
param (
    # Vacio = carpeta donde esta este .ps1 (lapiz USB u otra ruta)
    [string]$DeployRoot = "",
    [string]$SncDllName = "sapsncencryption.dll",
    [string]$BaseProduct = "SAPGUI",
    [string]$DomainName = "corp.ejemplo.local",
    [string]$DomainProbeHost = "SRV-DC-01.corp.ejemplo.local",
    [int]$NetworkTimeoutSeconds = 120,
    [int]$NetworkPollSeconds = 2,
    [switch]$SkipCleanupAndReboot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($DeployRoot)) {
    if (-not $PSScriptRoot) {
        throw "No se pudo resolver la carpeta del script. Pasa -DeployRoot explicitamente."
    }
    $DeployRoot = $PSScriptRoot
}
$DeployRoot = $DeployRoot.TrimEnd('\', '/')

$script:AnsiEnabled = ($Host.Name -eq "ConsoleHost")

function Write-L3Log {
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("Info", "Step", "Ok", "Warn", "Error", "Title")]
        [string]$Level = "Info"
    )

    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $esc = [char]27
    $map = @{
        Title = @{ Ansi = "35;1"; Color = "Magenta"; Tag = "TITLE" }
        Step  = @{ Ansi = "33;1"; Color = "Yellow";  Tag = "STEP"  }
        Ok    = @{ Ansi = "32;1"; Color = "Green";   Tag = "OK"    }
        Warn  = @{ Ansi = "33";   Color = "DarkYellow"; Tag = "WARN" }
        Error = @{ Ansi = "31;1"; Color = "Red";     Tag = "ERROR" }
        Info  = @{ Ansi = "36";   Color = "Cyan";    Tag = "INFO"  }
    }
    $style = $map[$Level]
    $line = "[{0}] [{1}] {2}" -f $ts, $style.Tag, $Message

    if ($script:AnsiEnabled) {
        Write-Host ("{0}[{1}m{2}{0}[0m" -f $esc, $style.Ansi, $line)
    }
    else {
        Write-Host $line -ForegroundColor $style.Color
    }

    $logDir = Join-Path $DeployRoot "Logs"
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir ("Deploy-SAP740_{0:yyyyMMdd}.log" -f (Get-Date))
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-IsAdmin)) {
        throw "Ejecuta EJECUTAR SAP.bat como Administrador (clic derecho)."
    }
}

function Assert-Path {
    param ([string]$Path, [string]$Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontro $Label en: $Path"
    }
}

function Test-RunningFromRemovable {
    try {
        $root = [System.IO.Path]::GetPathRoot($DeployRoot)
        $drive = Get-PSDrive -Name $root.TrimEnd(':\') -ErrorAction SilentlyContinue
        if ($drive -and $drive.Provider.Name -eq "FileSystem") {
            $vol = Get-Volume -DriveLetter $root[0] -ErrorAction SilentlyContinue
            if ($vol -and $vol.DriveType -eq "Removable") { return $true }
        }
        # Fallback: letra distinta de C: suele ser USB en puestos de campo
        return ($root -notmatch '^[Cc]:')
    }
    catch {
        return $true
    }
}

function Invoke-NativeInstaller {
    param (
        [string]$FilePath,
        [string]$Arguments,
        [int[]]$SuccessCodes = @(0),
        [string]$Label
    )

    Write-L3Log -Level Step -Message ("Lanzando {0}: {1} {2}" -f $Label, $FilePath, $Arguments)
    $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    if ($SuccessCodes -notcontains $proc.ExitCode) {
        throw ("{0} fallo. ExitCode: {1}" -f $Label, $proc.ExitCode)
    }
    Write-L3Log -Level Ok -Message ("{0} OK (ExitCode: {1})" -f $Label, $proc.ExitCode)
    return $proc.ExitCode
}

function Wait-DomainConnectivity {
    param (
        [string]$ComputerName,
        [int]$TimeoutSeconds,
        [int]$PollSeconds
    )

    Write-L3Log -Level Info -Message ("Esperando conectividad hacia {0} (timeout {1}s)..." -f $ComputerName, $TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        $ok = $false
        try {
            $tnc = Test-NetConnection -ComputerName $ComputerName -Port 389 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if ($tnc -and $tnc.TcpTestSucceeded) { $ok = $true }
        }
        catch { $ok = $false }

        if (-not $ok) {
            $ok = [bool](Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue)
        }

        if ($ok) {
            Write-L3Log -Level Ok -Message ("Conectividad OK con {0}" -f $ComputerName)
            return
        }
        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    throw ("Timeout de red: {0} no responde antes de {1}s." -f $ComputerName, $TimeoutSeconds)
}

try {
    Assert-Admin
    Assert-Path -Path $DeployRoot -Label "paquete SAP_740 (USB/raiz)"

    $fromUsb = Test-RunningFromRemovable
    Write-L3Log -Level Title -Message "===== DESPLIEGUE SAP GUI 7.40 DESDE MEDIO PORTATIL (EDR-Safe) ====="
    Write-L3Log -Level Info -Message ("Origen: {0}" -f $DeployRoot)
    if ($fromUsb) {
        Write-L3Log -Level Info -Message "Modo USB: se ejecuta in-place (no hay que pegar en C:\Deploy). El lapiz NO se borrara."
    }

    # --- Fase 0: SNC ---
    Write-L3Log -Level Step -Message "Fase 0: Instalar SNC..."
    $dllSource = Join-Path $DeployRoot ("Payload_SNC\SncClientEncryption\x64\{0}" -f $SncDllName)
    $sncTargetDir = "C:\Program Files\SAP\FrontEnd\SecureNetworkCommunications"
    $targetDll = Join-Path $sncTargetDir $SncDllName
    Assert-Path -Path $dllSource -Label "DLL SNC"

    New-Item -ItemType Directory -Path $sncTargetDir -Force | Out-Null
    Copy-Item -LiteralPath $dllSource -Destination $targetDll -Force
    [Environment]::SetEnvironmentVariable("SNC_LIB_64", $targetDll, "Machine")
    [Environment]::SetEnvironmentVariable("SNC_LIB", $targetDll, "Machine")
    Write-L3Log -Level Ok -Message "SNC listo."

    # --- Fase 0.5: VC++ ---
    Write-L3Log -Level Step -Message "Fase 0.5: Instalando Visual C++ (MSI)..."
    $msiFile = Join-Path $DeployRoot "3_libreria\vcredist_x86.msi"
    Assert-Path -Path $msiFile -Label "MSI VC++"
    Invoke-NativeInstaller -FilePath "msiexec.exe" -Arguments "/i `"$msiFile`" /qn /norestart" `
        -SuccessCodes @(0, 3010) -Label "VC++ Redistributable" | Out-Null

    # --- Fase 1: SAP base ---
    Write-L3Log -Level Step -Message "Fase 1: Instalando SAP GUI base..."
    $baseInstaller = Join-Path $DeployRoot "Payload_SAP\setup\NwSapSetup.exe"
    Assert-Path -Path $baseInstaller -Label "Instalador SAP base"
    Invoke-NativeInstaller -FilePath $baseInstaller -Arguments "/Product=`"$BaseProduct`" /Silent" `
        -SuccessCodes @(0, 67, 129, 144) -Label "SAP GUI Base" | Out-Null

    # --- Fase 2: Parche ---
    Write-L3Log -Level Step -Message "Fase 2: Aplicando parche SAP..."
    $patchEngine = Join-Path $DeployRoot "Payload_Patch\Setup\NwSapSetup.exe"
    Assert-Path -Path $patchEngine -Label "Motor de parche"
    Invoke-NativeInstaller -FilePath $patchEngine -Arguments "/Update /Silent" `
        -SuccessCodes @(0, 67, 129, 144) -Label "Parche SAP" | Out-Null

    # --- Fase 3: Common + services ---
    Write-L3Log -Level Step -Message "Fase 3: Copiando entradas SAP (Common/services)..."
    $sapEntriesPath = Join-Path $DeployRoot "4_Entradas SAP"
    $commonSource = Join-Path $sapEntriesPath "Common"
    $servicesSource = Join-Path $sapEntriesPath "services"
    $servicesDest = "C:\Windows\System32\drivers\etc\services"

    $profiles = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath "C:\Users\Default") {
        $profiles.Add("C:\Users\Default")
    }
    Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default User", "All Users") } |
        ForEach-Object {
            if (-not $profiles.Contains($_.FullName)) { $profiles.Add($_.FullName) }
        }

    foreach ($profilePath in $profiles) {
        $commonDest = Join-Path $profilePath "AppData\Roaming\SAP\Common"
        New-Item -ItemType Directory -Path $commonDest -Force | Out-Null
        if (Test-Path -LiteralPath $commonSource) {
            Copy-Item -Path (Join-Path $commonSource "*") -Destination $commonDest -Recurse -Force
        }
    }
    Write-L3Log -Level Ok -Message "Entradas Common listas."

    if (Test-Path -LiteralPath $servicesSource) {
        if (Test-Path -LiteralPath $servicesDest) {
            $backupPath = "{0}.bak_{1:yyyyMMdd_HHmmss}" -f $servicesDest, (Get-Date)
            Copy-Item -LiteralPath $servicesDest -Destination $backupPath -Force
            Write-L3Log -Level Info -Message ("Backup services: {0}" -f $backupPath)
        }
        Copy-Item -LiteralPath $servicesSource -Destination $servicesDest -Force
        Write-L3Log -Level Ok -Message "Archivo services actualizado."
    }
    else {
        Write-L3Log -Level Warn -Message "No se encontro archivo services en 4_Entradas SAP."
    }

    # --- Fase 3.5: Nombre de equipo + union a dominio (igual que el script inicial) ---
    Write-L3Log -Level Step -Message ("Fase 3.5: Solicitando nombre y union a {0}..." -f $DomainName)
    $nuevoNombre = Read-Host "Introduce el nuevo nombre del equipo (ej. PC-LAB-0001)"
    if ([string]::IsNullOrWhiteSpace($nuevoNombre)) {
        throw "Nombre de equipo vacio."
    }

    Wait-DomainConnectivity -ComputerName $DomainProbeHost `
        -TimeoutSeconds $NetworkTimeoutSeconds -PollSeconds $NetworkPollSeconds

    $creds = $Host.UI.PromptForCredential(
        "Autenticacion L3 requerida",
        ("Introduce credenciales con privilegios para {0}" -f $DomainName),
        $env:USERNAME,
        ""
    )
    if ($null -eq $creds) {
        throw "El operador cancelo la ventana de credenciales."
    }

    Add-Computer -NewName $nuevoNombre -DomainName $DomainName -Credential $creds -Force
    Write-L3Log -Level Ok -Message ("Union a dominio inyectada ({0} -> {1}). Pendiente de reinicio." -f $nuevoNombre, $DomainName)

    # --- Fase 4: reinicio (NO borrar el lapiz USB) ---
    if (-not $SkipCleanupAndReboot) {
        Write-L3Log -Level Step -Message "Fase 4: Limpieza menor y reinicio..."
        Clear-RecycleBin -DriveLetter C -Force -ErrorAction SilentlyContinue

        # Solo si alguien dejo una copia vieja en C:\Deploy, se limpia esa (no el USB)
        if (Test-Path -LiteralPath "C:\Deploy\SAP_740") {
            Remove-Item -LiteralPath "C:\Deploy\SAP_740" -Recurse -Force -ErrorAction SilentlyContinue
            Write-L3Log -Level Ok -Message "Eliminada copia local residual C:\Deploy\SAP_740"
        }
        if ($fromUsb) {
            Write-L3Log -Level Info -Message "Paquete en USB preservado (no se elimina el medio)."
        }

        Write-L3Log -Level Title -Message "===== LISTO - REINICIANDO PARA APLICAR DOMINIO ====="
        Write-L3Log -Level Info -Message "Puedes retirar el lapiz cuando el equipo apague/reinicie."
        Start-Sleep -Seconds 3
        Restart-Computer -Force
    }
    else {
        Write-L3Log -Level Warn -Message "SkipCleanupAndReboot: fin sin reiniciar. Reinicia manualmente para aplicar el dominio."
        Write-L3Log -Level Title -Message "===== DESPLIEGUE COMPLETADO ====="
    }
}
catch {
    Write-L3Log -Level Error -Message ("CRITICO: {0}" -f $_.Exception.Message)
    exit 1
}
