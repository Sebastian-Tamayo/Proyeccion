#!/usr/bin/env bash
# Aplica en CasaTorinoApp el export de ops/docs/scripts migrados desde Proyeccion.
# Uso (desde tu PC, con push a CasaTorinoApp):
#   bash scripts/aplicar-migracion-casatorino.sh
# O con tarball local:
#   TARBALL=/ruta/casatorino-from-proyeccion.tar.gz bash scripts/aplicar-migracion-casatorino.sh
set -euo pipefail

BRANCH="${BRANCH:-main}"
REPO_URL="${REPO_URL:-https://github.com/Sebastian-Tamayo/CasaTorinoApp.git}"
RELEASE_TAG="${RELEASE_TAG:-casatorino-export-2026-10-23}"
RELEASE_URL="https://github.com/Sebastian-Tamayo/Proyeccion/releases/download/${RELEASE_TAG}/casatorino-from-proyeccion.tar.gz"
# Fallback: tree del commit de export (antes de borrar en Proyeccion)
EXPORT_COMMIT="${EXPORT_COMMIT:-bd9ca63b3bc3b13b3ac80c3d10494142061609ad}"
WORKDIR="${TMPDIR:-/tmp}/casatorino-apply-$$"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> 1/4 Obteniendo paquete migrado"
if [[ -n "${TARBALL:-}" && -f "$TARBALL" ]]; then
  cp "$TARBALL" payload.tar.gz
  echo "    (tarball local: $TARBALL)"
elif curl -fsSL -L -o payload.tar.gz "$RELEASE_URL"; then
  echo "    (release $RELEASE_TAG)"
else
  echo "    Release no disponible; reconstruyendo desde Proyeccion @$EXPORT_COMMIT"
  git clone --filter=blob:none --no-checkout https://github.com/Sebastian-Tamayo/Proyeccion.git proyeccion
  cd proyeccion
  git fetch --depth 1 origin "$EXPORT_COMMIT"
  git checkout "$EXPORT_COMMIT"
  mkdir -p /tmp/casatorino-rebuild/docs/ops /tmp/casatorino-rebuild/scripts/ops
  cp docs/ACCESO-CASATORINO.md /tmp/casatorino-rebuild/docs/ops/ACCESO-GITHUB.md
  cp docs/ECOSISTEMA-VERCEL.md docs/FIX-RESERVAS-STORE.md docs/FIX-RESERVAS-VERCEL.md /tmp/casatorino-rebuild/docs/ops/
  cp -a docs/casatorino-fix /tmp/casatorino-rebuild/docs/ops/fix
  cp -a docs/casatorino-qr /tmp/casatorino-rebuild/docs/ops/qr
  cp -a docs/casatorino-sync /tmp/casatorino-rebuild/docs/ops/sync
  cp -a docs/casatorino-web-redesign /tmp/casatorino-rebuild/docs/ops/web-redesign
  cp docs/publicar-en-casatorinoapp.sh docs/sincronizar-web-casatorino.sh \
     docs/arreglar-reservas-prod.sh docs/redeploy-reservas-vercel.sh \
     /tmp/casatorino-rebuild/scripts/ops/
  rm -f /tmp/casatorino-rebuild/docs/ops/sync/.write-test
  cd "$WORKDIR"
  tar -czf payload.tar.gz -C /tmp/casatorino-rebuild .
fi

echo "==> 2/4 Clonando CasaTorinoApp ($BRANCH)"
git clone "$REPO_URL" dest
cd dest
git checkout "$BRANCH"
git checkout -b "cursor/import-ops-from-proyeccion-$(date +%Y%m%d)"

echo "==> 3/4 Extrayendo docs/ops + scripts/ops"
tar -xzf ../payload.tar.gz
# Mantener README de ops si venía en el paquete; no pisar docs existentes del producto
mkdir -p docs/ops scripts/ops
# El tar ya trae docs/ops y scripts/ops en la raíz del payload

echo "==> 4/4 Commit"
git add docs/ops scripts/ops
if [[ -f MANIFEST.txt ]]; then git add MANIFEST.txt; fi
git status -sb | head -50
git commit -m "$(cat <<'MSG'
docs(ops): importar material Casa Torino desde Proyeccion

Migra QR, sync tarballs, fixes Vercel/reservas y scripts de publicar
fuera de Sebastian-Tamayo/Proyeccion. Proyeccion queda solo para proyección.
MSG
)" || {
  echo "Sin cambios que commitear (¿ya importado?)."
  exit 0
}

echo
echo "Listo en rama local. Para publicar:"
echo "  cd $WORKDIR/dest && git push -u origin HEAD"
echo "Luego abre PR en https://github.com/Sebastian-Tamayo/CasaTorinoApp"
echo
if [[ "${PUSH:-0}" == "1" ]]; then
  git push -u origin HEAD
  echo "Push OK."
fi
