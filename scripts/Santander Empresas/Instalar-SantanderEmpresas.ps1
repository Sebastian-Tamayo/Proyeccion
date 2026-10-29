#Requires -RunAsAdministrator
<#
  Santander Empresas - Citrix (Santander GO / Genesys) + lanzador IronChip.
  Certificados (carpetas 1 y 3): NO se instalan (evitar alertas Kaspersky).
  Ejecutar: INSTALAR-TODO.bat desde la carpeta del lapiz (admin local).
#>
[CmdletBinding()]
param (
    [string]$EmpresasRoot = "",
    [string]$LogCopyRoot = "",
    [switch]$SoloCitrix,
    [switch]$SoloAccesoCitrix,
    [switch]$AsLibrary
)

$PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
if ([string]::IsNullOrWhiteSpace($PublicDesktop)) {
    $PublicDesktop = "C:\Users\Public\Desktop"
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($EmpresasRoot)) {
    $EmpresasRoot = $PSScriptRoot
}
$EmpresasRoot = $EmpresasRoot.Trim().Trim('"').TrimEnd('\', '/').TrimEnd('.')
try {
    $EmpresasRoot = (Resolve-Path -LiteralPath $EmpresasRoot -ErrorAction Stop).Path
}
catch {
    throw "Ruta Santander Empresas invalida: $EmpresasRoot"
}

$script:InstallIssues = @()

function Initialize-EmpresasLog {
    $logDir = Join-Path $env:TEMP "SantanderEmpresas"
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $script:EmpresasLogFile = Join-Path $logDir ("Instalar-Empresas_{0:yyyyMMdd}.log" -f (Get-Date))
}

Initialize-EmpresasLog

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
    if ($script:EmpresasLogFile) {
        try { Add-Content -LiteralPath $script:EmpresasLogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
    }
}

function Find-ChildFolder {
    param (
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Pattern
    )
    if (-not (Test-Path -LiteralPath $Root)) { return $null }
    $hit = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $Pattern } | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

function Get-CitrixSilentInstallArguments {
    param ([switch]$ForceInstall)
    # README banco: CitrixWorkspaceApp.exe /silent ADDLOCAL=BCR_Client (Genesys Media Helper)
    $argList = @("/silent", "ADDLOCAL=BCR_Client", "/noreboot")
    if ($ForceInstall) { $argList += "/forceinstall" }
    return @($argList)
}

function Test-CitrixBcrProductName {
    param ([string]$DisplayName)
    return ($DisplayName -match '(?i)Browser Content Redirection|Content Redirection Plug|\bBCR\b')
}

function Get-CitrixBcrRegistrationInfo {
    foreach ($p in @(Get-InstalledCitrixProducts)) {
        $dn = Get-RegistryPropertySafe -Object $p -Name "DisplayName"
        if (Test-CitrixBcrProductName -DisplayName $dn) {
            $dv = Get-RegistryPropertySafe -Object $p -Name "DisplayVersion" -Default "?"
            return ("{0} v{1}" -f $dn, $dv)
        }
    }
    return $null
}

function Test-CitrixBcrOnDisk {
    foreach ($root in @(Get-CitrixSearchRoots)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -match '(?i)\\Browser Content Redirection\\' -or
                $_.Name -match '(?i)^CtxBcr|^BCRClient|BrowserContentRedirection'
            } |
            Select-Object -First 1
        if ($hit) { return $true }
    }
    return $false
}

function Test-CitrixBcrFeatureInstalled {
    if (Get-CitrixBcrRegistrationInfo) { return $true }
    return (Test-CitrixBcrOnDisk)
}

function Write-CitrixBcrInstallStatus {
    param ([switch]$TreatMissingAsFatal)
    $info = Get-CitrixBcrRegistrationInfo
    if ($info) {
        Write-Log -Level Ok -Message ("BCR_Client VERIFICADO en Programas: {0}" -f $info)
        return $true
    }
    if (Test-CitrixBcrOnDisk) {
        Write-Log -Level Ok -Message "BCR_Client VERIFICADO en disco (plugin Browser Content Redirection)"
        return $true
    }
    $msg = "BCR_Client NO instalado (OBLIGATORIO Genesys Media Helper / audio Santander GO)"
    if ($TreatMissingAsFatal) {
        Write-Log -Level Error -Message $msg
        if ($script:InstallIssues -notcontains "BCR_Client OBLIGATORIO no instalado") {
            $script:InstallIssues += "BCR_Client OBLIGATORIO no instalado"
        }
    }
    else {
        Write-Log -Level Warn -Message $msg
    }
    return $false
}

function Get-CitrixPackageInstaller {
    param ([string]$Root)
    $citrixDir = Find-ChildFolder -Root $Root -Pattern "2.- Citrix*"
    if (-not $citrixDir) {
        return $null
    }
    $app = Join-Path $citrixDir "CitrixWorkspaceApp.exe"
    if (Test-Path -LiteralPath $app) { return $app }
    return $null
}

