"""Write a short-video script with Claude."""
from __future__ import annotations

import anthropic
from pydantic import BaseModel, Field


class Script(BaseModel):
    topic: str = Field(description="3-8 word label for this video's subject, used to avoid repeats")
    lines: list[str] = Field(description="On-screen caption beats in order; the first is the hook")
    caption: str = Field(description="Post caption, without hashtags")
    hashtags: list[str] = Field(description="3-5 hashtags, without the # sign")

    def narration(self) -> str:
        return " ".join(self.lines)

    def post_text(self, always: list[str] | None = None) -> str:
        tags = list(dict.fromkeys([*self.hashtags, *(always or [])]))
        tagline = " ".join("#" + t.lstrip("#").replace(" ", "") for t in tags)
        return f"{self.caption.strip()} {tagline}".strip()[:2200]


SYSTEM = """You write scripts for short vertical videos (about 20-35 seconds) that are shown \
as large on-screen captions, one beat at a time, optionally with a voiceover reading them.

Each beat is a single short sentence or fragment of at most 12 words, because it has to be \
readable in about two seconds on a phone. The first beat is the hook: it must make sense with \
no context and give a concrete reason to keep watching. Aim for 7-11 beats, and end on a beat \
that lands the point rather than asking for follows.

Everything stated as fact must be true and checkable; when you are unsure of a number or a \
date, pick a different angle instead of guessing. Do not give medical, legal or financial \
advice, and do not write about real private individuals."""


def write_script(cfg: dict, avoid_topics: list[str]) -> Script:
    client = anthropic.Anthropic()
    avoid = "\n".join(f"- {t}" for t in avoid_topics) or "(none yet)"
    prompt = (
        f"Account niche: {cfg['niche']}\n"
        f"Tone: {cfg['tone']}\n"
        f"Language: {cfg.get('language', 'English')}\n\n"
        f"Topics already covered, which this video must not repeat or closely resemble:\n{avoid}\n\n"
        "Write the next video."
    )
    response = client.beta.messages.parse(
        model=cfg.get("model", "claude-opus-5-5"),
        max_tokens=16000,
        system=SYSTEM,
        messages=[{"role": "user", "content": prompt}],
        output_config={"effort": "medium"},
        output_format=Script,
        # If a safety classifier declines, the API retries on a fallback model in the same call.
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
    )
    if response.stop_reason == "refusal":
        raise RuntimeError(f"Script generation was declined: {response.stop_details}")
    if response.stop_reason == "max_tokens" or response.parsed_output is None:
        raise RuntimeError(f"Script generation did not complete (stop_reason={response.stop_reason})")
    script = response.parsed_output
    script.lines = [line.strip() for line in script.lines if line.strip()]
    if len(script.lines) < 3:
        raise RuntimeError("Script came back with fewer than 3 beats")
    return script
