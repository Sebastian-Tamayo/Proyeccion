import asyncio
import os
import sys
from datetime import datetime

from agents.agente_1_l3 import consultar_agente_1
from agents.agente_2_devops import consultar_agente_2
from agents.agente_3_biz import consultar_agente_3

# Windows (cp1252) no imprime bien respuestas Claude con Unicode
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

RUTA_INBOX = os.path.join("inbox", "resumen_diario.md")
RUTA_MEMORIA = "memoria.md"
RUTA_OUTPUT_DIR = "output"
MARCADOR_VACIO = "(Pega el resumen de Gemini aqui.)"


def leer_texto(ruta: str, fallback: str) -> str:
    if not os.path.exists(ruta):
        return fallback
    with open(ruta, "r", encoding="utf-8") as f:
        return f.read()


def cargar_resumen_diario() -> str:
    if not os.path.exists(RUTA_INBOX):
        print(
            f"ERROR: Falta {RUTA_INBOX}. Crea el archivo y pega el resumen de Gemini."
        )
        sys.exit(1)

    contenido = leer_texto(RUTA_INBOX, fallback="").strip()
    if not contenido:
        print(f"ERROR: {RUTA_INBOX} está vacío. Pega el resumen de Gemini.")
        sys.exit(1)

    if MARCADOR_VACIO in contenido:
        sin_marcador = contenido.replace(MARCADOR_VACIO, "").strip()
        if len(sin_marcador) < 200:
            print(
                f"ERROR: No hay resumen útil en {RUTA_INBOX}.\n"
                "Pega el resumen de Gemini ahí y vuelve a ejecutar."
            )
            sys.exit(1)

    return contenido


def guardar_salida(resp_l3: str, resp_devops: str, resp_biz: str) -> str:
    os.makedirs(RUTA_OUTPUT_DIR, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    texto = (
        f"# Ejecucion {stamp}\n\n"
        f"## Agente 1 (L3)\n\n{resp_l3}\n\n"
        f"## Agente 2 (DevOps)\n\n{resp_devops}\n\n"
        f"## Agente 3 (Negocio)\n\n{resp_biz}\n"
    )
    ruta = os.path.join(RUTA_OUTPUT_DIR, "ultima_ejecucion.md")
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(texto)
    return ruta


async def procesar_incidencia(contexto_del_dia, memoria):
    print("Iniciando consulta a los 3 agentes simultáneamente. Por favor, espera...\n")

    contexto_enriquecido = (
        f"=== MEMORIA HISTÓRICA DEL USUARIO ===\n{memoria}\n\n"
        f"=== TAREA / PROBLEMA DEL DÍA ===\n{contexto_del_dia}"
    )

    resultados = await asyncio.gather(
        consultar_agente_1(contexto_enriquecido),
        consultar_agente_2(contexto_enriquecido),
        consultar_agente_3(contexto_enriquecido),
    )

    resp_l3, resp_devops, resp_biz = resultados

    print("=" * 70)
    print("RESPUESTA AGENTE 1 (Arquitecto L3)")
    print("=" * 70)
    print(resp_l3)
    print("\n" + "=" * 70)
    print("RESPUESTA AGENTE 2 (DevOps)")
    print("=" * 70)
    print(resp_devops)
    print("\n" + "=" * 70)
    print("RESPUESTA AGENTE 3 (Negocio, Big Data e IA)")
    print("=" * 70)
    print(resp_biz)
    print("\n" + "=" * 70)

    ruta = guardar_salida(resp_l3, resp_devops, resp_biz)
    print(f"\nSalida guardada en: {ruta}")


if __name__ == "__main__":
    memoria = leer_texto(
        RUTA_MEMORIA,
        fallback="Aún no hay registro de memoria histórica guardado.",
    )
    contexto_del_dia = cargar_resumen_diario()
    asyncio.run(procesar_incidencia(contexto_del_dia, memoria))
