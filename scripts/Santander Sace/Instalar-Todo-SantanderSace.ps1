#Requires -RunAsAdministrator
<#
  Santander Sace - lanzar con INSTALAR-TODO.bat
#>
[CmdletBinding()]
param (
    [string]$SantanderRoot = "",
    [switch]$OmitirBanesNet,
    [switch]$OmitirSupernet,
    [switch]$OmitirSepaTools,
    [switch]$OmitirSchGenerador,
    [switch]$OmitirAccesosDirectos,
    [switch]$OmitirPermisosDominio,
    [switch]$SoloModulosBanesNet,
    [switch]$SoloPermisosDominio
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($SantanderRoot)) {
    $SantanderRoot = $PSScriptRoot
}
$SantanderRoot = $SantanderRoot.Trim().Trim('"').TrimEnd('\', '/').TrimEnd('.')
try {
    $SantanderRoot = (Resolve-Path -LiteralPath $SantanderRoot -ErrorAction Stop).Path
}
catch {
    throw "Ruta Santander Sace invalida: $SantanderRoot"
}

$BanesTarget = "C:\BANESNET8"
# Ruta real lleva o con tilde; se construye en ASCII para evitar errores de codificacion del .ps1
$SupernetTarget = "C:\Supernet Programas de Gesti" + [char]0x00F3 + "n"
$PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
if ([string]::IsNullOrWhiteSpace($PublicDesktop)) {
    $PublicDesktop = "C:\Users\Public\Desktop"
}

function Initialize-InstallLog {
    $usbLogDir = Join-Path $SantanderRoot "Logs"
    $localLogDir = Join-Path $env:TEMP "SantanderSace"
    $useLocal = $false
    if ($SantanderRoot -match '^([A-Za-z]):') {
        $letter = $Matches[1]
        try {
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}:'" -f $letter) -ErrorAction Stop
            if ($disk.DriveType -eq 2) { $useLocal = $true }
        }
        catch { $useLocal = $true }
    }
    if ($useLocal) {
        $script:InstallLogDir = $localLogDir
        $script:InstallLogMirrorDir = $usbLogDir
    }
    else {
        $script:InstallLogDir = $usbLogDir
        $script:InstallLogMirrorDir = $null
    }
    if (-not (Test-Path -LiteralPath $script:InstallLogDir)) {
        New-Item -ItemType Directory -Path $script:InstallLogDir -Force | Out-Null
    }
    $script:InstallLogFile = Join-Path $script:InstallLogDir ("Instalar-Todo_{0:yyyyMMdd}.log" -f (Get-Date))
    if ($useLocal) {
        Write-Host ("[INFO] Log en disco local (USB/pendrive): {0}" -f $script:InstallLogFile) -ForegroundColor Cyan
    }
}

Initialize-InstallLog

function Write-Log {
    param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("Info", "Step", "Ok", "Warn", "Error", "Title")]
        [string]$Level = "Info"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{ Title = "Magenta"; Step = "Yellow"; Ok = "Green"; Warn = "DarkYellow"; Error = "Red"; Info = "Cyan" }
    $line = ("[{0}] [{1}] {2}" -f $ts, $Level.ToUpper(), $Message)
    Write-Host $line -ForegroundColor $colors[$Level]
    if (-not $script:InstallLogFile) { return }
    try {
        Add-Content -LiteralPath $script:InstallLogFile -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Host ("[WARN] No se pudo escribir log: {0}" -f $_.Exception.Message) -ForegroundColor DarkYellow
    }
    if ($script:InstallLogMirrorDir) {
        try {
            if (-not (Test-Path -LiteralPath $script:InstallLogMirrorDir)) {
                New-Item -ItemType Directory -Path $script:InstallLogMirrorDir -Force | Out-Null
            }
            $mirror = Join-Path $script:InstallLogMirrorDir (Split-Path -Leaf $script:InstallLogFile)
            Add-Content -LiteralPath $mirror -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch { }
    }
}

function Test-AlreadyInstalled {
    param ([string]$RegLeaf)
    foreach ($base in @("HKLM:\SOFTWARE\PAQUETES", "HKLM:\SOFTWARE\Wow6432Node\PAQUETES")) {
        $p = Join-Path $base $RegLeaf
        if (Test-Path -LiteralPath $p) { return $true }
    }
    return $false
}

# SID evita fallos en Windows ES (Administradores vs Administrators) y no debe romper el flujo
function Grant-FolderAcl {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Sid,
        [Parameter(Mandatory)][string]$Rights
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $grant = "{0}:{1}" -f $Sid, $Rights
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        $null = Start-Process -FilePath "icacls.exe" -ArgumentList @(
            $Path, "/grant", $grant, "/T", "/C"
        ) -Wait -WindowStyle Hidden
    }
    finally {
        $ErrorActionPreference = $prevEap
    }
}

function Enable-FolderInheritance {
    param ([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        $null = Start-Process -FilePath "icacls.exe" -ArgumentList @($Path, "/inheritance:e") -Wait -WindowStyle Hidden
    }
    finally {
        $ErrorActionPreference = $prevEap
    }
}

function Unblock-SantanderPath {
    param ([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Write-Log -Level Step -Message ("Quitando bloqueo Windows (Zone.Identifier) en: {0}" -f $Path)
    Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }
}

function Set-ShortcutRunAsAdminFlag {
    param (
        [Parameter(Mandatory)][string]$Path,
        [bool]$RunAsAdmin = $false
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -le 0x15) { return }
        if ($RunAsAdmin) {
            $bytes[0x15] = [byte]($bytes[0x15] -bor 0x20)
        }
        else {
            $bytes[0x15] = [byte]($bytes[0x15] -band (-bnot [byte]0x20))
        }
        [System.IO.File]::WriteAllBytes($Path, $bytes)
    }
    catch {
        Write-Log -Level Warn -Message ("No se pudo ajustar acceso directo: {0}" -f $Path)
    }
}

function Clear-PublicDesktopShortcutsRunAsAdmin {
    $fixed = 0
    Get-ChildItem -LiteralPath $PublicDesktop -Recurse -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ShortcutRunAsAdminFlag -Path $_.FullName -RunAsAdmin $false
        $fixed++
    }
    Write-Log -Level Ok -Message ("Accesos directos sin 'Ejecutar como administrador': {0}" -f $fixed)
}

function Add-SantanderDefenderExclusions {
    if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) { return }
    $paths = @($BanesTarget, $SupernetTarget) | Where-Object { Test-Path -LiteralPath $_ }
    foreach ($sp in @("${env:ProgramFiles(x86)}\SEPAtools", "$env:ProgramFiles\SEPAtools")) {
        if (Test-Path -LiteralPath $sp) { $paths += $sp }
    }
    if ($paths.Count -eq 0) { return }
    try {
        Add-MpPreference -ExclusionPath $paths -ErrorAction Stop
        Write-Log -Level Ok -Message ("Defender: exclusion de ruta Santander ({0} rutas)" -f $paths.Count)
    }
    catch {
        Write-Log -Level Warn -Message ("Defender exclusion no aplicada: {0}" -f $_.Exception.Message)
    }
}

