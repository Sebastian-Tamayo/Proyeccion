# Limpieza Gmail — bandeja completa (perfil Sebastián)

Cuenta: `sbsesebeese@gmail.com`

## Política

Sobre **toda la bandeja de entrada** (`in:inbox`):

| Acción | Condición |
|--------|-----------|
| **KEEP** | Contiene Sebastián / Olaya / Tamayo |
| **KEEP** | Ilerna, Capgemini, Intelci |
| **KEEP** | Gimnasio, estudios, bootcamp, DevOps |
| **KEEP** | Temas TIC (cloud, programación, soporte…) |
| **DELETE → papelera** | El resto de la bandeja |

Los mensajes van a **papelera** (~30 días), no a borrado permanente.  
Starred / IMPORTANT se protegen salvo `--include-starred`.

Perfil opcional solo spam: `--profile sebastian-spam`.

## Auth (móvil o PC)

Ver `auth_movil.py` / secretos `GMAIL_CLIENT_ID` + `GMAIL_CLIENT_SECRET`,  
o `credentials.json` OAuth Desktop.

## Comandos

```bash
# Demo sin Gmail
python3 scripts/grok_email_cleaner/limpiar_correos.py --demo

# DRY-RUN: toda la bandeja
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-inbox

# Prueba con N mensajes
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-inbox --max 50

# APLICAR
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-inbox --apply

# Solo spam (antiguo comportamiento)
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam
```

## Salida

- `output/grok_email_cleaner.md`
- `output/grok_email_cleaner.json`
