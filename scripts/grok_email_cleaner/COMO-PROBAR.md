# Limpieza Gmail — vaciar TODO

Cuenta: `sbsesebeese@gmail.com`

## Política (perfil default: `vaciar-todo`)

Mueve a **papelera** casi todo el buzón:

- Query: `-in:trash -in:drafts -in:chats`
- **KEEP = 0** (no conserva nada: ni Ilerna, ni Capgemini, ni starred)
- Recuperable ~30 días desde la papelera de Gmail

Perfiles opcionales con KEEP selectivo:

- `sebastian-inbox` — conserva nombre/Ilerna/Capgemini/TIC… en inbox
- `sebastian-spam` — misma lógica solo en spam

## Auth

Ver `auth_movil.py` o `credentials.json` OAuth.

## Comandos

```bash
# Demo (sin Gmail): borra los 5 de ejemplo
python3 scripts/grok_email_cleaner/limpiar_correos.py --demo

# DRY-RUN real: lista qué vaciaría
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile vaciar-todo

# APLICAR (pide escribir VACIAR)
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile vaciar-todo --apply

# APLICAR sin prompt
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile vaciar-todo --apply --yes
```

## Salida

- `output/grok_email_cleaner.md`
- `output/grok_email_cleaner.json`
