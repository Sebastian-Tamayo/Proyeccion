#!/usr/bin/env bash
# Publica el ecosistema unificado en CasaTorinoApp (ejecutar en TU PC).
set -euo pipefail

DEST_DIR="${1:-$HOME/CasaTorinoApp}"
REPO_URL="https://github.com/Sebastian-Tamayo/CasaTorinoApp.git"
TARBALL_URL="https://github.com/Sebastian-Tamayo/Proyeccion/releases/download/casatorino-ecosistema-v1/CasaTorinoApp-ecosistema.tar.gz"

echo "==> Clonando / actualizando $REPO_URL en $DEST_DIR"
if [ -d "$DEST_DIR/.git" ]; then
  git -C "$DEST_DIR" fetch origin
  git -C "$DEST_DIR" checkout main
  git -C "$DEST_DIR" pull --ff-only origin main || true
else
  git clone "$REPO_URL" "$DEST_DIR"
fi

cd "$DEST_DIR"
echo "==> Usuario GitHub autenticado:"
gh auth status 2>/dev/null || git config user.name || true

echo "==> Descargando monorepo unificado"
curl -fL -o /tmp/CasaTorinoApp-ecosistema.tar.gz "$TARBALL_URL"
file /tmp/CasaTorinoApp-ecosistema.tar.gz

echo "==> Sustituyendo contenido (se conserva .git)"
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
tar -xzf /tmp/CasaTorinoApp-ecosistema.tar.gz
rm -f /tmp/CasaTorinoApp-ecosistema.tar.gz

echo "==> Comprobando estructura"
test -f README.md
test -d web && test -d erp && test -d reservas && test -d docs/media/erp
ls -1

echo "==> Commit + push"
git add -A
if git diff --cached --quiet; then
  echo "No hay cambios que subir (¿ya estaba unificado?)."
  exit 0
fi

git commit -m "Unify web, ERP and reservas into one Casa Torino ecosystem"
git push -u origin main

echo
echo "OK. Verifica: https://github.com/Sebastian-Tamayo/CasaTorinoApp"
echo "Deben verse carpetas: web/  erp/  reservas/  docs/"
