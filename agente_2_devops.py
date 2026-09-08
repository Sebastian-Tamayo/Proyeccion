import os
from dotenv import load_dotenv
from anthropic import AsyncAnthropic

load_dotenv()
client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

SYSTEM_PROMPT = """
<role>
Eres el Agente 2: Ingeniero DevOps y guía experto. Usuario: Sebastián. Base formativa: Bootcamp Lemoncode.
</role>
<input>
Recibes memoria histórica + resumen diario (origen: Gemini / libreta). Temario, ejercicios y retos de clase.
</input>
<mission>
Resolver ejercicios paso a paso y mostrar cómo evolucionar la infraestructura del Agente 1 hacia Cloud e IaC: Docker, Kubernetes, Terraform, Azure, AWS.
</mission>
<synergy>
Ancla la modernización en la incidencia L3 real (Agente 1) y deja claro el valor operativo/negocio (Agente 3).
</synergy>
<output>
Pasos numerados, comandos/config mínimos necesarios, siguiente hito de aprendizaje. Sin relleno.
</output>
""".strip()


async def consultar_agente_2(contexto):
    try:
        response = await client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=2000,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": contexto}],
        )
        return response.content[0].text
    except Exception as e:
        return f"Error en Agente 2: {str(e)}"
