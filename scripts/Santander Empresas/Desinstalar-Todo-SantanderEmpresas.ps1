#Requires -RunAsAdministrator
<#
  Santander Empresas - lanzar con DESINSTALAR-TODO.bat
  Quita Citrix Workspace, IronChip y accesos del paquete (como Santander Sace).
#>
[CmdletBinding()]
param (
    [string]$EmpresasRoot = "",
    [switch]$MantenerLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrWhiteSpace($EmpresasRoot)) {
    $EmpresasRoot = $PSScriptRoot
}
$EmpresasRoot = $EmpresasRoot.Trim().Trim('"').TrimEnd('\', '/').TrimEnd('.')
if (Test-Path -LiteralPath $EmpresasRoot) {
    try {
        $EmpresasRoot = (Resolve-Path -LiteralPath $EmpresasRoot -ErrorAction Stop).Path
    }
    catch { }
}

$PublicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
if ([string]::IsNullOrWhiteSpace($PublicDesktop)) {
    $PublicDesktop = "C:\Users\Public\Desktop"
}

$script:UninstallIssues = @()

function Initialize-DesinstalarLog {
    $localLogDir = Join-Path $env:TEMP "SantanderEmpresas"
    $useLocal = $false
    if ($EmpresasRoot -match '^([A-Za-z]):') {
        try {
            $disk = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}:'" -f $Matches[1]) -ErrorAction Stop
            if ($disk.DriveType -eq 2) { $useLocal = $true }
        }
        catch { $useLocal = $true }
    }
    $script:DesinstalarLogDir = if ($useLocal) { $localLogDir } else { Join-Path $EmpresasRoot "Logs" }
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

$installScript = Join-Path $EmpresasRoot "Instalar-SantanderEmpresas.ps1"
if (-not (Test-Path -LiteralPath $installScript)) {
    Write-Log -Level Error -Message ("No encuentra: {0}" -f $installScript)
    exit 1
}

. $installScript -AsLibrary -EmpresasRoot $EmpresasRoot
$script:EmpresasLogFile = $script:DesinstalarLogFile

function Stop-IronChipProcesses {
    foreach ($n in @("IronChip", "Ironchip", "ICLogon", "IronchipLogon")) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log -Level Step -Message ("Cerrando proceso IronChip: {0}" -f $_.ProcessName)
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-InstalledIronChipProducts {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $items = @()
    foreach ($key in $keys) {
        $items += Get-ItemProperty $key -ErrorAction SilentlyContinue |
            Where-Object {
                $dn = [string]$_.DisplayName
                $dn -match '(?i)iron\s*chip|ironchip'
            }
    }
    return @($items | Sort-Object DisplayName -Unique)
}

function Uninstall-IronChip {
    Write-Log -Level Title -Message "Desinstalar IronChip"
    Stop-IronChipProcesses
    $products = @(Get-InstalledIronChipProducts)
    if (@($products).Count -eq 0) {
        Write-Log -Level Info -Message "IronChip no figura en Programas"
        return $true
    }
    $allOk = $true
    foreach ($prod in $products) {
        $dn = Get-RegistryPropertySafe -Object $prod -Name "DisplayName" -Default "IronChip"
        $guid = [string]$prod.PSChildName
        if ($guid -match '^\{[0-9A-Fa-f-]+\}$') {
            Write-Log -Level Step -Message ("IronChip MSI: {0}" -f $dn)
            $ok = Invoke-MsiexecUninstallGuid -Guid $guid -Label $dn
            if (-not $ok) {
                $allOk = $false
                $script:UninstallIssues += "IronChip: $dn"
            }
        }
        else {
            $uninstall = Get-RegistryPropertySafe -Object $prod -Name "UninstallString"
            $parsed = Split-UninstallString -UninstallString $uninstall
            if ($parsed -and (Test-Path -LiteralPath $parsed.Exe)) {
                Write-Log -Level Step -Message ("IronChip desinstalador: {0}" -f $dn)
                try {
                    $p = Start-Process -FilePath $parsed.Exe -ArgumentList @("/x", $guid, "/qn", "REBOOT=ReallySuppress") `
                        -PassThru -WindowStyle Hidden -ErrorAction Stop
                    $null = Wait-ProcessWithTimeout -Process $p -TimeoutSeconds 600 -Label $dn
                }
                catch {
                    Write-Log -Level Warn -Message $_.Exception.Message
                    $allOk = $false
                }
            }
        }
    }
    Start-Sleep -Seconds 2
    if (@(Get-InstalledIronChipProducts).Count -gt 0) {
        Write-Log -Level Warn -Message "IronChip sigue en Programas (repita o desinstale desde Panel de control)"
        $script:UninstallIssues += "IronChip residual"
        return $false
    }
    Write-Log -Level Ok -Message "IronChip eliminado"
    return $allOk
}

function Test-EmpresasShortcutTarget {
    param ([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { return $false }
    return ($TargetPath -match '(?i)\\citrix\\|\\ironchip|santander\s*go|CitrixWorkspaceApp|SelfService|Receiver\.exe|wfica32')
}

function Get-ExpectedEmpresasShortcutNames {
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $src = Join-Path $EmpresasRoot "accesos directos copiar en escritorio publico"
    if (-not (Test-Path -LiteralPath $src)) {
        $dir = Get-ChildItem -LiteralPath $EmpresasRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "accesos directos*" } | Select-Object -First 1
        if ($dir) { $src = $dir.FullName }
    }
    if (Test-Path -LiteralPath $src) {
        Get-ChildItem -LiteralPath $src -Recurse -Filter "*.lnk" -File -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$names.Add($_.Name) }
    }
    foreach ($n in @("Citrix Workspace.lnk", "Santander GO.lnk", "IronChip.lnk")) {
        [void]$names.Add($n)
    }
    return $names
}

function Remove-EmpresasDesktopShortcuts {
    Write-Log -Level Step -Message "Eliminando accesos Citrix / Santander Empresas"
    $expected = Get-ExpectedEmpresasShortcutNames
    $shell = New-Object -ComObject WScript.Shell
    $removed = 0
    $desktops = @($PublicDesktop)
    Get-ChildItem -LiteralPath "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") } |
        ForEach-Object {
            $d = Join-Path $_.FullName "Desktop"
            if (Test-Path -LiteralPath $d) { $desktops += $d }
        }
    foreach ($desk in ($desktops | Select-Object -Unique)) {
        Get-ChildItem -LiteralPath $desk -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
            $t = $shell.CreateShortcut($_.FullName).TargetPath
            $byName = $expected.Contains($_.Name) -or $_.Name -match '(?i)citrix|workspace|santander\s*go|ironchip'
            if ($byName -or (Test-EmpresasShortcutTarget -TargetPath $t)) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
                $removed++
            }
        }
    }
    Write-Log -Level Ok -Message ("Accesos eliminados: {0}" -f $removed)
}

function Remove-EmpresasLeftovers {
    if (Test-Path -LiteralPath "C:\Deploy") {
        try { Set-Location -LiteralPath $env:TEMP -ErrorAction SilentlyContinue } catch { }
        Remove-Item -LiteralPath "C:\Deploy" -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath "C:\Deploy")) {
            Write-Log -Level Ok -Message "C:\Deploy eliminado"
        }
        else {
            Write-Log -Level Warn -Message "No se pudo borrar C:\Deploy"
            $script:UninstallIssues += "C:\Deploy"
        }
    }
    if (-not $MantenerLogs) {
        $tempLog = Join-Path $env:TEMP "SantanderEmpresas"
        if (Test-Path -LiteralPath $tempLog) {
            Remove-Item -LiteralPath $tempLog -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-EmpresasUninstallComplete {
    $leftCitrix = @(Get-InstalledCitrixProducts)
    $leftIron = @(Get-InstalledIronChipProducts)
    if (@($leftCitrix).Count -gt 0) {
        foreach ($p in $leftCitrix) {
            $dn = Get-RegistryPropertySafe -Object $p -Name "DisplayName"
            Write-Log -Level Warn -Message ("Citrix sigue en Programas: {0}" -f $dn)
        }
        $script:UninstallIssues += "Citrix en Programas"
        return $false
    }
    if (@($leftIron).Count -gt 0) {
        Write-Log -Level Warn -Message "IronChip sigue en Programas"
        $script:UninstallIssues += "IronChip en Programas"
        return $false
    }
    Write-Log -Level Ok -Message "Comprobacion: sin Citrix ni IronChip en Programas"
    return $true
}

Write-Log -Level Title -Message "Desinstalacion Santander Empresas"
Write-Log -Level Info -Message ("Origen scripts: {0}" -f $EmpresasRoot)

Stop-IronChipProcesses
Stop-CitrixProcesses
Start-Sleep -Seconds 2

$null = Uninstall-IronChip
$citrixOk = Uninstall-ExistingCitrixWorkspace
if (-not $citrixOk) {
    $script:UninstallIssues += "Citrix incompleto"
}

Remove-EmpresasDesktopShortcuts
Remove-EmpresasLeftovers

$ok = Test-EmpresasUninstallComplete -and $citrixOk
if ($ok -and @($script:UninstallIssues).Count -eq 0) {
    Write-Log -Level Ok -Message "Desinstalacion completa. Reinicie el PC si algun instalador lo pidio."
}
else {
    Write-Log -Level Error -Message "Desinstalacion incompleta. Cierre Citrix/IronChip y ejecute de nuevo DESINSTALAR-TODO.bat"
}
Write-Log -Level Info -Message "No se borra el paquete USB. Reinstalar: INSTALAR-TODO.bat"
Write-Log -Level Info -Message ("Log: {0}" -f $script:DesinstalarLogFile)

if (-not $ok -or @($script:UninstallIssues).Count -gt 0) { exit 1 }
exit 0
