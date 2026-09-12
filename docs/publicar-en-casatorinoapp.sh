#!/usr/bin/env bash
# Publica web + ERP + reservas SOLO en CasaTorinoApp.
# Compatible con Git Bash en Windows.
set -euo pipefail

TARBALL_URL="https://github.com/Sebastian-Tamayo/Proyeccion/releases/download/casatorino-ecosistema-v1/CasaTorinoApp-ecosistema.tar.gz"
WORKDIR=$(mktemp -d)
echo "Workdir: $WORKDIR"
cd "$WORKDIR"

echo "==> 1/4 Clonando destino CasaTorinoApp"
git clone https://github.com/Sebastian-Tamayo/CasaTorinoApp.git dest
cd dest

echo "==> 2/4 Descargando monorepo unificado (tarball)"
curl -fL --retry 3 -o /tmp/CasaTorinoApp-ecosistema.tar.gz "$TARBALL_URL"
ls -lh /tmp/CasaTorinoApp-ecosistema.tar.gz

echo "==> 3/4 Sustituyendo contenido (se conserva .git)"
# borrar todo excepto .git
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
mkdir -p _extract
tar -xzf /tmp/CasaTorinoApp-ecosistema.tar.gz -C _extract
# el tarball ya contiene web/ erp/ reservas/ en la raíz
cp -a _extract/. .
rm -rf _extract
rm -f /tmp/CasaTorinoApp-ecosistema.tar.gz

echo "==> Estructura resultante:"
ls -1
test -d web
test -d erp
test -d reservas
test -f README.md

echo "==> 4/4 Commit + push a CasaTorinoApp"
git add -A
if git diff --cached --quiet; then
  echo "No hay cambios (¿ya estaba unificado?)."
else
  git commit -m "Unify Casa Torino ecosystem: web + ERP + reservas"
  git push origin main
fi

echo
echo "OK -> https://github.com/Sebastian-Tamayo/CasaTorinoApp"
echo "Deben verse carpetas: web/  erp/  reservas/  docs/"

echo
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
