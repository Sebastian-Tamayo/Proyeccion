# Cómo generar el informe con los 3 agentes (recordatorio)

Guía rápida para **Sebastián Olaya Tamayo**. Dos formas de trabajar: **Python local** (informe automático) y **Cursor** (adjuntar archivos y pedir informe en el chat).

---

## Qué hacen los agentes (idea clara)

| Agente | Foco |
|--------|------|
| **1 – L3** | Infra, PowerShell, scripts, EDR-safe, diagnóstico operativo |
| **2 – DevOps** | Intune, pipelines, empaquetado, Lemoncode / cloud |
| **3 – Negocio** | ROI, tiempos, KPIs, narrativa para gestión |

En `main.py` **no se escriben emails entre ellos**: los **tres leen el mismo contexto a la vez** (memoria + tu resumen del día) y devuelven **tres secciones** en un solo informe. En los prompts están instruidos a **coherencia cruzada** (L3 ↔ DevOps ↔ negocio).

---

## Local vs GitHub (importante)

- **`inbox/resumen_diario.md`** = datos reales del día → **NO se sube** (`.gitignore`).
- **`inbox/resumen_diario.example.md`** = plantilla pública en el repo.
- Telemetría de sitio: `docs/Documentacion Agente/` → **NO se sube**.
- Para reclutadores: usa `docs/casos/*-ANON.md` o anonimiza antes de memoria/push.
- Detalle: [`LOCAL-VS-GITHUB.md`](LOCAL-VS-GITHUB.md).

## Método A — Informe automático (`python main.py`)

### 1. Preparar entorno (una vez)

```bash
cd C:\L3 proyeccion\Proyeccion
pip install -r requirements.txt
```

Crea `.env` (copia de `.env.example`):

```env
ANTHROPIC_API_KEY=tu_clave_anthropic
```

### 2. Escribir la entrada del día

Edita **`inbox/resumen_diario.md`**:

- Quita o sustituye el marcador `(Pega el resumen de Gemini aqui.)`
- Pega **mínimo ~200 caracteres** útiles (no solo el placeholder)
- Estructura recomendada (puedes copiarla):

```markdown
**Fecha:** YYYY-MM-DD

## 1. Contexto / incidencia
(qué pasó, entorno genérico, sin secretos)

## 2. Hechos y logs (opcional)
(códigos de error, tiempos, “40 min Citrix”, etc.)

## 3. Objetivo Agente 1 (L3)
(qué script, qué validar)

## 4. Objetivo Agente 2 (DevOps)
(cómo escalaría en Intune/CI)

## 5. Objetivo Agente 3 (Negocio)
(ROI, ahorro de tiempo, riesgo)

## 6. Adjuntos
(lista: “ver scripts/Santander Empresas/Instalar-….ps1” — en local; en Cursor usa @archivos)
```

**Memoria larga:** `memoria.md` se **inyecta sola** en cada ejecución. Ahí van casos ya cerrados (SAP, Iber, Santander, MFA…). No hace falta repetir todo el historial en el inbox.

### 3. Ejecutar

```bash
python main.py
```

### 4. Leer el informe

Salida: **`output/ultima_ejecucion.md`**

Contiene:

- `## Agente 1 (L3)`
- `## Agente 2 (DevOps)`
- `## Agente 3 (Negocio)`

También se imprime en consola.

### 5. Guardar lo bueno en memoria

Cuando un informe te encaje, di en Cursor algo como: **“está bien, añade a memoria”**.  
Regla del repo: se anexa a **`memoria.md`** (anonimizado). No se hace push de memoria con datos reales de clientes.

---

## Método B — Cursor (adjuntar más información)

Útil cuando quieres **logs, scripts enteros, capturas** sin pasar solo por el inbox.

1. Abre el proyecto **`Proyeccion`** en Cursor.
2. En el chat:
   - **`@`** → elige archivos o carpetas (`Instalar-SantanderEmpresas.ps1`, log, LEEME…).
   - O arrastra archivos al chat.
3. Pega el **mismo bloque estructurado** que usarías en `inbox/resumen_diario.md` (contexto + objetivos por agente).
4. Pide explícitamente, por ejemplo:

   > “Genera informe en formato de los 3 agentes (L3, DevOps, Negocio) como `output/ultima_ejecucion.md`.”

5. Si quieres **alinear** con el pipeline Python: copia tu prompt final a `inbox/resumen_diario.md` y ejecuta `python main.py` para tener versión Claude API en el archivo de salida.

**Qué adjuntar sin riesgo (antes de GitHub):**

- Scripts `.ps1` / `.bat`, LEEME, logs **sin** usuarios reales, hosts ni rutas de cliente (o anonimiza).
- **No** adjuntes `.env`, `credentials.json`, certificados `.cer` del banco, MSI/EXE gigantes si no hace falta.

---

## Flujo típico de un día (checklist)

```
[ ] Gemini / libreta → resumen estructurado
[ ] Pegar en inbox/resumen_diario.md (+ fecha)
[ ] (Opcional) @archivos en Cursor para profundizar
[ ] python main.py   — o —   informe solo en Cursor
[ ] Revisar output/ultima_ejecucion.md
[ ] Implementar cambios en scripts/
[ ] Si OK → “añade a memoria”
[ ] Push solo código/docs; memoria anonimizada
```

---

## Errores frecuentes

| Mensaje | Solución |
|---------|----------|
| `Falta inbox/resumen_diario.md` | Crear el archivo en `inbox/` |
| `No hay resumen útil` | Pegar más texto; quitar solo el marcador vacío |
| `Error en Agente N: ... API` | Revisar `ANTHROPIC_API_KEY` en `.env` |
| Informes genéricos | Objetivos por agente más concretos + adjuntar script/log |

---

## Enlaces en el repo

- Flujo corto: [`FLUJO.md`](FLUJO.md)
- Orquestador: [`main.py`](../main.py)
- Agentes: [`agents/`](../agents/)
- Casos portfolio (Santander, SAP…): [`casos/`](casos/)

---

*Última actualización: documento de recordatorio operativo; no sustituye la API key ni las políticas de tu empresa.*
