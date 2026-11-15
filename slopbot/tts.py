"""Optional voiceover. Returns None when no provider is configured."""
from __future__ import annotations

from pathlib import Path

import requests

from .config import require_env


def synthesize(text: str, cfg: dict, out: Path) -> Path | None:
    voice = cfg.get("voice", {})
    provider = voice.get("provider", "none")
    if provider == "none":
        return None
    if provider != "elevenlabs":
        raise SystemExit(f"Unknown voice provider: {provider}")
    r = requests.post(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice['voice_id']}",
        headers={"xi-api-key": require_env("ELEVENLABS_API_KEY")},
        json={"text": text, "model_id": voice.get("model_id", "eleven_multilingual_v2")},
        timeout=120,
    )
    r.raise_for_status()
    out.write_bytes(r.content)
    return out
