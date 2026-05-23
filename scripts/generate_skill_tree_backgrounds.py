#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "UNBOUND" / "Assets.xcassets" / "Cosmetics"
SIZE = (1080, 1920)


SKINS = {
    "violet": {
        "bg": ("#090713", "#17112B"),
        "primary": "#9B5CFF",
        "secondary": "#16A3B8",
        "impact": "#FF5F7A",
        "motif": "arcane",
    },
    "graphite": {
        "bg": ("#05070A", "#111827"),
        "primary": "#94A3B8",
        "secondary": "#334155",
        "impact": "#E2E8F0",
        "motif": "tactical",
    },
    "ember": {
        "bg": ("#100604", "#2A0E08"),
        "primary": "#FF7A3D",
        "secondary": "#7F1D1D",
        "impact": "#FFB86B",
        "motif": "thermal",
    },
    "jade": {
        "bg": ("#03120D", "#05251B"),
        "primary": "#55D487",
        "secondary": "#0F766E",
        "impact": "#B7F7C8",
        "motif": "glass",
    },
    "frost": {
        "bg": ("#03101A", "#082B45"),
        "primary": "#67E8F9",
        "secondary": "#1E3A8A",
        "impact": "#CFFAFE",
        "motif": "cryo",
    },
    "gold": {
        "bg": ("#120B03", "#2A1B05"),
        "primary": "#FFC857",
        "secondary": "#B45309",
        "impact": "#FFF4D1",
        "motif": "relic",
    },
    "void": {
        "bg": ("#05030B", "#18122B"),
        "primary": "#D946EF",
        "secondary": "#8B5CF6",
        "impact": "#F5D0FE",
        "motif": "eclipse",
    },
    "aurora": {
        "bg": ("#031313", "#11102A"),
        "primary": "#5EEAD4",
        "secondary": "#7C3AED",
        "impact": "#F0ABFC",
        "motif": "aurora",
    },
    "holographic": {
        "bg": ("#06111A", "#160A26"),
        "primary": "#B5F3FE",
        "secondary": "#D8B4FE",
        "impact": "#F5A4FF",
        "motif": "prism",
    },
    "ascendant": {
        "bg": ("#090806", "#241B08"),
        "primary": "#FFF3B0",
        "secondary": "#FFC857",
        "impact": "#FFFFFF",
        "motif": "apex",
    },
}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def add_rgba(base: Image.Image, overlay: Image.Image) -> None:
    base.alpha_composite(overlay)


def gradient(bg_top: str, bg_bottom: str) -> Image.Image:
    w, h = SIZE
    top = hex_to_rgb(bg_top)
    bottom = hex_to_rgb(bg_bottom)
    img = Image.new("RGBA", SIZE)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = mix(top, bottom, t)
        for x in range(w):
            vignette = 1.0 - 0.32 * (abs(x - w / 2) / (w / 2)) ** 1.8
            px[x, y] = (int(c[0] * vignette), int(c[1] * vignette), int(c[2] * vignette), 255)
    return img


def add_noise(img: Image.Image, seed: int) -> None:
    random.seed(seed)
    w, h = SIZE
    noise = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    px = noise.load()
    for y in range(h):
        for x in range(w):
            n = random.randint(0, 18)
            px[x, y] = (255, 255, 255, n)
    add_rgba(img, noise.filter(ImageFilter.GaussianBlur(0.35)))


def glow(img: Image.Image, center: tuple[int, int], color: str, radius: int, alpha: int) -> None:
    w, h = SIZE
    rgb = hex_to_rgb(color)
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    px = layer.load()
    cx, cy = center
    for y in range(max(0, cy - radius), min(h, cy + radius)):
        for x in range(max(0, cx - radius), min(w, cx + radius)):
            d = math.dist((x, y), center) / radius
            if d <= 1:
                a = int(alpha * (1 - d) ** 2)
                px[x, y] = (*rgb, a)
    add_rgba(img, layer.filter(ImageFilter.GaussianBlur(24)))


def draw_hex_grid(draw: ImageDraw.ImageDraw, color: str, alpha: int, offset: int = 0) -> None:
    rgb = hex_to_rgb(color)
    r = 72
    step_x = r * 1.5
    step_y = math.sqrt(3) * r
    y = -r + offset
    row = 0
    while y < SIZE[1] + r:
        x = -r + (row % 2) * step_x / 2
        while x < SIZE[0] + r:
            pts = []
            for i in range(6):
                a = math.radians(60 * i + 30)
                pts.append((x + r * math.cos(a), y + r * math.sin(a)))
            draw.line(pts + [pts[0]], fill=(*rgb, alpha), width=2)
            x += step_x
        y += step_y
        row += 1


def draw_rank_spine(draw: ImageDraw.ImageDraw, primary: str, impact: str) -> None:
    p = hex_to_rgb(primary)
    q = hex_to_rgb(impact)
    xs = [170, 330, 500, 700, 885]
    ys = [260, 430, 620, 840, 1110, 1390, 1640]
    points = []
    for i, y in enumerate(ys):
        x = xs[i % len(xs)] + int(math.sin(i * 1.7) * 40)
        points.append((x, y))
    for i in range(len(points) - 1):
        tint = p if i < len(points) - 2 else q
        draw.line([points[i], points[i + 1]], fill=(*tint, 72), width=5)
    for i, point in enumerate(points):
        tint = q if i == len(points) - 1 else p
        x, y = point
        poly = []
        for j in range(6):
            a = math.radians(60 * j + 30)
            poly.append((x + 28 * math.cos(a), y + 28 * math.sin(a)))
        draw.polygon(poly, outline=(*tint, 145), fill=(*tint, 20))


