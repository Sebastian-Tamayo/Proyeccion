"""Agente Grok: clasifica correos candidatos a papelera (no borra por sí mismo)."""

from __future__ import annotations

import json
import os
import re
from typing import Any

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

GROK_MODEL = os.getenv("GROK_MODEL", "grok-4.3")
XAI_BASE_URL = os.getenv("XAI_BASE_URL", "https://api.x.ai/v1")

SYSTEM_PROMPT = """
<role>
Eres el Agente Grok Correo. Usuario: Sebastián Olaya Tamayo.
Clasificas correos de Gmail para limpieza segura del buzón.
</role>
<mission>
Decidir qué mensajes pueden ir a la PAPELERA (trash) y cuáles CONSERVAR.
Nunca inventes IDs. Solo usa los id que recibas en la lista.
</mission>
<rules>
- Preferir CONSERVAR ante la duda.
- Marcar DELETE solo si es claramente ruido: newsletters no pedidas, spam
  promocional, notificaciones masivas, recibos antiguos irrelevantes,
  alertas de marketing, redes sociales repetitivas.
- Marcar KEEP si hay: trabajo, facturas recientes, bancos, gobierno,
  salud, viajes próximos, conversaciones personales, 2FA, seguridad,
  contratos, RRHH, o cualquier hilo que parezca importante.
- No borrar solo por estar leído.
- Responder ÚNICAMENTE JSON válido (sin markdown).
</rules>
<output_schema>
{
  "decisions": [
    {
      "id": "gmail_message_id",
      "action": "DELETE" | "KEEP",
      "confidence": 0.0,
      "reason": "motivo corto en español"
    }
  ],
  "summary": "resumen breve de la pasada"
}
</output_schema>
""".strip()


def _client() -> OpenAI:
    api_key = os.getenv("XAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "Falta XAI_API_KEY en .env. Consíguela en https://console.x.ai/"
        )
    return OpenAI(api_key=api_key, base_url=XAI_BASE_URL)


def _extraer_json(texto: str) -> dict[str, Any]:
    texto = texto.strip()
    if texto.startswith("```"):
        texto = re.sub(r"^```(?:json)?\s*", "", texto)
        texto = re.sub(r"\s*```$", "", texto)
    return json.loads(texto)


def clasificar_correos(
    correos: list[dict[str, Any]],
    criterios_extra: str = "",
) -> dict[str, Any]:
    """Pide a Grok que clasifique una lista de metadatos de correo."""
    if not correos:
        return {"decisions": [], "summary": "Sin correos para clasificar."}

    payload = {
        "criterios_extra": criterios_extra or "(ninguno)",
        "correos": correos,
    }
    user_msg = (
        "Clasifica estos correos. Devuelve solo JSON.\n\n"
        + json.dumps(payload, ensure_ascii=False, indent=2)
    )

    client = _client()
    response = client.chat.completions.create(
        model=GROK_MODEL,
        temperature=0.1,
        max_tokens=4000,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
        ],
    )
    texto = response.choices[0].message.content or "{}"
    data = _extraer_json(texto)

    ids_validos = {c["id"] for c in correos}
    decisions = []
    for item in data.get("decisions", []):
        mid = str(item.get("id", ""))
        action = str(item.get("action", "KEEP")).upper()
        if mid not in ids_validos:
            continue
        if action not in {"DELETE", "KEEP"}:
            action = "KEEP"
        try:
            confidence = float(item.get("confidence", 0.0))
        except (TypeError, ValueError):
            confidence = 0.0
        decisions.append(
            {
                "id": mid,
                "action": action,
                "confidence": max(0.0, min(1.0, confidence)),
                "reason": str(item.get("reason", ""))[:240],
            }
        )

    vistos = {d["id"] for d in decisions}
    for correo in correos:
        if correo["id"] not in vistos:
            decisions.append(
                {
                    "id": correo["id"],
                    "action": "KEEP",
                    "confidence": 1.0,
                    "reason": "No clasificado por Grok; se conserva por seguridad.",
                }
            )

    return {
        "decisions": decisions,
        "summary": str(data.get("summary", "")),
        "model": GROK_MODEL,
    }
