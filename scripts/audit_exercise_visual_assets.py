#!/usr/bin/env python3
"""Report exercise_visual asset sets that are not covered by known resolver paths.

This is a conservative audit, not an automatic delete tool. The app resolves
many exercise images dynamically with UIImage(named:), so plain grep will
produce false positives.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "UNBOUND"
ASSET_ROOT = APP / "Assets.xcassets"


def normalized(value: str) -> str:
    value = value.strip().lower().replace("\u2013", "-").replace("\u2014", "-")
    return " ".join(part.lower() for part in re.split(r"[^0-9a-zA-Z]+", value) if part)


def slug(value: str) -> str:
    return normalized(value).replace(" ", "-")


def sanitized(value: str) -> str:
    return "".join(ch.lower() if (ch.isalnum() or ch == "-") else "_" for ch in value)


def add(candidates: dict[str, set[str]], name: str, reason: str) -> None:
    if name:
        candidates.setdefault(name, set()).add(reason)


def quoted_strings(text: str) -> list[str]:
    return re.findall(r'"([^"]+)"', text)


def scan_exact_swift_strings(candidates: dict[str, set[str]]) -> None:
    for path in APP.rglob("*.swift"):
        text = path.read_text(errors="ignore")
        rel = path.relative_to(ROOT)
        for asset in re.findall(r'"(exercise_visual_[^"]+)"', text):
            add(candidates, asset, f"exact Swift string in {rel}")


def scan_exercise_catalog(candidates: dict[str, set[str]]) -> None:
    path = APP / "Models/ExerciseCatalog.swift"
    text = path.read_text(errors="ignore")
    for name in re.findall(r"\.init\(name:\s*\"([^\"]+)\"", text):
        movement_id = "exercise." + slug(name)
        raw_name = movement_id.replace("exercise.", "").replace("exercise_", "")
        add(candidates, "exercise_visual_" + sanitized(movement_id), "ExerciseVisualAsset direct exercise id")
        add(candidates, "exercise_visual_exercise_" + slug(raw_name), "ExerciseVisualAsset exercise slug")
        add(
            candidates,
            "exercise_visual_exercise_" + normalized(raw_name).replace(" ", "_"),
            "ExerciseVisualAsset exercise underscored fallback",
        )


def scan_cardio_types(candidates: dict[str, set[str]]) -> None:
    path = APP / "Models/CardioSession.swift"
    text = path.read_text(errors="ignore")
    match = re.search(r"enum CardioType[^{]+\{(.+?)\n\}", text, re.S)
    if not match:
        return

    for line in match.group(1).splitlines():
        if "case " not in line:
            continue
        case_text = re.sub(r"//.*", "", line).split("case", 1)[1]
        for raw_case in case_text.split(","):
            case_name = raw_case.strip().split()[0] if raw_case.strip() else ""
            if case_name:
                add(candidates, "exercise_visual_" + sanitized("cardio." + case_name), "CardioType movement id")


def scan_movement_catalog_helpers(candidates: dict[str, set[str]]) -> None:
    path = APP / "Models/MovementCatalog.swift"
    text = path.read_text(errors="ignore")
    helper_patterns = [
        ("carry.", r"carry\(\s*\"([^\"]+)\"", "MovementCatalog carry definition"),
        ("mobility.", r"mobility\(\s*\"([^\"]+)\"", "MovementCatalog mobility definition"),
        ("skill-drill.", r"skillDrill\(\s*\"([^\"]+)\"", "MovementCatalog skill drill definition"),
    ]

    for prefix, pattern, reason in helper_patterns:
        for identifier in re.findall(pattern, text):
            add(candidates, "exercise_visual_" + sanitized(prefix + identifier), reason)


def scan_skill_tree(candidates: dict[str, set[str]]) -> None:
    paths = [APP / "Models/SkillTreeContent.swift"]
    tiers = APP / "Models/SkillTreeContent/Tiers"
    if tiers.exists():
        paths.extend(sorted(tiers.glob("*.swift")))

    for path in paths:
        text = path.read_text(errors="ignore")
        rel = path.relative_to(ROOT)

        for skill_id in re.findall(r'id:\s*"([a-z]+\.[^"]+)"', text):
            add(candidates, "exercise_visual_skill_" + sanitized(skill_id), f"skill id in {rel}")
            add(candidates, "exercise_visual_exercise_" + slug(skill_id.split(".")[-1]), f"skill id slug in {rel}")

        for skill_id in re.findall(r'"([a-z]+\.[a-z0-9][a-z0-9._-]+)"', text):
            add(candidates, "exercise_visual_skill_" + sanitized(skill_id), f"possible skill id in {rel}")
            add(candidates, "exercise_visual_exercise_" + slug(skill_id.split(".")[-1]), f"possible skill slug in {rel}")

        for literal in quoted_strings(text):
            literal_slug = slug(literal)
            if literal_slug:
                add(candidates, "exercise_visual_exercise_" + literal_slug, f"quoted skill/tree slug in {rel}")


def scan_skill_and_routine_resolvers(candidates: dict[str, set[str]]) -> None:
    paths = [
        APP / "Views/Home/SkillDetailView.swift",
        APP / "Views/Home/Components/FormPhaseSlideshow.swift",
        APP / "Models/RoutineStep.swift",
    ]

    for path in paths:
        if not path.exists():
            continue
        text = path.read_text(errors="ignore")
        rel = path.relative_to(ROOT)
        for literal in quoted_strings(text):
            literal_slug = slug(literal)
            if literal_slug:
                add(candidates, "exercise_visual_exercise_" + literal_slug, f"quoted resolver slug in {rel}")


def collect_candidates() -> dict[str, set[str]]:
    candidates: dict[str, set[str]] = {}
    scan_exact_swift_strings(candidates)
    scan_exercise_catalog(candidates)
    scan_cardio_types(candidates)
    scan_movement_catalog_helpers(candidates)
    scan_skill_tree(candidates)
    scan_skill_and_routine_resolvers(candidates)
    return candidates


def collect_assets() -> list[str]:
    return sorted(path.name.removesuffix(".imageset") for path in ASSET_ROOT.glob("exercise_visual_*.imageset"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="Exit non-zero when orphan candidates are found.")
    args = parser.parse_args()

    assets = collect_assets()
    candidates = collect_candidates()
    orphan_candidates = [asset for asset in assets if asset not in candidates]

    print(f"exercise_visual asset sets: {len(assets)}")
    print(f"covered by known resolver candidates: {len(assets) - len(orphan_candidates)}")

    if orphan_candidates:
        print("\nLikely orphan candidates:")
        for asset in orphan_candidates:
            print(f"- UNBOUND/Assets.xcassets/{asset}.imageset")
        print("\nReview exact names and semantic slugs before deleting.")
        return 1 if args.strict else 0

    print("No likely orphan exercise visuals found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
