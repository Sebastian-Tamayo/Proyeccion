"""Cliente Gmail OAuth: listar (con paginación) y mover a papelera."""

from __future__ import annotations

import os
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import Any

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]

DEFAULT_CREDENTIALS = Path(
    os.getenv("GMAIL_CREDENTIALS_PATH", "scripts/grok_email_cleaner/credentials.json")
)
DEFAULT_TOKEN = Path(
    os.getenv("GMAIL_TOKEN_PATH", "scripts/grok_email_cleaner/token.json")
)


def autenticar(
    credentials_path: Path = DEFAULT_CREDENTIALS,
    token_path: Path = DEFAULT_TOKEN,
):
    """OAuth local. Abre el navegador la primera vez."""
    creds = None
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not credentials_path.exists():
                raise FileNotFoundError(
                    f"No está {credentials_path}. Descarga OAuth Desktop "
                    "desde Google Cloud Console (Gmail API) y guárdalo ahí.\n"
                    "Guía: scripts/grok_email_cleaner/COMO-PROBAR.md"
                )
            flow = InstalledAppFlow.from_client_secrets_file(
                str(credentials_path), SCOPES
            )
            creds = flow.run_local_server(port=0)
        token_path.parent.mkdir(parents=True, exist_ok=True)
        token_path.write_text(creds.to_json(), encoding="utf-8")

    return build("gmail", "v1", credentials=creds)


def email_perfil(service) -> str:
    """Email de la cuenta autenticada."""
    profile = service.users().getProfile(userId="me").execute()
    return str(profile.get("emailAddress", "")).lower()


def _header(headers: list[dict[str, str]], name: str) -> str:
    name_l = name.lower()
    for h in headers:
        if h.get("name", "").lower() == name_l:
            return h.get("value", "")
    return ""


def _snippet_seguro(texto: str, max_len: int = 180) -> str:
    return " ".join((texto or "").split())[:max_len]


def _meta_de_mensaje(service, mid: str) -> dict[str, Any]:
    full = (
        service.users()
        .messages()
        .get(
            userId="me",
            id=mid,
            format="metadata",
            metadataHeaders=["From", "To", "Subject", "Date", "List-Unsubscribe"],
        )
        .execute()
    )
    headers = full.get("payload", {}).get("headers", [])
    labels = set(full.get("labelIds", []))
    return {
        "id": mid,
        "thread_id": full.get("threadId", ""),
        "from": _header(headers, "From"),
        "to": _header(headers, "To"),
        "subject": _header(headers, "Subject"),
        "date": _header(headers, "Date"),
        "snippet": _snippet_seguro(full.get("snippet", "")),
        "labels": sorted(labels),
        "starred": "STARRED" in labels,
        "important": "IMPORTANT" in labels,
        "unread": "UNREAD" in labels,
        "has_unsubscribe": bool(_header(headers, "List-Unsubscribe")),
    }


def listar_correos(
    service,
    *,
    query: str = "in:inbox",
    max_results: int = 25,
) -> list[dict[str, Any]]:
    """Lista hasta max_results (máx. 500 por llamada interna de página)."""
    return listar_correos_paginado(
        service, query=query, max_results=max_results, page_size=100
    )


def listar_correos_paginado(
    service,
    *,
    query: str = "in:spam",
    max_results: int | None = None,
    page_size: int = 100,
) -> list[dict[str, Any]]:
    """
    Pagina todos los resultados de la query.
    max_results=None → sin límite artificial (cuidado con buzones enormes).
    """
    page_size = max(1, min(int(page_size), 100))
    salida: list[dict[str, Any]] = []
    page_token: str | None = None

    while True:
        kwargs: dict[str, Any] = {
            "userId": "me",
            "q": query,
            "maxResults": page_size,
        }
        if page_token:
            kwargs["pageToken"] = page_token
        resp = service.users().messages().list(**kwargs).execute()
        for item in resp.get("messages", []):
            salida.append(_meta_de_mensaje(service, item["id"]))
            if max_results is not None and len(salida) >= max_results:
                return salida
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return salida


def mover_a_papelera(service, message_id: str) -> None:
    """Trash = recuperable ~30 días. No es delete permanente."""
    service.users().messages().trash(userId="me", id=message_id).execute()


def mover_varios_a_papelera(service, message_ids: list[str]) -> list[str]:
    """Trasha uno a uno; devuelve IDs OK."""
    ok: list[str] = []
    for mid in message_ids:
        mover_a_papelera(service, mid)
        ok.append(mid)
    return ok


def formatear_fecha(raw: str) -> str:
    try:
        return parsedate_to_datetime(raw).isoformat()
    except (TypeError, ValueError, IndexError):
        return raw or ""
