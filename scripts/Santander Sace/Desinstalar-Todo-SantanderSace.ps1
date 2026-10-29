#Requires -RunAsAdministrator
<#
  Santander Sace - lanzar con DESINSTALAR-TODO.bat
#>
[CmdletBinding()]
param (
    [string]$SantanderRoot = "",
    [switch]$MantenerPaqueteUsb,
    [switch]$MantenerLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($SantanderRoot)) {
    $SantanderRoot = $PSScriptRoot
}
$SantanderRoot = $SantanderRoot.Trim().Trim('"').TrimEnd('\', '/').TrimEnd('.')
if (Test-Path -LiteralPath $SantanderRoot) {
    try {
        $SantanderRoot = (Resolve-Path -LiteralPath $SantanderRoot -ErrorAction Stop).Path
    }
    catch { }
}

$BanesPaths = @("C:\BANESNET8", (Join-Path $env:ProgramFiles "BanesNet8"))
$SupernetRoot = "C:\Supernet Programas de Gesti" + [char]0x00F3 + "n"
$PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
if ([string]::IsNullOrWhiteSpace($PublicDesktop)) {
    $PublicDesktop = "C:\Users\Public\Desktop"
}
$SepaPaths = @("${env:ProgramFiles(x86)}\SEPAtools", "$env:ProgramFiles\SEPAtools")
$script:UninstallIssues = @()

function Initialize-DesinstalarLog {
    $localLogDir = Join-Path $env:TEMP "SantanderSace"
    $useLocal = $false
    if ($SantanderRoot -match '^([A-Za-z]):') {
        try {
            $disk = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}:'" -f $Matches[1]) -ErrorAction Stop
            if ($disk.DriveType -eq 2) { $useLocal = $true }
        }
        catch { $useLocal = $true }
    }
    $script:DesinstalarLogDir = if ($useLocal) { $localLogDir } else { Join-Path $SantanderRoot "Logs" }
    if (-not (Test-Path -LiteralPath $script:DesinstalarLogDir)) {
        New-Item -ItemType Directory -Path $script:DesinstalarLogDir -Force | Out-Null
    }
    $script:DesinstalarLogFile = Join-Path $script:DesinstalarLogDir ("Desinstalar-Todo_{0:yyyyMMdd}.log" -f (Get-Date))
}

Initialize-DesinstalarLog

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
    if ($script:DesinstalarLogFile) {
        try { Add-Content -LiteralPath $script:DesinstalarLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
    }
}

function Stop-SantanderProcesses {
    $names = @(
        "NominasPensionesLight", "ConfirmingLight", "ConfirmingAmpliadoLight",
        "CreditosComercialesLight", "DomiciliacionesLight", "EfectosComercialesLight",
        "EurocobroLight", "InformCuentasLight", "IngresoChequesLight", "Norma19_SEPALight",
        "Norma34_14Light", "PagosDomiciliadosLight", "TransfCheques", "TransfChequesAmpliadoLight",
        "TransfInternacional", "BANESNET", "setup132", "BAN32INS", "BAN32DES",
        "InstalarSEPAtools", "DesInstalarModulo", "DesinstalarModulo"
    )
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log -Level Step -Message ("Cerrando proceso: {0} (PID {1})" -f $_.ProcessName, $_.Id)
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Wait-ProcessWithTimeout {
    param (
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 90
    )
    if ($null -eq $Process) { return $false }
    try {
        $null = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $Process.HasExited) {
            Write-Log -Level Warn -Message ("Tiempo agotado ({0}s) PID {1}; forzando cierre" -f $TimeoutSeconds, $Process.Id)
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            return $false
        }
        return ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010)
    }
    catch {
        return $false
    }
}