function Write-SantanderDomainBlockDiagnostic {
    $diagDir = Join-Path $env:TEMP "SantanderSace"
    if (-not (Test-Path -LiteralPath $diagDir)) { New-Item -ItemType Directory -Path $diagDir -Force | Out-Null }
    $out = Join-Path $diagDir "DIAGNOSTICO-BLOQUEO-DOMINIO.txt"
    $lines = @(
        "Santander Sace - Si usuario DOMINIO ve: administrador bloqueo esta aplicacion",
        "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Equipo: $env:COMPUTERNAME",
        "",
        "NO es fallo del USB. Suele ser AppLocker / Smart App Control (GPO dominio).",
        "Los administradores locales pueden ejecutar; usuarios estandar no.",
        "",
        "Rutas que IT debe PERMITIR en AppLocker:",
        "  C:\BANESNET8\",
        "  C:\Supernet Programas de Gestion\",
        "  C:\Program Files\SEPAtools\",
        "  C:\Program Files (x86)\SEPAtools\",
        "",
        "Prueba en PC con usuario dominio (CMD normal, sin admin):",
        "  dir C:\BANESNET8\BIN\BAN32_34.exe",
        "  C:\BANESNET8\BIN\BAN32_34.exe",
        "Si falla igual: politica de dominio (no permisos NTFS).",
        "",
        "Visor de eventos (soporte):",
        "  Aplicacion y servicios -> Microsoft -> Windows -> AppLocker/EXE and DLL",
        "",
        "Accesos deben estar en escritorio PUBLICO y apuntar a C:\ (no USB)."
    )
    $shell = New-Object -ComObject WScript.Shell
    Get-ChildItem -LiteralPath $PublicDesktop -Filter "*.lnk" -File -ErrorAction SilentlyContinue | Select-Object -First 5 | ForEach-Object {
        $t = $shell.CreateShortcut($_.FullName).TargetPath
        $lines += ("Acceso: {0} -> {1}" -f $_.Name, $t)
    }
    $logDir = Split-Path -Parent $out
    if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Set-Content -LiteralPath $out -Value $lines -Encoding UTF8
    Write-Log -Level Info -Message ("Diagnostico IT: {0}" -f $out)
}

function Grant-StandardUserSantanderAccess {
    Write-Log -Level Title -Message "Ajustes para usuarios de dominio (sin admin local)"
    $grantSids = @(
        @{ Sid = "*S-1-5-11"; Name = "Authenticated Users" },
        @{ Sid = "*S-1-5-32-545"; Name = "Users" }
    )
    $paths = @($BanesTarget, $SupernetTarget)
    if (Test-Path -LiteralPath (Join-Path $env:ProgramFiles "BanesNet8")) {
        $paths += (Join-Path $env:ProgramFiles "BanesNet8")
    }
    foreach ($sp in @("${env:ProgramFiles(x86)}\SEPAtools", "$env:ProgramFiles\SEPAtools")) {
        if (Test-Path -LiteralPath $sp) { $paths += $sp }
    }
    foreach ($extra in @("C:\LOGS", "C:\SAN", "C:\SAN\PAQUETES")) {
        if (-not (Test-Path -LiteralPath $extra)) {
            New-Item -ItemType Directory -Path $extra -Force -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-Path -LiteralPath $extra) { $paths += $extra }
    }

    foreach ($p in ($paths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        Unblock-SantanderPath -Path $p
        Enable-FolderInheritance -Path $p
        foreach ($g in $grantSids) {
            Grant-FolderAcl -Path $p -Sid $g.Sid -Rights "(OI)(CI)M"
        }
        $bin = Join-Path $p "BIN"
        if (Test-Path -LiteralPath $bin) {
            foreach ($g in $grantSids) {
                Grant-FolderAcl -Path $bin -Sid $g.Sid -Rights "(OI)(CI)RX"
            }
        }
        Write-Log -Level Ok -Message ("Permisos dominio aplicados: {0}" -f $p)
    }

    Clear-PublicDesktopShortcutsRunAsAdmin
    Repair-ShortcutTargets
    Add-SantanderDefenderExclusions
    Write-SantanderDomainBlockDiagnostic
    Write-Log -Level Ok -Message "Listo: usuarios de dominio abren programas desde accesos del escritorio publico"
}

function Write-DomainUserReadyCheck {
    Write-Log -Level Title -Message "Comprobacion uso usuario de dominio"
    $bin = Join-Path $BanesTarget "BIN"
    if (Test-Path -LiteralPath $bin) {
        $exeCount = @(Get-ChildItem -LiteralPath $bin -Filter "BAN32*.exe" -File -ErrorAction SilentlyContinue).Count
        Write-Log -Level Info -Message ("BANESNET8\BIN: {0} modulos BAN32*.exe" -f $exeCount)
    }
    else {
        Write-Log -Level Warn -Message "Falta C:\BANESNET8\BIN - repita instalacion BanesNet"
    }
    if (Test-Path -LiteralPath $SupernetTarget) {
        Write-Log -Level Ok -Message ("Supernet presente: {0}" -f $SupernetTarget)
    }
    $sample = Get-ChildItem -LiteralPath $PublicDesktop -Filter "*.lnk" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sample) {
        $shell = New-Object -ComObject WScript.Shell
        $t = $shell.CreateShortcut($sample.FullName).TargetPath
        Write-Log -Level Info -Message ("Ejemplo acceso publico: {0} -> {1}" -f $sample.Name, $t)
        if (-not (Test-Path -LiteralPath $t)) {
            Write-Log -Level Warn -Message "Destino del acceso no existe; repita INSTALAR-TODO.bat"
        }
    }
    Write-Log -Level Info -Message "Prueba: cierre sesion admin e inicie sesion con usuario de dominio; abra icono del escritorio PUBLICO"
}

function Test-SantanderPaquete {
    param ([string]$Root)
    $checks = @(
        @{ Name = "BANESNET"; Path = Join-Path $Root "BANESNET"; File = "BANESNET.EXE" },
        @{ Name = "SepaTools"; Path = Join-Path $Root "SepaTools"; File = "Instalar.vbs" },
        @{ Name = "Supernet"; Path = Join-Path $Root "SUITE SANTANDER MODULOS para Basnet"; File = "ConfirmingLight.exe" },
        @{ Name = "Accesos directos"; Path = Join-Path $Root "accesos directos copiar en escritorio publico"; File = $null }
    )
    $missing = @()
    foreach ($c in $checks) {
        if (-not $c.Path -or -not (Test-Path -LiteralPath $c.Path)) {
            $missing += $c.Name
            continue
        }
        if ($c.File -and -not (Test-Path -LiteralPath (Join-Path $c.Path $c.File))) {
            $missing += ("{0} ({1})" -f $c.Name, $c.File)
        }
    }
    if ($missing.Count -gt 0) {
        Write-Log -Level Warn -Message ("Paquete incompleto. Falta: {0}. Copie del USB (ver ESTRUCTURA-USB.txt)" -f ($missing -join "; "))
        return $false
    }
    Write-Log -Level Ok -Message "Paquete Santander Sace completo en origen"
    return $true
}

