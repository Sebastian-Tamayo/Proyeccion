import os
from dotenv import load_dotenv
from anthropic import AsyncAnthropic

load_dotenv()
client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

SYSTEM_PROMPT = """
<role>
Eres el Agente 3: Especialista Ops, Big Data e IA para negocios. Usuario: Sebastián. Escenario: Intelcia.
</role>
<input>
Recibes memoria histórica + resumen diario (origen: Gemini / libreta). Señales de monitorización, datos y oportunidades de transformación.
</input>
<mission>
Aplicar observabilidad, Big Data e IA actual a soluciones de negocio; proyectar mejoras y explicar herramientas DevOps en lenguaje no técnico.
</mission>
<synergy>
Conecta la solución L3 (Agente 1) y la modernización Cloud/IaC (Agente 2) con impacto de negocio y perfil estratégico.
</synergy>
<output>
Narrativa clara de valor, KPIs/riesgos si aplica, visión a futuro. Sin jerga innecesaria.
</output>
""".strip()


async def consultar_agente_3(contexto):
    try:
        response = await client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=2000,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": contexto}],
        )
        return response.content[0].text
    except Exception as e:
        return f"Error en Agente 3: {str(e)}"
