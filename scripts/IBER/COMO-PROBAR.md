# Iber / Altitude SIPPhone — Zero-Touch

## Objetivo

Instalar Altitude uCI SoftPhone + SSO sin pausas manuales, desde **lápiz USB** (`$PSScriptRoot`).

## Contenido del paquete (USB)

```
USB:\IBER\   (o Deploy Iber\)
  Instalar-Iber.ps1
  EJECUTAR-Iber.bat
  Altitude.exe
  Altitude.SoftPhone.exe.config
  SIPPhoneSSO.exe
  RegistrarSoftphone.bat
  setup.iss                 (opcional, recomendado)
  Logs\                     (se crea solo)
```

No hace falta copiar a `C:\Deploy Iber`.

## Cómo probar

1. Copia el paquete al USB (binarios reales + scripts nuevos).
2. Clic derecho → **Ejecutar como administrador** en `EJECUTAR-Iber.bat`.
3. El script:
   - lanza `Altitude.exe` en silencio
   - espera la carpeta `...\Altitude SIPPhone`
   - copia `.config`, `SIPPhoneSSO.exe`, acceso directo y `RegistrarSoftphone.bat`

## Si el modo silencioso falla (InstallShield)

Graba un fichero de respuesta **una vez** en un PC de lab:

```bat
Altitude.exe /r /f1"%~dp0setup.iss"
```

Completa el asistente, guarda `setup.iss` junto al script y vuelve a ejecutar el Zero-Touch (usará `/s /f1"setup.iss"`).

## Switches útiles

```powershell
# Solo post-config (Altitude ya instalado)
.\Instalar-Iber.ps1 -SkipInstall

# Forzar argumentos InstallShield
.\Instalar-Iber.ps1 -AltitudeSilentArgs '/s /f1"D:\IBER\setup.iss"'
```

## Nota EDR-safe

Sin `Read-Host`, sin `cmd` ofuscado, rutas relativas, logging a `Logs\`.
