#!/usr/bin/env python3
"""
Bot Grok → Gmail: clasifica correos y (opcionalmente) los mueve a la papelera.

Por defecto es DRY-RUN: solo muestra qué borraría. Nada se elimina sin --apply.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Raíz del repo en PYTHONPATH
ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv

from agents.agente_grok_correo import clasificar_correos

try:
    from scripts.grok_email_cleaner.gmail_client import (
        autenticar,
        listar_correos,
        mover_a_papelera,
    )
except ImportError:
    from gmail_client import autenticar, listar_correos, mover_a_papelera  # type: ignore

load_dotenv(ROOT / ".env")

OUTPUT_DIR = ROOT / "output"
MIN_CONFIDENCE_DEFAULT = 0.75


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=(
            "Clasifica correos con Grok y mueve a papelera Gmail. "
            "Sin --apply solo simula (dry-run)."
        )
    )
    p.add_argument(
        "--query",
        default=os.getenv("GMAIL_QUERY", "in:inbox newer_than:30d"),
        help='Consulta Gmail (default: in:inbox newer_than:30d)',
    )
    p.add_argument(
        "--max",
        type=int,
        default=int(os.getenv("GMAIL_MAX", "25")),
        help="Máximo de correos a revisar (1-100).",
    )
    p.add_argument(
        "--criterios",
        default="",
        help="Instrucciones extra para Grok (ej: 'borra newsletters de LinkedIn').",
    )
    p.add_argument(
        "--min-confidence",
        type=float,
        default=float(os.getenv("GROK_MIN_CONFIDENCE", str(MIN_CONFIDENCE_DEFAULT))),
        help="Confianza mínima para DELETE (default 0.75).",
    )
    p.add_argument(
        "--include-starred",
        action="store_true",
        help="Permite proponer DELETE en correos con estrella/importantes.",
    )
    p.add_argument(
        "--apply",
        action="store_true",
        help="Ejecuta trash real. Sin esto solo dry-run.",
    )
    p.add_argument(
        "--yes",
        action="store_true",
        help="Con --apply, no pide confirmación interactiva.",
    )
    p.add_argument(
        "--demo",
        action="store_true",
        help="Clasifica correos de ejemplo sin conectar a Gmail (prueba Grok).",
    )
    return p.parse_args()


def correos_demo() -> list[dict]:
    return [
        {
            "id": "demo_001",
            "thread_id": "t1",
            "from": "ofertas@tienda-spam.example",
            "to": "yo@example.com",
            "subject": "🔥 70% OFF solo hoy — no te lo pierdas",
            "date": "Mon, 01 Sep 2026 10:00:00 +0000",
            "snippet": "Cupón exclusivo de marketing masivo...",
            "labels": ["INBOX", "UNREAD"],
            "starred": False,
            "important": False,
            "unread": True,
            "has_unsubscribe": True,
        },
        {
            "id": "demo_002",
            "thread_id": "t2",
            "from": "rrhh@empresademo.example",
            "to": "sebastian@example.com",
            "subject": "Contrato anexo — firma pendiente",
            "date": "Tue, 02 Sep 2026 09:00:00 +0000",
            "snippet": "Adjunto el anexo laboral para revisión...",
            "labels": ["INBOX", "IMPORTANT"],
            "starred": False,
            "important": True,
            "unread": True,
            "has_unsubscribe": False,
        },
        {
            "id": "demo_003",
            "thread_id": "t3",
            "from": "noreply@linkedin.com",
            "to": "yo@example.com",
            "subject": "Tienes 12 notificaciones nuevas",
            "date": "Wed, 03 Sep 2026 12:00:00 +0000",
            "snippet": "Fulano y 11 personas más vieron tu perfil...",
            "labels": ["INBOX"],
            "starred": False,
            "important": False,
            "unread": False,
            "has_unsubscribe": True,
        },
    ]


def filtrar_protegidos(
    decisions: list[dict],
    correos_by_id: dict[str, dict],
    *,
    include_starred: bool,
    min_confidence: float,
) -> tuple[list[dict], list[dict]]:
    """Separa DELETE ejecutable vs bloqueados/conservados."""
    a_borrar: list[dict] = []
    conservados: list[dict] = []

    for d in decisions:
        correo = correos_by_id.get(d["id"], {})
        protegido = (correo.get("starred") or correo.get("important")) and not include_starred
        if d["action"] != "DELETE":
            conservados.append({**d, "blocked": False})
            continue
        if protegido:
            conservados.append(
                {
                    **d,
                    "action": "KEEP",
                    "blocked": True,
                    "reason": f"Protegido (starred/important). Original: {d.get('reason', '')}",
                }
            )
            continue
        if float(d.get("confidence", 0)) < min_confidence:
            conservados.append(
                {
                    **d,
                    "action": "KEEP",
                    "blocked": True,
                    "reason": (
                        f"Confianza {d.get('confidence')} < {min_confidence}. "
                        f"Original: {d.get('reason', '')}"
                    ),
                }
            )
            continue
        a_borrar.append({**d, "blocked": False})

    return a_borrar, conservados


def guardar_informe(
    *,
    query: str,
    dry_run: bool,
    summary: str,
    model: str,
    a_borrar: list[dict],
    conservados: list[dict],
    correos_by_id: dict[str, dict],
    aplicados: list[str],
) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ruta = OUTPUT_DIR / "grok_email_cleaner.md"
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    lineas = [
        f"# Grok Email Cleaner — {stamp}",
        "",
        f"- Modo: {'DRY-RUN' if dry_run else 'APPLY (papelera)'}",
        f"- Query: `{query}`",
        f"- Modelo: `{model}`",
        f"- Resumen Grok: {summary or '(sin resumen)'}",
        f"- Candidatos a papelera: {len(a_borrar)}",
        f"- Conservados / bloqueados: {len(conservados)}",
        f"- Movidos a papelera: {len(aplicados)}",
        "",
        "## Candidatos DELETE",
        "",
    ]
    if not a_borrar:
        lineas.append("_Ninguno._")
    for d in a_borrar:
        c = correos_by_id.get(d["id"], {})
        estado = "TRASHED" if d["id"] in aplicados else "PENDIENTE"
        lineas.append(
            f"- [{estado}] `{d['id']}` conf={d.get('confidence')} — "
            f"**{c.get('subject', '(sin asunto)')}** | {c.get('from', '')}\n"
            f"  - Motivo: {d.get('reason', '')}"
        )

    lineas.extend(["", "## KEEP / bloqueados", ""])
    if not conservados:
        lineas.append("_Ninguno._")
    for d in conservados:
        c = correos_by_id.get(d["id"], {})
        flag = " (bloqueado)" if d.get("blocked") else ""
        lineas.append(
            f"- `{d['id']}`{flag} conf={d.get('confidence')} — "
            f"**{c.get('subject', '(sin asunto)')}**\n"
            f"  - Motivo: {d.get('reason', '')}"
        )

    ruta.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    return ruta


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    args = parse_args()

    if args.demo:
        print("Modo DEMO: correos de ejemplo (sin Gmail).\n")
        correos = correos_demo()
        query = "demo"
    else:
        print("Autenticando Gmail...")
        service = autenticar()
        print(f"Listando correos con query: {args.query!r} (max={args.max})")
        correos = listar_correos(service, query=args.query, max_results=args.max)
        if not correos:
            print("No hay correos que coincidan con la query.")
            return 0

    correos_by_id = {c["id"]: c for c in correos}
    print(f"Enviando {len(correos)} correos a Grok para clasificar...")
    resultado = clasificar_correos(correos, criterios_extra=args.criterios)
    a_borrar, conservados = filtrar_protegidos(
        resultado.get("decisions", []),
        correos_by_id,
        include_starred=args.include_starred,
        min_confidence=args.min_confidence,
    )

    print("\n" + "=" * 60)
    print(f"Resumen Grok: {resultado.get('summary', '')}")
    print(f"Candidatos a papelera: {len(a_borrar)}")
    print(f"Conservar / bloqueados: {len(conservados)}")
    print("=" * 60)

    for d in a_borrar:
        c = correos_by_id[d["id"]]
        print(
            f"  DELETE  [{d['confidence']:.2f}] {c.get('subject', '')[:70]}\n"
            f"          de: {c.get('from', '')[:60]}\n"
            f"          motivo: {d.get('reason', '')}"
        )

    aplicados: list[str] = []
    dry_run = not args.apply

    if args.apply and a_borrar:
        if args.demo:
            print("\n--apply ignorado en --demo (no hay Gmail real).")
        else:
            if not args.yes:
                resp = input(
                    f"\n¿Mover {len(a_borrar)} correo(s) a la PAPELERA? [escribe SI]: "
                ).strip()
                if resp != "SI":
                    print("Cancelado. No se movió nada.")
                    dry_run = True
                else:
                    dry_run = False
            if not dry_run:
                service = autenticar()
                for d in a_borrar:
                    mover_a_papelera(service, d["id"])
                    aplicados.append(d["id"])
                    print(f"  → Papelera: {d['id']}")
    elif args.apply and not a_borrar:
        print("\nNada que aplicar.")
    else:
        print(
            "\nDRY-RUN: no se eliminó nada. "
            "Repite con --apply --yes cuando quieras ejecutar."
        )

    ruta = guardar_informe(
        query=args.query if not args.demo else "demo",
        dry_run=dry_run or args.demo,
        summary=str(resultado.get("summary", "")),
        model=str(resultado.get("model", "")),
        a_borrar=a_borrar,
        conservados=conservados,
        correos_by_id=correos_by_id,
        aplicados=aplicados,
    )
    print(f"\nInforme: {ruta}")

    # También JSON máquina-legible
    json_path = OUTPUT_DIR / "grok_email_cleaner.json"
    json_path.write_text(
        json.dumps(
            {
                "dry_run": dry_run or args.demo,
                "query": args.query if not args.demo else "demo",
                "summary": resultado.get("summary"),
                "model": resultado.get("model"),
                "to_trash": a_borrar,
                "kept": conservados,
                "trashed_ids": aplicados,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"JSON:    {json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
