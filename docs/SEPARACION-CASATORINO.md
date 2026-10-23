# Casa Torino ya no vive en Proyeccion

Todo el material de **Casa Torino** (QR, sync, fixes Vercel, scripts de publicar)
se migra a:

**https://github.com/Sebastian-Tamayo/CasaTorinoApp**

- Producto (web / ERP / reservas): ese repo
- Ops migradas: `docs/ops/` y `scripts/ops/` en CasaTorinoApp

## Aplicar la migración (una vez, desde tu PC)

```bash
# Opción A — si ya existe el release en Proyeccion:
curl -fsSL https://raw.githubusercontent.com/Sebastian-Tamayo/Proyeccion/cursor/migrar-casatorino-fuera-8823/scripts/aplicar-migracion-casatorino.sh | bash

# Opción B — clonando Proyeccion en esta rama:
git clone https://github.com/Sebastian-Tamayo/Proyeccion.git
cd Proyeccion
git checkout cursor/migrar-casatorino-fuera-8823
bash scripts/aplicar-migracion-casatorino.sh
# luego: cd /tmp/casatorino-apply-*/dest && git push -u origin HEAD
```

Nada se pierde: el commit de origen es `bd9ca63` en el historial de Proyeccion
y el release `casatorino-export-2026-10-23` (si está publicado).

Este archivo es solo un cartel de separación; no contiene código de Casa Torino.
