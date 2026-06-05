#!/usr/bin/env python3
"""Classify exercise visual backgrounds by alpha and border color."""

from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "UNBOUND" / "Assets.xcassets"


def classify_border(image: Image.Image) -> str:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    alpha_histogram = alpha.histogram()
    transparent_pixels = alpha_histogram[0]
    points = [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
        (width // 2, 0),
        (width // 2, height - 1),
        (0, height // 2),
        (width - 1, height // 2),
    ]
    samples = [rgba.getpixel(point) for point in points]
    transparent_samples = [sample for sample in samples if sample[3] < 16]
    opaque_samples = [sample for sample in samples if sample[3] > 245]

    if transparent_pixels > width * height * 0.2 and len(transparent_samples) >= 2:
        return "transparent"

    if len(opaque_samples) < 4:
        return "transparent"

    avg = tuple(sum(sample[index] for sample in opaque_samples) // len(opaque_samples) for index in range(3))
    if max(avg) < 32:
        return "opaque-black"
    if min(avg) > 220:
        return "opaque-white"
    if avg[1] > max(avg[0], avg[2]) + 35:
        return "opaque-greenish"
    return f"opaque-rgb({avg[0]},{avg[1]},{avg[2]})"


def alpha_stats(image: Image.Image) -> tuple[int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    histogram = alpha.histogram()
    transparent = histogram[0]
    opaque = histogram[255]
    semitransparent = sum(histogram[1:255])
    return transparent, semitransparent, opaque


def rows(asset_root: Path) -> list[dict[str, str | int]]:
    found: list[dict[str, str | int]] = []
    for imageset in sorted(asset_root.glob("exercise_visual_exercise_*.imageset")):
        asset_name = imageset.stem
        png = imageset / f"{asset_name}.png"
        if not png.exists():
            continue
        image = Image.open(png)
        transparent, semitransparent, opaque = alpha_stats(image)
        found.append(
            {
                "asset": asset_name,
                "classification": classify_border(image),
                "width": image.width,
                "height": image.height,
                "transparent_pixels": transparent,
                "semitransparent_pixels": semitransparent,
                "opaque_pixels": opaque,
            }
        )
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit exercise visual background consistency.")
    parser.add_argument("--asset-root", type=Path, default=ASSET_ROOT)
    parser.add_argument("--csv", type=Path, help="Optional CSV output path")
    parser.add_argument("--only", help="Only print rows with this classification")
    args = parser.parse_args()

    data = rows(args.asset_root)
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(data[0].keys()) if data else [])
            writer.writeheader()
            writer.writerows(data)

    counts = Counter(row["classification"] for row in data)
    print(f"exercise visual assets: {len(data)}")
    for classification, count in sorted(counts.items()):
        print(f"{classification}: {count}")

    for row in data:
        if args.only and row["classification"] != args.only:
            continue
        print(
            f"{row['classification']}\t{row['asset']}\t"
            f"{row['width']}x{row['height']}\t"
            f"alpha0={row['transparent_pixels']}\t"
            f"alpha255={row['opaque_pixels']}"
        )


if __name__ == "__main__":
    main()
