#!/usr/bin/env python3
"""
Bot limpieza Gmail (reglas Sebastián y/o Grok).

Perfil vaciar-todo (default):
  Mueve a papelera TODOS los correos del buzón (inbox, spam, etc.).
  No conserva nada. Excluye solo trash/drafts/chats.

Perfiles opcionales:
  sebastian-inbox — KEEP nombre/Ilerna/Capgemini/TIC…; resto inbox → papelera
  sebastian-spam  — misma política solo sobre spam

Por defecto DRY-RUN. Nada se elimina sin --apply.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dotenv import load_dotenv

load_dotenv(ROOT / ".env")

try:
    from scripts.grok_email_cleaner.gmail_client import (
        autenticar,
        email_perfil,
        listar_correos_paginado,
        mover_varios_a_papelera,
    )
    from scripts.grok_email_cleaner.reglas_keep import (
        CRITERIOS_GROK_SEBASTIAN,
        CUENTA_OBJETIVO,
        QUERY_INBOX_TODO,
        QUERY_SPAM_TODO,
        QUERY_VACIAR_TODO,
        clasificar_borrar_todo,
        clasificar_por_reglas,
    )
except ImportError:
    from gmail_client import (  # type: ignore
        autenticar,
        email_perfil,
        listar_correos_paginado,
        mover_varios_a_papelera,
    )
    from reglas_keep import (  # type: ignore
        CRITERIOS_GROK_SEBASTIAN,
        CUENTA_OBJETIVO,
        QUERY_INBOX_TODO,
        QUERY_SPAM_TODO,
        QUERY_VACIAR_TODO,
        clasificar_borrar_todo,
        clasificar_por_reglas,
    )

OUTPUT_DIR = ROOT / "output"
MIN_CONFIDENCE_DEFAULT = 0.75


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=(
            "Limpia Gmail. Perfil vaciar-todo borra todo sin KEEP. "
            "Sin --apply solo simula."
        )
    )
    p.add_argument(
        "--profile",
        choices=["vaciar-todo", "sebastian-inbox", "sebastian-spam", "custom"],
        default="vaciar-todo",
        help=(
            "vaciar-todo = borrar TODO el buzón (default). "
            "sebastian-inbox = KEEP selectivo en inbox. "
            "sebastian-spam = KEEP selectivo solo en spam."
        ),
    )
    p.add_argument(
        "--query",
        default=None,
        help="Query Gmail. Por defecto del perfil.",
    )
    p.add_argument(
        "--max",
        type=int,
        default=None,
        help="Máximo de correos. Sin valor = todos los de la query.",
    )
    p.add_argument(
        "--use-grok",
        action="store_true",
        help="Clasificar con Grok (no aplica a vaciar-todo).",
    )
    p.add_argument(
        "--criterios",
        default="",
        help="Criterios extra si usas --use-grok.",
    )
    p.add_argument(
        "--min-confidence",
        type=float,
        default=float(os.getenv("GROK_MIN_CONFIDENCE", str(MIN_CONFIDENCE_DEFAULT))),
        help="Confianza mínima DELETE si usas Grok (default 0.75).",
    )
    p.add_argument(
        "--include-starred",
        action="store_true",
        help="Permite trash de starred/IMPORTANT (vaciar-todo ya lo hace).",
    )
    p.add_argument(
        "--expect-account",
        default=CUENTA_OBJETIVO,
        help=f"Email que debe coincidir con OAuth (default {CUENTA_OBJETIVO}).",
    )
    p.add_argument(
        "--apply",
        action="store_true",
        help="Ejecuta trash real.",
    )
    p.add_argument(
        "--yes",
        action="store_true",
        help="Con --apply, no pide confirmación interactiva.",
    )
    p.add_argument(
        "--demo",
        action="store_true",
        help="Correos de ejemplo (sin Gmail).",
    )
    return p.parse_args()


def correos_demo() -> list[dict]:
    return [
        {
            "id": "demo_spam_promo",
            "from": "ofertas@tienda-spam.example",
            "to": CUENTA_OBJETIVO,
            "subject": "70% OFF solo hoy",
            "snippet": "Cupón marketing masivo",
            "labels": ["INBOX"],
            "starred": False,
            "important": False,
            "unread": True,
            "has_unsubscribe": True,
            "date": "",
            "thread_id": "t1",
        },
        {
            "id": "demo_ilerna",
            "from": "secretaria@ilerna.es",
            "to": CUENTA_OBJETIVO,
            "subject": "Matrícula pendiente",
            "snippet": "Hola Sebastián, revisa tu matrícula",
            "labels": ["INBOX"],
            "starred": False,
            "important": False,
            "unread": True,
            "has_unsubscribe": False,
            "date": "",
            "thread_id": "t2",
        },
        {
            "id": "demo_capgemini",
            "from": "noreply@capgemini.com",
            "to": CUENTA_OBJETIVO,
            "subject": "Proceso selección",
            "snippet": "Actualización de candidatura",
            "labels": ["INBOX"],
            "starred": False,
            "important": False,
            "unread": False,
            "has_unsubscribe": False,
            "date": "",
            "thread_id": "t3",
        },
        {
            "id": "demo_devops",
            "from": "info@lemoncode.net",
            "to": CUENTA_OBJETIVO,
            "subject": "Bootcamp DevOps módulo 3",
            "snippet": "Contenido cloud y terraform",
            "labels": ["INBOX"],
            "starred": False,
            "important": False,
            "unread": False,
            "has_unsubscribe": False,
            "date": "",
            "thread_id": "t4",
        },
        {
            "id": "demo_random",
            "from": "noreply@casino-xyz.example",
            "to": CUENTA_OBJETIVO,
            "subject": "Gana dinero ya",
            "snippet": "Apuesta gratis",
            "labels": ["INBOX"],
            "starred": False,
            "important": False,
            "unread": True,
            "has_unsubscribe": True,
            "date": "",
            "thread_id": "t5",
        },
    ]


def filtrar_protegidos(
    decisions: list[dict],
    correos_by_id: dict[str, dict],
    *,
    include_starred: bool,
    min_confidence: float,
    rules_only: bool,
) -> tuple[list[dict], list[dict]]:
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
        if not rules_only and float(d.get("confidence", 0)) < min_confidence:
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
    account: str,
    a_borrar: list[dict],
    conservados: list[dict],
    correos_by_id: dict[str, dict],
    aplicados: list[str],
) -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ruta = OUTPUT_DIR / "grok_email_cleaner.md"
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    lineas = [
        f"# Email Cleaner — {stamp}",
        "",
        f"- Cuenta: `{account or '(demo)'}`",
        f"- Modo: {'DRY-RUN' if dry_run else 'APPLY (papelera)'}",
        f"- Query: `{query}`",
        f"- Motor: `{model}`",
        f"- Resumen: {summary or '(sin resumen)'}",
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
            f"- [{estado}] `{d['id']}` — "
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
            f"- `{d['id']}`{flag} — "
            f"**{c.get('subject', '(sin asunto)')}**\n"
            f"  - Motivo: {d.get('reason', '')}"
        )

    ruta.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    return ruta


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    args = parse_args()
    vaciar = args.profile == "vaciar-todo"
    rules_only = not args.use_grok or vaciar
    # Vaciar = también starred/IMPORTANT
    include_starred = True if vaciar else args.include_starred
    account = ""

    if args.profile == "vaciar-todo":
        query = args.query or QUERY_VACIAR_TODO
    elif args.profile == "sebastian-spam":
        query = args.query or QUERY_SPAM_TODO
    elif args.profile == "sebastian-inbox":
        query = args.query or QUERY_INBOX_TODO
    else:
        query = args.query or os.getenv("GMAIL_QUERY", QUERY_VACIAR_TODO)

    if args.demo:
        print("Modo DEMO: correos de ejemplo (sin Gmail).\n")
        correos = correos_demo()
        query = "demo vaciar-todo" if vaciar else "demo in:inbox"
        account = CUENTA_OBJETIVO
        service = None
    else:
        print("Autenticando Gmail...")
        service = autenticar()
        account = email_perfil(service)
        print(f"Cuenta OAuth: {account}")
        esperado = (args.expect_account or "").lower().strip()
        if esperado and account != esperado:
            print(
                f"ERROR: la sesión es {account}, se esperaba {esperado}.\n"
                "Borra scripts/grok_email_cleaner/token.json y vuelve a login "
                f"con {esperado}."
            )
            return 2
        limite = args.max
        print(
            f"Listando correos query={query!r} "
            f"max={'TODOS' if limite is None else limite}"
        )
        correos = listar_correos_paginado(
            service, query=query, max_results=limite
        )
        if not correos:
            print("No hay correos que coincidan con la query.")
            return 0

    correos_by_id = {c["id"]: c for c in correos}

    if vaciar:
        print(f"Marcando {len(correos)} correos para VACIAR (DELETE todos)...")
        resultado = clasificar_borrar_todo(correos)
    elif rules_only:
        print(f"Clasificando {len(correos)} correos con REGLAS Sebastián...")
        resultado = clasificar_por_reglas(correos)
    else:
        from agents.agente_grok_correo import clasificar_correos

        criterios = args.criterios or CRITERIOS_GROK_SEBASTIAN
        print(f"Clasificando {len(correos)} correos con GROK...")
        resultado = clasificar_correos(correos, criterios_extra=criterios)

    a_borrar, conservados = filtrar_protegidos(
        resultado.get("decisions", []),
        correos_by_id,
        include_starred=include_starred,
        min_confidence=args.min_confidence,
        rules_only=rules_only,
    )

    print("\n" + "=" * 60)
    print(resultado.get("summary", ""))
    print(f"Candidatos a papelera: {len(a_borrar)}")
    print(f"Conservar: {len(conservados)}")
    if vaciar:
        print("AVISO: perfil vaciar-todo — no se conserva ningún correo.")
    print("=" * 60)

    for d in conservados[:20]:
        c = correos_by_id[d["id"]]
        print(f"  KEEP    {c.get('subject', '')[:70]}")
        print(f"          motivo: {d.get('reason', '')}")
    if len(conservados) > 20:
        print(f"  ... +{len(conservados) - 20} KEEP más")

    for d in a_borrar[:30]:
        c = correos_by_id[d["id"]]
        print(f"  DELETE  {c.get('subject', '')[:70]}")
        print(f"          de: {c.get('from', '')[:60]}")
    if len(a_borrar) > 30:
        print(f"  ... +{len(a_borrar) - 30} DELETE más")

    aplicados: list[str] = []
    dry_run = not args.apply

    if args.apply and a_borrar:
        if args.demo:
            print("\n--apply ignorado en --demo.")
        else:
            if not args.yes:
                palabra = "VACIAR" if vaciar else "SI"
                resp = input(
                    f"\n¿Mover {len(a_borrar)} correo(s) a PAPELERA "
                    f"en {account}? [escribe {palabra}]: "
                ).strip()
                if resp != palabra:
                    print("Cancelado.")
                    dry_run = True
                else:
                    dry_run = False
            if not dry_run:
                assert service is not None
                print(f"Moviendo {len(a_borrar)} a papelera...")
                aplicados = mover_varios_a_papelera(
                    service, [d["id"] for d in a_borrar]
                )
                print(f"Listo: {len(aplicados)} movidos a papelera.")
    elif args.apply and not a_borrar:
        print("\nNada que aplicar.")
    else:
        print(
            "\nDRY-RUN: no se eliminó nada.\n"
            "Para VACIAR TODO el buzón:\n"
            "  python3 scripts/grok_email_cleaner/limpiar_correos.py "
            "--profile vaciar-todo --apply --yes"
        )

    ruta = guardar_informe(
        query=query,
        dry_run=dry_run or args.demo,
        summary=str(resultado.get("summary", "")),
        model=str(resultado.get("model", "")),
        account=account,
        a_borrar=a_borrar,
        conservados=conservados,
        correos_by_id=correos_by_id,
        aplicados=aplicados,
    )
    print(f"\nInforme: {ruta}")

    json_path = OUTPUT_DIR / "grok_email_cleaner.json"
    json_path.write_text(
        json.dumps(
            {
                "account": account,
                "dry_run": dry_run or args.demo,
                "query": query,
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