function Test-InstallerExitOk {
    param ([object]$ExitCode)
    return ($null -eq $ExitCode -or $ExitCode -eq 0 -or $ExitCode -eq 3010)
}

function Invoke-InstallerProcess {
    param (
        [Parameter(Mandatory)][string]$ExePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory = "",
        [ValidateSet("Hidden", "Normal")]
        [string]$WindowStyle = "Hidden"
    )
    $sp = @{
        FilePath    = $ExePath
        PassThru    = $true
        Wait        = $true
        WindowStyle = $WindowStyle
        ErrorAction = "Stop"
    }
    if ($WorkingDirectory -and (Test-Path -LiteralPath $WorkingDirectory)) {
        $sp.WorkingDirectory = $WorkingDirectory
    }
    if ($ArgumentList -and $ArgumentList.Count -gt 0) {
        $sp.ArgumentList = $ArgumentList
    }
    return Start-Process @sp
}

function Invoke-SilentExe {
    param (
        [Parameter(Mandatory)][string]$ExePath,
        [string]$Label = "",
        [string]$WorkingDirectory = "",
        [switch]$AllowInteractiveFallback,
        [scriptblock]$VerifySuccess
    )
    if (-not (Test-Path -LiteralPath $ExePath)) {
        Write-Log -Level Warn -Message ("No se encontro el ejecutable: {0}" -f $ExePath)
        return $false
    }
    if (-not $WorkingDirectory) {
        $WorkingDirectory = Split-Path -Parent $ExePath
    }
    $name = if ($Label) { $Label } else { Split-Path -Leaf $ExePath }
    $silentArgSets = @(
        @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"),
        @("/VERYSILENT", "/NORESTART"),
        @("/SILENT", "/NORESTART"),
        @("/silent", "/norestart"),
        @("/S", "/v/qn"),
        @("/s", "/v`"/qn`""),
        @("/S"),
        @("/s"),
        @("/quiet", "/norestart")
    )

    foreach ($tryArgs in $silentArgSets) {
        $argDisplay = $tryArgs -join " "
        Write-Log -Level Step -Message ("{0} silencioso -> {1}" -f $name, $argDisplay)
        try {
            $proc = Invoke-InstallerProcess -ExePath $ExePath -ArgumentList $tryArgs `
                -WorkingDirectory $WorkingDirectory -WindowStyle Hidden
            if (-not (Test-InstallerExitOk -ExitCode $proc.ExitCode)) {
                Write-Log -Level Warn -Message ("{0} silencioso exit {1} ({2})" -f $name, $proc.ExitCode, $argDisplay)
                continue
            }
            if ($VerifySuccess) {
                $verified = [bool](& $VerifySuccess)
                if (-not $verified) {
                    Write-Log -Level Warn -Message ("{0} silencioso termino pero no paso verificacion; otro intento o manual" -f $name)
                    continue
                }
            }
            Write-Log -Level Ok -Message ("{0} instalado en silencio (exit {1})" -f $name, $proc.ExitCode)
            return $true
        }
        catch {
            Write-Log -Level Warn -Message ("{0} silencioso fallo: {1}" -f $name, $_.Exception.Message)
        }
    }

    if (-not $AllowInteractiveFallback) {
        Write-Log -Level Warn -Message ("No se pudo instalar en silencio: {0}" -f $name)
        return $false
    }

    Write-Log -Level Warn -Message ("Abriendo asistente MANUAL para {0} (complete y cierre la ventana)" -f $name)
    try {
        $proc = Invoke-InstallerProcess -ExePath $ExePath -WorkingDirectory $WorkingDirectory -WindowStyle Normal
        if ($VerifySuccess) {
            $verified = [bool](& $VerifySuccess)
            if ($verified) {
                Write-Log -Level Ok -Message ("{0} OK tras asistente manual" -f $name)
                return $true
            }
            Write-Log -Level Warn -Message ("{0} manual terminado pero verificacion aun falla" -f $name)
            return $false
        }
        if (Test-InstallerExitOk -ExitCode $proc.ExitCode) {
            Write-Log -Level Ok -Message ("{0} finalizado tras asistente manual (exit {1})" -f $name, $proc.ExitCode)
            return $true
        }
        return $false
    }
    catch {
        Write-Log -Level Warn -Message ("{0} manual fallo: {1}" -f $name, $_.Exception.Message)
        return $false
    }
}

