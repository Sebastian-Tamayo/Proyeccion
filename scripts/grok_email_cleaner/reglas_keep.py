"""Reglas fijas de conservación para limpieza de bandeja (Sebastián).

KEEP si coincide; el resto de la bandeja de entrada → DELETE (papelera).
No hace falta Grok para este perfil.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any

# Cuenta objetivo (OAuth debe ser esta)
CUENTA_OBJETIVO = "sbsesebeese@gmail.com"

# Queries Gmail
QUERY_INBOX_TODO = "in:inbox"
QUERY_SPAM_TODO = "in:spam"
# Casi todo el buzón (excepto papelera, borradores y chats)
QUERY_VACIAR_TODO = "-in:trash -in:drafts -in:chats"

# Patrones KEEP (sobre from+to+subject+snippet normalizado)
KEEP_PATTERNS: list[tuple[str, str]] = [
    # Nombre
    (r"sebastian", "Contiene el nombre Sebastián"),
    (r"\bolaya\b", "Contiene apellido Olaya"),
    (r"\btamayo\b", "Contiene apellido Tamayo"),
    # Formación / empresas / vida
    (r"ilerna", "Correo Ilerna"),
    (r"capgemini", "Correo Capgemini"),
    (r"intelci", "Correo Intelci/Intelcia"),
    (r"gimnasio|\bgym\b|fitness|deport", "Relacionado con gimnasio"),
    (r"estudio|estudiant|universidad|formacion|campus|matricula", "Relacionado con estudios"),
    (r"bootcamp", "Bootcamp"),
    (r"devops|lemoncode", "DevOps / Lemoncode"),
    # TIC / tech
    (
        r"\btic\b|informatica|programac|software|desarroll|developer|"
        r"cloud|azure|aws|gcp|kubernetes|docker|terraform|linux|"
        r"cibersegur|cyber|helpdesk|\bl3\b|sysadmin|redes\b|sistemas|"
        r"soporte tecnico|it support|tecnolog",
        "Relacionado con TIC",
    ),
]


def normalizar(texto: str) -> str:
    """Minúsculas + sin acentos para matching robusto."""
    if not texto:
        return ""
    nfkd = unicodedata.normalize("NFKD", texto)
    sin_acentos = "".join(c for c in nfkd if not unicodedata.combining(c))
    return sin_acentos.lower()


def texto_correo(correo: dict[str, Any]) -> str:
    partes = [
        correo.get("from", ""),
        correo.get("to", ""),
        correo.get("subject", ""),
        correo.get("snippet", ""),
    ]
    return normalizar(" ".join(partes))


def motivo_keep(correo: dict[str, Any]) -> str | None:
    """Si debe conservarse, devuelve el motivo; si no, None."""
    blob = texto_correo(correo)
    for pattern, motivo in KEEP_PATTERNS:
        if re.search(pattern, blob, flags=re.IGNORECASE):
            return motivo
    return None


def clasificar_por_reglas(correos: list[dict[str, Any]]) -> dict[str, Any]:
    """
    Política Sebastián bandeja:
    - KEEP si coincide con patrones protegidos
    - DELETE el resto
    """
    decisions: list[dict[str, Any]] = []
    kept = 0
    deleted = 0
    for correo in correos:
        motivo = motivo_keep(correo)
        if motivo:
            kept += 1
            decisions.append(
                {
                    "id": correo["id"],
                    "action": "KEEP",
                    "confidence": 1.0,
                    "reason": motivo,
                }
            )
        else:
            deleted += 1
            decisions.append(
                {
                    "id": correo["id"],
                    "action": "DELETE",
                    "confidence": 1.0,
                    "reason": (
                        "Bandeja sin coincidencia KEEP "
                        "(nombre/Ilerna/Capgemini/gimnasio/estudios/DevOps/TIC)"
                    ),
                }
            )
    return {
        "decisions": decisions,
        "summary": (
            f"Reglas Sebastián inbox: KEEP={kept}, DELETE={deleted}, "
            f"total={len(correos)}"
        ),
        "model": "rules:sebastian-inbox",
    }


def clasificar_borrar_todo(correos: list[dict[str, Any]]) -> dict[str, Any]:
    """Marca TODOS los correos como DELETE. No conserva ninguno."""
    decisions = [
        {
            "id": correo["id"],
            "action": "DELETE",
            "confidence": 1.0,
            "reason": "Vaciar buzón: borrar todo sin excepciones KEEP",
        }
        for correo in correos
    ]
    return {
        "decisions": decisions,
        "summary": (
            f"Vaciar TODO: DELETE={len(decisions)}, KEEP=0, "
            f"total={len(correos)}"
        ),
        "model": "rules:vaciar-todo",
    }


CRITERIOS_GROK_SEBASTIAN = """
Perfil sbsesebeese@gmail.com — limpieza de BANDEJA DE ENTRADA (inbox).
CONSERVA (KEEP) si el correo menciona o viene de:
- Nombre Sebastián / Olaya / Tamayo
- Ilerna, Capgemini, Intelci/Intelcia
- Gimnasio, estudios, bootcamp, DevOps, Lemoncode
- Cualquier tema TIC (informática, cloud, programación, soporte, etc.)
EL RESTO de la bandeja → DELETE (papelera).
Ante duda en marketing genérico → DELETE.
""".strip()
