#!/usr/bin/env bash
set -euo pipefail

TARBALL_URL="https://github.com/Sebastian-Tamayo/Proyeccion/releases/download/casatorino-ecosistema-v1/CasaTorinoApp-ecosistema.tar.gz"
WORKDIR=$(mktemp -d)
echo "Workdir: $WORKDIR"
cd "$WORKDIR"

echo "==> 1/4 Descargando monorepo (tarball) FUERA del repo"
curl -fL --retry 3 -o "$WORKDIR/ecosistema.tar.gz" "$TARBALL_URL"
ls -lh "$WORKDIR/ecosistema.tar.gz"

echo "==> 2/4 Clonando CasaTorinoApp"
git clone https://github.com/Sebastian-Tamayo/CasaTorinoApp.git dest
cd dest

echo "==> 3/4 Sustituyendo contenido"
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
mkdir _extract
tar -xzf "$WORKDIR/ecosistema.tar.gz" -C _extract
cp -a _extract/. .
rm -rf _extract

echo "==> Estructura:"
ls -1
test -d web && test -d erp && test -d reservas && test -f README.md

echo "==> 4/4 Commit + push"
git add -A
git commit -m "Unify Casa Torino ecosystem: web + ERP + reservas" || true
git push origin main

echo
echo "OK -> https://github.com/Sebastian-Tamayo/CasaTorinoApp"