function Invoke-BanesNetInsSilent {
    param ([Parameter(Mandatory)][string]$InsPath)
    $wd = Split-Path -Parent $InsPath
    foreach ($arg in @("/S", "/s", "/SILENT", "/VERYSILENT")) {
        Write-Log -Level Step -Message ("BAN32INS silencioso -> {0}" -f $arg)
        try {
            $p = Invoke-InstallerProcess -ExePath $InsPath -ArgumentList @($arg) `
                -WorkingDirectory $wd -WindowStyle Hidden
            if (Test-InstallerExitOk -ExitCode $p.ExitCode) { return $true }
        }
        catch { }
    }
    return $false
}

function Invoke-BanesNetInsManual {
    param (
        [Parameter(Mandatory)][string]$InsPath,
        [string]$Reason = ""
    )
    $wd = Split-Path -Parent $InsPath
    if ($Reason) { Write-Log -Level Warn -Message $Reason }
    Write-Log -Level Warn -Message "Asistente MANUAL BAN32INS: instale los parches .RTP pendientes y pulse Salir"
    $null = Invoke-InstallerProcess -ExePath $InsPath -WorkingDirectory $wd -WindowStyle Normal
}

function Expand-BanesNetSetup132 {
    param ([string]$BanesDir)
    $setup132 = Join-Path $BanesDir "setup132.exe"
    if (Test-Path -LiteralPath $setup132) { return $setup132 }

    $cab = Join-Path $BanesDir "SETUP132.EX_"
    if (-not (Test-Path -LiteralPath $cab)) {
        Write-Log -Level Error -Message ("Falta SETUP132.EX_ en {0}" -f $BanesDir)
        return $null
    }

    Write-Log -Level Step -Message "Expandiendo SETUP132.EX_ a setup132.exe (requerido por BanesNet)"
    Push-Location -LiteralPath $BanesDir
    try {
        $out = cmd /c "expand SETUP132.EX_ setup132.exe" 2>&1
        $out | ForEach-Object { Write-Log -Level Info -Message ([string]$_) }
    }
    finally {
        Pop-Location
    }

    if (Test-Path -LiteralPath $setup132) {
        Write-Log -Level Ok -Message "setup132.exe listo"
        return $setup132
    }
    Write-Log -Level Error -Message "No se pudo crear setup132.exe"
    return $null
}

function Test-BanesNetInstalled {
    foreach ($root in @($BanesTarget, (Join-Path $env:ProgramFiles "BanesNet8"))) {
        $ins = Join-Path $root "BIN\BAN32INS.EXE"
        if (Test-Path -LiteralPath $ins) { return $root }
    }
    return $null
}

function Set-BanesNetSetupLst {
    param ([string]$BanesDir, [string]$TargetDir)
    $lst = Join-Path $BanesDir "SETUP.LST"
    if (-not (Test-Path -LiteralPath $lst)) { return }
    $content = Get-Content -LiteralPath $lst -Raw -Encoding Default
    if ($content -notmatch "AppPath=") { return }
    if ($content -match 'DefaultDir=\$\(ProgramFiles\)\\BanesNet8') {
        $content = $content -replace 'DefaultDir=\$\(ProgramFiles\)\\BanesNet8', ("DefaultDir={0}" -f $TargetDir)
    }
    elseif ($content -match '(?m)^DefaultDir=.*') {
        $content = $content -replace '(?m)^DefaultDir=.*', ("DefaultDir={0}" -f $TargetDir)
    }
    # AppPath debe quedar vacio; solo DefaultDir fija la ruta destino en el asistente
    $content = $content -replace '(?m)^AppPath=.*', 'AppPath='
    Set-Content -LiteralPath $lst -Value $content -Encoding Default
    Write-Log -Level Info -Message ("SETUP.LST DefaultDir={0}, AppPath vacio" -f $TargetDir)
}

function Write-Paso {
    param ([string]$Numero, [string]$Titulo)
    Write-Log -Level Title -Message ("========== PASO {0} - {1} ==========" -f $Numero, $Titulo)
}

function Initialize-BanesNetTarget {
    foreach ($sub in @("BIN", "DAT", "BD", "PATCH", "AYUDA")) {
        $p = Join-Path $BanesTarget $sub
        if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
    Grant-FolderAcl -Path $BanesTarget -Sid "*S-1-5-32-544" -Rights "(OI)(CI)F"
    Grant-FolderAcl -Path $BanesTarget -Sid "*S-1-5-32-545" -Rights "(OI)(CI)M"
}

function Initialize-BanesNetSourceDir {
    param ([string]$BanesDir)
    Set-BanesNetSetupLst -BanesDir $BanesDir -TargetDir $BanesTarget
    Expand-BanesNetSetup132 -BanesDir $BanesDir | Out-Null
}

function Test-RobocopySuccess {
    param ([int]$ExitCode)
    if (($ExitCode -band 16) -ne 0) { return $false }
    if (($ExitCode -band 8) -ne 0) { return $false }
    return $true
}

function Get-BanesNetWorkingDir {
    param ([string]$BanesDir)
    $stage = "C:\Temp\BanesNetSetup"
    if (-not (Test-Path -LiteralPath (Join-Path $BanesDir "BANESNET.EXE"))) {
        return $BanesDir
    }

    $useStage = $true
    Write-Log -Level Step -Message ("Copia de trabajo BanesNet en {0} (evita rutas con espacios en USB)" -f $stage)
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $robocopy = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
        $BanesDir, $stage, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS", "/R:1", "/W:1", "/Z"
    ) -Wait -PassThru -WindowStyle Hidden
    $robocopyExit = if ($null -ne $robocopy.ExitCode) { [int]$robocopy.ExitCode } else { 0 }
    if (-not (Test-RobocopySuccess -ExitCode $robocopyExit) -or -not (Test-Path -LiteralPath (Join-Path $stage "BANESNET.EXE"))) {
        Write-Log -Level Warn -Message ("Copia a Temp no disponible (robocopy {0}); se usa BANESNET en origen: {1}" -f $robocopyExit, $BanesDir)
        $useStage = $false
    }

    $workDir = if ($useStage) { $stage } else { $BanesDir }
    Initialize-BanesNetSourceDir -BanesDir $workDir
    return $workDir
}

function Install-BanesNetBase {
    param ([string]$BanesDir)
    if (-not (Test-Path -LiteralPath $BanesDir)) {
        Write-Log -Level Error -Message ("Carpeta BANESNET no encontrada: {0}" -f $BanesDir)
        return $null
    }

    if (Test-BanesNetInstalled) {
        Write-Log -Level Ok -Message ("BanesNet base ya instalada en {0}" -f (Test-BanesNetInstalled))
        return Test-BanesNetInstalled
    }

    Initialize-BanesNetTarget
    $workDir = Get-BanesNetWorkingDir -BanesDir $BanesDir
    $bootstrap = Join-Path $workDir "BANESNET.EXE"
    if (-not (Test-Path -LiteralPath $bootstrap)) {
        Write-Log -Level Error -Message ("Falta BANESNET.EXE en {0}" -f $BanesDir)
        return $null
    }

    Write-Log -Level Warn -Message "BanesNet base: asistente MANUAL obligatorio. Destino C:\BANESNET8. En DLL/fuentes use Omitir."
    $p = Start-Process -FilePath $bootstrap -WorkingDirectory $workDir -PassThru -Wait -WindowStyle Normal
    Write-Log -Level Info -Message ("BANESNET.EXE termino con codigo {0}" -f $p.ExitCode)
    return Test-BanesNetInstalled
}

function Install-BanesNet {
    param ([string]$BanesDir)
    $root = Install-BanesNetBase -BanesDir $BanesDir
    if (-not $root) {
        Write-Log -Level Error -Message "BanesNet base no instalada. Ejecute INSTALAR-TODO.bat (paso 1/6) o BANESNET\BANESNET.EXE"
    }
}

function Get-ExpectedBanesNetModuleBases {
    param ([string]$BanesSourceDir)
    $bases = @()
    foreach ($rtp in @(Get-ChildItem -LiteralPath $BanesSourceDir -Filter "*.RTP" -File -ErrorAction SilentlyContinue)) {
        if ($rtp.BaseName -match '^BNET[89]_(.+)$') {
            $bases += ("BAN32_{0}" -f $Matches[1])
        }
    }
    if ($bases.Count -eq 0) {
        return @(
            "BAN32_19", "BAN32_32", "BAN32_34", "BAN32_58", "BAN32_CH", "BAN32_CI",
            "BAN32_EX", "BAN32_IE", "BAN32_JZ", "BAN32_PP", "BAN32_SD", "BAN32_SP"
        )
    }
    return @($bases | Select-Object -Unique)
}

function Test-BanesNetBinHasModule {
    param (
        [string]$BinDir,
        [string]$ModuleBase
    )
    return [bool](Get-ChildItem -LiteralPath $BinDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -ieq ".exe" -and $_.BaseName -ieq $ModuleBase })
}

function Get-MissingBanesNetModules {
    param (
        [string]$BanesSourceDir,
        [string]$BanesInstallDir
    )
    $bin = Join-Path $BanesInstallDir "BIN"
    if (-not (Test-Path -LiteralPath $bin)) { return @(Get-ExpectedBanesNetModuleBases -BanesSourceDir $BanesSourceDir) }
    $missing = @()
    foreach ($base in (Get-ExpectedBanesNetModuleBases -BanesSourceDir $BanesSourceDir)) {
        if (-not (Test-BanesNetBinHasModule -BinDir $bin -ModuleBase $base)) {
            $missing += $base
        }
    }
    return $missing
}

function Test-BanesNetModulesComplete {
    param (
        [string]$BanesInstallDir,
        [string]$BanesSourceDir
    )
    if ([string]::IsNullOrWhiteSpace($BanesSourceDir)) {
        $BanesSourceDir = Join-Path $SantanderRoot "BANESNET"
    }
    $missing = @(Get-MissingBanesNetModules -BanesSourceDir $BanesSourceDir -BanesInstallDir $BanesInstallDir)
    if ($missing.Count -eq 0) { return $true }
    Write-Log -Level Warn -Message ("Modulos BanesNet no detectados en BIN: {0}" -f ($missing -join ", "))
    return $false
}

function Install-BanesNetRtpModules {
    param ([string]$BanesSourceDir, [string]$BanesInstallDir)
    $ins = Join-Path $BanesInstallDir "BIN\BAN32INS.EXE"
    if (-not (Test-Path -LiteralPath $ins)) {
        Write-Log -Level Warn -Message "BAN32INS.EXE no existe aun; instale antes la base BanesNet"
        return
    }

    $rtpFiles = @(Get-ChildItem -LiteralPath $BanesSourceDir -Filter "*.RTP" -File -ErrorAction SilentlyContinue)
    if ($rtpFiles.Count -eq 0) {
        Write-Log -Level Warn -Message "No hay ficheros .RTP en la carpeta BANESNET del paquete"
        return
    }

    foreach ($sub in @("PATCH", "DAT")) {
        $dest = Join-Path $BanesInstallDir $sub
        if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        foreach ($rtp in $rtpFiles) {
            Copy-Item -LiteralPath $rtp.FullName -Destination (Join-Path $dest $rtp.Name) -Force
        }
    }
    Write-Log -Level Ok -Message ("Copiados {0} ficheros RTP a PATCH y DAT" -f $rtpFiles.Count)

    if (Test-BanesNetModulesComplete -BanesInstallDir $BanesInstallDir -BanesSourceDir $BanesSourceDir) {
        Write-Log -Level Ok -Message "Modulos BanesNet ya presentes en BIN"
        return
    }

    Write-Log -Level Step -Message "Modulos BanesNet: silencioso primero, manual si faltan parches"
    $null = Invoke-BanesNetInsSilent -InsPath $ins

    if (-not (Test-BanesNetModulesComplete -BanesInstallDir $BanesInstallDir -BanesSourceDir $BanesSourceDir)) {
        Invoke-BanesNetInsManual -InsPath $ins -Reason "BAN32INS silencioso no dejo todos los modulos en BIN"
    }

    if (-not (Test-BanesNetModulesComplete -BanesInstallDir $BanesInstallDir -BanesSourceDir $BanesSourceDir)) {
        $still = @(Get-MissingBanesNetModules -BanesSourceDir $BanesSourceDir -BanesInstallDir $BanesInstallDir)
        Invoke-BanesNetInsManual -InsPath $ins -Reason ("Siguen faltando: {0}. Instale esos parches en el asistente" -f ($still -join ", "))
    }

    $missingAfter = @(Get-MissingBanesNetModules -BanesSourceDir $BanesSourceDir -BanesInstallDir $BanesInstallDir)
    if ($missingAfter.Count -eq 0) {
        Write-Log -Level Ok -Message "Modulos BanesNet instalados en BIN"
        return
    }

    $expectedCount = @(Get-ExpectedBanesNetModuleBases -BanesSourceDir $BanesSourceDir).Count
    $installedCount = $expectedCount - $missingAfter.Count
    Write-Log -Level Warn -Message (
        "Quedan {0} modulo(s) sin instalar ({1}/{2} OK): {3}. Si no usa ese modulo, puede ignorarlo; si no, abra C:\BANESNET8\BIN\BAN32INS.EXE e instale el parche .RTP correspondiente." `
            -f $missingAfter.Count, $installedCount, $expectedCount, ($missingAfter -join ", ")
    )
}

function Install-SupernetSuite {
    param ([string]$SuiteDir)
    $modules = @(
        "ConfirmingAmpliadoLight.exe", "ConfirmingLight.exe", "CreditosComercialesLight.exe",
        "DomiciliacionesLight.exe", "EfectosComercialesLight.exe", "EurocobroLight.exe",
        "InformCuentasLight.exe", "IngresoChequesLight.exe", "NominasPensionesLight.exe",
        "Norma19_SEPALight.exe", "Norma34_14Light.exe", "PagosDomiciliadosLight.exe",
        "TransfCheques.exe", "TransfChequesAmpliadoLight.exe", "TransfInternacional.exe"
    )
    foreach ($m in $modules) {
        $exe = Join-Path $SuiteDir $m
        if (-not (Test-Path -LiteralPath $exe)) {
            Write-Log -Level Warn -Message ("Supernet: no encontrado en paquete: {0}" -f $m)
            continue
        }
        $ok = Invoke-SilentExe -ExePath $exe -Label $m -WorkingDirectory $SuiteDir -AllowInteractiveFallback
        if (-not $ok) {
            Write-Log -Level Warn -Message ("Supernet {0}: revise instalacion; puede relanzar solo este paso 3/6" -f $m)
        }
    }

    $srcMdb = Join-Path $SuiteDir "BD\SCH.mdb"
    if (Test-Path -LiteralPath $srcMdb) {
        $bd = Join-Path $SupernetTarget "BD"
        if (-not (Test-Path -LiteralPath $bd)) { New-Item -ItemType Directory -Path $bd -Force | Out-Null }
        Copy-Item -LiteralPath $srcMdb -Destination (Join-Path $bd "SCH.mdb") -Force
        Write-Log -Level Ok -Message "SCH.mdb copiado"
    }
}

function Test-SepaToolsInstalled {
    foreach ($sp in @("${env:ProgramFiles(x86)}\SEPAtools", "$env:ProgramFiles\SEPAtools")) {
        if (Test-Path -LiteralPath $sp) { return $true }
    }
    return (Test-AlreadyInstalled -RegLeaf "SEPA_Tools")
}

function Install-SepaTools {
    param ([string]$SepaDir)
    if (Test-SepaToolsInstalled) {
        Write-Log -Level Ok -Message "SEPA Tools ya instalado"
        return
    }
    if (-not (Test-Path -LiteralPath "C:\LOGS")) { New-Item -ItemType Directory -Path "C:\LOGS" -Force | Out-Null }

    Write-Log -Level Step -Message "SEPA Tools: cscript Instalar.vbs (silencioso)"
    Push-Location -LiteralPath $SepaDir
    try {
        $proc = Start-Process -FilePath "cscript.exe" -ArgumentList @("//Nologo", "Instalar.vbs") -Wait -PassThru -NoNewWindow
        Write-Log -Level Info -Message ("SEPA cscript exit {0}" -f $proc.ExitCode)
    }
    finally { Pop-Location }

    if (-not (Test-SepaToolsInstalled)) {
        Write-Log -Level Warn -Message "SEPA silencioso no dejo carpeta SEPAtools; intento manual InstalarSEPAtools.exe"
        $sepaExe = Get-ChildItem -LiteralPath $SepaDir -Recurse -Filter "InstalarSEPAtools.exe" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($sepaExe) {
            $verify = { Test-SepaToolsInstalled }
            $null = Invoke-SilentExe -ExePath $sepaExe.FullName -Label "InstalarSEPAtools" `
                -WorkingDirectory $sepaExe.DirectoryName -AllowInteractiveFallback -VerifySuccess $verify
        }
        else {
            Write-Log -Level Warn -Message "No se encontro InstalarSEPAtools.exe; ejecute manualmente SepaTools\Instalar.vbs"
            $null = Invoke-InstallerProcess -FilePath "cscript.exe" -ArgumentList @("//Nologo", "Instalar.vbs") `
                -WorkingDirectory $SepaDir -WindowStyle Normal
        }
    }
    else {
        Write-Log -Level Ok -Message "SEPA Tools instalado"
    }

    foreach ($sp in @("${env:ProgramFiles(x86)}\SEPAtools", "$env:ProgramFiles\SEPAtools")) {
        Grant-FolderAcl -Path $sp -Sid "*S-1-5-32-545" -Rights "(OI)(CI)M"
    }
}

function Get-SchGeneradorContentRoot {
    param ([string]$SchRoot)
    if (-not (Test-Path -LiteralPath $SchRoot)) { return $null }

    $zips = @(Get-ChildItem -LiteralPath $SchRoot -Filter "*.zip" -File -ErrorAction SilentlyContinue)
    if (@($zips).Count -gt 0) {
        $expand = Join-Path $env:TEMP ("SCHGeneradorExpand_{0:yyyyMMddHHmmss}" -f (Get-Date))
        New-Item -ItemType Directory -Path $expand -Force | Out-Null
        foreach ($z in $zips) {
            Write-Log -Level Step -Message ("SCH: descomprimiendo {0}" -f $z.Name)
            try {
                Expand-Archive -LiteralPath $z.FullName -DestinationPath $expand -Force -ErrorAction Stop
            }
            catch {
                Write-Log -Level Warn -Message ("SCH zip no descomprimido: {0}" -f $_.Exception.Message)
                return $SchRoot
            }
        }
        $nested = Join-Path $expand "SCH generador de ficheros"
        if (Test-Path -LiteralPath $nested) { return $nested }
        $oneDir = @(Get-ChildItem -LiteralPath $expand -Directory -ErrorAction SilentlyContinue)
        if (@($oneDir).Count -eq 1) { return $oneDir[0].FullName }
        return $expand
    }

    $sameName = Join-Path $SchRoot "SCH generador de ficheros"
    if (Test-Path -LiteralPath $sameName) { return $sameName }

    $inner = Get-ChildItem -LiteralPath $SchRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "SCH*" } | Select-Object -First 1
    if ($inner) { return $inner.FullName }
    return $SchRoot
}

