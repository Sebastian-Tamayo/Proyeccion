# Casa Torino ya no vive en Proyeccion

Todo el material de **Casa Torino** (QR, sync, fixes Vercel, scripts de publicar)
se migra a:

**https://github.com/Sebastian-Tamayo/CasaTorinoApp**

- Producto (web / ERP / reservas): ese repo
- Ops migradas: `docs/ops/` y `scripts/ops/` en CasaTorinoApp

## Aplicar la migración (una vez, desde tu PC)

Release ya publicado:
https://github.com/Sebastian-Tamayo/Proyeccion/releases/tag/casatorino-export-2026-10-23

```bash
# Git Bash / WSL (con tu login de GitHub que pueda push a CasaTorinoApp)
curl -fsSL -o /tmp/aplicar-migracion-casatorino.sh \
  https://raw.githubusercontent.com/Sebastian-Tamayo/Proyeccion/cursor/migrar-casatorino-fuera-8823/scripts/aplicar-migracion-casatorino.sh
PUSH=1 bash /tmp/aplicar-migracion-casatorino.sh
```

O da a Cursor **Contents: Read and write** en `CasaTorinoApp` y escribe en el chat: `acceso listo`.

Nada se pierde: historial `bd9ca63` en Proyeccion + release `casatorino-export-2026-10-23`.

Este archivo es solo un cartel de separación; no contiene código de Casa Torino.
