#!/usr/bin/env python3
"""Create switchable exercise visual asset sets from changed catalog images.

The root exercise_visual_* imagesets remain the compatibility/current set.
Changed working-tree assets are copied to exercise_visual_jot_* names.
Tracked pre-change versions from HEAD are copied to exercise_visual_legacy_* names.
"""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "UNBOUND" / "Assets.xcassets"
JOT_GROUP = ASSET_ROOT / "ExerciseVisualsJot"
LEGACY_GROUP = ASSET_ROOT / "ExerciseVisualsLegacy"
MANIFEST = ROOT / "docs" / "asset-sets" / "exercise-visual-asset-sets.json"


@dataclass(frozen=True)
class AssetChange:
    git_png_path: str
    base_name: str
    png_name: str
    legacy_available: bool


def git_lines(*args: str) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def git_blob(path: str) -> bytes | None:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"HEAD:{path}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def prefixed_name(base_name: str, prefix: str) -> str:
    expected = "exercise_visual_"
    if not base_name.startswith(expected):
        raise ValueError(f"Unexpected exercise visual asset name: {base_name}")
    return f"{expected}{prefix}_{base_name.removeprefix(expected)}"


def changed_png_paths() -> list[str]:
    tracked = git_lines(
        "diff",
        "--name-only",
        "--",
        "UNBOUND/Assets.xcassets/exercise_visual*.imageset/*.png",
    )
    untracked = git_lines(
        "ls-files",
        "--others",
        "--exclude-standard",
        "--",
        "UNBOUND/Assets.xcassets/exercise_visual*.imageset/*.png",
    )
    return sorted(set(tracked + untracked))


def changes() -> list[AssetChange]:
    found: list[AssetChange] = []
    for git_png_path in changed_png_paths():
        png_path = ROOT / git_png_path
        imageset = png_path.parent
        base_name = imageset.name.removesuffix(".imageset")
        legacy_available = git_blob(git_png_path) is not None
        found.append(
            AssetChange(
                git_png_path=git_png_path,
                base_name=base_name,
                png_name=png_path.name,
                legacy_available=legacy_available,
            )
        )
    return found


def contents_json(asset_name: str, source_contents: bytes | None) -> dict:
    if source_contents:
        contents = json.loads(source_contents.decode("utf-8"))
    else:
        contents = {
            "images": [
                {"idiom": "universal", "scale": "1x"},
                {"idiom": "universal", "scale": "2x"},
                {"idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1},
        }

    png_name = f"{asset_name}.png"
    images = contents.setdefault("images", [])
    first_slot = next((image for image in images if image.get("scale") == "1x"), None)
    if first_slot is None:
        first_slot = {"idiom": "universal", "scale": "1x"}
        images.insert(0, first_slot)
    first_slot["filename"] = png_name

    for image in images[1:]:
        if image.get("filename") == png_name:
            image.pop("filename", None)

    contents["info"] = {"author": "xcode", "version": 1}
    return contents


def ensure_group(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )


def write_imageset(
    group: Path,
    asset_name: str,
    png_bytes: bytes,
    source_contents: bytes | None,
) -> None:
    imageset = group / f"{asset_name}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    png_name = f"{asset_name}.png"
    (imageset / png_name).write_bytes(png_bytes)
    (imageset / "Contents.json").write_text(
        json.dumps(contents_json(asset_name, source_contents), indent=2) + "\n"
    )


def main() -> None:
    ensure_group(JOT_GROUP)
    ensure_group(LEGACY_GROUP)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)

    manifest: list[dict[str, object]] = []
    for change in changes():
        current_png_path = ROOT / change.git_png_path
        current_contents_path = current_png_path.parent / "Contents.json"
        current_contents = current_contents_path.read_bytes() if current_contents_path.exists() else None

        jot_name = prefixed_name(change.base_name, "jot")
        write_imageset(JOT_GROUP, jot_name, current_png_path.read_bytes(), current_contents)

        legacy_name = prefixed_name(change.base_name, "legacy")
        legacy_png = git_blob(change.git_png_path)
        legacy_contents = git_blob(
            str(Path(change.git_png_path).parent / "Contents.json")
        )
        if legacy_png is not None:
            write_imageset(LEGACY_GROUP, legacy_name, legacy_png, legacy_contents)

        manifest.append(
            {
                "base": change.base_name,
                "jot": jot_name,
                "legacy": legacy_name if legacy_png is not None else None,
                "legacyAvailable": legacy_png is not None,
                "source": change.git_png_path,
            }
        )

    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {len(manifest)} jot assets")
    print(f"wrote {sum(1 for item in manifest if item['legacyAvailable'])} legacy assets")
    print(f"manifest: {MANIFEST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