function Copy-SchGeneradorTree {
    param (
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$DestRoot
    )
    if (-not (Test-Path -LiteralPath $SourceRoot)) { return $false }
    if (-not (Test-Path -LiteralPath $SupernetTarget)) {
        New-Item -ItemType Directory -Path $SupernetTarget -Force | Out-Null
    }
    if (Test-Path -LiteralPath $DestRoot) {
        Remove-Item -LiteralPath $DestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null

    Write-Log -Level Step -Message ("SCH: copiando paquete a {0}" -f $DestRoot)
    $robocopy = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
        $SourceRoot, $DestRoot, "/E", "/R:2", "/W:2", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS"
    ) -Wait -PassThru -WindowStyle Hidden
    $rc = if ($null -ne $robocopy.ExitCode) { [int]$robocopy.ExitCode } else { 0 }
    if (-not (Test-RobocopySuccess -ExitCode $rc)) {
        Write-Log -Level Warn -Message ("SCH robocopy aviso codigo {0}; se comprueba destino" -f $rc)
    }
    Unblock-SantanderPath -Path $DestRoot
    Grant-FolderAcl -Path $DestRoot -Sid "*S-1-5-32-545" -Rights "(OI)(CI)M"
    $hasFiles = [bool](Get-ChildItem -LiteralPath $DestRoot -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1)
    return $hasFiles
}

