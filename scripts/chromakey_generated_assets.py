#!/usr/bin/env python3
"""Convert generated green-screen exercise visuals into transparent imagesets.

Expected workflow:
1. Generate each image with a flat chroma-green background.
2. Name the generated PNG after the target asset, for example:
   exercise_visual_exercise_pushup.png
3. Run this script on the PNG or directory to remove the green and install it
   into the matching .imageset.

The keying rule intentionally targets saturated green only so cyan/teal rim
lights survive.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "UNBOUND" / "Assets.xcassets"
DEFAULT_OUT = ROOT / "build" / "generated-transparent-assets"


def parse_hex_color(value: str) -> tuple[int, int, int]:
    raw = value.removeprefix("#")
    if len(raw) != 6:
        raise argparse.ArgumentTypeError("Expected color in #RRGGBB format")
    try:
        return tuple(int(raw[index : index + 2], 16) for index in (0, 2, 4))  # type: ignore[return-value]
    except ValueError as error:
        raise argparse.ArgumentTypeError("Expected color in #RRGGBB format") from error


def generated_pngs(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    return sorted(item for item in path.glob("*.png") if item.is_file())


def target_group(asset_name: str, asset_root: Path) -> Path:
    if asset_name.startswith("exercise_visual_jot_"):
        return asset_root / "ExerciseVisualsJot"
    if asset_name.startswith("exercise_visual_legacy_"):
        return asset_root / "ExerciseVisualsLegacy"
    return asset_root


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


def key_alpha(
    source: Image.Image,
    key_color: tuple[int, int, int],
    tolerance: int,
    feather: int,
    min_green: int,
    despill: bool,
) -> Image.Image:
    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    kr, kg, kb = key_color
    feather = max(feather, 1)

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            distance = abs(r - kr) + abs(g - kg) + abs(b - kb)
            green_dominance = g - max(r, b)
            is_green_candidate = g >= min_green and green_dominance >= 45

            if is_green_candidate and distance <= tolerance:
                pixels[x, y] = (r, g, b, 0)
                continue

            if is_green_candidate and distance <= tolerance + feather:
                keep = (distance - tolerance) / feather
                new_alpha = int(a * keep)
                if despill:
                    g = min(g, max(r, b) + 24)
                pixels[x, y] = (r, g, b, new_alpha)
                continue

            if despill and is_green_candidate and distance <= tolerance + feather * 2:
                g = min(g, max(r, b) + 36)
                pixels[x, y] = (r, g, b, a)

    return image


def resize_square(image: Image.Image, size: int | None) -> Image.Image:
    if size is None:
        return image
    if image.width != image.height:
        raise ValueError(f"Expected a square image before resize, got {image.size}")
    if image.width == size:
        return image
    return image.resize((size, size), Image.Resampling.LANCZOS)


def write_imageset(asset_root: Path, asset_name: str, image: Image.Image) -> Path:
    group = target_group(asset_name, asset_root)
    group.mkdir(parents=True, exist_ok=True)
    if group != asset_root:
        group_contents = group / "Contents.json"
        if not group_contents.exists():
            group_contents.write_text(
                json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
            )

    imageset = group / f"{asset_name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    image.save(imageset / f"{asset_name}.png")
    contents_path = imageset / "Contents.json"
    if not contents_path.exists():
        contents_path.write_text(json.dumps(imageset_contents(asset_name), indent=2) + "\n")
    return imageset


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove chroma-green backgrounds from generated UNBOUND assets."
    )
    parser.add_argument("source", type=Path, help="Generated PNG file or directory of PNGs")
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=ASSET_ROOT,
        help="Assets.xcassets root used when --install is set",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUT,
        help="Directory for transparent PNG output when not installing",
    )
    parser.add_argument(
        "--key",
        type=parse_hex_color,
        default=parse_hex_color("#00FF00"),
        help="Chroma key color, default #00FF00",
    )
    parser.add_argument("--tolerance", type=int, default=80)
    parser.add_argument("--feather", type=int, default=80)
    parser.add_argument("--min-green", type=int, default=160)
    parser.add_argument(
        "--size",
        type=int,
        default=None,
        help="Resize square output to this pixel size before writing",
    )
    parser.add_argument("--no-despill", action="store_true")
    parser.add_argument(
        "--install",
        action="store_true",
        help="Write directly into matching .imageset directories",
    )
    args = parser.parse_args()

    pngs = generated_pngs(args.source)
    if not pngs:
        raise SystemExit(f"No PNG files found at {args.source}")

    if not args.install:
        args.out_dir.mkdir(parents=True, exist_ok=True)

    for png in pngs:
        asset_name = png.stem
        transparent = key_alpha(
            Image.open(png),
            args.key,
            args.tolerance,
            args.feather,
            args.min_green,
            despill=not args.no_despill,
        )
        transparent = resize_square(transparent, args.size)

        if args.install:
            destination = write_imageset(args.asset_root, asset_name, transparent)
            print(f"installed {asset_name} -> {destination}")
        else:
            destination = args.out_dir / f"{asset_name}.png"
            transparent.save(destination)
            print(f"wrote {destination}")


if __name__ == "__main__":
    main()
