# SAP_740 — mapa estructural (ClienteIndustrial / Zero-Touch)

Ruta origen: `D:\Programas\SCRIPTS\SAP, IBER Y KAS\Deploy\SAP_740`

| Elemento | Rol | Peso aprox. |
|----------|-----|-------------|
| `Deploy-SAP740.ps1` | Orquestador EDR-Safe (refactor) | ~8–12 KB |
| `EJECUTAR SAP.bat` | Lanzador elevado | mínimo |
| `1_Certificados\` | 4× `.cer` (aún no consumidos por el script) | ~7 KB |
| `3_libreria\vcredist_x86.msi` | VC++ Redistributable | ~2.2 MB |
| `4_Entradas SAP\` | `Common` + `services` | bajo |
| `Payload_SNC\` | SNC / `sapsncencryption.dll` + setup | ~29 MB |
| `Payload_SAP\` | Instalación base NwSapSetup | ~437 MB / ~1908 files |
| `Payload_Patch\` | Parche acumulativo NwSapSetup | ~332 MB / ~1351 files |
| `Logs\` | Log diario UTF-8 del script | runtime |

## Fases del despliegue

1. SNC (copia DLL + env machine)
2. VC++ MSI (`msiexec /qn`)
3. SAP GUI base (`NwSapSetup /Product=SAPGUI /Silent`)
4. Parche (`NwSapSetup /Update /Silent`)
5. Perfiles Common + `services`
6. Unión a dominio `corp.ejemplo.local` (opcional `-SkipDomainJoin`)
7. Limpieza `C:\Deploy` + reinicio (opcional `-SkipCleanupAndReboot`)

## Cambios EDR-Safe vs legacy

- Eliminado `Add-Type` / PInvoke `kernel32.dll` (QuickEdit)
- Eliminado `cmd.exe` oculto con `timeout & rmdir & shutdown`
- Limpieza con `Remove-Item` + `Restart-Computer`
- Timeouts de red parametrizados + `Test-NetConnection` (LDAP 389) con fallback ICMP
- `Write-L3Log` con ANSI VT + log a archivo
- Switches de prueba: `-SkipDomainJoin`, `-SkipCleanupAndReboot`

Backup del script original: `Deploy-SAP740.ps1.bak_pre_edr` (en la carpeta D:).
