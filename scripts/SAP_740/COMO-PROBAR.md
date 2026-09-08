# Cómo probar SAP_740 desde el lápiz

## Ya puedes probarlo cuando

1. Copies a la raíz del USB la carpeta completa `SAP_740` (con payloads + scripts nuevos).
2. Tengas un PC de prueba con red al dominio `corp.ejemplo.local` / DC `SRV-DC-01.corp.ejemplo.local`.
3. Ejecutes como **Administrador**.

## Preparar el USB

Copia tal cual (mantener estructura):

```
USB:\SAP_740\
  Deploy-SAP740.ps1      ← versión nueva (USB + dominio)
  EJECUTAR SAP.bat       ← lanzador con auto-elevación
  1_Certificados\
  3_libreria\
  4_Entradas SAP\
  Payload_SNC\
  Payload_SAP\
  Payload_Patch\
  Logs\                  (se crea solo)
```

Origen actualizado en disco:
- `D:\Programas\SCRIPTS\SAP, IBER Y KAS\Deploy\SAP_740\`
- Copia de trabajo en repo: `C:\Proyectos\AgentesDemo\scripts\SAP_740\`

## Ejecución en el puesto

1. Inserta el lápiz.
2. Abre la carpeta `SAP_740`.
3. Clic derecho en `EJECUTAR SAP.bat` → **Ejecutar como administrador**.
4. Espera SNC → VC++ → SAP → Parche → entradas.
5. Te pedirá **nombre de equipo** (ej. `PC-LAB-0001`).
6. Ventana de **credenciales** de dominio `corp.ejemplo.local`.
7. Reinicio automático (el USB **no** se borra).

## Prueba sin reiniciar (laboratorio)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "E:\SAP_740\Deploy-SAP740.ps1" -SkipCleanupAndReboot
```

(Sigue pidiendo nombre + credenciales de dominio; solo omite el reboot.)

## Qué cambió vs pegar en `C:\Deploy`

| Antes | Ahora |
|-------|--------|
| Pegar paquete en `C:\Deploy\SAP_740` | Ejecutar in-place desde el USB |
| Borraba `C:\Deploy` al final | No borra el lápiz; solo limpia residual `C:\Deploy\SAP_740` si existiera |
| Dominio + nombre | Igual: pide nombre y une a `corp.ejemplo.local` |
