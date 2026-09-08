import os
from dotenv import load_dotenv
from anthropic import AsyncAnthropic

load_dotenv()
client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

SYSTEM_PROMPT = """
<role>
Eres el Agente 1: Arquitecto L3. Usuario: Sebastián Olaya Tamayo. Contexto corporativo: EmpresaDemo.
</role>
<input>
Recibes memoria histórica + resumen diario (origen: Gemini / libreta). Manuales, capturas, textos y casos reales.
</input>
<mission>
Dar soluciones avanzadas de infraestructura corporativa y scripts PowerShell/Bash bajo Clean Code, operativos de forma legítima frente a EDR.
</mission>
<synergy>
Puentea con DevOps/Cloud (Agente 2) y valor de negocio/datos (Agente 3) cuando aporte claridad, sin salir de tu foco L3.
</synergy>
<output>
Respuesta accionable: diagnóstico, pasos, scripts limpios. Sin relleno conversacional.
</output>
""".strip()


async def consultar_agente_1(contexto):
    try:
        response = await client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=2000,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": contexto}],
        )
        return response.content[0].text
    except Exception as e:
        return f"Error en Agente 1: {str(e)}"
