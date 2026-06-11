#!/usr/bin/env python3
"""Generate visual review contact sheets from the UNBOUND asset audit CSV."""

from __future__ import annotations

import argparse
import csv
import html
import math
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_AUDIT = ROOT / "LocalArtifacts" / "asset-quality-audit-20260610" / "asset-quality-audit.csv"
DEFAULT_OUT = ROOT / "LocalArtifacts" / "asset-semantic-review-20260610"


def load_font(size: int) -> ImageFont.ImageFont:
    for candidate in [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttf",
    ]:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def row_title(asset: str) -> str:
    for prefix in [
        "exercise_visual_exercise_",
        "exercise_visual_mobility_",
        "exercise_visual_skill-drill_",
        "exercise_visual_jot_exercise_",
        "exercise_visual_legacy_exercise_",
        "exercise_visual_legacy_skill-drill_",
        "mobility_reference_",
    ]:
        if asset.startswith(prefix):
            return asset.removeprefix(prefix)
    return asset


def draw_wrapped(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, width: int, font: ImageFont.ImageFont, fill: tuple[int, int, int]) -> None:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=font) <= width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    x, y = xy
    for line in lines[:3]:
        draw.text((x, y), line, font=font, fill=fill)
        y += 14


def make_page(rows: list[dict[str, str]], path: Path, title: str, page_index: int, page_count: int) -> None:
    cols = 4
    tile = 240
    label_h = 76
    header_h = 56
    rows_count = math.ceil(len(rows) / cols)
    sheet = Image.new("RGB", (cols * tile, header_h + rows_count * (tile + label_h)), (8, 10, 12))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(18)
    label_font = load_font(12)
    small_font = load_font(10)
    draw.text((14, 14), f"{title} · page {page_index + 1}/{page_count}", fill=(230, 245, 242), font=title_font)
    draw.text((14, 36), "Semantic QA: movement accuracy, avatar consistency, blur/pixelation, matte/halo, apparatus correctness.", fill=(150, 180, 176), font=small_font)

    for index, row in enumerate(rows):
        x = (index % cols) * tile
        y = header_h + (index // cols) * (tile + label_h)
        image = Image.open(ROOT / row["path"]).convert("RGBA")
        preview = Image.new("RGBA", image.size, (5, 8, 10, 255))
        preview.alpha_composite(image)
        preview.thumbnail((tile - 16, tile - 16), Image.Resampling.LANCZOS)
        px = x + (tile - preview.width) // 2
        py = y + (tile - preview.height) // 2
        sheet.paste(preview.convert("RGB"), (px, py))
        draw.rectangle((x + 4, y + 4, x + tile - 5, y + tile - 5), outline=(28, 44, 48), width=1)
        draw_wrapped(draw, (x + 8, y + tile + 6), row_title(row["asset"]), tile - 16, label_font, (230, 245, 242))
        meta = f"{row['kind']} · {row['width']}x{row['height']} · {int(int(row['file_bytes']) / 1024)} KB"
        draw.text((x + 8, y + tile + 52), meta[:42], fill=(96, 230, 224), font=small_font)

    sheet.save(path)


def write_index(pages: list[tuple[str, Path, int]], rows: list[dict[str, str]], path: Path) -> None:
    counts = Counter(row["kind"] for row in rows)
    links = "\n".join(
        f'<li><a href="{html.escape(page.name)}">{html.escape(title)}</a> ({count} assets)</li>'
        for title, page, count in pages
    )
    summary = " · ".join(f"{html.escape(kind)}: {count}" for kind, count in sorted(counts.items()))
    path.write_text(
        f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
body{{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;background:#080a0c;color:#e6f5f2;padding:24px}}
a{{color:#86fff7}} li{{margin:8px 0}} code{{color:#b8cbc7}}
</style></head><body>
<h1>UNBOUND Semantic Asset Review Sheets</h1>
<p>{len(rows)} assets · {summary}</p>
<p>Review these sheets for pose accuracy, pixelation, old-style visuals, character consistency, transparency halos, and apparatus correctness.</p>
<ul>{links}</ul>
</body></html>
"""
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit-csv", type=Path, default=DEFAULT_AUDIT)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--include-fallbacks", action="store_true", help="Include Jot/Legacy duplicate fallback rows.")
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows = [row for row in csv.DictReader(args.audit_csv.open()) if row["exists"] == "True" and row["path"]]
    if not args.include_fallbacks:
        rows = [row for row in rows if row["kind"] not in {"exercise-jot", "exercise-legacy"}]

    groups = [
        ("exercise-current", "Current Exercise And Movement Cutouts"),
        ("mobility-reference", "Mobility Reference Assets"),
        ("skill-icon", "Skill Icon Assets"),
        ("skill-phase", "Skill Phase Cards"),
    ]
    pages: list[tuple[str, Path, int]] = []
    for kind, title in groups:
        kind_rows = [row for row in rows if row["kind"] == kind]
        if not kind_rows:
            continue
        page_size = 16
        page_count = math.ceil(len(kind_rows) / page_size)
        for page_index in range(page_count):
            page_rows = kind_rows[page_index * page_size : (page_index + 1) * page_size]
            filename = f"{kind}-{page_index + 1:03d}.png"
            path = args.out_dir / filename
            make_page(page_rows, path, title, page_index, page_count)
            pages.append((f"{title} {page_index + 1:03d}", path, len(page_rows)))

    write_index(pages, rows, args.out_dir / "index.html")
    print(f"wrote {len(pages)} pages to {args.out_dir}")


if __name__ == "__main__":
    main()
