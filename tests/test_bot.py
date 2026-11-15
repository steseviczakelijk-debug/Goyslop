import datetime as dt
import subprocess

import pytest

from slopbot import bot, render
from slopbot.generate import Script
from slopbot.store import Store
from slopbot.tiktok import MB, TikTok, chunk_plan

CFG = {
    "schedule": {"posts_per_day": 3, "active_hours": [9, 21], "jitter_minutes": 0},
    "video": {"width": 540, "height": 960, "fps": 30, "font": "Inter", "words_per_second": 2.6},
    "tiktok": {"privacy_level": "SELF_ONLY", "redirect_uri": "http://localhost:8721/callback"},
}


@pytest.mark.parametrize("size", [1, 4 * MB, 10 * MB, 10 * MB + 1, 25 * MB, 199 * MB + 7])
def test_chunk_plan_covers_file_exactly(size):
    chunk_size, count, ranges = chunk_plan(size)
    assert count == len(ranges) == max(size // chunk_size, 1)
    assert ranges[0][0] == 0 and ranges[-1][1] == size - 1
    for (_, prev_last), (first, _) in zip(ranges, ranges[1:]):
        assert first == prev_last + 1
    assert all(last - first + 1 == chunk_size for first, last in ranges[:-1])
    assert ranges[-1][1] - ranges[-1][0] + 1 < 2 * chunk_size


def test_post_text_dedupes_tags_and_caps_length():
    s = Script(topic="t", lines=["a"], caption="x" * 3000, hashtags=["fyp", "#design"])
    assert len(s.post_text(["fyp"])) == 2200
    s.caption = "Hello"
    assert s.post_text(["fyp"]) == "Hello #fyp #design"


def test_schedule_respects_cap_window_and_spacing(tmp_path):
    store = Store(tmp_path / "h.db")
    noon = dt.datetime(2026, 1, 5, 12, 0)
    assert bot.next_slot(CFG, store, now=noon) == noon
    assert bot.next_slot(CFG, store, now=noon.replace(hour=3)) == noon.replace(hour=9)
    assert bot.next_slot(CFG, store, now=noon.replace(hour=22)) == dt.datetime(2026, 1, 6, 9, 0)

    def posted(at):
        pid = store.add("t", "c", "v.mp4")
        store.db.execute("UPDATE posts SET status='posted', created_at=? WHERE id=?", (at.timestamp(), pid))
        store.db.commit()

    posted(noon)
    assert bot.next_slot(CFG, store, now=noon + dt.timedelta(minutes=1)) == noon + dt.timedelta(hours=4)
    posted(noon + dt.timedelta(hours=4))
    posted(noon + dt.timedelta(hours=8))
    assert bot.next_slot(CFG, store, now=noon + dt.timedelta(hours=8, minutes=1)) == dt.datetime(2026, 1, 6, 9, 0)


def test_render_produces_vertical_h264(tmp_path):
    lines = ["Manhole covers are round.", "A round lid can't fall in.", "That is the whole trick."]
    out = tmp_path / "v.mp4"
    duration = render.render(lines, CFG, out, seed=1)
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=codec_name,width,height:format=duration",
         "-of", "default=nw=1", str(out)], capture_output=True, text=True, check=True).stdout
    assert "codec_name=h264" in probe and "codec_name=aac" in probe
    assert "width=540" in probe and "height=960" in probe
    assert duration == pytest.approx(float(probe.split("duration=")[1]), abs=0.2)


class FakeResponse:
    def __init__(self, status=200, body=None):
        self.status_code, self._body, self.text = status, body or {}, ""

    def json(self):
        return self._body


def test_post_video_sends_ranges_and_ai_label(tmp_path, monkeypatch):
    video = tmp_path / "v.mp4"
    video.write_bytes(b"x" * (25 * MB))
    tk = TikTok(CFG, token_path=tmp_path / "tok.json")
    monkeypatch.setattr(tk, "access_token", lambda: "tok")
    calls, puts = [], []

    def post(url, headers=None, json=None, timeout=None):
        calls.append((url, json))
        if "creator_info" in url:
            data = {"privacy_level_options": ["SELF_ONLY"], "max_video_post_duration_sec": 600}
        elif "init" in url:
            data = {"publish_id": "p1", "upload_url": "https://upload.example/x"}
        else:
            data = {"status": "PUBLISH_COMPLETE"}
        return FakeResponse(body={"data": data, "error": {"code": "ok"}})

    def put(url, data=None, headers=None, timeout=None):
        puts.append((headers["Content-Range"], len(data)))
        return FakeResponse(status=201 if len(puts) == 2 else 206)

    monkeypatch.setattr(tk.http, "post", post)
    monkeypatch.setattr(tk.http, "put", put)

    assert tk.post_video(video, "caption", 20) == "p1"
    init = next(body for url, body in calls if "init" in url)
    assert init["post_info"]["is_aigc"] is True
    assert init["source_info"] == {"source": "FILE_UPLOAD", "video_size": 25 * MB, "chunk_size": 10 * MB, "total_chunk_count": 2}
    assert puts == [(f"bytes 0-{10 * MB - 1}/{25 * MB}", 10 * MB), (f"bytes {10 * MB}-{25 * MB - 1}/{25 * MB}", 15 * MB)]


def test_render_uses_gameplay_footage_when_present(tmp_path):
    clips = tmp_path / "clips"
    clips.mkdir()
    # 2-second widescreen clip, shorter than the video, so looping and cropping are both exercised.
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=s=640x360:r=30:d=2",
                    "-pix_fmt", "yuv420p", str(clips / "a.mp4")], check=True)
    cfg = {**CFG, "video": {**CFG["video"], "footage_dir": str(clips)}}
    out = tmp_path / "v.mp4"
    duration = render.render(["One two three.", "Four five six.", "Seven eight nine."], cfg, out, seed=1)
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=width,height:format=duration",
         "-of", "default=nw=1", str(out)], capture_output=True, text=True, check=True).stdout
    assert "width=540" in probe and "height=960" in probe
    assert float(probe.split("duration=")[1]) == pytest.approx(duration, abs=0.2)


def test_game_brief_replaces_niche_only_when_game_is_set():
    from slopbot.generate import subject
    assert subject({"niche": "facts", "game": {"name": ""}}) == "Account niche: facts"
    brief = subject({"niche": "facts", "game": {"name": "Moss Runner", "features": ["grappling hook"]}})
    assert "Moss Runner" in brief and "- grappling hook" in brief and "facts" not in brief
