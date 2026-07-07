#!/usr/bin/env python3
"""
kilo_login.py — Kilo AI free-tier authentication helper.

Usage (CLI):
    python3 kilo_login.py            # interactive device flow if no token
    python3 kilo_login.py --status   # print current token state

Important env vars (set by this script or externally):
    LLM_PROVIDER=kilo
    KILO_API_URL=https://api.kilo.ai/api/gateway
    KILO_API_KEY=...
    LLM_MODEL=kilo-auto/free
"""

from __future__ import annotations

import argparse
import os
import time
from pathlib import Path

import requests

KILO_API_BASE = "https://api.kilo.ai/api/gateway"
ENV_FILE_PATH = Path.home() / ".kilo.env"


def _require_field(payload: dict, name: str) -> str:
    value = payload.get(name) or os.environ.get(name)
    if not value:
        raise ValueError(f"Missing required field: {name}")
    return value


def _write_env_file(env_path: Path, api_key: str | None = None) -> None:
    env_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Kilo CLI authentication",
        "LLM_PROVIDER=kilo",
        f"KILO_API_URL={KILO_API_BASE}",
        "LLM_MODEL=kilo-auto/free",
    ]
    if api_key:
        lines.append(f"KILO_API_KEY={api_key}")
    env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _read_env_file(path: Path = ENV_FILE_PATH) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.exists():
        return data
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key.strip()] = value.strip().strip("'\"")
    return data


def env_file_exists(path: Path = ENV_FILE_PATH) -> bool:
    return path.exists()


def login(
    base_url: str = KILO_API_BASE, env_path: Path = ENV_FILE_PATH, api_key: str | None = None
) -> str:
    if not api_key:
        api_key = _prompt_api_key()
    _write_env_file(env_path, api_key=api_key)
    os.environ["KILO_API_KEY"] = api_key
    os.environ["LLM_PROVIDER"] = "kilo"
    os.environ["KILO_API_URL"] = base_url
    os.environ["LLM_MODEL"] = "kilo-auto/free"
    return api_key


def test_auth(base_url: str = KILO_API_BASE, api_key: str | None = None) -> bool:
    if not api_key:
        api_key = os.environ.get("KILO_API_KEY") or _read_env_file().get("KILO_API_KEY")
    if not api_key:
        return False

    try:
        resp = requests.get(
            f"{base_url.rstrip('/')}/status",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=15,
        )
        return resp.status_code == 200
    except requests.RequestException:
        return False


def _prompt_api_key() -> str:
    api_key = input("Cole seu Kilo API key: ").strip()
    if not api_key:
        raise SystemExit("API key vazia. Abortando.")
    return api_key


def device_authorization(
    base_url: str = KILO_API_BASE,
    client_id: str = "kilo-cli",
    timeout: float = 30.0,
) -> dict:
    if not base_url.rstrip("/"):
        raise ValueError("base_url cannot be empty")

    resp = requests.post(
        f"{base_url.rstrip('/')}/oauth/device_authorization",
        json={"client_id": client_id, "scope": "openid profile offline_access"},
        timeout=timeout,
        headers={"Accept": "application/json", "Content-Type": "application/json"},
    )
    resp.raise_for_status()
    body = resp.json()
    required = ("device_code", "user_code", "verification_uri", "expires_in", "interval")
    missing = [k for k in required if k not in body]
    if missing:
        raise ValueError(f"Missing keys from device authorization: {missing}")
    return body


def poll_for_token(
    base_url: str,
    device_code: str,
    client_id: str = "kilo-cli",
    timeout: int = 600,
    poll_interval: float = 5.0,
) -> dict | None:
    url = f"{base_url.rstrip('/')}/oauth/token"
    start = time.monotonic()
    delay = poll_interval
    while time.monotonic() - start < timeout:
        try:
            resp = requests.post(
                url,
                data={
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "device_code": device_code,
                    "client_id": client_id,
                },
                headers={"Accept": "application/json"},
                timeout=15,
            )
        except requests.RequestException:
            time.sleep(delay)
            continue

        body = resp.json()
        if resp.status_code == 200 and "access_token" in body:
            return body

        error = body.get("error", "")
        if error == "slow_down":
            delay = max(1.0, min(5.0, delay - 0.5))
            time.sleep(delay)
            continue

        authorization_pending = error == "authorization_pending"
        expired = error == "expired_token"
        access_denied = error == "access_denied"

        if expired or access_denied:
            return None

        if not authorization_pending:
            time.sleep(delay)

        time.sleep(delay)
    return None


def cli() -> int:
    parser = argparse.ArgumentParser(description="Kilo free login helper")
    parser.add_argument("--status", action="store_true", help="check current token state")
    args = parser.parse_args()

    if args.status:
        loaded = _read_env_file()
        key = loaded.get("KILO_API_KEY")
        ok = test_auth(api_key=key) if key else False
        print(f"token_found={bool(key)} token_valid={ok}")
        return 0 if ok else 1

    if env_file_exists() and _read_env_file().get("KILO_API_KEY"):
        if test_auth():
            print("Login ja ativo.")
            return 0
        print("Token salvo parece invalido. Vou pedir um novo.")

    api_key = _prompt_api_key()
    _write_env_file(ENV_FILE_PATH, api_key=api_key)
    os.environ["KILO_API_KEY"] = api_key
    os.environ["LLM_PROVIDER"] = "kilo"
    os.environ["KILO_API_URL"] = KILO_API_BASE
    os.environ["LLM_MODEL"] = "kilo-auto/free"
    print("Login ok. API key salva em ~/.kilo.env")
    return 0


if __name__ == "__main__":
    raise SystemExit(cli())
