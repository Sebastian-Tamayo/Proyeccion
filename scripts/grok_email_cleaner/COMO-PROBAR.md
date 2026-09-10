# Conectar Gmail desde el MÓVIL (sin PC)

El MCP de Gmail de Cursor **no comparte** el login del móvil/PC con este Cloud Agent.
Por eso usamos **código de dispositivo**: el agente te da un código y tú lo apruebas en el teléfono.

Cuenta: `sbsesebeese@gmail.com`

## Paso 1 — Crear credenciales en Google (desde el móvil, Chrome)

1. Abre https://console.cloud.google.com/ (con `sbsesebeese@gmail.com`)
2. Crea un proyecto (o elige uno)
3. Activa **Gmail API**:
   https://console.cloud.google.com/apis/library/gmail.googleapis.com
4. **APIs y servicios → Pantalla de consentimiento OAuth**
   - Tipo: Externo
   - Añádete como usuario de prueba: `sbsesebeese@gmail.com`
5. **APIs y servicios → Credenciales → Crear credenciales → ID de cliente OAuth**
   - Tipo de aplicación: **TVs and Limited Input devices** (TVs y dispositivos de entrada limitada)
   - Nombre: `Proyeccion Gmail Movil`
6. Copia:
   - **Client ID**
   - **Client Secret**

## Paso 2 — Pegar secretos en Cursor Cloud (móvil)

1. Abre el entorno del agente:  
   https://cursor.com/dashboard/cloud-agents/environments/e/dc2a4ff4-ad4f-11f1-bf4b-42ffb4d10ea7
2. Añade secretos / variables:
   - `GMAIL_CLIENT_ID` = (tu Client ID)
   - `GMAIL_CLIENT_SECRET` = (tu Client Secret)
3. Guarda. Si hace falta, reinicia / reabre el agente.

(Alternativa: crear `.env` en el repo con esas dos claves — **no lo subas a Git**.)

## Paso 3 — Autorizar con el móvil

Dile al agente: **“lanza auth móvil”**  
o ejecuta:

```bash
python3 scripts/grok_email_cleaner/auth_movil.py
```

Te mostrará algo como:

```
Abre: https://www.google.com/device
Código: ABCD-EFGH
```

En el móvil:

1. Abre ese enlace
2. Pega el código
3. Elige **`sbsesebeese@gmail.com`**
4. Pulsa **Permitir**

## Paso 4 — Limpiar spam

```bash
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam --apply --yes
```

## Política

KEEP: Sebastián / Ilerna / Capgemini / Intelci / gimnasio / estudios / DevOps / TIC  
DELETE (papelera): el resto del spam
