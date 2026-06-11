#!/usr/bin/env python3
"""Create the research-backed semantic review queue for UNBOUND movement assets.

The structural audit answers "is the PNG technically healthy?"  This manifest
answers "does the visual teach the right movement?" and keeps the queue stable
enough to split across agents.
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_AUDIT = ROOT / "LocalArtifacts" / "asset-quality-audit-20260610" / "asset-quality-audit.csv"
DEFAULT_OUT = ROOT / "LocalArtifacts" / "asset-semantic-review-20260610"


EXERCISE_PREFIXES = [
    "exercise_visual_exercise_",
    "exercise_visual_mobility_",
    "exercise_visual_skill-drill_",
    "exercise_visual_jot_exercise_",
    "exercise_visual_legacy_exercise_",
    "exercise_visual_legacy_skill-drill_",
    "mobility_reference_",
]

STYLE_LOCK = (
    "UNBOUND anime/webtoon male athlete, sharp messy black hair, visible low-detail face, "
    "lean calisthenics build, black sleeveless top, black pants, black shoes, wrist wraps, "
    "cyan/teal rim or motion accent, no purple, no UI/logos/text."
)


@dataclass(frozen=True)
class ManifestItem:
    review_id: str
    lane: str
    batch: str
    asset: str
    display_name: str
    kind: str
    path: str
    current_status: str
    research_query: str
    required_visual_standard: str
    reference_sources: str = ""
    semantic_findings: str = ""
    priority: str = ""
    generation_prompt: str = ""
    candidate_paths: str = ""
    decision: str = "pending"
    integrated_paths: str = ""


def display_name(asset: str) -> str:
    value = asset
    for prefix in EXERCISE_PREFIXES:
        if value.startswith(prefix):
            value = value.removeprefix(prefix)
            break
    return value.replace("_", " ").replace("-", " ").title()


def search_query(name: str) -> str:
    return f"{name} exercise proper form key positions reference"


def batch_for(name: str, lane: str) -> str:
    initial = next((ch for ch in name.lower() if ch.isalpha()), "misc")
    if lane == "skill-phase":
        return f"skill-{initial}"
    if lane == "mobility-reference":
        return f"mobility-{initial}"
    return f"exercise-{initial}"


def standard_for(name: str, lane: str) -> str:
    if lane == "skill-phase":
        return (
            "Four phase cards must show a coherent progression with the same camera, apparatus, "
            "character identity, and body direction. Each phase needs one clear coaching idea, "
            "not just a different crop of the same pose."
        )
    if lane == "mobility-reference":
        return (
            "Reference state must show the target joint position and start/end distinction when relevant. "
            "Use plain dark background or transparent catalog treatment according to existing asset surface."
        )
    return (
        "Single transparent 1024x1024 catalog cutout must read as the named movement without labels. "
        "Pose, apparatus, grip, stance, range, and load must match the exercise name."
    )


def asset_lane(kind: str) -> str | None:
    if kind == "exercise-current":
        return "exercise-cutout"
    if kind == "mobility-reference":
        return "mobility-reference"
    if kind == "skill-phase":
        return "skill-phase"
    return None


def load_audit_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"Missing audit CSV: {path}")
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def phase_prefix(asset: str) -> str:
    return re.sub(r"_phase[1-4]$", "", asset)


def manifest_items(rows: list[dict[str, str]]) -> list[ManifestItem]:
    items: list[ManifestItem] = []

    for row in rows:
        lane = asset_lane(row["kind"])
        if lane != "exercise-cutout":
            continue
        name = display_name(row["asset"])
        items.append(
            ManifestItem(
                review_id=f"exercise:{row['asset']}",
                lane=lane,
                batch=batch_for(name, lane),
                asset=row["asset"],
                display_name=name,
                kind=row["kind"],
                path=row["path"],
                current_status="pending_semantic_research",
                research_query=search_query(name),
                required_visual_standard=standard_for(name, lane),
                generation_prompt=(
                    f"Create a 1024x1024 transparent-background UNBOUND exercise cutout for {name}. "
                    f"Show the key recognizable position of the movement. Character lock: {STYLE_LOCK}"
                ),
            )
        )

    mobility_rows = [row for row in rows if asset_lane(row["kind"]) == "mobility-reference"]
    for row in mobility_rows:
        name = display_name(row["asset"])
        items.append(
            ManifestItem(
                review_id=f"mobility:{row['asset']}",
                lane="mobility-reference",
                batch=batch_for(name, "mobility-reference"),
                asset=row["asset"],
                display_name=name,
                kind=row["kind"],
                path=row["path"],
                current_status="pending_semantic_research",
                research_query=search_query(name),
                required_visual_standard=standard_for(name, "mobility-reference"),
                generation_prompt=(
                    f"Create a UNBOUND mobility reference asset for {name}. "
                    f"Show the target stretch position clearly. Character lock: {STYLE_LOCK}"
                ),
            )
        )

    phase_rows = [row for row in rows if asset_lane(row["kind"]) == "skill-phase"]
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in phase_rows:
        grouped[phase_prefix(row["asset"])].append(row)
    for prefix, group in sorted(grouped.items()):
        name = display_name(prefix)
        phases = sorted(row["asset"] for row in group)
        items.append(
            ManifestItem(
                review_id=f"skill:{prefix}",
                lane="skill-phase",
                batch=batch_for(name, "skill-phase"),
                asset=prefix,
                display_name=name,
                kind="skill-phase-set",
                path=";".join(row["path"] for row in sorted(group, key=lambda item: item["asset"])),
                current_status="pending_semantic_research",
                research_query=f"{name} calisthenics skill progression phases form reference",
                required_visual_standard=standard_for(name, "skill-phase"),
                semantic_findings=f"Phases present: {', '.join(phases)}",
                generation_prompt=(
                    f"Create a 2x2 UNBOUND form breakdown for {name}. "
                    f"Each panel must teach a distinct phase with the same camera and apparatus. "
                    f"Character lock: {STYLE_LOCK}"
                ),
            )
        )

    return sorted(items, key=lambda item: (item.lane, item.batch, item.display_name, item.asset))


def write_csv(items: list[ManifestItem], path: Path) -> None:
    fields = list(ManifestItem.__dataclass_fields__.keys())
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for item in items:
            writer.writerow({field: getattr(item, field) for field in fields})


def write_markdown(items: list[ManifestItem], path: Path) -> None:
    lane_counts: dict[str, int] = defaultdict(int)
    batch_counts: dict[str, int] = defaultdict(int)
    for item in items:
        lane_counts[item.lane] += 1
        batch_counts[item.batch] += 1

    lines: list[str] = []
    lines.append("# UNBOUND Semantic Asset Manifest")
    lines.append("")
    lines.append("Generated: 2026-06-10")
    lines.append("")
    lines.append("## Purpose")
    lines.append("")
    lines.append(
        "This is the research-backed queue for verifying whether every movement visual actually "
        "matches the intended exercise or skill phase. Structural PNG health is tracked separately."
    )
    lines.append("")
    lines.append("## Counts")
    lines.append("")
    for lane, count in sorted(lane_counts.items()):
        lines.append(f"- {lane}: {count}")
    lines.append("")
    lines.append("## Batches")
    lines.append("")
    for batch, count in sorted(batch_counts.items()):
        lines.append(f"- {batch}: {count}")
    lines.append("")
    lines.append("## Review Contract")
    lines.append("")
    lines.append("- Research the movement first from reputable form sources before judging or regenerating.")
    lines.append("- Reject clean art if pose, grip, apparatus, stance, load, or range is wrong.")
    lines.append("- Catalog cutouts must remain 1024x1024 PNGs with real alpha.")
    lines.append("- Skill phase cards must remain 625x625 dark cards and teach distinct phase cues.")
    lines.append("- Use local image generation only; do not use Higgsfield.")
    lines.append("- Archive raw candidates, processed alpha outputs, accepted paths, and rejection reasons.")
    lines.append("")
    lines.append("## Initial Queue Sample")
    lines.append("")
    lines.append("| Lane | Batch | Asset | Query | Decision |")
    lines.append("|---|---|---|---|---|")
    for item in items[:80]:
        lines.append(
            f"| {item.lane} | {item.batch} | `{item.asset}` | {item.research_query} | {item.decision} |"
        )
    lines.append("")
    lines.append(f"Full CSV: `{path.with_suffix('.csv').relative_to(ROOT)}`")
    path.write_text("\n".join(lines) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit-csv", type=Path, default=DEFAULT_AUDIT)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    items = manifest_items(load_audit_rows(args.audit_csv))
    csv_path = args.out_dir / "semantic-asset-manifest.csv"
    md_path = args.out_dir / "semantic-asset-manifest.md"
    write_csv(items, csv_path)
    write_markdown(items, md_path)
    print(f"wrote {csv_path}")
    print(f"wrote {md_path}")
    print(f"manifest items: {len(items)}")


if __name__ == "__main__":
    main()
