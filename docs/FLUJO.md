# Flujo: Gemini → 3 agentes Claude

1. Trabaja el día en **Gemini** (libreta diaria) y pide un resumen.
2. Pega ese resumen en [`inbox/resumen_diario.md`](../inbox/resumen_diario.md).
3. Lanza: `python main.py` (desde la raíz del repo).
4. Revisa [`output/ultima_ejecucion.md`](../output/ultima_ejecucion.md).
5. Si aporta, consolida en [`memoria.md`](../memoria.md) (siempre anonimizado antes de push).

`memoria.md` = historial a largo plazo (no el dump del día).  
Los agentes viven en `agents/` y usan la API de **Claude**.
