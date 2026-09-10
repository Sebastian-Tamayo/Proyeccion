# Bot Grok + Gmail: limpieza segura de correos

Clasifica con **Grok (xAI)** y mueve a la **papelera** de Gmail (recuperable ~30 días).  
**Por defecto es dry-run**: no borra nada hasta que pases `--apply`.

## Requisitos

1. Cuenta xAI con API key → https://console.x.ai/
2. Proyecto Google Cloud con **Gmail API** habilitada
3. Credencial OAuth **Desktop app** descargada como `credentials.json`

## Setup

```bash
# Desde la raíz del repo
pip install -r requirements.txt
cp .env.example .env   # si aún no tienes .env
```

En `.env`:

```env
XAI_API_KEY=tu_clave_xai
GROK_MODEL=grok-4.3
```

Coloca el OAuth de Google aquí:

```
scripts/grok_email_cleaner/credentials.json
```

`token.json` se crea solo en el primer login (navegador).

## Uso

```bash
# 1) Probar solo Grok con correos inventados (sin Gmail)
python scripts/grok_email_cleaner/limpiar_correos.py --demo

# 2) Dry-run real: lista inbox reciente y propone borrados
python scripts/grok_email_cleaner/limpiar_correos.py

# 3) Query custom + criterios
python scripts/grok_email_cleaner/limpiar_correos.py \
  --query 'in:inbox category:promotions newer_than:60d' \
  --max 40 \
  --criterios 'Borra newsletters y promos; conserva bancos y trabajo'

# 4) Aplicar (pide confirmar escribiendo SI)
python scripts/grok_email_cleaner/limpiar_correos.py --apply

# 5) Aplicar sin prompt (automatización)
python scripts/grok_email_cleaner/limpiar_correos.py --apply --yes
```

## Seguridad

| Control | Comportamiento |
|---------|----------------|
| Dry-run por defecto | Sin `--apply` no toca Gmail |
| Papelera, no delete | `messages.trash` (recuperable) |
| Estrella / IMPORTANT | Se protegen salvo `--include-starred` |
| Confianza mínima | Default `0.75` (`--min-confidence`) |
| Duda → KEEP | El prompt de Grok prioriza conservar |
| Secretos | `credentials.json` y `token.json` en `.gitignore` |

## Salida

- `output/grok_email_cleaner.md` — informe legible
- `output/grok_email_cleaner.json` — decisiones máquina-legibles

## Google Cloud (resumen)

1. Google Cloud Console → crear proyecto
2. APIs & Services → enable **Gmail API**
3. OAuth consent screen (External / Testing + tu email de prueba)
4. Credentials → Create OAuth client ID → **Desktop app**
5. Descargar JSON → renombrar a `credentials.json` en esta carpeta

Scopes usados: `https://www.googleapis.com/auth/gmail.modify`
