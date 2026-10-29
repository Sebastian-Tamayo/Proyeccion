# Caso portfolio: despliegue Citrix + Genesys (retail banking)

**Autor:** Sebastián Olaya Tamayo · **Rol:** soporte L3 / automatización de puesto  
**Artefactos:** [`scripts/Santander Empresas/`](../../scripts/Santander%20Empresas/)

> Scripts y documentación **propios**. Instaladores del banco (Citrix, IronChip) **no** van en Git por tamaño y licencia; el repo incluye la lógica de despliegue.

## Problema de negocio

Migración de puestos a una suite **virtual desktop + contact center en la nube**: hacía falta Citrix Workspace con **audio en el navegador** (Media Helper / Genesys) y un factor adicional de autenticación, en muchos equipos con **versiones mezcladas** de cliente Citrix.

El procedimiento manual habitual — **desinstalar Citrix completo e instalar otra build** — podía superar **~40 minutos** por PC, con ventanas colgadas, restos en “Programas y características” y accesos directos que solo abrían la bandeja (sin ventana de Workspace).

## Enfoque (cómo trabajo)

1. **Medir antes de automatizar:** logs por fases, códigos de salida del instalador Citrix, inventario de MSI/bootstrapper en registro.
2. **Separar síntoma de causa:** el bloqueo de audio no era “falta de la versión X” sino la ausencia del componente **BCR** (*Browser Content Redirection*) → `ADDLOCAL=BCR_Client`.
3. **Reducir blast radius:** dejar de forzar desinstalación total por defecto; **configurar BCR sobre el cliente existente** con `/forceinstall`, reintentos y verificación en Programas.
4. **Criterio de éxito explícito:** el script **no** da por bueno el puesto sin plugin BCR; códigos informativos (40017/40032) no cuentan como fallo si BCR queda verificado.
5. **Operación en campo:** un `.bat` con UAC, copia a `C:\Deploy`, logs en `%TEMP%`, accesos en escritorio público sin “Ejecutar como administrador”, desinstalador simétrico.

## Resultado técnico

| Antes (manual) | Después (automatizado) |
|----------------|-------------------------|
| ~40 min desinstalar + instalar Citrix | Minutos en **añadir/reparar BCR** (sin ciclo completo de desinstalación) |
| Mezcla 26.x / 25.x difícil de limpiar | Ruta opcional `DESINSTALAR-TODO.bat` cuando hace falta pizarra limpia |
| Acceso a `wfica32` → solo bandeja | `.lnk` al lanzador con UI (`CitrixWorkspaceApp` / `Receiver.exe`) |
| “Instalación OK” sin comprobar audio | Verificación **BCR** obligatoria antes de IronChip |

## Stack

PowerShell (`#Requires -RunAsAdministrator`), `.bat` launcher, registro de desinstalación Windows, APIs Citrix silenciosas, logging estructurado.

## Qué demuestra para reclutadores

- **Pensamiento de root cause** (BCR vs reinstalar todo el cliente).
- **Automatización pragmática** (idempotencia, reintentos, no bloquear por códigos benignos).
- **Documentación operativa** (LEEME, desinstalación, opciones del `.bat`).
- **Seguridad operativa:** sin certificados raíz en el flujo por defecto; sin secretos en repo.
