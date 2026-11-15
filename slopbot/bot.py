"""Pipeline (script -> voice -> video -> post) and the posting loop."""
from __future__ import annotations

import datetime as dt
import json
import random
import time
from pathlib import Path

from . import generate, render, tts
from .config import DATA
from .store import Store
from .tiktok import TikTok


def log(message: str) -> None:
    print(f"[{dt.datetime.now():%Y-%m-%d %H:%M:%S}] {message}", flush=True)


def make_video(cfg: dict, store: Store, script: generate.Script | None = None) -> tuple[int, Path, generate.Script, float]:
    script = script or generate.write_script(cfg, store.recent_topics())
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = DATA / "videos" / f"{stamp}.mp4"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.with_suffix(".json").write_text(script.model_dump_json(indent=2))
    voice = tts.synthesize(script.narration(), cfg, out.with_suffix(".mp3"))
    duration = render.render(script.lines, cfg, out, voice=voice, seed=hash(stamp))
    post_id = store.add(script.topic, script.post_text(cfg.get("hashtags_always")), str(out))
    log(f"Rendered {out} ({duration:.1f}s): {script.topic}")
    return post_id, out, script, duration


def post_once(cfg: dict, store: Store, script: generate.Script | None = None) -> None:
    post_id, video, script, duration = make_video(cfg, store, script)
    try:
        publish_id = TikTok(cfg).post_video(video, script.post_text(cfg.get("hashtags_always")), duration)
    except Exception as e:
        store.mark(post_id, "failed", detail=str(e))
        raise
    store.mark(post_id, "posted", publish_id=publish_id)
    log(f"Posted ({cfg['tiktok']['privacy_level']}), publish_id {publish_id}")


def next_slot(cfg: dict, store: Store, now: dt.datetime | None = None) -> dt.datetime:
    """When the next post may go out, respecting the daily cap, active hours and spacing."""
    sched = cfg["schedule"]
    now = now or dt.datetime.now()
    start_h, end_h = sched["active_hours"]
    per_day = max(int(sched["posts_per_day"]), 1)
    gap = dt.timedelta(hours=(end_h - start_h) / per_day)

    midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    window_start = midnight + dt.timedelta(hours=start_h)
    window_end = midnight + dt.timedelta(hours=end_h)
    tomorrow = window_start + dt.timedelta(days=1)

    if store.posted_since(midnight.timestamp()) >= per_day:
        return tomorrow
    candidate = max(now, window_start)
    last = store.last_posted_at()
    if last:
        candidate = max(candidate, dt.datetime.fromtimestamp(last) + gap)
    return candidate if candidate < window_end else tomorrow


def run_forever(cfg: dict) -> None:
    store = Store()
    jitter = cfg["schedule"].get("jitter_minutes", 0) * 60
    failures = 0
    while True:
        slot = next_slot(cfg, store) + dt.timedelta(seconds=random.uniform(0, jitter))
        wait = (slot - dt.datetime.now()).total_seconds()
        if wait > 0:
            log(f"Next post at {slot:%Y-%m-%d %H:%M}")
            time.sleep(wait)
        try:
            post_once(cfg, store)
            failures = 0
        except Exception as e:
            failures += 1
            backoff = min(60 * 2 ** failures, 3600)
            log(f"Post failed ({e}); retrying in {backoff // 60} min")
            time.sleep(backoff)


def load_script(path: str) -> generate.Script:
    return generate.Script(**json.loads(Path(path).read_text()))
