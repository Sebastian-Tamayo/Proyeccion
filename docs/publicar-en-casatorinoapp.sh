#!/usr/bin/env bash
# Publica web + ERP + reservas SOLO en CasaTorinoApp (ejecutar en tu PC con tu usuario GitHub).
set -euo pipefail

RECOVERY=7c725aa2f746e14c6021473af10676d2c7e3a6b9
WORKDIR=$(mktemp -d)
echo "Workdir: $WORKDIR"
cd "$WORKDIR"

echo "==> 1/4 Clonando destino CasaTorinoApp"
git clone https://github.com/Sebastian-Tamayo/CasaTorinoApp.git dest
cd dest

echo "==> 2/4 Recuperando monorepo unificado desde historial Proyeccion"
git clone --filter=blob:none --no-checkout https://github.com/Sebastian-Tamayo/Proyeccion.git /tmp/proy-hist
git -C /tmp/proy-hist fetch --depth 1 origin "$RECOVERY"
git -C /tmp/proy-hist checkout "$RECOVERY" -- casa-torino

echo "==> 3/4 Sustituyendo contenido (se conserva .git)"
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a /tmp/proy-hist/casa-torino/. .

echo "==> Estructura:"
ls -1
test -d web && test -d erp && test -d reservas && test -f README.md

echo "==> 4/4 Commit + push"
git add -A
git commit -m "Unify Casa Torino ecosystem: web + ERP + reservas"
git push origin main

echo
echo "OK -> https://github.com/Sebastian-Tamayo/CasaTorinoApp"
echo "Deben verse: web/  erp/  reservas/  docs/"

# Optional: archive old web repo
read -r -p "¿Archivar casa-torino-web con README de redirección? [y/N] " ans || true
if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
  cd "$WORKDIR"
  git clone https://github.com/Sebastian-Tamayo/casa-torino-web.git webold
  cd webold
  find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cat > README.md <<'MD'
# Moved

Este repositorio está archivado.

El ecosistema Casa Torino (web + ERP + reservas) vive unificado en:

**https://github.com/Sebastian-Tamayo/CasaTorinoApp**
MD
  git add -A
  git commit -m "Archive: moved into CasaTorinoApp monorepo"
  git push origin main
  echo "casa-torino-web archivado."
fi
