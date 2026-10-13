#!/usr/bin/env python3
"""Draws the app icon (a slashed bell on a soft light tile) and writes Resources/AppIcon.icns.

Everything is drawn from basic shapes at 4x size and scaled down for smooth edges. The tile
follows the macOS icon grid: an 824px rounded square centred on a 1024px canvas.
Requires Pillow (pip3 install pillow).
"""
import math
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE, TILE, RADIUS = 1024, 824, 185
SS = 4  # supersampling factor
INK = (22, 23, 28, 255)


def tile() -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    o = (SIZE - TILE) // 2
    rect = (o, o, o + TILE, o + TILE)

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((o, o + 14, o + TILE, o + TILE + 14), RADIUS, fill=(40, 50, 80, 70))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))

    grad = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(grad)
    top, bottom = (252, 253, 255), (226, 230, 239)
    for y in range(SIZE):
        t = min(max((y - o) / TILE, 0), 1)
        draw.line([(0, y), (SIZE, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(rect, RADIUS, fill=255)
    canvas.paste(grad, (0, 0), mask)

    rim = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(rect, RADIUS, outline=(255, 255, 255, 210), width=3)
    canvas.alpha_composite(rim)
    return canvas


def thick_line(draw: ImageDraw.ImageDraw, a, b, width: float, fill: int) -> None:
    """Line with round caps."""
    draw.line([a, b], fill=fill, width=round(width))
    r = width / 2
    for x, y in (a, b):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def glyph_mask() -> Image.Image:
    """Bell with a diagonal slash, as an anti-aliased alpha mask (1024px)."""
    n = SIZE * SS
    s = lambda v: v * SS  # noqa: E731 - design units are 1024px canvas pixels
    cx = 512
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)

    # Bell body: a dome that flares out towards the rim.
    dome_top, dome_center, flare_end = 330, 468, 620
    r_dome, r_flare = 138, 196
    left, right = [], []
    for i in range(200 + 1):
        y = dome_top + (flare_end - dome_top) * i / 200
        if y <= dome_center:
            w = math.sqrt(max(r_dome ** 2 - (y - dome_center) ** 2, 0))
        else:
            t = (y - dome_center) / (flare_end - dome_center)
            w = r_dome + (r_flare - r_dome) * t ** 2.2
        left.append((s(cx - w), s(y)))
        right.append((s(cx + w), s(y)))
    d.polygon(left + right[::-1], fill=255)

    # Rim, knob and clapper.
    d.rounded_rectangle((s(cx - 212), s(604), s(cx + 212), s(648)), s(22), fill=255)
    d.ellipse((s(cx - 30), s(296), s(cx + 30), s(356)), fill=255)
    d.pieslice((s(cx - 52), s(626), s(cx + 52), s(730)), 0, 180, fill=255)

    # Slash: cut a wide gap through the bell, then draw the slash inside it.
    a, b = (s(326), s(716)), (s(698), s(288))
    thick_line(d, a, b, s(40 + 2 * 20), 0)
    thick_line(d, a, b, s(40), 255)

    return mask.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    icon = tile()
    ink = Image.new("RGBA", (SIZE, SIZE), INK)
    icon.paste(ink, (0, 0), glyph_mask())
    icon.save(os.path.join(ROOT, "Resources/AppIcon.png"))
    icon.save(os.path.join(ROOT, "docs/icon.png"))

    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.mkdir(iconset)
        for size in (16, 32, 128, 256, 512):
            icon.resize((size, size), Image.LANCZOS).save(f"{iconset}/icon_{size}x{size}.png")
            icon.resize((size * 2, size * 2), Image.LANCZOS).save(f"{iconset}/icon_{size}x{size}@2x.png")
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(ROOT, "Resources/AppIcon.icns")],
                       check=True)
    print("Wrote Resources/AppIcon.icns")


if __name__ == "__main__":
    main()
