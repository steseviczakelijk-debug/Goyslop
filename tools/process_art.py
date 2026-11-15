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


def key_checkerboard(im):
    """Remove a painted-in white/grey 'transparency' checkerboard.

    Only pale, colourless pixels that connect to the image border are removed,
    so highlights inside the figure survive.
    """
    from PIL import ImageFilter
    a = np.array(im.convert("RGB")).astype(np.int16)
    pale = (a.max(axis=2) - a.min(axis=2) < 16) & (a.min(axis=2) > 222)
    reached = np.zeros_like(pale)
    reached[0, :], reached[-1, :], reached[:, 0], reached[:, -1] = pale[0, :], pale[-1, :], pale[:, 0], pale[:, -1]
    while True:
        grown = np.array(Image.fromarray((reached * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))) > 0
        grown &= pale
        if grown.sum() == reached.sum():
            break
        reached = grown
    # Eat two more pixels so no pale fringe is left around the figure.
    edge = np.array(Image.fromarray((reached * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    out = np.dstack([a, np.where(edge, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out)


def pose_sheet(poses, dst, height, pad=6):
    """Several poses of one figure side by side in one picture.

    All poses are cropped by the same box so the figure does not jump when the
    game switches between them. Returns how much taller the shared box is than
    the first pose alone, so the game can keep the figure the same size.
    """
    cleaned = []
    for im in poses:
        a = np.array(im)
        a[a[..., 3] < 60] = 0
        cleaned.append(Image.fromarray(a))
    boxes = [im.getbbox() for im in cleaned]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    cells = [fit(im.crop(box), height=height) for im in cleaned]
    w = cells[0].width + pad * 2
    sheet = Image.new("RGBA", (w * len(cells), height), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sheet.paste(cell, (i * w + pad, 0))
    sheet.save(OUT / dst)
    grow = (box[3] - box[1]) / (boxes[0][3] - boxes[0][1])
    print(dst, sheet.size, "poses", len(cells), "height x%.3f" % grow)


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
    # Pose order matters: the game refers to poses by their position.
    pose_sheet([load("01_archer.png"), key_black(load("30b_archer_shot.png")), load("40a_archer_step.png"),
                load("40b_archer_cheer.png")], "archer.png", 320)
    pose_sheet([load("02_orc.png"), key_black(load("30a_orc_step.png"))], "orc.png", 256)
    pose_sheet([load("03_troll.png"), key_checkerboard(load("36_troll_step.png")), load("41_troll_hurt.png")],
               "troll.png", 512)
    sprite("35a_troll_windup.png", "troll_windup.png", height=512)
    sprite("35b_troll_smash.png", "troll_smash.png", height=512)
    sprite("08_arrow.png", "arrow.png", height=192)
    sprite("34_orc_fall.png", "orc_fall.png", height=256)
    sprite("40c_archer_fall.png", "archer_fall.png", height=256)

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
    ring = np.array(load("37_warning_ring.png"))
    ring[ring[..., 3] < 70] = 0  # drop the ragged outer glow
    ring = Image.fromarray(ring)
    ring = ring.crop(ring.getbbox())
    side = max(ring.size)
    square = Image.new("RGBA", (side, side), (255, 20, 10, 0))
    square.paste(ring, ((side - ring.width) // 2, (side - ring.height) // 2))
    square.resize((256, 256), Image.LANCZOS).save(OUT / "warning_ring.png")
    sheet = load("27_confetti.png")
    atlas = Image.new("RGBA", (96 * 3, 96 * 2), (0, 0, 0, 0))
    for i in range(6):
        col, row = i % 3, i // 3
        cell = sheet.crop((col * 512, row * 512, col * 512 + 512, row * 512 + 512))
        piece = clean(cell, threshold=140)
        piece.thumbnail((88, 88), Image.LANCZOS)
        atlas.paste(piece, (col * 96 + (96 - piece.width) // 2, row * 96 + (96 - piece.height) // 2))
    atlas.save(OUT / "confetti.png")

    # Bridge wall: the stone strip without its white margins, and the capstones.
    side = load("42a_wall_side.png").convert("RGB").crop((0, 221, 1774, 664))
    side.resize((1024, 256), Image.LANCZOS).save(OUT / "wall_side.png")
    load("42b_wall_top.png").convert("RGB").resize((128, 384), Image.LANCZOS).save(OUT / "wall_top.png")

    # Interface
    sprite("28_menu_panel.png", "ui_menu_panel.png", width=640)
    sprite("29_pause_icon.png", "ui_pause.png", height=96)
    sprite("38_progress_fill.png", "ui_progress_fill.png", height=48)
    sprite("39a_victory_banner.png", "ui_title_victory.png", width=768)
    if (RAW / "39b_defeat_banner.png").exists():
        sprite("39b_defeat_banner.png", "ui_title_defeat.png", width=768)
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
