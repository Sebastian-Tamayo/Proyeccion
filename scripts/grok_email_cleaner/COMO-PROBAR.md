# Limpieza spam Gmail — perfil Sebastián

Cuenta objetivo: `sbsesebeese@gmail.com`

## Política

Sobre **todo el spam** (`in:spam`):

| Acción | Condición |
|--------|-----------|
| **KEEP** | Contiene Sebastián / Olaya / Tamayo |
| **KEEP** | Ilerna, Capgemini, Intelci |
| **KEEP** | Gimnasio, estudios, bootcamp, DevOps |
| **KEEP** | Temas TIC (cloud, programación, soporte…) |
| **DELETE → papelera** | El resto del spam |

Los mensajes van a **papelera** (recuperables ~30 días), no a borrado permanente.

## Setup (obligatorio en tu PC)

Este entorno cloud **no tiene** tu OAuth de Gmail ni puede abrir el login interactivo por ti.

1. Google Cloud → habilita **Gmail API** → OAuth Desktop → descarga JSON
2. Guárdalo como `scripts/grok_email_cleaner/credentials.json`
3. En `.env` (opcional, solo si usas `--use-grok`):
   ```env
   XAI_API_KEY=...
   ```
4. Instala deps:
   ```bash
   pip install -r requirements.txt
   ```

## Comandos

```bash
# Simulación con ejemplos (sin Gmail)
python3 scripts/grok_email_cleaner/limpiar_correos.py --demo

# DRY-RUN real: lista TODO el spam y muestra qué borraría
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam

# Limitar a N mensajes (prueba)
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam --max 50

# APLICAR: mueve a papelera (pide escribir SI)
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam --apply

# APLICAR sin prompt
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam --apply --yes
```

Al autenticar, elige **sbsesebeese@gmail.com**. Si te equivocas de cuenta:

```bash
rm scripts/grok_email_cleaner/token.json
```

## Salida

- `output/grok_email_cleaner.md`
- `output/grok_email_cleaner.json`
