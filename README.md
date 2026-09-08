# Proyección — Ecosistema de 3 Agentes

Pipeline personal para conectar el día a día técnico (Intelcia + Lemoncode) con tres agentes Claude en Python: L3, DevOps y Negocio/Big Data/IA.

## Arquitectura

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
 Arquitecto L3   DevOps          Ops / Big Data / IA
 (Claude API)    (Claude API)    (Claude API)
```

| Pieza | Rol |
|--------|-----|
| **Gemini** | Libreta diaria. Genera el resumen del día (fuera de este repo). |
| **`inbox/resumen_diario.md`** | Punto oficial donde pegas ese resumen. |
| **`memoria.md`** | Historial a largo plazo (evolución, objetivos). |
| **`main.py`** | Orquesta las 3 llamadas en paralelo y muestra las respuestas. |
| **Agentes 1–3** | System prompts XML; modelo Claude vía Anthropic API. |

## Requisitos

- Python 3.10+
- Cuenta Anthropic con API key (créditos Claude)

```bash
pip install -r requirements.txt
```

Crea un archivo `.env` en la raíz (no se sube a Git):

```env
ANTHROPIC_API_KEY=tu_clave_aqui
```

## Uso diario

1. Trabaja el día en **Gemini** y pide un resumen estructurado.
2. Pégalo en [`inbox/resumen_diario.md`](inbox/resumen_diario.md) (sustituye la plantilla).
3. Ejecuta:

```bash
python main.py
```

Si el inbox está vacío o solo tiene la plantilla, `main.py` sale con error y no consume créditos.

Más detalle del flujo: [`FLUJO.md`](FLUJO.md).

## Agentes

| Archivo | Foco |
|---------|------|
| `agente_1_l3.py` | Incidencias reales Intelcia, infra corporativa, scripts PowerShell/Bash Clean Code frente a EDR legítimo. |
| `agente_2_devops.py` | Bootcamp Lemoncode, Cloud e IaC (Docker, Kubernetes, Terraform, Azure, AWS). |
| `agente_3_biz.py` | Observabilidad, Big Data, IA y valor de negocio / proyección estratégica. |

Cada agente recibe el mismo contexto enriquecido: memoria histórica + resumen del día.

## Estructura del repo

```
Proyeccion/
├── main.py
├── agente_1_l3.py
├── agente_2_devops.py
├── agente_3_biz.py
├── memoria.md
├── FLUJO.md
├── inbox/
│   └── resumen_diario.md
├── requirements.txt
├── .gitignore
└── README.md
```

## Seguridad

- **Nunca** subas `.env` ni claves API.
- Los scripts del Agente 1 deben ser legítimos y compatibles con políticas EDR corporativas.

## Licencia

Uso personal / educativo (Sebastián Tamayo — proyección L3 → DevOps → visión de negocio).