function Invoke-UninstallerSilent {
    param (
        [Parameter(Mandatory)][string]$Path,
        [int]$TimeoutSeconds = 90
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $wd = Split-Path -Parent $Path
    $argSets = @(
        @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"),
        @("/SILENT"),
        @("/S"),
        @("/s")
    )
    foreach ($argSet in $argSets) {
        $label = $argSet -join " "
        Write-Log -Level Step -Message ("Desinstalar silencioso: {0} {1}" -f (Split-Path -Leaf $Path), $label)
        try {
            $p = Start-Process -FilePath $Path -ArgumentList $argSet -WorkingDirectory $wd `
                -PassThru -WindowStyle Hidden -ErrorAction Stop
            if (Wait-ProcessWithTimeout -Process $p -TimeoutSeconds $TimeoutSeconds) {
                Write-Log -Level Ok -Message ("Desinstalador OK: {0}" -f (Split-Path -Leaf $Path))
                return $true
            }
        }
        catch {
            Write-Log -Level Warn -Message $_.Exception.Message
        }
    }
    return $false
}

function Uninstall-SepaTools {
    $sepaDir = Join-Path $SantanderRoot "SepaTools"
    $vbs = Join-Path $sepaDir "Desinstalar.vbs"
    if (Test-Path -LiteralPath $vbs) {
        Write-Log -Level Step -Message "SEPA Tools: Desinstalar.vbs (max 3 min)"
        Push-Location -LiteralPath $sepaDir
        try {
            $proc = Start-Process -FilePath "cscript.exe" -ArgumentList @("//Nologo", "Desinstalar.vbs") `
                -PassThru -NoNewWindow -ErrorAction Stop
            $null = Wait-ProcessWithTimeout -Process $proc -TimeoutSeconds 180
            if ($proc.HasExited) {
                Write-Log -Level Info -Message ("Desinstalar.vbs exit {0}" -f $proc.ExitCode)
            }
        }
        finally { Pop-Location }
    }
    else {
        Write-Log -Level Warn -Message "No hay SepaTools en paquete; borrando carpetas SEPA en Program Files"
    }
    foreach ($sp in $SepaPaths) {
        if (Test-Path -LiteralPath $sp) {
            Remove-Item -LiteralPath $sp -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level Ok -Message ("Eliminado: {0}" -f $sp)
        }
    }
    foreach ($reg in @(
        "HKLM:\SOFTWARE\PAQUETES\SEPA_Tools",
        "HKLM:\SOFTWARE\Wow6432Node\PAQUETES\SEPA_Tools"
    )) {
        if (Test-Path -LiteralPath $reg) {
            Remove-Item -LiteralPath $reg -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level Ok -Message ("Registro eliminado: {0}" -f $reg)
        }
    }
}

function Get-SupernetInstallRoots {
    $roots = @()
    if (Test-Path -LiteralPath $SupernetRoot) { $roots += $SupernetRoot }
    Get-ChildItem -Path "C:\" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "Supernet Programas*" } |
        ForEach-Object { if ($roots -notcontains $_.FullName) { $roots += $_.FullName } }
    return @($roots)
}

function Invoke-SupernetUninstaller {
    param ([string]$Root)
    $primary = @(
        (Join-Path $Root "DesInstalarModulo.exe"),
        (Join-Path $Root "DesinstalarModulo.exe")
    )
    foreach ($u in $primary) {
        if (Test-Path -LiteralPath $u) {
            if (Invoke-UninstallerSilent -Path $u -TimeoutSeconds 120) { return }
        }
    }
    $unins = Get-ChildItem -LiteralPath $Root -Recurse -Filter "unins*.exe" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($unins) {
        Invoke-UninstallerSilent -Path $unins.FullName -TimeoutSeconds 120 | Out-Null
    }
}

function Uninstall-Supernet {
    $roots = @(Get-SupernetInstallRoots)
    if ($roots.Count -eq 0) {
        Write-Log -Level Info -Message "Supernet no encontrado en disco"
        return
    }
    foreach ($root in $roots) {
        Write-Log -Level Step -Message ("Desinstalando Supernet: {0}" -f $root)
        Invoke-SupernetUninstaller -Root $root
        if (Test-Path -LiteralPath $root) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $root) {
            $msg = "No se pudo borrar todo Supernet (cierre procesos): {0}" -f $root
            Write-Log -Level Warn -Message $msg
            $script:UninstallIssues += $msg
        }
        else {
            Write-Log -Level Ok -Message ("Supernet eliminado: {0}" -f $root)
        }
    }
}

function Uninstall-BanesNet {
    foreach ($root in $BanesPaths) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        $des = @(
            (Join-Path $root "BIN\BAN32DES.EXE"),
            (Join-Path $root "BIN\BAN32DES.exe"),
            (Join-Path $env:WinDir "BAN32DES.exe"),
            (Join-Path $env:WinDir "BAN32DES.EXE")
        )
        foreach ($d in $des) {
            if (Test-Path -LiteralPath $d) {
                $null = Invoke-UninstallerSilent -Path $d -TimeoutSeconds 120
                break
            }
        }

        if (Test-Path -LiteralPath $root) {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $root)) {
                Write-Log -Level Ok -Message ("BanesNet eliminado: {0}" -f $root)
            }
            else {
                Write-Log -Level Warn -Message ("Quedan archivos en {0} (cierre BanesNet y reintente)" -f $root)
            }
        }
    }
}

function Test-SantanderShortcutTarget {
    param ([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { return $false }
    return ($TargetPath -match '(?i)\\BANESNET8\\|\\BanesNet8\\|\\Supernet Programas de Gesti|\\SEPAtools\\|BAN32_\d|BAN32_[A-Z]{2}\.exe')
}

function Get-ExpectedPublicShortcutNames {
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $src = Join-Path $SantanderRoot "accesos directos copiar en escritorio publico"
    if (-not (Test-Path -LiteralPath $src)) {
        $src = Get-ChildItem -LiteralPath $SantanderRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "accesos directos*" } | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $src -or -not (Test-Path -LiteralPath $src)) { return $names }

    Get-ChildItem -LiteralPath $src -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $folderLabel = $_.Name
        Get-ChildItem -LiteralPath $_.FullName -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$names.Add($_.Name)
            [void]$names.Add(("{0} - {1}" -f $folderLabel, $_.Name))
        }
    }
    return $names
}