function Get-SchInstallShieldSetup {
    param ([string]$ContentRoot)
    $candidates = @()
    $roots = @($ContentRoot)
    $roots += @(Get-ChildItem -LiteralPath $ContentRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)

    foreach ($dir in ($roots | Select-Object -Unique)) {
        $hasIns = (Test-Path -LiteralPath (Join-Path $dir "setup.ins")) -or
            (Test-Path -LiteralPath (Join-Path $dir "setup.ini")) -or
            (Test-Path -LiteralPath (Join-Path $dir "data.tag"))
        if (-not $hasIns) { continue }

        $exes = @(Get-ChildItem -LiteralPath $dir -Filter "*.exe" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^(?i)unins' })
        foreach ($e in $exes) {
            $score = 0
            if ($e.Name -match '(?i)^setup') { $score += 10 }
            if ($e.Name -match '(?i)instal') { $score += 8 }
            if ($e.Name -match '(?i)^sch') { $score += 5 }
            if ($e.Length -gt 100000) { $score += 2 }
            $candidates += [PSCustomObject]@{ Path = $e.FullName; Score = $score; Dir = $dir }
        }
    }

    if (@($candidates).Count -eq 0) { return $null }
    return ($candidates | Sort-Object -Property Score -Descending | Select-Object -First 1).Path
}

function Invoke-SchSetupFromStage {
    param (
        [Parameter(Mandatory)][string]$ContentRoot,
        [Parameter(Mandatory)][string]$SetupExe
    )
    $stage = "C:\Temp\SCHGeneradorSetup"
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Write-Log -Level Step -Message ("SCH: copia de trabajo en {0} (evita C:\Deploy y USB)" -f $stage)
    $robocopy = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
        $ContentRoot, $stage, "/E", "/R:2", "/W:2", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS"
    ) -Wait -PassThru -WindowStyle Hidden
    $rc = if ($null -ne $robocopy.ExitCode) { [int]$robocopy.ExitCode } else { 0 }
    if (-not (Test-RobocopySuccess -ExitCode $rc)) {
        Write-Log -Level Warn -Message ("SCH stage robocopy {0}" -f $rc)
    }

    $rel = $SetupExe.Substring($ContentRoot.Length).TrimStart('\')
    $stagedExe = Join-Path $stage $rel
    if (-not (Test-Path -LiteralPath $stagedExe)) {
        $leaf = Split-Path -Leaf $SetupExe
        $found = Get-ChildItem -LiteralPath $stage -Recurse -Filter $leaf -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $stagedExe = $found.FullName }
    }
    if (-not (Test-Path -LiteralPath $stagedExe)) {
        Write-Log -Level Warn -Message "SCH: no se encontro instalador en copia de trabajo; solo queda copia en Supernet"
        return
    }

    $wd = Split-Path -Parent $stagedExe
    $label = "SCH generador (" + (Split-Path -Leaf $stagedExe) + ")"
    $silentArgs = @("/S", "/s", "/SILENT", "/VERYSILENT")
    foreach ($arg in $silentArgs) {
        Write-Log -Level Step -Message ("{0} silencioso -> {1}" -f $label, $arg)
        try {
            $p = Invoke-InstallerProcess -ExePath $stagedExe -ArgumentList @($arg) -WorkingDirectory $wd -WindowStyle Hidden
            if (Test-InstallerExitOk -ExitCode $p.ExitCode) {
                Write-Log -Level Ok -Message ("{0} instalado en silencio" -f $label)
                return
            }
        }
        catch {
            Write-Log -Level Warn -Message $_.Exception.Message
        }
    }

    Write-Log -Level Warn -Message ("SCH: asistente MANUAL desde {0}. Complete el asistente (no cierre la consola)." -f $wd)
    Write-Log -Level Warn -Message "Si dice que falta informacion: cierre, compruebe que el USB trae la carpeta SCH completa y vuelva a ejecutar paso 5."
    try {
        $p = Invoke-InstallerProcess -ExePath $stagedExe -WorkingDirectory $wd -WindowStyle Normal
        if (Test-InstallerExitOk -ExitCode $p.ExitCode) {
            Write-Log -Level Ok -Message "SCH generador OK tras asistente manual"
        }
        else {
            Write-Log -Level Warn -Message ("SCH asistente exit {0}; el generador puede usarse desde la copia en Supernet" -f $p.ExitCode)
        }
    }
    catch {
        Write-Log -Level Warn -Message ("SCH manual: {0}" -f $_.Exception.Message)
    }
}

