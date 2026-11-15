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
    sprite("01_archer.png", "archer.png", height=320)
    sprite("02_orc.png", "orc.png", height=256)
    sprite("03_troll.png", "troll.png", height=512)
    sprite("08_arrow.png", "arrow.png", height=192)

    # Gates: one shape, three colours
    gate = sprite("04_gate_blue.png", "gate_blue.png", width=512)
    recolor_blue(gate, 0.0).save(OUT / "gate_red.png")
    recolor_blue(gate, 0.78).save(OUT / "gate_purple.png")
    sprite("07_gate_post.png", "gate_post.png", height=384)

    # Bridge floor: keep four whole stone rows so it repeats along the road
    floor = load("09_bridge_floor.png").convert("RGB").crop((0, 188, 1254, 962))
    floor = floor.resize((512, 316), Image.LANCZOS)
    floor.save(OUT / "bridge_floor.png")

    # Railing: one post plus one beam span, so segments chain end to end
    rail = clean(load("10_railing.png"))
    rail = fit(rail.crop((0, 0, 1385, rail.height)), height=256)
    rail.save(OUT / "railing.png")
    print("railing.png", rail.size)

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

    # Interface
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
