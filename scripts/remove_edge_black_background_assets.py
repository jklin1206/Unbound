#!/usr/bin/env python3
"""Remove edge-connected black backgrounds from exercise visual assets.

This is intentionally narrower than a global "black to alpha" keyer. It only
removes dark pixels connected to the canvas border so black clothing, shoes, and
equipment survive when they are separated from the background.
"""

from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "UNBOUND" / "Assets.xcassets"
DEFAULT_OUT = ROOT / "build" / "edge-black-transparent-assets"


def imageset_contents(asset_name: str) -> dict:
    return {
        "images": [
            {
                "idiom": "universal",
                "filename": f"{asset_name}.png",
                "scale": "1x",
            },
            {
                "idiom": "universal",
                "scale": "2x",
            },
            {
                "idiom": "universal",
                "scale": "3x",
            },
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }


def normalize_asset_name(value: str) -> str:
    stem = Path(value).stem
    if stem.endswith(".imageset"):
        stem = stem.removesuffix(".imageset")
    if stem.startswith("exercise_visual_exercise_"):
        return stem
    return f"exercise_visual_exercise_{stem}"


def resolve_png(asset_root: Path, asset_name: str) -> Path:
    png = asset_root / f"{asset_name}.imageset" / f"{asset_name}.png"
    if not png.exists():
        raise FileNotFoundError(f"Missing asset PNG: {png}")
    return png


def is_dark_background_pixel(pixel: tuple[int, int, int, int], threshold: int) -> bool:
    r, g, b, a = pixel
    if a == 0:
        return False
    return max(r, g, b) <= threshold


def edge_connected_dark_mask(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    total = width * height
    seen = bytearray(total)
    queue: deque[tuple[int, int]] = deque()

    def index(x: int, y: int) -> int:
        return y * width + x

    def add_if_background(x: int, y: int) -> None:
        idx = index(x, y)
        if seen[idx]:
            return
        if is_dark_background_pixel(pixels[x, y], threshold):
            seen[idx] = 255
            queue.append((x, y))

    for x in range(width):
        add_if_background(x, 0)
        add_if_background(x, height - 1)
    for y in range(height):
        add_if_background(0, y)
        add_if_background(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            add_if_background(x - 1, y)
        if x < width - 1:
            add_if_background(x + 1, y)
        if y > 0:
            add_if_background(x, y - 1)
        if y < height - 1:
            add_if_background(x, y + 1)

    return Image.frombytes("L", (width, height), bytes(seen))


def remove_edge_black_background(
    source: Image.Image,
    threshold: int,
    feather: float,
) -> Image.Image:
    rgba = source.convert("RGBA")
    mask = edge_connected_dark_mask(rgba, threshold)
    if feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))

    pixels = rgba.load()
    mask_pixels = mask.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            background_amount = mask_pixels[x, y]
            if background_amount == 0:
                continue
            new_alpha = max(0, min(255, int(a * (255 - background_amount) / 255)))
            pixels[x, y] = (r, g, b, new_alpha)

    return rgba


def write_imageset(asset_root: Path, asset_name: str, image: Image.Image) -> Path:
    imageset = asset_root / f"{asset_name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    image.save(imageset / f"{asset_name}.png")
    contents_path = imageset / "Contents.json"
    if not contents_path.exists():
        contents_path.write_text(json.dumps(imageset_contents(asset_name), indent=2) + "\n")
    return imageset


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Remove edge-connected black backgrounds from UNBOUND exercise assets."
    )
    parser.add_argument(
        "assets",
        nargs="+",
        help="Asset slugs, full asset names, .imageset paths, or PNG paths.",
    )
    parser.add_argument("--asset-root", type=Path, default=ASSET_ROOT)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--threshold", type=int, default=36)
    parser.add_argument("--feather", type=float, default=1.2)
    parser.add_argument("--install", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.install:
        args.out_dir.mkdir(parents=True, exist_ok=True)

    for value in args.assets:
        path = Path(value)
        if path.exists() and path.is_file():
            source_path = path
            asset_name = normalize_asset_name(path.name)
        else:
            asset_name = normalize_asset_name(value)
            source_path = resolve_png(args.asset_root, asset_name)

        transparent = remove_edge_black_background(
            Image.open(source_path),
            threshold=args.threshold,
            feather=args.feather,
        )

        if args.install:
            destination = write_imageset(args.asset_root, asset_name, transparent)
            print(f"installed {asset_name} -> {destination}")
        else:
            destination = args.out_dir / f"{asset_name}.png"
            transparent.save(destination)
            print(f"wrote {destination}")


if __name__ == "__main__":
    main()