function Test-ShouldRemovePublicShortcut {
    param (
        [System.IO.FileInfo]$LinkFile,
        [string]$TargetPath,
        [System.Collections.Generic.HashSet[string]]$ExpectedNames
    )
    if ($ExpectedNames.Contains($LinkFile.Name)) { return $true }
    if (Test-SantanderShortcutTarget -TargetPath $TargetPath) { return $true }
    if ($LinkFile.Name -match '(?i)^BanesNet 8 - .+\.lnk$') { return $true }
    if ($LinkFile.Name -match '(?i)^Supernet Programas de Gesti') { return $true }
    return $false
}

function Remove-PublicShortcuts {
    $supernetFolderName = "Supernet Programas de Gesti" + [char]0x00F3 + "n"
    $folders = @(
        (Join-Path $PublicDesktop "BanesNet 8"),
        (Join-Path $PublicDesktop $supernetFolderName)
    )
    foreach ($f in $folders) {
        if (Test-Path -LiteralPath $f) {
            Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level Ok -Message ("Carpeta de accesos eliminada: {0}" -f $f)
        }
    }

    $expectedNames = Get-ExpectedPublicShortcutNames
    $shell = New-Object -ComObject WScript.Shell
    $removed = 0
    Get-ChildItem -LiteralPath $PublicDesktop -Recurse -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $t = $shell.CreateShortcut($_.FullName).TargetPath
        if (Test-ShouldRemovePublicShortcut -LinkFile $_ -TargetPath $t -ExpectedNames $expectedNames) {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            $removed++
        }
    }
    Write-Log -Level Ok -Message ("Accesos directos Santander eliminados (escritorio publico): {0}" -f $removed)
}

function Remove-BanesNetRegistry {
    $keys = @(
        "HKLM:\SOFTWARE\PAQUETES\BANESNET8",
        "HKLM:\SOFTWARE\Wow6432Node\PAQUETES\BANESNET8",
        "HKLM:\SOFTWARE\BanesNet8",
        "HKLM:\SOFTWARE\Wow6432Node\BanesNet8"
    )
    foreach ($k in $keys) {
        if (Test-Path -LiteralPath $k) {
            Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level Ok -Message ("Registro eliminado: {0}" -f $k)
        }
    }
}

function Test-UninstallComplete {
    $left = @()
    foreach ($p in ($BanesPaths + $SepaPaths + @(Get-SupernetInstallRoots))) {
        if (Test-Path -LiteralPath $p) { $left += $p }
    }
    if ($left.Count -gt 0) {
        Write-Log -Level Warn -Message ("Quedan rutas instaladas: {0}" -f ($left -join "; "))
        $script:UninstallIssues += "Rutas residuales"
        return $false
    }
    Write-Log -Level Ok -Message "Comprobacion: sin carpetas BanesNet, Supernet ni SEPAtools"
    return $true
}

function Remove-SantanderLeftovers {
    $extra = @(
        "C:\Deploy",
        "C:\SAN\PAQUETES",
        "C:\Temp\BanesNetSetup",
        (Join-Path $env:TEMP "BANESNET*")
    )
    if (-not $MantenerLogs) { $extra += "C:\LOGS" }
    foreach ($e in $extra) {
        if ($e -like "*`*") {
            Get-Item -Path $e -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        elseif (Test-Path -LiteralPath $e) {
            Remove-Item -LiteralPath $e -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log -Level Ok -Message ("Extra eliminado: {0}" -f $e)
        }
    }
}

Write-Log -Level Title -Message "Desinstalacion Santander Sace"
Stop-SantanderProcesses
Start-Sleep -Seconds 2

Uninstall-SepaTools
Uninstall-Supernet
Uninstall-BanesNet
Remove-BanesNetRegistry
Remove-PublicShortcuts
Remove-SantanderLeftovers

$ok = Test-UninstallComplete
if ($ok) {
    Write-Log -Level Ok -Message "Desinstalacion completa. Reinicie el PC si lo pidio algun instalador."
}
else {
    Write-Log -Level Error -Message "Desinstalacion incompleta. Cierre procesos Santander y ejecute de nuevo DESINSTALAR-TODO.bat"
}
Write-Log -Level Info -Message "No se borra el paquete USB/carpeta del script. Reinstalar: INSTALAR-TODO.bat"

if (-not $ok -or $script:UninstallIssues.Count -gt 0) { exit 1 }
exit 0