function Get-IronChipMsi {
    param ([string]$Root)
    $ironDir = Find-ChildFolder -Root $Root -Pattern "*Ironchip*"
    if (-not $ironDir) { return $null }
    $msi = Join-Path $ironDir "IronchipWindowsLogon.msi"
    if (Test-Path -LiteralPath $msi) { return $msi }
    $found = Get-ChildItem -LiteralPath $ironDir -Filter "*.msi" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Get-RegistryPropertySafe {
    param (
        $Object,
        [string]$Name,
        [string]$Default = ""
    )
    if ($null -eq $Object) { return $Default }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
    return [string]$prop.Value
}

function Wait-ProcessWithTimeout {
    param (
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutSeconds = 600,
        [string]$Label = "proceso"
    )
    if ($null -eq $Process) { return $false }
    try {
        $null = $Process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $Process.HasExited) {
            Write-Log -Level Warn -Message ("Tiempo agotado ({0}s) en {1} (PID {2}); forzando cierre" -f $TimeoutSeconds, $Label, $Process.Id)
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

function Stop-CitrixProcesses {
    $names = @(
        "wfica32", "Receiver", "SelfService", "SelfServicePlugin", "AuthManager",
        "CitrixWorkspaceApp", "Redirector", "CWAWebHelper", "HdxTeams"
    )
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log -Level Step -Message ("Cerrando {0} (PID {1})" -f $_.ProcessName, $_.Id)
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 2
}

function Get-InstalledCitrixProducts {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $items = @()
    foreach ($k in $keys) {
        $entries = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if (-not $entries) { continue }
        foreach ($entry in @($entries)) {
            $dn = Get-RegistryPropertySafe -Object $entry -Name "DisplayName"
            if ([string]::IsNullOrWhiteSpace($dn)) { continue }
            if ($dn -match '(?i)^citrix\s') {
                $items += $entry
            }
        }
    }
    return @($items | Sort-Object { Get-RegistryPropertySafe -Object $_ -Name "DisplayName" } -Unique)
}

function Get-CitrixSearchRoots {
    $roots = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in @(
            (Join-Path $env:ProgramFiles "Citrix"),
            (Join-Path ${env:ProgramFiles(x86)} "Citrix"),
            (Join-Path $env:ProgramFiles "Common Files\Citrix"),
            (Join-Path ${env:ProgramFiles(x86)} "Common Files\Citrix"),
            "C:\Citrix"
        )) {
        if (Test-Path -LiteralPath $path) {
            try { [void]$roots.Add((Resolve-Path -LiteralPath $path -ErrorAction Stop).Path) } catch { [void]$roots.Add($path) }
        }
    }
    foreach ($prod in @(Get-InstalledCitrixProducts)) {
        $loc = Get-RegistryPropertySafe -Object $prod -Name "InstallLocation"
        if (-not [string]::IsNullOrWhiteSpace($loc) -and (Test-Path -LiteralPath $loc)) {
            [void]$roots.Add($loc.TrimEnd('\'))
        }
    }
    return @($roots)
}

function Find-CitrixExecutableByNames {
    param ([string[]]$Names)
    foreach ($name in $Names) {
        foreach ($root in @(Get-CitrixSearchRoots)) {
            $hit = Get-ChildItem -LiteralPath $root -Recurse -Filter $name -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}

function Find-CitrixWorkspaceAppExe {
    return Find-CitrixExecutableByNames -Names @(
        'CitrixWorkspaceApp.exe', 'Citrix Workspace.exe', 'SelfService.exe'
    )
}

function Get-CitrixKnownLaunchCandidatePaths {
    $ordered = [System.Collections.Generic.List[string]]::new()
    foreach ($pf in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if ([string]::IsNullOrWhiteSpace($pf)) { continue }
        foreach ($rel in @(
                "Citrix\ICA Client\Citrix Workspace\CitrixWorkspaceApp.exe",
                "Citrix\ICA Client\Receiver\Receiver.exe",
                "Citrix\SelfServicePlugin\SelfService.exe"
            )) {
            $full = Join-Path $pf $rel
            if ((Test-Path -LiteralPath $full) -and -not $ordered.Contains($full)) {
                $ordered.Add($full)
            }
        }
    }
    return @($ordered)
}

function Get-CitrixLaunchTargetFromKnownPaths {
    foreach ($path in @(Get-CitrixKnownLaunchCandidatePaths)) {
        if (-not (Test-CitrixDesktopLaunchTargetValid -TargetPath $path)) { continue }
        $label = "ruta estandar Citrix"
        if ($path -match '(?i)\\CitrixWorkspaceApp\.exe$') {
            $label = "CitrixWorkspaceApp (cliente nuevo / 2603)"
        }
        elseif ($path -match '(?i)\\Receiver\\Receiver\.exe$') {
            $label = "Receiver.exe (Citrix Workspace 2507 - ventana principal)"
        }
        elseif ($path -match '(?i)\\SelfService\.exe$') {
            $label = "SelfService (tienda plugin)"
        }
        return @{
            Exe         = $path
            Arguments   = ""
            WorkingDir  = Split-Path -Parent $path
            SourceLabel = $label
        }
    }
    return $null
}

function Test-CitrixDesktopLaunchTargetValid {
    param ([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { return $false }
    if (-not (Test-Path -LiteralPath $TargetPath)) { return $false }
    if ($TargetPath -match '(?i)\\(wfica32|wfcrun32|redirector|webhelper|concentr)\.exe$') {
        return $false
    }
    return ($TargetPath -match '(?i)\\(CitrixWorkspaceApp|SelfService|Receiver)\.exe$')
}

function Get-CitrixPreferredDesktopLaunchTarget {
    $shell = New-Object -ComObject WScript.Shell
    $menuLnk = Find-CitrixStartMenuShortcut
    if ($menuLnk) {
        $sc = $shell.CreateShortcut($menuLnk)
        if (Test-CitrixDesktopLaunchTargetValid -TargetPath $sc.TargetPath) {
            return @{
                Exe         = $sc.TargetPath
                Arguments   = $sc.Arguments
                WorkingDir  = if ($sc.WorkingDirectory) { $sc.WorkingDirectory } else { Split-Path -Parent $sc.TargetPath }
                SourceLabel = ("menu Inicio: {0}" -f (Split-Path -Leaf $menuLnk))
            }
        }
    }

    $known = Get-CitrixLaunchTargetFromKnownPaths
    if ($known) { return $known }

    $bestScore = -999
    $bestPath = $null
    foreach ($root in @(Get-CitrixSearchRoots)) {
        Get-ChildItem -LiteralPath $root -Recurse -Filter "*.exe" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $path = $_.FullName
            $leaf = $_.Name
            if (-not (Test-CitrixDesktopLaunchTargetValid -TargetPath $path)) { return }
            $score = 0
            if ($leaf -ieq 'CitrixWorkspaceApp.exe') { $score += 200 }
            if ($path -match '(?i)\\Citrix Workspace\\') { $score += 80 }
            if ($leaf -ieq 'Receiver.exe' -and $path -match '(?i)\\ICA Client\\Receiver\\') { $score += 150 }
            if ($leaf -ieq 'SelfService.exe' -and $path -match '(?i)SelfServicePlugin') { $score += 60 }
            if ($leaf -ieq 'SelfService.exe') { $score += 40 }
            if ($score -gt $bestScore) {
                $bestScore = $score
                $bestPath = $path
            }
        }
    }
    if ($bestPath) {
        return @{
            Exe         = $bestPath
            Arguments   = ""
            WorkingDir  = Split-Path -Parent $bestPath
            SourceLabel = "ejecutable CitrixWorkspaceApp/SelfService"
        }
    }
    return $null
}

function Find-CitrixLaunchExecutable {
    $desktop = Get-CitrixPreferredDesktopLaunchTarget
    if ($desktop) { return $desktop.Exe }
    return Find-CitrixWorkspaceAppExe
}

function Write-CitrixDiscoveryDiagnostic {
    Write-Log -Level Info -Message "Diagnostico Citrix (Programas vs disco):"
    $prods = @(Get-InstalledCitrixProducts)
    if (@($prods).Count -eq 0) {
        Write-Log -Level Info -Message "  Sin entradas Citrix en Programas"
    }
    foreach ($prod in $prods) {
        $dn = Get-RegistryPropertySafe -Object $prod -Name "DisplayName"
        $dv = Get-RegistryPropertySafe -Object $prod -Name "DisplayVersion" -Default "?"
        $loc = Get-RegistryPropertySafe -Object $prod -Name "InstallLocation" -Default "(sin InstallLocation)"
        Write-Log -Level Info -Message ("  Programas: {0} v{1} | {2}" -f $dn, $dv, $loc)
    }
    foreach ($root in @(Get-CitrixSearchRoots)) {
        Write-Log -Level Info -Message ("  Carpeta: {0}" -f $root)
    }
    foreach ($path in @(Get-CitrixKnownLaunchCandidatePaths)) {
        $ok = Test-CitrixDesktopLaunchTargetValid -TargetPath $path
        Write-Log -Level Info -Message ("  Ruta estandar: {0} ({1})" -f $path, $(if ($ok) { "OK" } else { "no valida o ausente" }))
    }
    $pref = Get-CitrixPreferredDesktopLaunchTarget
    if ($pref) {
        Write-Log -Level Info -Message ("  Acceso recomendado: {0} ({1})" -f $pref.Exe, $pref.SourceLabel)
    }
    else {
        Write-Log -Level Warn -Message "  Acceso recomendado: NO (instalacion incompleta / mezcla 2603+2507)"
    }
}

function Invoke-CitrixRepairInstall {
    param ([Parameter(Mandatory)][string]$InstallerPath)
    if (-not (Test-Path -LiteralPath $InstallerPath)) { return $false }
    $wd = Split-Path -Parent $InstallerPath
    $argList = @(Get-CitrixSilentInstallArguments -ForceInstall)
    Write-Log -Level Step -Message ("Reparacion Citrix (+ BCR_Client): {0} {1}" -f (Split-Path -Leaf $InstallerPath), ($argList -join " "))
    try {
        $p = Start-Process -FilePath $InstallerPath -ArgumentList $argList -WorkingDirectory $wd `
            -PassThru -WindowStyle Hidden -ErrorAction Stop
        $null = Wait-ProcessWithTimeout -Process $p -TimeoutSeconds 1200 -Label "CitrixRepair"
        Write-Log -Level Info -Message ("Reparacion Citrix exit {0}" -f $p.ExitCode)
        Start-Sleep -Seconds 8
        if (Test-CitrixBcrFeatureInstalled) { return $true }
        return (Test-CitrixInstallExitOk -ExitCode $p.ExitCode)
    }
    catch {
        Write-Log -Level Warn -Message $_.Exception.Message
        return $false
    }
}

function Test-CitrixClientOperational {
    $wfica = Find-CitrixExecutableByNames -Names @('wfica32.exe')
    $ui = Get-CitrixPreferredDesktopLaunchTarget
    return ([bool]$wfica -or [bool]$ui)
}

function Invoke-CitrixUninstallExe {
    param (
        [Parameter(Mandatory)][string]$ExePath,
        [string]$Label = ""
    )
    if (-not (Test-Path -LiteralPath $ExePath)) { return $false }
    $name = if ($Label) { $Label } else { Split-Path -Leaf $ExePath }
    $wd = Split-Path -Parent $ExePath
    Write-Log -Level Step -Message ("Desinstalando Citrix: {0} /silent /uninstall (max 15 min)" -f $name)
    try {
        $p = Start-Process -FilePath $ExePath -ArgumentList @("/silent", "/uninstall") `
            -WorkingDirectory $wd -PassThru -WindowStyle Hidden -ErrorAction Stop
        $finished = Wait-ProcessWithTimeout -Process $p -TimeoutSeconds 900 -Label $name
        if (-not $finished) {
            Write-Log -Level Warn -Message ("{0} uninstall no termino a tiempo" -f $name)
            return $false
        }
        Write-Log -Level Info -Message ("{0} uninstall exit {1}" -f $name, $p.ExitCode)
        return ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010)
    }
    catch {
        Write-Log -Level Warn -Message $_.Exception.Message
        return $false
    }
}

function Test-MsiexecExitOk {
    param ([int]$ExitCode)
    # 1605 = producto ya no instalado (normal tras desinstalar el paquete maestro)
    return ($ExitCode -eq 0 -or $ExitCode -eq 3010 -or $ExitCode -eq 1605)
}

function Split-UninstallString {
    param ([string]$UninstallString)
    $raw = [Environment]::ExpandEnvironmentVariables($UninstallString.Trim())
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    if ($raw.StartsWith('"')) {
        $end = $raw.IndexOf('"', 1)
        if ($end -lt 1) { return $null }
        $exe = $raw.Substring(1, $end - 1)
        $args = $raw.Substring($end + 1).Trim()
        return @{ Exe = $exe; Args = $args }
    }
    $space = $raw.IndexOf(' ')
    if ($space -lt 0) {
        return @{ Exe = $raw; Args = "" }
    }
    return @{ Exe = $raw.Substring(0, $space); Args = $raw.Substring($space + 1).Trim() }
}

function Get-CitrixBootstrapProducts {
    $all = @(Get-InstalledCitrixProducts)
    $masters = @()
    foreach ($p in $all) {
        $dn = Get-RegistryPropertySafe -Object $p -Name "DisplayName"
        if ($dn -match '(?i)^Citrix Workspace (2603|2507|\d{4})') {
            $masters += $p
            continue
        }
        if ($dn -match '(?i)^Citrix Workspace 2603') {
            $masters += $p
        }
    }
    return @($masters | Sort-Object {
            $name = Get-RegistryPropertySafe -Object $_ -Name "DisplayName"
            if ($name -match '2603|26\.3') { return "0-$name" }
            return "1-$name"
        } -Unique)
}

function Test-NoCitrix2603Remaining {
    foreach ($p in @(Get-InstalledCitrixProducts)) {
        $dn = Get-RegistryPropertySafe -Object $p -Name "DisplayName"
        $dv = Get-RegistryPropertySafe -Object $p -Name "DisplayVersion" -Default ""
        if ($dn -match '2603|26\.3' -or $dv -match '^26\.3') {
            return $false
        }
    }
    return $true
}

function Test-CitrixInstallExitOk {
    param ([int]$ExitCode)
    if ($ExitCode -eq 0 -or $ExitCode -eq 3010 -or $ExitCode -eq 40037) {
        return $true
    }
    if ($ExitCode -eq 40032) {
        if (-not (Test-NoCitrix2603Remaining)) {
            Write-Log -Level Error -Message "Exit 40032 pero sigue Citrix 26.3/2603 en Programas; desinstale antes"
            return $false
        }
        if (Test-CitrixBcrFeatureInstalled) {
            Write-Log -Level Ok -Message "Exit 40032: Citrix ya instalado y BCR presente"
            return $true
        }
        Write-Log -Level Warn -Message "Exit 40032 sin BCR en Programas; se requiere ADDLOCAL=BCR_Client /forceinstall"
    }
    if ($ExitCode -eq 40002) {
        Write-Log -Level Error -Message "Exit 40002: instalacion Citrix previa; repita paso 1 (desinstalar)"
    }
    if ($ExitCode -eq 40026) {
        Write-Log -Level Error -Message "Exit 40026: reinicie el PC y ejecute de nuevo INSTALAR-TODO.bat"
    }
    return $false
}

function Invoke-MsiexecUninstallGuid {
    param (
        [Parameter(Mandatory)][string]$Guid,
        [string]$Label = "MSI"
    )
    $log = Join-Path $env:TEMP ("CitrixMsiUninstall_{0}.log" -f ([Guid]::NewGuid().ToString("N").Substring(0, 8)))
    Write-Log -Level Step -Message ("MSI /x {0} ({1})" -f $Guid, $Label)
    try {
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
            "/x", $Guid, "/qn", "REBOOT=ReallySuppress", "/L*v", $log
        ) -PassThru -WindowStyle Hidden -ErrorAction Stop
        $null = Wait-ProcessWithTimeout -Process $p -TimeoutSeconds 600 -Label $Label
        Write-Log -Level Info -Message ("{0} msiexec exit {1} (log: {2})" -f $Label, $p.ExitCode, $log)
        return (Test-MsiexecExitOk -ExitCode $p.ExitCode)
    }
    catch {
        Write-Log -Level Warn -Message $_.Exception.Message
        return $false
    }
}

function Invoke-CitrixProductRemoval {
    param ($Product)
    $dn = Get-RegistryPropertySafe -Object $Product -Name "DisplayName" -Default "Citrix"
    $guid = [string]$Product.PSChildName
    $uninstall = Get-RegistryPropertySafe -Object $Product -Name "UninstallString"

    if (-not [string]::IsNullOrWhiteSpace($uninstall)) {
        $parsed = Split-UninstallString -UninstallString $uninstall
        if ($null -eq $parsed -or -not (Test-Path -LiteralPath $parsed.Exe)) {
            if ($guid -match '^\{[0-9A-Fa-f-]+\}$') {
                return Invoke-MsiexecUninstallGuid -Guid $guid -Label $dn
            }
            Write-Log -Level Warn -Message ("UninstallString invalido para: {0}" -f $dn)
            return $false
        }

        $exe = $parsed.Exe
        $argText = $parsed.Args
        if ($exe -match '(?i)msiexec(\.exe)?$') {
            if ($guid -match '^\{[0-9A-Fa-f-]+\}$') {
                return Invoke-MsiexecUninstallGuid -Guid $guid -Label $dn
            }
        }

        Write-Log -Level Step -Message ("Bootstrapper/desinstalar: {0}" -f $dn)
        $argList = @()
        if (-not [string]::IsNullOrWhiteSpace($argText)) {
            $argList += ($argText -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        if (($argList -join ' ') -notmatch '(?i)/silent') { $argList += '/silent' }
        if (($argList -join ' ') -notmatch '(?i)/uninstall') { $argList += '/uninstall' }
        if ($exe -match '(?i)bootstrapper' -and (($argList -join ' ') -notmatch '(?i)/cleanup')) {
            $argList += '/cleanup'
        }
        try {
            $p = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory (Split-Path -Parent $exe) `
                -PassThru -WindowStyle Hidden -ErrorAction Stop
            $null = Wait-ProcessWithTimeout -Process $p -TimeoutSeconds 900 -Label $dn
            Write-Log -Level Info -Message ("{0} exit {1}" -f $dn, $p.ExitCode)
            return ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010)
        }
        catch {
            Write-Log -Level Warn -Message $_.Exception.Message
            return $false
        }
    }

    if ($guid -match '^\{[0-9A-Fa-f-]+\}$') {
        return Invoke-MsiexecUninstallGuid -Guid $guid -Label $dn
    }
    return $false
}

function Test-CitrixProgramsRemoved {
    $left = @(Get-InstalledCitrixProducts)
    if (@($left).Count -eq 0) { return $true }
    foreach ($p in $left) {
        $dn = Get-RegistryPropertySafe -Object $p -Name "DisplayName"
        Write-Log -Level Warn -Message ("Sigue en Programas y caracteristicas: {0}" -f $dn)
    }
    return $false
}

function Invoke-CitrixReceiverCleanup {
    $paths = @(
        (Join-Path ${env:ProgramFiles(x86)} "Citrix\ICA Client\ReceiverCleanupUtility.exe"),
        (Join-Path $env:ProgramFiles "Citrix\ICA Client\ReceiverCleanupUtility.exe")
    )
    foreach ($p in $paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        Write-Log -Level Step -Message "ReceiverCleanupUtility (silencioso)"
        try {
            $proc = Start-Process -FilePath $p -ArgumentList @("/silent") -PassThru -WindowStyle Hidden -ErrorAction Stop
            $null = Wait-ProcessWithTimeout -Process $proc -TimeoutSeconds 300 -Label "ReceiverCleanupUtility"
        }
        catch {
            Write-Log -Level Warn -Message $_.Exception.Message
        }
        break
    }
}

function Uninstall-ExistingCitrixWorkspace {
    Write-Log -Level Title -Message "Paso 1/3 - Desinstalar Citrix Workspace existente (incl. 2603 x64)"
    Stop-CitrixProcesses

    $installed = @(Get-InstalledCitrixProducts)
    if (@($installed).Count -eq 0) {
        Write-Log -Level Ok -Message "No hay entradas Citrix en Programas; se instala la version del lapiz"
        return $true
    }
    foreach ($prod in $installed) {
        $dn = Get-RegistryPropertySafe -Object $prod -Name "DisplayName"
        $dv = Get-RegistryPropertySafe -Object $prod -Name "DisplayVersion" -Default "?"
        Write-Log -Level Info -Message ("Instalado: {0} | version {1}" -f $dn, $dv)
    }

    $appExe = Find-CitrixWorkspaceAppExe
    if ($appExe) {
        Write-Log -Level Step -Message "Metodo oficial Citrix: CitrixWorkspaceApp.exe /silent /uninstall"
        $null = Invoke-CitrixUninstallExe -ExePath $appExe -Label "CitrixWorkspaceApp (en disco)"
    }

    $masters = @(Get-CitrixBootstrapProducts)
    foreach ($master in $masters) {
        $masterName = Get-RegistryPropertySafe -Object $master -Name "DisplayName"
        Write-Log -Level Step -Message ("Paquete Workspace (bootstrapper): {0}" -f $masterName)
        $null = Invoke-CitrixProductRemoval -Product $master
        Stop-CitrixProcesses
        Start-Sleep -Seconds 3
    }

    for ($round = 1; $round -le 3; $round++) {
        $batch = @(Get-InstalledCitrixProducts)
        if (@($batch).Count -eq 0) { break }
        Write-Log -Level Step -Message ("Pase {0}/3: quitando componentes Citrix restantes ({1})" -f $round, @($batch).Count)
        foreach ($prod in $batch) {
            $null = Invoke-CitrixProductRemoval -Product $prod
        }
        Stop-CitrixProcesses
        Start-Sleep -Seconds 5
    }

    Invoke-CitrixReceiverCleanup
    Start-Sleep -Seconds 3

    if (Test-CitrixProgramsRemoved) {
        Write-Log -Level Ok -Message "Citrix anterior eliminado de Programas (listo para instalar 24.x del lapiz)"
        return $true
    }

    Write-Log -Level Error -Message "Citrix 2603 (u otro) SIGUE en Programas. NO se instala la version nueva encima."
    Write-Log -Level Warn -Message "Reinicio NO es obligatorio por norma; ayuda si algun MSI quedo bloqueado. Tras reiniciar, ejecute otra vez INSTALAR-TODO.bat (solo desinstalara lo que quede e instalara)."
    return $false
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
    catch { }
}

function Find-CitrixStartMenuShortcut {
    $roots = @(
        (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs")
    )
    $roots += @(Get-CitrixSearchRoots)
    foreach ($root in ($roots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Recurse -Filter "*.lnk" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '(?i)citrix|workspace' } |
            Sort-Object { if ($_.Name -match '(?i)^Citrix Workspace') { 0 } else { 1 } } |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Get-EmpresasCitrixShortcutsFromPackage {
    param ([string]$Root)
    $src = Join-Path $Root "accesos directos copiar en escritorio publico"
    if (-not (Test-Path -LiteralPath $src)) {
        $dir = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "accesos directos*" } | Select-Object -First 1
        if ($dir) { $src = $dir.FullName }
    }
    if (-not (Test-Path -LiteralPath $src)) { return @() }

    $shell = New-Object -ComObject WScript.Shell
    $links = @()
    Get-ChildItem -LiteralPath $src -Recurse -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $t = $shell.CreateShortcut($_.FullName).TargetPath
        if ($_.Name -match '(?i)citrix|workspace|santander\s*go' -or $t -match '(?i)\\citrix\\') {
            $links += $_
        }
    }
    return @($links)
}

function New-CitrixPublicShortcut {
    param (
        [Parameter(Mandatory)][string]$TargetExe,
        [string]$Arguments = "",
        [string]$WorkingDirectory = "",
        [string]$LinkFileName = "Citrix Workspace.lnk"
    )
    if (-not (Test-CitrixDesktopLaunchTargetValid -TargetPath $TargetExe)) {
        throw ("Destino invalido para acceso Citrix (no usar wfica32/solo bandeja): {0}" -f $TargetExe)
    }
    $dest = Join-Path $PublicDesktop $LinkFileName
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($dest)
    $sc.TargetPath = $TargetExe
    $sc.Arguments = $Arguments
    $wd = if ($WorkingDirectory) { $WorkingDirectory } else { Split-Path -Parent $TargetExe }
    $sc.WorkingDirectory = $wd
    $sc.WindowStyle = 1
    if (Test-Path -LiteralPath $TargetExe) {
        $sc.IconLocation = ("{0},0" -f $TargetExe)
    }
    $sc.Description = "Citrix Workspace - Santander GO (abre la aplicacion, no solo la bandeja)"
    $sc.Save()
    Set-ShortcutRunAsAdminFlag -Path $dest -RunAsAdmin $false
    return $dest
}

function Copy-CitrixShortcutToUserDesktops {
    param ([Parameter(Mandatory)][string]$SourceShortcutPath)
    if (-not (Test-Path -LiteralPath $SourceShortcutPath)) { return }
    $leaf = Split-Path -Leaf $SourceShortcutPath
    $copied = 0
    Get-ChildItem -LiteralPath "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") } |
        ForEach-Object {
            $desk = Join-Path $_.FullName "Desktop"
            if (-not (Test-Path -LiteralPath $desk)) { return }
            try {
                $dest = Join-Path $desk $leaf
                Copy-Item -LiteralPath $SourceShortcutPath -Destination $dest -Force -ErrorAction Stop
                Set-ShortcutRunAsAdminFlag -Path $dest -RunAsAdmin $false
                $copied++
                Write-Log -Level Ok -Message ("Acceso en escritorio usuario: {0}" -f $dest)
            }
            catch {
                Write-Log -Level Warn -Message ("No se pudo copiar acceso a {0}: {1}" -f $desk, $_.Exception.Message)
            }
        }
    if ($copied -eq 0) {
        $fallback = [Environment]::GetFolderPath("Desktop")
        if ($fallback -and (Test-Path -LiteralPath $fallback)) {
            $dest = Join-Path $fallback $leaf
            Copy-Item -LiteralPath $SourceShortcutPath -Destination $dest -Force -ErrorAction SilentlyContinue
            Set-ShortcutRunAsAdminFlag -Path $dest -RunAsAdmin $false
            Write-Log -Level Ok -Message ("Acceso en escritorio: {0}" -f $dest)
        }
    }
}

function Publish-CitrixPublicDesktopShortcut {
    param ([string]$PackageRoot)
    Write-Log -Level Step -Message ("Publicando acceso Citrix en escritorio publico: {0}" -f $PublicDesktop)

    $shell = New-Object -ComObject WScript.Shell
    $usedPackage = $false
    foreach ($lnk in @(Get-EmpresasCitrixShortcutsFromPackage -Root $PackageRoot)) {
        $t = $shell.CreateShortcut($lnk.FullName).TargetPath
        if (-not (Test-CitrixDesktopLaunchTargetValid -TargetPath $t)) {
            Write-Log -Level Warn -Message ("Acceso en paquete ignorado (destino incorrecto): {0} -> {1}" -f $lnk.Name, $t)
            continue
        }
        $destPath = Join-Path $PublicDesktop $lnk.Name
        Copy-Item -LiteralPath $lnk.FullName -Destination $destPath -Force
        Set-ShortcutRunAsAdminFlag -Path $destPath -RunAsAdmin $false
        $usedPackage = $true
        Write-Log -Level Ok -Message ("Acceso copiado desde paquete: {0}" -f $lnk.Name)
    }

    $launch = Get-CitrixPreferredDesktopLaunchTarget
    if (-not $launch) {
        Write-CitrixDiscoveryDiagnostic
        Write-Log -Level Warn -Message "Citrix sin CitrixWorkspaceApp/SelfService valido para acceso directo."
        $script:InstallIssues += "Citrix incompleto; falta acceso en escritorio publico"
        return $false
    }

    Get-ChildItem -LiteralPath $PublicDesktop -Filter "*.lnk" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '(?i)citrix|workspace' } |
        ForEach-Object {
            $old = $shell.CreateShortcut($_.FullName).TargetPath
            if (-not (Test-CitrixDesktopLaunchTargetValid -TargetPath $old)) {
                Write-Log -Level Warn -Message ("Acceso antiguo apuntaba mal ({0}); se recrea" -f $old)
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }

    $linkName = "Citrix Workspace.lnk"
    $created = New-CitrixPublicShortcut -TargetExe $launch.Exe -Arguments $launch.Arguments `
        -WorkingDirectory $launch.WorkingDir -LinkFileName $linkName
    Write-Log -Level Ok -Message ("Acceso directo: {0} -> {1} ({2})" -f $linkName, $launch.Exe, $launch.SourceLabel)
    Write-Log -Level Info -Message "Si solo ve el icono en la bandeja: clic derecho en Citrix junto al reloj -> Abrir Citrix Workspace"
    if ($usedPackage) {
        Write-Log -Level Info -Message "Tambien hay acceso del paquete USB si venia en la carpeta accesos directos"
    }
    Copy-CitrixShortcutToUserDesktops -SourceShortcutPath $created
    return $true
}

function Invoke-CitrixPackageInstallerRun {
    param (
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string]$PhaseLabel = "Citrix"
    )
    if (-not (Test-Path -LiteralPath $InstallerPath)) {
        return @{ Ok = $false; ExitCode = -1 }
    }
    try {
        Unblock-File -LiteralPath $InstallerPath -ErrorAction SilentlyContinue
    }
    catch { }

    $ver = (Get-Item -LiteralPath $InstallerPath).VersionInfo
    if ($ver.FileVersion) {
        Write-Log -Level Info -Message ("Instalador Citrix archivo version: {0}" -f $ver.FileVersion)
    }

    $wd = Split-Path -Parent $InstallerPath
    Write-Log -Level Step -Message ("{0} {1}" -f (Split-Path -Leaf $InstallerPath), ($ArgumentList -join " "))
    Write-Log -Level Info -Message "ADDLOCAL=BCR_Client = redireccion de contenido del navegador (obligatorio Genesys Media Helper)"
    Write-Log -Level Info -Message "Puede tardar varios minutos (silencioso, sin ventana)..."

    try {
        $p = Start-Process -FilePath $InstallerPath -ArgumentList $ArgumentList -WorkingDirectory $wd `
            -PassThru -WindowStyle Hidden -ErrorAction Stop
        $finished = Wait-ProcessWithTimeout -Process $p -TimeoutSeconds 1200 -Label (Split-Path -Leaf $InstallerPath)
        if (-not $finished) {
            Write-Log -Level Warn -Message ("{0} supero 20 min; compruebe Programas o reinicie y repita" -f $PhaseLabel)
            $script:InstallIssues += "Citrix install timeout"
            return @{ Ok = $false; ExitCode = -2 }
        }
        Write-Log -Level Info -Message ("Citrix install exit {0}" -f $p.ExitCode)
        $exitOk = Test-CitrixInstallExitOk -ExitCode $p.ExitCode
        if (-not $exitOk) {
            Write-Log -Level Warn -Message ("{0} codigo exit {1} (se comprueba BCR despues; 40017/40032 pueden ser informativos)" -f $PhaseLabel, $p.ExitCode)
            $script:InstallIssues += "Citrix exit $($p.ExitCode)"
        }
        return @{ Ok = $exitOk; ExitCode = $p.ExitCode }
    }
    catch {
        Write-Log -Level Error -Message $_.Exception.Message
        $script:InstallIssues += "Citrix install fallo"
        return @{ Ok = $false; ExitCode = -1 }
    }
}

function Invoke-CitrixBcrInstallAttempt {
    param (
        [Parameter(Mandatory)][string]$InstallerPath,
        [int]$AttemptNumber,
        [int]$AttemptTotal
    )
    Write-Log -Level Step -Message ("BCR intento {0}/{1}: ADDLOCAL=BCR_Client + /forceinstall" -f $AttemptNumber, $AttemptTotal)
    Stop-CitrixProcesses
    Start-Sleep -Seconds 3
    $argList = @(Get-CitrixSilentInstallArguments -ForceInstall)
    $run = Invoke-CitrixPackageInstallerRun -InstallerPath $InstallerPath -ArgumentList $argList `
        -PhaseLabel ("BCR ADDLOCAL=BCR_Client (intento {0})" -f $AttemptNumber)
    Start-Sleep -Seconds 10
    $bcrOk = Write-CitrixBcrInstallStatus
    return @{
        BcrOk   = $bcrOk
        ExitOk  = $run.Ok
        ExitCode = $run.ExitCode
    }
}

function Enable-CitrixBcrOnExistingWorkspace {
    param ([Parameter(Mandatory)][string]$InstallerPath)
    Write-Log -Level Title -Message "Paso 1/3 - OBLIGATORIO: configurar BCR_Client (Genesys / audio Santander GO)"
    Write-Log -Level Info -Message "Comando fijo: CitrixWorkspaceApp.exe /silent ADDLOCAL=BCR_Client /noreboot /forceinstall"
    Write-Log -Level Info -Message "No se desinstala Citrix; se anade o repara el plugin BCR sobre la version actual"

    $products = @(Get-InstalledCitrixProducts)
    if (@($products).Count -eq 0) {
        Write-Log -Level Warn -Message "No hay Citrix en Programas; /forceinstall intentara cliente + BCR"
    }
    else {
        foreach ($prod in $products) {
            $dn = Get-RegistryPropertySafe -Object $prod -Name "DisplayName"
            $dv = Get-RegistryPropertySafe -Object $prod -Name "DisplayVersion" -Default "?"
            Write-Log -Level Info -Message ("Citrix en PC: {0} v{1}" -f $dn, $dv)
        }
    }

    $bcrBefore = Test-CitrixBcrFeatureInstalled
    if ($bcrBefore) {
        Write-Log -Level Info -Message ("BCR detectado antes de instalar: {0}" -f (Get-CitrixBcrRegistrationInfo))
        Write-Log -Level Info -Message "Se ejecuta /forceinstall igualmente para asegurar ADDLOCAL=BCR_Client"
    }

    $maxAttempts = 3
    $lastAttempt = $null
    for ($i = 1; $i -le $maxAttempts; $i++) {
        $lastAttempt = Invoke-CitrixBcrInstallAttempt -InstallerPath $InstallerPath -AttemptNumber $i -AttemptTotal $maxAttempts
        if ($lastAttempt.BcrOk) { break }
        if ($i -lt $maxAttempts) {
            Write-Log -Level Warn -Message "BCR ausente tras intento $i; reintento tras cerrar Citrix..."
            Start-Sleep -Seconds 5
        }
    }

    if (-not (Test-CitrixBcrFeatureInstalled)) {
        Write-Log -Level Step -Message "Ultimo recurso: reparacion Citrix solo BCR (/forceinstall)"
        $null = Invoke-CitrixRepairInstall -InstallerPath $InstallerPath
        Start-Sleep -Seconds 10
        $null = Write-CitrixBcrInstallStatus -TreatMissingAsFatal
    }

    if (Test-CitrixBcrFeatureInstalled) {
        Write-Log -Level Ok -Message "=== BCR_Client CONFIGURADO (requisito Genesys cumplido) ==="
        $launch = Find-CitrixLaunchExecutable
        if ($launch) {
            Write-Log -Level Ok -Message ("Citrix operativo: {0}" -f $launch)
        }
        else {
            Write-CitrixDiscoveryDiagnostic
            Write-Log -Level Warn -Message "BCR OK; falta lanzador UI (solo-acceso-citrix). IronChip puede continuar."
        }
        return $true
    }

    Write-Log -Level Error -Message "FALLO CRITICO: BCR no instalado. No usar Genesys Media Helper hasta resolver."
    if ($null -ne $lastAttempt) {
        Write-Log -Level Error -Message ("Ultimo exit instalador Citrix: {0}" -f $lastAttempt.ExitCode)
    }
    $null = Write-CitrixBcrInstallStatus -TreatMissingAsFatal
    return $false
}

function Start-IronChipInstaller {
    param ([string]$MsiPath)
    Write-Log -Level Title -Message "Paso 3/3 - IronChip (asistente MANUAL - usted continua)"
    if (-not $MsiPath -or -not (Test-Path -LiteralPath $MsiPath)) {
        Write-Log -Level Warn -Message "IronchipWindowsLogon.msi no encontrado en carpeta 4-Ironchip"
        return
    }
    try { Unblock-File -LiteralPath $MsiPath -ErrorAction SilentlyContinue } catch { }
    Write-Log -Level Warn -Message "Se abre el asistente MSI. Complete la configuracion IronChip y cierre la ventana."
    Write-Log -Level Info -Message "Manual: proxy/DNS *.ironchip.com si aplica (ver PDF en 4-Ironchip)"
    Write-Log -Level Info -Message ("MSI: {0}" -f $MsiPath)
    try {
        $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "`"$MsiPath`"") `
            -Wait -PassThru -WindowStyle Normal -ErrorAction Stop
        Write-Log -Level Info -Message ("IronChip msiexec exit {0}" -f $p.ExitCode)
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            Write-Log -Level Ok -Message "IronChip: asistente finalizado"
        }
        else {
            Write-Log -Level Warn -Message "IronChip termino con codigo distinto de 0 (puede ser cancelacion parcial)"
        }
    }
    catch {
        Write-Log -Level Error -Message $_.Exception.Message
    }
}

function Get-EmpresasLogCopyRoot {
    if (-not [string]::IsNullOrWhiteSpace($LogCopyRoot)) {
        try {
            return (Resolve-Path -LiteralPath $LogCopyRoot.Trim().Trim('"') -ErrorAction Stop).Path
        }
        catch { }
    }
    if ($EmpresasRoot -notlike "C:\Deploy*") {
        return $EmpresasRoot
    }
    return $null
}

function Copy-EmpresasLogToPackage {
    if (-not $script:EmpresasLogFile -or -not (Test-Path -LiteralPath $script:EmpresasLogFile)) { return }
    $copyRoot = Get-EmpresasLogCopyRoot
    if (-not $copyRoot) {
        Write-Log -Level Warn -Message "Log solo en TEMP (no hay ruta lapiz para copia)"
        return
    }
    try {
        $dest = Join-Path $copyRoot ("Instalar-Empresas_{0:yyyyMMdd}.log" -f (Get-Date))
        Copy-Item -LiteralPath $script:EmpresasLogFile -Destination $dest -Force -ErrorAction Stop
        Write-Log -Level Info -Message ("Copia del log en paquete: {0}" -f $dest)
    }
    catch {
        Write-Log -Level Warn -Message ("No se pudo copiar log al lapiz: {0}" -f $_.Exception.Message)
    }
}

function Remove-EmpresasDeployStaging {
    if (-not (Test-Path -LiteralPath "C:\Deploy")) { return $true }
    try { Set-Location -LiteralPath $env:TEMP -ErrorAction SilentlyContinue } catch { }
    Write-Log -Level Step -Message "Eliminando copia temporal C:\Deploy (y todo su contenido)..."
    for ($i = 1; $i -le 6; $i++) {
        try {
            Remove-Item -LiteralPath "C:\Deploy" -Recurse -Force -ErrorAction Stop
            Write-Log -Level Ok -Message "C:\Deploy eliminado"
            return $true
        }
        catch {
            if ($i -lt 6) { Start-Sleep -Seconds 2 }
        }
    }
    Write-Log -Level Warn -Message "No se pudo borrar C:\Deploy (cierre programas y borre a mano)"
    return $false
}

function Invoke-SantanderEmpresasInstallMain {
    Write-Log -Level Title -Message ("Santander Empresas - origen: {0}" -f $EmpresasRoot)
    Write-Log -Level Info -Message "Certificados (carpetas 1 y 3): OMITIDOS a proposito (no se importan CRT/P7B)"

    $citrixInstaller = Get-CitrixPackageInstaller -Root $EmpresasRoot
    if ($citrixInstaller) {
        Write-Log -Level Info -Message ("Instalador Citrix del paquete: {0}" -f (Split-Path -Leaf $citrixInstaller))
    }

if ($SoloAccesoCitrix) {
    Write-Log -Level Title -Message "Solo acceso Citrix -> Escritorio publico"
    if (-not (Test-CitrixClientOperational) -and $citrixInstaller) {
        Write-Log -Level Warn -Message "Sin lanzador Citrix; intento reparacion silenciosa antes del acceso..."
        $null = Invoke-CitrixRepairInstall -InstallerPath $citrixInstaller
        Start-Sleep -Seconds 10
    }
    if (-not (Test-CitrixClientOperational)) {
        Write-CitrixDiscoveryDiagnostic
        Write-Log -Level Error -Message "Citrix incompleto. Ejecute INSTALAR-TODO.bat o DESINSTALAR-TODO.bat y repita si hay mezcla de versiones."
        Copy-EmpresasLogToPackage
        exit 1
    }
    if (-not (Publish-CitrixPublicDesktopShortcut -PackageRoot $EmpresasRoot)) {
        Copy-EmpresasLogToPackage
        exit 1
    }
    Copy-EmpresasLogToPackage
    exit 0
}

$ironMsi = Get-IronChipMsi -Root $EmpresasRoot
$script:CitrixInstallOk = $false

if (-not $citrixInstaller) {
    Write-Log -Level Error -Message "Falta carpeta 2.- Citrix... con CitrixWorkspaceApp.exe"
    $script:InstallIssues += "Paquete Citrix incompleto"
}
else {
    $script:CitrixInstallOk = Enable-CitrixBcrOnExistingWorkspace -InstallerPath $citrixInstaller
    if (-not $script:CitrixInstallOk -or -not (Test-CitrixBcrFeatureInstalled)) {
        $script:CitrixInstallOk = $false
        if ($script:InstallIssues -notcontains "BCR_Client OBLIGATORIO no instalado") {
            $script:InstallIssues += "BCR_Client OBLIGATORIO no instalado"
        }
    }
    elseif (-not (Publish-CitrixPublicDesktopShortcut -PackageRoot $EmpresasRoot)) {
        $script:InstallIssues += "Acceso Citrix no publicado en escritorio publico"
    }
}

if (-not $SoloCitrix) {
    if ($script:CitrixInstallOk) {
        Start-IronChipInstaller -MsiPath $ironMsi
    }
    else {
        Write-Log -Level Warn -Message "IronChip NO se abre: termine BCR/Citrix y vuelva a ejecutar el .bat"
    }
}

Copy-EmpresasLogToPackage

function Repair-InstallIssuesAfterSuccessfulBcr {
    if (-not $script:CitrixInstallOk -or -not (Test-CitrixBcrFeatureInstalled)) { return }
    $noise = @($script:InstallIssues | Where-Object { $_ -match '^Citrix exit \d+' })
    if (@($noise).Count -eq 0) { return }
    $script:InstallIssues = @($script:InstallIssues | Where-Object { $_ -notmatch '^Citrix exit \d+' })
    Write-Log -Level Info -Message ("Instalador Citrix devolvio {0}; BCR verificado OK -> no cuenta como fallo" -f ($noise -join "; "))
}

Repair-InstallIssuesAfterSuccessfulBcr

if (@($script:InstallIssues).Count -gt 0) {
    Write-Log -Level Warn -Message ("Fin con avisos: {0}" -f ($script:InstallIssues -join "; "))
    Write-Log -Level Info -Message ("Log: {0}" -f $script:EmpresasLogFile)
    if (Test-Path -LiteralPath "C:\Deploy") {
        Write-Log -Level Info -Message "Se conserva C:\Deploy para reintentar tras corregir errores"
    }
    exit 1
}

if (Test-Path -LiteralPath "C:\Deploy") {
    $null = Remove-EmpresasDeployStaging
}

    if (-not (Test-CitrixBcrFeatureInstalled)) {
        Write-Log -Level Error -Message "Fin abortado: BCR_Client no verificado en el PC"
        exit 1
    }
    Write-Log -Level Ok -Message "Fin Santander Empresas. BCR OK. Log: $($script:EmpresasLogFile)"
    Write-Log -Level Info -Message "Prueba: Santander GO + URL Media Helper con extension BCR"
    exit 0
}

if (-not $AsLibrary) {
    Invoke-SantanderEmpresasInstallMain
}
