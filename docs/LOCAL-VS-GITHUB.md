# Local vs GitHub — qué se sube y qué no

## Regla

| Solo en tu PC (NO Git) | Sí se puede subir |
|------------------------|-------------------|
| `inbox/resumen_diario.md` con hosts/IPs/OU reales | `inbox/resumen_diario.example.md` (plantilla) |
| `docs/Documentacion Agente/` | `docs/casos/*-ANON.md` y casos portfolio |
| Logs con usuarios/rutas reales | Scripts `.ps1`/`.bat` + LEEME |
| API keys, `.env`, certificados banco | README, guías de flujo |

## Flujo diario (seguro)

1. Trabajas el resumen **con datos reales** en `inbox/resumen_diario.md` (ignorado por Git).
2. `python main.py` → `output/ultima_ejecucion.md` (también ignorado si hay datos de sitio).
3. Si el informe aporta a portfolio: **reescribe anonimizado** en `docs/casos/` o pide “añade a memoria” **solo tras anonimizar**.
4. `git status`: no debe aparecer `resumen_diario.md` ni `Documentacion Agente`.

## Si Git aún “ve” el resumen

Estaba trackeado antes del ignore. Hay que sacarlo del índice (el archivo local **no** se borra):

```powershell
cd C:\L3 proyeccion\Proyeccion
git rm --cached inbox/resumen_diario.md
git add .gitignore inbox/resumen_diario.example.md docs/LOCAL-VS-GITHUB.md docs/casos/SEMANA-L3-OPERATIVA-ANON.md
git commit -m "Stop tracking local daily summary; keep anonymized portfolio docs"
```

## Primera vez en un PC nuevo

```powershell
copy inbox\resumen_diario.example.md inbox\resumen_diario.md
# Edita resumen_diario.md con el día real (queda local)
```
