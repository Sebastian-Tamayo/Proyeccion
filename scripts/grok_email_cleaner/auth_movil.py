"""OAuth Gmail usable desde el móvil (device code flow).

1) Creas un cliente OAuth tipo "TVs and Limited Input devices" en Google Cloud.
2) Pones GMAIL_CLIENT_ID y GMAIL_CLIENT_SECRET en el entorno.
3) Ejecutas auth_movil.py → te sale un código + enlace.
4) En el móvil abres el enlace, pegas el código, eliges sbsesebeese@gmail.com.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import requests
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

load_dotenv(ROOT / ".env")

DEVICE_CODE_URL = "https://oauth2.googleapis.com/device/code"
TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPES = "https://www.googleapis.com/auth/gmail.modify"
TOKEN_PATH = Path(
    os.getenv("GMAIL_TOKEN_PATH", str(ROOT / "scripts/grok_email_cleaner/token.json"))
)
CUENTA = os.getenv("GMAIL_EXPECT_ACCOUNT", "sbsesebeese@gmail.com")


def _client_creds() -> tuple[str, str]:
    cid = os.getenv("GMAIL_CLIENT_ID", "").strip()
    secret = os.getenv("GMAIL_CLIENT_SECRET", "").strip()
    if not cid or not secret:
        raise RuntimeError(
            "Faltan GMAIL_CLIENT_ID / GMAIL_CLIENT_SECRET.\n"
            "Créalos en Google Cloud (tipo: TVs and Limited Input devices)\n"
            "y añádelos como secretos del Cloud Agent / .env"
        )
    return cid, secret


def iniciar_device_flow() -> dict:
    cid, _secret = _client_creds()
    resp = requests.post(
        DEVICE_CODE_URL,
        data={"client_id": cid, "scope": SCOPES},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def esperar_token(device_code: str, interval: int, expires_in: int) -> dict:
    cid, secret = _client_creds()
    deadline = time.time() + max(30, int(expires_in) - 5)
    sleep_for = max(3, int(interval))
    while time.time() < deadline:
        time.sleep(sleep_for)
        resp = requests.post(
            TOKEN_URL,
            data={
                "client_id": cid,
                "client_secret": secret,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            },
            timeout=30,
        )
        data = resp.json()
        if "access_token" in data:
            return data
        err = data.get("error")
        if err == "authorization_pending":
            print(".", end="", flush=True)
            continue
        if err == "slow_down":
            sleep_for += 2
            print("+", end="", flush=True)
            continue
        if err == "access_denied":
            raise RuntimeError("Acceso denegado en Google.")
        if err == "expired_token":
            raise RuntimeError("El código expiró. Vuelve a ejecutar auth_movil.py")
        raise RuntimeError(f"Error OAuth: {data}")
    raise RuntimeError("Tiempo agotado esperando autorización en el móvil.")


def guardar_token(token_resp: dict) -> Path:
    payload = {
        "token": token_resp.get("access_token"),
        "refresh_token": token_resp.get("refresh_token"),
        "token_uri": TOKEN_URL,
        "client_id": os.getenv("GMAIL_CLIENT_ID", "").strip(),
        "client_secret": os.getenv("GMAIL_CLIENT_SECRET", "").strip(),
        "scopes": [SCOPES],
    }
    if "expiry" not in payload and token_resp.get("expires_in"):
        # google.oauth2.credentials acepta expiry ISO; lo dejamos opcional
        pass
    TOKEN_PATH.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return TOKEN_PATH


def verificar_cuenta() -> str:
    from scripts.grok_email_cleaner.gmail_client import autenticar, email_perfil

    service = autenticar(token_path=TOKEN_PATH)
    return email_perfil(service)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    print("=== Auth Gmail desde el MÓVIL (device code) ===\n")
    data = iniciar_device_flow()
    url = data.get("verification_url") or "https://www.google.com/device"
    code = data["user_code"]
    print("1) En el móvil abre:")
    print(f"   {url}")
    print("2) Introduce este código:")
    print(f"\n   >>>  {code}  <<<\n")
    print(f"3) Elige la cuenta: {CUENTA}")
    print("4) Pulsa Allow / Permitir")
    print("\nEsperando que autorices", end="", flush=True)

    token_resp = esperar_token(
        data["device_code"],
        interval=int(data.get("interval", 5)),
        expires_in=int(data.get("expires_in", 1800)),
    )
    print("\nOK: token recibido.")
    ruta = guardar_token(token_resp)
    print(f"Guardado: {ruta}")

    try:
        email = verificar_cuenta()
        print(f"Cuenta conectada: {email}")
        if email.lower() != CUENTA.lower():
            print(
                f"AVISO: se esperaba {CUENTA}. "
                f"Borra {TOKEN_PATH} y repite con la cuenta correcta."
            )
            return 2
    except Exception as exc:  # noqa: BLE001
        print(f"Token guardado, pero no pude verificar perfil aún: {exc}")
    print("\nListo. Ya puedes limpiar spam con limpiar_correos.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
