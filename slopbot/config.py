"""Config loading: config.yaml for behaviour, environment (.env) for secrets."""
from __future__ import annotations

import os
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DATA = Path(os.environ.get("SLOPBOT_DATA", ROOT / "data"))


def load_env(path: Path = ROOT / ".env") -> None:
    """Minimal .env reader; real environment variables win."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


def load_config(path: str | Path | None = None) -> dict:
    load_env()
    with open(path or ROOT / "config.yaml") as f:
        cfg = yaml.safe_load(f)
    DATA.mkdir(parents=True, exist_ok=True)
    return cfg


def require_env(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise SystemExit(f"{name} is not set. Add it to .env (see .env.example).")
    return value
