# Proyección — Ecosistema de 3 Agentes

Proyecto de **Sebastián Olaya Tamayo**. Monorepo personal: orquestador de IA (Python + Claude) + laboratorios y casos L3/DevOps/Negocio.

**Objetivo:** documentar la transición de soporte L3 → DevOps/Cloud → visión de negocio (Big Data/IA), con artefactos reutilizables y memoria operativa.

## Arquitectura del orquestador

```
Gemini (libreta diaria)
        │
        ▼ resumen del día
inbox/resumen_diario.md
        │
        ▼  python main.py
   ┌────┴────┐
   │ main.py │  + memoria.md
   └────┬────┘
        │ asyncio.gather
   ┌────┼────────────┐
   ▼    ▼            ▼
 Agente 1        Agente 2        Agente 3
 L3              DevOps          Negocio / Big Data / IA
 (Claude)        (Claude)        (Claude)
        │
        ▼
output/ultima_ejecucion.md
```

| Pieza | Rol |
|--------|-----|
| **Gemini** | Libreta diaria (fuera del repo). |
| **`inbox/`** | Entrada del día: pega aquí el resumen. |
| **`memoria.md`** | Historial a largo plazo (anonimizado). |
| **`main.py`** | Orquesta las 3 llamadas en paralelo. |
| **`agents/`** | System prompts XML + clientes Anthropic. |
| **`scripts/`** | Casos reales / laboratorios (artefactos). |
| **`output/`** | Última respuesta de los agentes. |
| **`docs/`** | Guías cortas de flujo. |

## Configuración local

```bash
pip install -r requirements.txt
cp .env.example .env   # o crea .env a mano
```

```env
ANTHROPIC_API_KEY=tu_clave_aqui
XAI_API_KEY=tu_clave_xai          # solo para el bot de correos Grok
GROK_MODEL=grok-4.3
```

> `.env` **nunca** se sube a Git.

## Flujo de trabajo diario

1. Resume el día en Gemini.
2. Pega el texto en [`inbox/resumen_diario.md`](inbox/resumen_diario.md).
3. Ejecuta: `python main.py`
4. Revisa `output/ultima_ejecucion.md` y consolida en `memoria.md` si aporta.

Detalle: [`docs/FLUJO.md`](docs/FLUJO.md).

## Agentes

| Módulo | Foco |
|--------|------|
| [`agents/agente_1_l3.py`](agents/agente_1_l3.py) | Infra L3, scripts Clean Code / EDR-safe |
| [`agents/agente_2_devops.py`](agents/agente_2_devops.py) | Lemoncode, Cloud, IaC |
| [`agents/agente_3_biz.py`](agents/agente_3_biz.py) | ROI, KPIs, narrativa de negocio |
| [`agents/agente_grok_correo.py`](agents/agente_grok_correo.py) | Grok (xAI): clasifica correos para limpieza Gmail |

## Casos y laboratorios (`scripts/`)

Enfoque **monorepo**: el orquestador y los artefactos viven juntos para buscar soluciones pasadas sin salir del proyecto.

| Caso | Descripción |
|------|-------------|
| [`scripts/SAP_740/`](scripts/SAP_740/) | Zero-Touch SAP GUI 7.40 desde USB, PowerShell EDR-safe, unión a dominio parametrizable |
| [`scripts/IBER/`](scripts/IBER/) | Zero-Touch Altitude uCI / SIPPhone desde USB (InstallShield silencioso + post-config) |
| [`scripts/grok_email_cleaner/`](scripts/grok_email_cleaner/) | Bot Grok + Gmail: clasifica y mueve spam/promos a papelera (dry-run por defecto) |

Guía de prueba USB: [`scripts/SAP_740/COMO-PROBAR.md`](scripts/SAP_740/COMO-PROBAR.md).

```powershell
# Producción: pasar dominio real (en repo hay placeholders)
.\Deploy-SAP740.ps1 -DomainName "corp.ejemplo.local" -DomainProbeHost "SRV-DC-01.corp.ejemplo.local"
```

## Impacto y resultados (portfolio)

| Resultado | Valor |
|-----------|--------|
| Pipeline Gemini → 3 agentes Claude | Menos fricción para documentar incidencias y proyectar aprendizaje |
| Playbook MFA: desasignar en consola ≠ borrar usuario AD | Evita cascadas de SID/buzón/compliance |
| `Deploy-SAP740.ps1` EDR-safe | Sin PInvoke/kernel32 ni `cmd` ofuscado; menos falsos positivos SOC |
| Ejecución desde lápiz USB | Menor lead time de provisión (sin pegar a `C:\Deploy`) |
| Memoria y docs anonimizados | Repo publicable sin filtrar datos personales/corporativos |

*Cifras de ROI en `memoria.md` son estimaciones de escenario de laboratorio (datos ficticios).*

## Bot Grok: limpiar correos (Gmail)

Perfil **Sebastián spam** (`sbsesebeese@gmail.com`): conserva nombre/Ilerna/Capgemini/Intelci/gimnasio/estudios/DevOps/TIC; el resto del spam → papelera.

```bash
pip install -r requirements.txt
# Pon credentials.json de Gmail OAuth (Desktop) en scripts/grok_email_cleaner/
python3 scripts/grok_email_cleaner/limpiar_correos.py --demo
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam
python3 scripts/grok_email_cleaner/limpiar_correos.py --profile sebastian-spam --apply
```

Guía: [`scripts/grok_email_cleaner/COMO-PROBAR.md`](scripts/grok_email_cleaner/COMO-PROBAR.md).

## Estructura del repositorio

```
Proyeccion/
├── main.py
├── agents/
│   ├── agente_1_l3.py
│   ├── agente_2_devops.py
│   ├── agente_3_biz.py
│   └── agente_grok_correo.py
├── inbox/
│   └── resumen_diario.md
├── output/
│   └── ultima_ejecucion.md
├── scripts/
│   ├── SAP_740/
│   ├── IBER/
│   └── grok_email_cleaner/
├── docs/
│   └── FLUJO.md
├── memoria.md
├── requirements.txt
├── .env.example
├── .gitignore
└── README.md
```

## Por qué monorepo

- Un solo sitio para orquestador + scripts + memoria.
- Historial de “casos resueltos” enlazado al README.
- Repos separados solo cuando un artefacto merezca ciclo de vida/CI propio.

## Seguridad

- No subir `.env`, secretos ni datos personales reales.
- Dominios/hosts en ejemplos son placeholders (`ejemplo.local`).
- Scripts L3: solo automatización legítima y compatible con EDR.

## Licencia

Uso personal / educativo — proyección de Sebastián Olaya Tamayo (L3 → DevOps → visión de negocio).