def draw_motif(img: Image.Image, skin: str, cfg: dict[str, str]) -> None:
    primary = cfg["primary"]
    secondary = cfg["secondary"]
    impact = cfg["impact"]
    motif = cfg["motif"]
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    draw_hex_grid(draw, secondary, 24 if skin != "graphite" else 18, offset=0)
    draw_rank_spine(draw, primary, impact)

    p = hex_to_rgb(primary)
    s = hex_to_rgb(secondary)
    i = hex_to_rgb(impact)

    if motif in {"arcane", "prism", "aurora"}:
        for band in range(6):
            y = 250 + band * 230
            draw.arc((80, y - 210, 1000, y + 420), 196, 342, fill=(*p, 28 + band * 4), width=4)
            draw.arc((170, y - 140, 920, y + 330), 204, 332, fill=(*s, 22), width=3)

    if motif == "tactical":
        for x in range(80, 1080, 160):
            draw.line((x, 120, x + 120, 1800), fill=(*p, 18), width=1)
        for y in range(180, 1840, 180):
            draw.line((70, y, 1010, y + 35), fill=(*p, 20), width=1)

    if motif == "thermal":
        for y in range(220, 1780, 170):
            draw.line((90, y, 980, y + random.randint(-38, 38)), fill=(*i, 34), width=8)
            draw.line((150, y + 42, 920, y + random.randint(-20, 60)), fill=(*p, 25), width=3)

    if motif == "glass":
        for k in range(8):
            x = 120 + k * 125
            draw.polygon([(x, 170), (x + 90, 980), (x - 35, 1810)], outline=(*p, 22), fill=(*s, 10))

    if motif == "cryo":
        for k in range(16):
            x = random.randint(70, 1010)
            y = random.randint(160, 1780)
            draw.line((x - 70, y, x + 70, y), fill=(*i, 32), width=2)
            draw.line((x, y - 70, x, y + 70), fill=(*i, 32), width=2)
            draw.line((x - 44, y - 44, x + 44, y + 44), fill=(*p, 24), width=1)

    if motif == "relic":
        for r in [180, 270, 360, 450]:
            draw.ellipse((540 - r, 960 - r, 540 + r, 960 + r), outline=(*p, 28), width=4)
        for a in range(0, 360, 30):
            x = 540 + math.cos(math.radians(a)) * 450
            y = 960 + math.sin(math.radians(a)) * 450
            draw.line((540, 960, x, y), fill=(*s, 18), width=2)

    if motif == "eclipse":
        draw.ellipse((210, 520, 870, 1180), outline=(*p, 58), width=10)
        draw.ellipse((275, 585, 805, 1115), outline=(*s, 40), width=4)
        draw.ellipse((350, 660, 730, 1040), fill=(0, 0, 0, 72))

    if motif == "apex":
        for a in range(0, 360, 18):
            x = 540 + math.cos(math.radians(a)) * 760
            y = 820 + math.sin(math.radians(a)) * 760
            draw.line((540, 820, x, y), fill=(*i, 18), width=3)
        draw.polygon([(540, 180), (700, 740), (540, 1080), (380, 740)], outline=(*p, 80), fill=(*p, 18))

    add_rgba(img, layer.filter(ImageFilter.GaussianBlur(0.15)))


def finish(img: Image.Image, cfg: dict[str, str], seed: int) -> Image.Image:
    random.seed(seed)
    glow(img, (200, 250), cfg["primary"], 520, 110)
    glow(img, (900, 650), cfg["secondary"], 620, 90)
    glow(img, (560, 1540), cfg["impact"], 520, 74)

    shade = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    px = shade.load()
    w, h = SIZE
    for y in range(h):
        for x in range(w):
            top_fade = max(0, (y - h * 0.10) / (h * 0.90))
            edge = (abs(x - w / 2) / (w / 2)) ** 2
            a = int(105 * top_fade + 85 * edge)
            px[x, y] = (0, 0, 0, min(180, a))
    add_rgba(img, shade)
    add_noise(img, seed)
    return img


def write_imageset(name: str, img: Image.Image) -> None:
    asset_name = f"skill_tree_bg_{name}"
    out_dir = ASSET_ROOT / f"{asset_name}.imageset"
    out_dir.mkdir(parents=True, exist_ok=True)
    img.save(out_dir / f"{asset_name}.png")
    (out_dir / "Contents.json").write_text(
        json.dumps(
            {
                "images": [{"filename": f"{asset_name}.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n"
    )


def main() -> None:
    for index, (name, cfg) in enumerate(SKINS.items()):
        random.seed(4100 + index)
        img = gradient(cfg["bg"][0], cfg["bg"][1])
        draw_motif(img, name, cfg)
        img = finish(img, cfg, 7300 + index)
        write_imageset(name, img)


if __name__ == "__main__":
    main()
