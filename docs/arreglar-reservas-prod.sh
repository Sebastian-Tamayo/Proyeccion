#!/usr/bin/env bash
set -euo pipefail
NEW='https://crudcrud.com/api/c0b4ee5b6c0745b4adf479e7b4a1d208/reservas'
OLD='https://crudcrud.com/api/cb465a48c3914fd7a9983528b6e00580/reservas'
WORKDIR=$(mktemp -d)
echo "Workdir: $WORKDIR"
cd "$WORKDIR"
git clone https://github.com/Sebastian-Tamayo/CasaTorinoApp.git app
cd app
FILE=reservas/server/reservas-store.js
test -f "$FILE"
if grep -q "$NEW" "$FILE"; then
  echo "Store ya actualizado en código."
else
  sed -i "s|$OLD|$NEW|g" "$FILE" || true
  # fallback rewrite if sed no match (Windows paths etc)
  python - <<PY
from pathlib import Path
p=Path("$FILE")
t=p.read_text(encoding='utf-8')
import re
t2=re.sub(r"https://crudcrud.com/api/[a-f0-9]+/reservas", "$NEW", t)
p.write_text(t2, encoding='utf-8')
print('rewrote store url')
PY
fi
grep crudcrud "$FILE"
git add "$FILE"
git commit -m "fix reservas: replace expired CrudCrud store (fixes 500 API)" || echo "sin cambios de commit"
git push origin main
echo
echo "Espera 1-2 min el deploy de Vercel y prueba:"
echo "  https://reservas-casatorino.vercel.app/api/reservas"
echo "Debe devolver [] o una lista JSON, no error 500."
