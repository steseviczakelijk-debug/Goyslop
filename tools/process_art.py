"""Turn the raw generated art in assets/raw into game-ready textures in assets/.

Run from the repo root:  python3 tools/process_art.py
"""
import colorsys
from pathlib import Path

import numpy as np
from PIL import Image

RAW = Path("assets/raw")
OUT = Path("assets")


def load(name):
    return Image.open(RAW / name).convert("RGBA")


def clean(im, threshold=60):
    """Drop faint stray pixels and crop to the visible content."""
    a = np.array(im)
    a[a[..., 3] < threshold] = 0
    im = Image.fromarray(a)
    return im.crop(im.getbbox())


def fit(im, width=None, height=None):
    if width:
        size = (width, round(im.height * width / im.width))
    else:
        size = (round(im.width * height / im.height), height)
    return im.resize(size, Image.LANCZOS)


def sprite(src, dst, **size):
    im = fit(clean(load(src)), **size)
    im.save(OUT / dst)
    print(dst, im.size)
    return im


def key_black(im):
    """Make a solid black backdrop transparent, softening the edge it leaves."""
    from PIL import ImageFilter
    a = np.array(im.convert("RGB")).astype(np.float32)
    mx = a.max(axis=2)
    backdrop = Image.fromarray(((mx < 26) * 255).astype(np.uint8))
    near = np.array(backdrop.filter(ImageFilter.MaxFilter(7))) > 0
    alpha = np.where(near, np.clip((mx - 14.0) / 40.0, 0.0, 1.0), 1.0)
    rgb = np.where(near[..., None], np.clip(a / np.maximum(alpha, 0.25)[..., None], 0, 255), a)
    out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out)


def pose_pair(first, second, dst_first, dst_second, height):
    """Two poses of one figure, cropped by the same box so they line up."""
    a = np.array(first)
    b = np.array(second)
    a[a[..., 3] < 60] = 0
    b[b[..., 3] < 60] = 0
    first, second = Image.fromarray(a), Image.fromarray(b)
    box_a, box_b = first.getbbox(), second.getbbox()
    box = (min(box_a[0], box_b[0]), min(box_a[1], box_b[1]), max(box_a[2], box_b[2]), max(box_a[3], box_b[3]))
    for im, dst in ((first, dst_first), (second, dst_second)):
        out = fit(im.crop(box), height=height)
        out.save(OUT / dst)
        print(dst, out.size)


def recolor_blue(im, hue):
    """Shift only the blue cloth to another hue; gold trim and metal stay."""
    a = np.array(im).astype(np.float32) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a[..., :3].max(axis=-1)
    mn = a[..., :3].min(axis=-1)
    blue = (b >= mx - 1e-6) & (mx - mn > 0.25)
    out = a.copy()
    for y, x in zip(*np.nonzero(blue)):
        _, s, v = colorsys.rgb_to_hsv(r[y, x], g[y, x], b[y, x])
        out[y, x, :3] = colorsys.hsv_to_rgb(hue, s, v)
    return Image.fromarray((out * 255).astype(np.uint8))


def main():
    # Units
    pose_pair(load("01_archer.png"), key_black(load("30b_archer_shot.png")), "archer.png", "archer_shot.png", 320)
    pose_pair(load("02_orc.png"), key_black(load("30a_orc_step.png")), "orc.png", "orc_step.png", 256)
    sprite("03_troll.png", "troll.png", height=512)
    sprite("08_arrow.png", "arrow.png", height=192)
    sprite("34_orc_fall.png", "orc_fall.png", height=256)

    # Gates: one shape, three colours
    gate = sprite("04_gate_blue.png", "gate_blue.png", width=512)
    recolor_blue(gate, 0.0).save(OUT / "gate_red.png")
    recolor_blue(gate, 0.78).save(OUT / "gate_purple.png")
    sprite("07_gate_post.png", "gate_post.png", height=384)

    # Bridge floor: keep four whole stone rows so it repeats along the road
    floor = load("09_bridge_floor.png").convert("RGB").crop((0, 188, 1254, 962))
    floor = floor.resize((512, 316), Image.LANCZOS)
    floor.save(OUT / "bridge_floor.png")

    # Ground
    for src, dst in (("11_grass.png", "grass.png"), ("12_water.png", "water.png")):
        load(src).convert("RGB").resize((512, 512), Image.LANCZOS).save(OUT / dst)

    # Scenery
    sprite("13_pine_tree.png", "pine.png", height=512)
    sprite("14_bush.png", "bush.png", height=256)
    sprite("15_rock.png", "rock.png", height=256)
    sprite("16_banner_pole.png", "banner_pole.png", height=512)
    sprite("17_castle.png", "castle.png", width=1024)
    load("18_sky.png").convert("RGB").save(OUT / "sky.png")

    # Effects
    sprite("25_puff.png", "puff.png", height=128)
    sprite("26_spark.png", "spark.png", height=128)
    sheet = load("27_confetti.png")
    atlas = Image.new("RGBA", (96 * 3, 96 * 2), (0, 0, 0, 0))
    for i in range(6):
        col, row = i % 3, i // 3
        cell = sheet.crop((col * 512, row * 512, col * 512 + 512, row * 512 + 512))
        piece = clean(cell, threshold=140)
        piece.thumbnail((88, 88), Image.LANCZOS)
        atlas.paste(piece, (col * 96 + (96 - piece.width) // 2, row * 96 + (96 - piece.height) // 2))
    atlas.save(OUT / "confetti.png")
    sprite("31_rail_post.png", "rail_post.png", height=256)

    # Interface
    sprite("28_menu_panel.png", "ui_menu_panel.png", width=640)
    sprite("29_pause_icon.png", "ui_pause.png", height=96)
    sprite("19_level_banner.png", "ui_level_banner.png", width=1024)
    sprite("20a_progress_bar.png", "ui_progress_bar.png", width=1024)
    sprite("20b_castle_icon.png", "ui_castle_icon.png", height=128)
    sprite("21_counter_badge.png", "ui_badge.png", height=192)
    sprite("22_button.png", "ui_button.png", width=768)
    sprite("23_coin.png", "coin.png", height=128)

    # App icon: full-bleed icon plus Android adaptive layers
    icon = load("24_app_icon.png").convert("RGB")
    icon.resize((512, 512), Image.LANCZOS).save(OUT / "icon.png")
    icon.resize((192, 192), Image.LANCZOS).save(OUT / "icon_192.png")
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.paste(icon.resize((300, 300), Image.LANCZOS), (66, 66))
    fg.save(OUT / "icon_foreground.png")
    Image.new("RGB", (432, 432), (40, 140, 240)).save(OUT / "icon_background.png")


if __name__ == "__main__":
    main()