function Ensure-SchMdbPresent {
    param ([string]$SuiteDir)
    $destMdb = Join-Path $SupernetTarget "BD\SCH.mdb"
    if (Test-Path -LiteralPath $destMdb) { return }
    $srcMdb = Join-Path $SuiteDir "BD\SCH.mdb"
    if (-not (Test-Path -LiteralPath $srcMdb)) {
        Write-Log -Level Warn -Message "SCH.mdb no encontrado en SUITE; el generador puede pedir la base"
        return
    }
    $bd = Join-Path $SupernetTarget "BD"
    if (-not (Test-Path -LiteralPath $bd)) { New-Item -ItemType Directory -Path $bd -Force | Out-Null }
    Copy-Item -LiteralPath $srcMdb -Destination $destMdb -Force
    Write-Log -Level Ok -Message "SCH.mdb copiado (paso 5)"
}

function Install-SchGenerador {
    param (
        [string]$SchRoot,
        [string]$SuiteDir
    )
    if (-not (Test-Path -LiteralPath $SchRoot)) {
        Write-Log -Level Warn -Message "Carpeta SCH generador no encontrada en paquete (opcional)"
        return
    }

    Ensure-SchMdbPresent -SuiteDir $SuiteDir
    $contentRoot = Get-SchGeneradorContentRoot -SchRoot $SchRoot
    if (-not $contentRoot -or -not (Test-Path -LiteralPath $contentRoot)) {
        Write-Log -Level Warn -Message "SCH generador: contenido vacio o ilegible"
        return
    }

    $dest = Join-Path $SupernetTarget "SCH generador de ficheros"
    $copied = Copy-SchGeneradorTree -SourceRoot $contentRoot -DestRoot $dest
    if ($copied) {
        Write-Log -Level Ok -Message ("SCH generador desplegado en {0}" -f $dest)
    }

    $setupExe = Get-SchInstallShieldSetup -ContentRoot $contentRoot
    if (-not $setupExe) {
        Write-Log -Level Ok -Message "SCH: paquete descomprimido (sin instalador InstallShield aparte)"
        return
    }

    Invoke-SchSetupFromStage -ContentRoot $contentRoot -SetupExe $setupExe
}

function Remove-SantanderDeployStaging {
    if (-not (Test-Path -LiteralPath "C:\Deploy")) { return $true }
    try { Set-Location -LiteralPath $env:TEMP -ErrorAction SilentlyContinue } catch { }
    for ($i = 1; $i -le 6; $i++) {
        try {
            Remove-Item -LiteralPath "C:\Deploy" -Recurse -Force -ErrorAction Stop
            Write-Log -Level Ok -Message "C:\Deploy eliminado desde script"
            return $true
        }
        catch {
            if ($i -lt 6) { Start-Sleep -Seconds 2 }
        }
    }
    Write-Log -Level Warn -Message "No se pudo borrar C:\Deploy (el .bat reintentara; cierre ventanas abiertas del paquete)"
    return $false
}

function Find-FirstFile {
    param ([string[]]$Roots, [string]$FileName)
    foreach ($r in $Roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $f = Get-ChildItem -LiteralPath $r -Recurse -Filter $FileName -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

function Get-BanesNetBinDirectory {
    foreach ($root in @($BanesTarget, (Join-Path $env:ProgramFiles "BanesNet8"))) {
        $bin = Join-Path $root "BIN"
        if (-not (Test-Path -LiteralPath $bin)) { continue }
        $any = Get-ChildItem -LiteralPath $bin -Filter "BAN32*.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($any) { return $bin }
    }
    return $null
}

function Get-SupernetBinDirectory {
    if (-not (Test-Path -LiteralPath $SupernetTarget)) { return $null }
    $hit = Find-FirstFile -Roots @($SupernetTarget) -FileName "Norma34TC.exe"
    if ($hit) { return Split-Path -Parent $hit }
    $any = Get-ChildItem -LiteralPath $SupernetTarget -Recurse -Filter "*Light.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($any) { return $any.DirectoryName }
    return $null
}

function Repair-ShortcutTargets {
    $shell = New-Object -ComObject WScript.Shell
    $realBanes = Get-BanesNetBinDirectory
    if ($realBanes) {
        Write-Log -Level Info -Message ("BanesNet BIN real: {0}" -f $realBanes)
    }
    else {
        Write-Log -Level Warn -Message "BanesNet BIN sin modulos (C:\BANESNET8\BIN vacio o incompleto). Complete pasos 1/6 y 2/6 antes de usar accesos BanesNet."
    }

    $realSuper = Get-SupernetBinDirectory
    if ($realSuper) {
        Write-Log -Level Info -Message ("Supernet real: {0}" -f $realSuper)
    }

    Get-ChildItem -LiteralPath $PublicDesktop -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $sc = $shell.CreateShortcut($_.FullName)
        $t = $sc.TargetPath
        $changed = $false
        if ($realBanes -and ($t -match '(?i)[\\/]banesnet8[\\/]bin[\\/]')) {
            $leaf = Split-Path -Leaf $t
            $newT = Join-Path $realBanes $leaf
            if (Test-Path -LiteralPath $newT) {
                $sc.TargetPath = $newT
                $sc.WorkingDirectory = $realBanes
                $changed = $true
            }
        }
        if ($realSuper -and ($t -match '(?i)[\\/]supernet programas de gesti')) {
            $leaf = Split-Path -Leaf $t
            $newT = Join-Path $realSuper $leaf
            if (Test-Path -LiteralPath $newT) {
                $sc.TargetPath = $newT
                if (-not $sc.WorkingDirectory) { $sc.WorkingDirectory = $realSuper }
                $changed = $true
            }
        }
        if ($changed) { $sc.Save() }
    }
}

function Test-PublicShortcutsHealth {
    $shell = New-Object -ComObject WScript.Shell
    $brokenBanes = 0
    $brokenSuper = 0
    $ok = 0
    Get-ChildItem -LiteralPath $PublicDesktop -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $t = $shell.CreateShortcut($_.FullName).TargetPath
        if ($t -match '(?i)banesnet8') {
            if (Test-Path -LiteralPath $t) { $ok++ } else { $brokenBanes++ }
        }
        elseif ($t -match '(?i)supernet programas') {
            if (Test-Path -LiteralPath $t) { $ok++ } else { $brokenSuper++ }
        }
    }
    if ($brokenBanes -gt 0) {
        Write-Log -Level Warn -Message ("{0} accesos BanesNet apuntan a exe inexistentes (instale modulos .RTP)" -f $brokenBanes)
    }
    if ($brokenSuper -gt 0) {
        Write-Log -Level Warn -Message ("{0} accesos Supernet rotos" -f $brokenSuper)
    }
    if ($ok -gt 0) {
        Write-Log -Level Ok -Message ("{0} accesos directos con destino valido en escritorio publico" -f $ok)
    }
}

