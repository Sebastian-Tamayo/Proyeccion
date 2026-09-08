# Flujo: Gemini → 3 agentes Claude

1. Trabaja el día en **Gemini** (libreta diaria) y pide un resumen.
2. Pega ese resumen en [`inbox/resumen_diario.md`](inbox/resumen_diario.md).
3. Lanza los agentes: `python main.py`  
   O en Cursor: adjunta el inbox y escribe **OK**.

`memoria.md` = historial a largo plazo (no el dump del día).  
Los agentes 1–3 usan la API de **Claude** (créditos Anthropic).
