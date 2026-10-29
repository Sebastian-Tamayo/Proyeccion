# Caso portfolio: suite bancaria legacy en puesto Windows

**Autor:** Sebastián Olaya Tamayo · **Rol:** soporte L3 / automatización de puesto  
**Artefactos:** [`scripts/Santander Sace/`](../../scripts/Santander%20Sace/)

> Binarios de terceros (BanesNet, Supernet, SEPA) **no** están en Git; el repositorio contiene orquestación, desinstalación y permisos para usuarios de dominio.

## Problema de negocio

Puestos de oficina que necesitan **varios programas legacy** (core bancario desktop, módulos RTP, SEPA, generador SCH) y **accesos en escritorio público** para usuarios **de dominio sin privilegios de administrador**. Instalación manual = muchos pasos, reinicios, asistentes distintos y errores de permisos (AppLocker / “bloqueado por el administrador”).

## Solución: un solo lanzador USB

`INSTALAR-TODO.bat` (admin local) → `Instalar-Todo-SantanderSace.ps1`:

1. **BanesNet** base → `C:\BANESNET8`
2. **Módulos** (.RTP + `BAN32INS`)
3. **Supernet** (*Light + SCH)
4. **SEPA Tools** (`Instalar.vbs` / desinstalador simétrico)
5. **Generador SCH**
6. **Accesos directos** en escritorio público (sin copiar carpetas enteras)
7. **Permisos NTFS** para usuarios de dominio (SID, no solo nombre de grupo local)

Política **silencioso primero, manual si falla** — reduce tiempo en el 80 % de casos sin perder recuperación cuando el instalador legacy no coopera.

## Desinstalación

`DESINSTALAR-TODO.bat` + `Desinstalar-Todo-SantanderSace.ps1`: cierra procesos, desinstala SEPA/Supernet/BanesNet, limpia accesos y registro PAQUETES, logs en USB o `%TEMP%`.

## Enfoque profesional

| Práctica | Implementación |
|----------|----------------|
| Deploy desde USB | Copia a `C:\Deploy`, `Unblock-File`, logs duplicados si el medio es pendrive |
| Dominio vs local | LEEME separados para agentes y soporte; permisos explícitos post-install |
| Idempotencia parcial | Flags `-Omitir*` para re-ejecutar solo módulos o accesos |
| Operación reversible | Desinstalador total al estilo del instalador |

## Qué demuestra para reclutadores

- Orquestación **multi-producto** en entorno **Windows real** (MSI, InstallShield, VBS, `.lnk`).
- Sensibilidad a **AD / AppLocker** (no asumir admin en el usuario final).
- **Runbooks** (`LEEME-*`, `PASOS-*`) para handoff a otro técnico o a mesa de servicio.