function Get-ShortcutsSourceFolder {
    $exact = Join-Path $SantanderRoot "accesos directos copiar en escritorio publico"
    if (Test-Path -LiteralPath $exact) { return $exact }
    $found = Get-ChildItem -LiteralPath $SantanderRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "accesos directos*" } | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Copy-PublicShortcuts {
    $src = Get-ShortcutsSourceFolder
    if (-not $src) {
        Write-Log -Level Warn -Message ("Sin carpeta 'accesos directos...' en {0}" -f $SantanderRoot)
        return
    }

    $supernetFolderName = "Supernet Programas de Gesti" + [char]0x00F3 + "n"
    foreach ($legacyName in @("BanesNet 8", $supernetFolderName)) {
        $legacyPath = Join-Path $PublicDesktop $legacyName
        if (Test-Path -LiteralPath $legacyPath) {
            Remove-Item -LiteralPath $legacyPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level Info -Message ("Eliminada carpeta antigua en escritorio publico: {0}" -f $legacyName)
        }
    }

    Write-Log -Level Step -Message ("Copiando accesos (.lnk) al escritorio publico (sin subcarpetas): {0}" -f $PublicDesktop)
    $count = 0
    $usedNames = @{}
    Get-ChildItem -LiteralPath $src -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $folderLabel = $_.Name
        Get-ChildItem -LiteralPath $_.FullName -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $destLeaf = $_.Name
            $key = $destLeaf.ToLowerInvariant()
            if ($usedNames.ContainsKey($key)) {
                $destLeaf = "{0} - {1}" -f $folderLabel, $_.Name
                $key = $destLeaf.ToLowerInvariant()
            }
            $usedNames[$key] = $true
            $destPath = Join-Path $PublicDesktop $destLeaf
            Copy-Item -LiteralPath $_.FullName -Destination $destPath -Force
            $count++
        }
    }
    Repair-ShortcutTargets
    Test-PublicShortcutsHealth
    Write-Log -Level Ok -Message ("{0} accesos directos en la raiz de {1}" -f $count, $PublicDesktop)
}

if ($SoloPermisosDominio) {
    Write-Log -Level Title -Message "Solo permisos usuarios de dominio (Santander Sace)"
    Grant-StandardUserSantanderAccess
    Write-DomainUserReadyCheck
    Write-Log -Level Ok -Message "Fin permisos dominio"
    exit 0
}

Write-Log -Level Title -Message ("Instalacion Santander Sace - origen: {0}" -f $SantanderRoot)
Unblock-SantanderPath -Path $SantanderRoot
$null = Test-SantanderPaquete -Root $SantanderRoot

$banesDir = Join-Path $SantanderRoot "BANESNET"
$suiteDir = Join-Path $SantanderRoot "SUITE SANTANDER MODULOS para Basnet"
$sepaDir = Join-Path $SantanderRoot "SepaTools"
$schDir = Join-Path $SantanderRoot "SCH generador de ficheros"

if ($SoloModulosBanesNet) {
    $root = Test-BanesNetInstalled
    if (-not $root) {
        Write-Log -Level Error -Message "Primero instale la base: BANESNET\BANESNET.EXE -> C:\BANESNET8"
        exit 1
    }
    Install-BanesNetRtpModules -BanesSourceDir $banesDir -BanesInstallDir $root
    Write-Log -Level Ok -Message "Fin modulos BanesNet. Si faltan, vea MODULOS-MANUAL.txt"
    exit 0
}

$script:InstallHadErrors = $false

try {
    if (-not $OmitirBanesNet) {
        Write-Paso -Numero "1/6" -Titulo "BanesNet 8 base (BANESNET.EXE -> C:\BANESNET8)"
        $banesRoot = Install-BanesNetBase -BanesDir $banesDir
        if ($banesRoot) {
            Write-Paso -Numero "2/6" -Titulo "Modulos BanesNet (.RTP + BAN32INS)"
            Install-BanesNetRtpModules -BanesSourceDir $banesDir -BanesInstallDir $banesRoot
        }
        else {
            Write-Log -Level Warn -Message "Se omiten modulos BanesNet hasta tener base instalada"
            $script:InstallHadErrors = $true
        }
    }

    if (-not $OmitirSupernet) {
        Write-Paso -Numero "3/6" -Titulo "Supernet Programas de Gestion (*Light.exe + SCH.mdb)"
        Install-SupernetSuite -SuiteDir $suiteDir
    }

    if (-not $OmitirSepaTools) {
        Write-Paso -Numero "4/6" -Titulo "SEPA Tools (silencioso)"
        Install-SepaTools -SepaDir $sepaDir
    }

    if (-not $OmitirSchGenerador) {
        Write-Paso -Numero "5/6" -Titulo "Generador SCH"
        Install-SchGenerador -SchRoot $schDir -SuiteDir $suiteDir
    }
}
catch {
    Write-Log -Level Error -Message ("Instalacion interrumpida: {0}" -f $_.Exception.Message)
    $script:InstallHadErrors = $true
}
finally {
    if (-not $OmitirAccesosDirectos) {
        Write-Paso -Numero "6/6" -Titulo "Accesos directos -> Escritorio publico"
        Copy-PublicShortcuts
    }
    if (-not $OmitirPermisosDominio) {
        Grant-StandardUserSantanderAccess
        Write-DomainUserReadyCheck
    }
}

if ($script:InstallHadErrors) {
    Write-Log -Level Error -Message "Fin con errores. Revise log en %TEMP%\SantanderSace\"
    exit 1
}

if ($SantanderRoot -like "C:\Deploy*") {
    $null = Remove-SantanderDeployStaging
}

Write-Log -Level Ok -Message "Fin instalacion Santander Sace. Log en %TEMP%\SantanderSace\"
exit 0
