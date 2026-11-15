"""Render caption beats over an animated gradient into a 9:16 MP4 with ffmpeg."""
from __future__ import annotations

import random
import subprocess
from pathlib import Path

PALETTES = [
    ("0x0f172a", "0x7c3aed", "0xdb2777"),
    ("0x052e2b", "0x0d9488", "0x2563eb"),
    ("0x1c1917", "0xea580c", "0xbe123c"),
    ("0x0b1026", "0x1d4ed8", "0x06b6d4"),
    ("0x14110f", "0xa16207", "0x15803d"),
]


FOOTAGE_TYPES = {".mp4", ".mov", ".mkv", ".webm", ".m4v"}


def pick_footage(cfg: dict, rng: random.Random) -> Path | None:
    folder = cfg["video"].get("footage_dir")
    if not folder:
        return None
    root = Path(folder) if Path(folder).is_absolute() else Path(__file__).resolve().parent.parent / folder
    clips = sorted(p for p in root.glob("*") if p.suffix.lower() in FOOTAGE_TYPES) if root.is_dir() else []
    return rng.choice(clips) if clips else None


def audio_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        check=True, capture_output=True, text=True,
    )
    return float(out.stdout.strip())


def beat_timings(lines: list[str], wps: float, total: float | None = None) -> list[tuple[float, float]]:
    """(start, end) per beat. Paced by word count; scaled to `total` when a voiceover sets the length."""
    weights = [max(len(line.split()), 3) for line in lines]
    if total is None:
        durations = [max(w / wps, 1.4) for w in weights]
    else:
        durations = [total * w / sum(weights) for w in weights]
    timings, t = [], 0.0
    for d in durations:
        timings.append((t, t + d))
        t += d
    return timings


def _ts(seconds: float) -> str:
    cs = round(seconds * 100)
    return f"{cs // 360000}:{cs // 6000 % 60:02d}:{cs // 100 % 60:02d}.{cs % 100:02d}"


def build_ass(lines: list[str], timings: list[tuple[float, float]], cfg: dict) -> str:
    v = cfg["video"]
    size = round(v["height"] * 0.05)
    head = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {v['width']}
PlayResY: {v['height']}
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Beat,{v.get('font', 'Inter')},{size},&H00FFFFFF,&H00FFFFFF,&H00101010,&H80000000,-1,0,0,0,100,100,0,0,1,{max(size // 14, 3)},2,5,{v['width'] // 10},{v['width'] // 10},0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    events = []
    for line, (start, end) in zip(lines, timings):
        text = line.replace("\\", "").replace("{", "(").replace("}", ")").replace("\n", " ")
        pop = r"{\fad(90,60)\fscx92\fscy92\t(0,140,\fscx100\fscy100)}"
        events.append(f"Dialogue: 0,{_ts(start)},{_ts(end)},Beat,,0,0,0,,{pop}{text}")
    return head + "\n".join(events) + "\n"


def render(lines: list[str], cfg: dict, out: Path, voice: Path | None = None, seed: int | None = None) -> float:
    """Write the MP4 to `out` and return its duration in seconds."""
    v = cfg["video"]
    total = audio_duration(voice) + 0.4 if voice else None
    timings = beat_timings(lines, v.get("words_per_second", 2.6), total)
    duration = timings[-1][1]

    out.parent.mkdir(parents=True, exist_ok=True)
    ass = out.with_suffix(".ass")
    ass.write_text(build_ass(lines, timings, cfg), encoding="utf-8")

    rng = random.Random(seed)
    clip = pick_footage(cfg, rng)
    if clip:
        # Start at a random point; loop if the clip is shorter than the video.
        start = rng.uniform(0, max(audio_duration(clip) - duration, 0))
        video_in = ["-stream_loop", "-1", "-ss", f"{start:.2f}", "-i", str(clip.resolve())]
        dim = float(v.get("footage_dim", 0.15))
        prepare = (
            f"scale={v['width']}:{v['height']}:force_original_aspect_ratio=increase,"
            f"crop={v['width']}:{v['height']},fps={v['fps']},eq=brightness={-dim:.2f},"
        )
    else:
        c0, c1, c2 = rng.choice(PALETTES)
        video_in = ["-f", "lavfi", "-i", (
            f"gradients=s={v['width']}x{v['height']}:r={v['fps']}:d={duration:.3f}"
            f":c0={c0}:c1={c1}:c2={c2}:nb_colors=3:speed=0.008"
        )]
        prepare = ""
    audio = ["-i", str(voice.resolve())] if voice else ["-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo"]
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        *video_in,
        *audio,
        "-map", "0:v:0", "-map", "1:a:0",
        # Relative filename + cwd avoids ffmpeg filter-path escaping.
        "-vf", f"{prepare}subtitles={ass.name},format=yuv420p",
        "-t", f"{duration:.3f}",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-c:a", "aac", "-b:a", "128k", "-ar", "44100",
        "-movflags", "+faststart",
        out.name,
    ]
    subprocess.run(cmd, check=True, cwd=out.parent)
    return duration
