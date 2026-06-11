#!/usr/bin/env python3
"""Convert generated checkerboard-background cutouts to true alpha PNGs.

Local image generation can return a visually transparent checkerboard baked into
RGB pixels. This helper removes only light, low-saturation background pixels
connected to the image edge, then fits the remaining cutout into a square PNG.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def is_checker_pixel(pixel: tuple[int, int, int, int], light: int, chroma: int) -> bool:
    r, g, b, _ = pixel
    return min(r, g, b) >= light and max(r, g, b) - min(r, g, b) <= chroma


def checker_mask(
    image: Image.Image,
    light: int,
    chroma: int,
    component_min_area: int,
) -> bytearray:
    width, height = image.size
    pixels = image.load()
    mask = bytearray(width * height)
    checker = bytearray(width * height)
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    for y in range(height):
        for x in range(width):
            if is_checker_pixel(pixels[x, y], light, chroma):
                checker[y * width + x] = 1

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if mask[index]:
            return
        if checker[index]:
            mask[index] = 1
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                enqueue(nx, ny)

    if component_min_area > 0:
        for y in range(height):
            for x in range(width):
                start = y * width + x
                if visited[start] or mask[start] or not checker[start]:
                    continue
                component: list[tuple[int, int]] = []
                visited[start] = 1
                queue.append((x, y))
                while queue:
                    cx, cy = queue.popleft()
                    component.append((cx, cy))
                    for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                        if not (0 <= nx < width and 0 <= ny < height):
                            continue
                        index = ny * width + nx
                        if visited[index] or mask[index] or not checker[index]:
                            continue
                        visited[index] = 1
                        queue.append((nx, ny))
                if len(component) >= component_min_area:
                    for cx, cy in component:
                        mask[cy * width + cx] = 1

    return mask


def key_checkerboard(
    image: Image.Image,
    light: int,
    chroma: int,
    component_min_area: int,
) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    mask = checker_mask(rgba, light, chroma, component_min_area)

    for y in range(height):
        for x in range(width):
            if mask[y * width + x]:
                r, g, b, _ = pixels[x, y]
                pixels[x, y] = (r, g, b, 0)

    return rgba


def fit_square(image: Image.Image, size: int, margin: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    left = max(0, bbox[0] - margin)
    top = max(0, bbox[1] - margin)
    right = min(image.width, bbox[2] + margin)
    bottom = min(image.height, bbox[3] + margin)
    cropped = image.crop((left, top, right, bottom))

    scale = min(size / cropped.width, size / cropped.height)
    new_size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(new_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x = (size - resized.width) // 2
    y = (size - resized.height) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--margin", type=int, default=28)
    parser.add_argument("--light", type=int, default=216)
    parser.add_argument("--chroma", type=int, default=16)
    parser.add_argument(
        "--component-min-area",
        type=int,
        default=10000,
        help="Also remove trapped checkerboard components at least this large.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    image = Image.open(args.input)
    keyed = key_checkerboard(image, args.light, args.chroma, args.component_min_area)
    fitted = fit_square(keyed, args.size, args.margin)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fitted.save(args.output)


if __name__ == "__main__":
    main()
