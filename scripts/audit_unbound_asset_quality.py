#!/usr/bin/env python3
"""Audit UNBOUND exercise, movement, and skill visual assets.

This is a review-queue generator, not a delete or rewrite tool. It scores the
current asset catalog against the newer UNBOUND visual standard:

- catalog/movement visuals: 1024 square transparent cutouts
- skill phase visuals: 625 square dark labeled phase cards
- no tiny legacy/vector silhouettes hiding inside large canvases
- no missing required catalog/skill/mobility images
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "UNBOUND"
ASSETS = APP / "Assets.xcassets"
DEFAULT_OUT = ROOT / "LocalArtifacts" / "asset-quality-audit-20260610"


def normalized(value: str) -> str:
    value = value.strip().lower().replace("\u2013", "-").replace("\u2014", "-")
    return " ".join(part for part in re.split(r"[^0-9a-zA-Z]+", value) if part)


def slug(value: str) -> str:
    return normalized(value).replace(" ", "-")


def sanitized(value: str) -> str:
    return "".join(ch.lower() if (ch.isalnum() or ch == "-") else "_" for ch in value)


def existing_current_exercise_assets() -> set[str]:
    return {imageset.stem for imageset in ASSETS.glob("exercise_visual_*.imageset")}


def resolver_manual_slug_map() -> dict[str, list[str]]:
    resolver = APP / "Views" / "Home" / "SkillTraditionalVisualResolver.swift"
    if not resolver.exists():
        return {}

    text = resolver.read_text(errors="ignore")
    match = re.search(
        r"manualSlugMap:\s*\[String:\s*\[String\]\]\s*=\s*\[(.*?)\]\s*\n\s*private static",
        text,
        re.S,
    )
    if not match:
        return {}

    mappings: dict[str, list[str]] = {}
    for key, raw_values in re.findall(r'"([^"]+)":\s*\[([^\]]*)\]', match.group(1)):
        mappings[key] = re.findall(r'"([^"]+)"', raw_values)
    return mappings


def resolver_generated_skill_icon_ids() -> set[str]:
    resolver = APP / "Views" / "Home" / "SkillTraditionalVisualResolver.swift"
    if not resolver.exists():
        return set()

    text = resolver.read_text(errors="ignore")
    match = re.search(
        r"generatedSkillIconNodeIds:\s*Set<String>\s*=\s*\[(.*?)\]\s*\n\s*private static",
        text,
        re.S,
    )
    if not match:
        return set()
    return set(re.findall(r'"([^"]+)"', match.group(1)))


def asset_contents_filename(imageset: Path) -> str | None:
    contents = imageset / "Contents.json"
    if not contents.exists():
        return None
    try:
        payload = json.loads(contents.read_text())
    except json.JSONDecodeError:
        return None
    for image in payload.get("images", []):
        filename = image.get("filename")
        if filename:
            return filename
    return None


def png_for_imageset(imageset: Path) -> Path | None:
    filename = asset_contents_filename(imageset)
    if filename and (imageset / filename).exists():
        return imageset / filename
    fallback = imageset / f"{imageset.stem}.png"
    if fallback.exists():
        return fallback
    pngs = sorted(imageset.glob("*.png"))
    return pngs[0] if pngs else None


def expected_current_exercise_assets() -> dict[str, set[str]]:
    required: dict[str, set[str]] = defaultdict(set)
    existing = existing_current_exercise_assets()
    manual_slug_map = resolver_manual_slug_map()
    generated_skill_icon_ids = resolver_generated_skill_icon_ids()

    catalog = APP / "Models" / "ExerciseCatalog.swift"
    if catalog.exists():
        text = catalog.read_text(errors="ignore")
        for name in re.findall(r"\.init\(name:\s*\"([^\"]+)\"", text):
            required["exercise_visual_exercise_" + slug(name)].add("ExerciseCatalog primary slug")

    movement = APP / "Models" / "MovementCatalog.swift"
    if movement.exists():
        text = movement.read_text(errors="ignore")
        for prefix, pattern, reason in [
            ("carry.", r"carry\(\s*\"([^\"]+)\"", "MovementCatalog carry"),
            ("mobility.", r"mobility\(\s*\"([^\"]+)\"", "MovementCatalog mobility"),
            ("skill-drill.", r"skillDrill\(\s*\"([^\"]+)\"", "MovementCatalog skill drill"),
        ]:
            for identifier in re.findall(pattern, text):
                required["exercise_visual_" + sanitized(prefix + identifier)].add(reason)

    skill_paths = sorted((APP / "Models" / "SkillTreeContent").glob("*.swift"))
    skill_paths += sorted((APP / "Models" / "SkillTreeContent" / "Tiers").glob("*.swift"))
    skill_paths += [APP / "Models" / "SkillTreeContent.swift"]
    for path in [p for p in skill_paths if p.exists()]:
        text = path.read_text(errors="ignore")
        rel = str(path.relative_to(ROOT))
        for match in re.finditer(r'id:\s*"([a-z]+\.[^"]+)".{0,700}?title:\s*"([^"]+)"', text, re.S):
            skill_id, title = match.groups()
            if skill_id in generated_skill_icon_ids:
                continue

            window = text[match.start() : match.end() + 700]
            candidates = list(manual_slug_map.get(skill_id, []))
            candidates.append(title)
            candidates.append(skill_id.split(".")[-1])
            candidates.extend(re.findall(r'exercise(?:Name)?:\s*"([^"]+)"', window))

            resolved = False
            normalized_candidates: list[str] = []
            for candidate in candidates:
                candidate_slug = slug(candidate)
                if not candidate_slug or candidate_slug in normalized_candidates:
                    continue
                normalized_candidates.append(candidate_slug)
                if "exercise_visual_exercise_" + candidate_slug in existing:
                    resolved = True
                    break

            if not resolved and normalized_candidates:
                required["exercise_visual_exercise_" + normalized_candidates[0]].add(
                    f"unresolved skill visual candidate in {rel}"
                )

    return required


def expected_phase_prefixes() -> dict[str, set[str]]:
    prefixes: dict[str, set[str]] = defaultdict(set)
    form_root = APP / "Views" / "Home" / "Components"
    for path in sorted(form_root.glob("FormPhaseLibrary+*.swift")):
        text = path.read_text(errors="ignore")
        rel = str(path.relative_to(ROOT))
        for prefix in re.findall(r'"([a-z0-9_]+-[a-z0-9_-]+|[a-z0-9_]+)"', text):
            if "_" in prefix and not prefix.startswith("phase"):
                if prefix.startswith(("pp_", "cal_", "cl_", "ld_", "pl_", "hs_", "oah_")):
                    prefixes[prefix].add(f"asset prefix literal in {rel}")
        for literal in re.findall(r'assetPrefix\s*=\s*"([^"]+)"', text):
            prefixes[literal].add(f"assetPrefix in {rel}")
    return prefixes


@dataclass
class AssetRow:
    asset: str
    kind: str
    path: str
    required_by: str = ""
    exists: bool = True
    width: int = 0
    height: int = 0
    file_bytes: int = 0
    alpha_transparent_pct: float = 0.0
    semitransparent_pct: float = 0.0
    opaque: bool = True
    content_bbox_pct: float = 0.0
    content_width_pct: float = 0.0
    content_height_pct: float = 0.0
    unique_sample: int = 0
    edge_density: float = 0.0
    issues: list[str] = field(default_factory=list)

    @property
    def issue_text(self) -> str:
        return ";".join(self.issues)

    @property
    def priority(self) -> int:
        priority = 0
        high = {
            "missing",
            "wrong-size",
            "opaque-catalog-bg",
            "tiny-content",
            "low-detail-candidate",
            "legacy-vector-candidate",
            "missing-phase",
        }
        for issue in self.issues:
            if issue in high:
                priority += 2
            else:
                priority += 1
        if self.kind.startswith("required"):
            priority += 1
        return priority


def inspect_image(asset: str, kind: str, imageset: Path, required_by: str = "") -> AssetRow:
    png = png_for_imageset(imageset)
    row = AssetRow(asset=asset, kind=kind, path=str(imageset.relative_to(ROOT)), required_by=required_by)
    if png is None:
        row.exists = False
        row.issues.append("missing-png")
        return row

    row.path = str(png.relative_to(ROOT))
    row.file_bytes = png.stat().st_size
    image = Image.open(png).convert("RGBA")
    row.width, row.height = image.size

    arr = np.asarray(image)
    alpha = arr[:, :, 3]
    total = alpha.size
    transparent = int(np.count_nonzero(alpha == 0))
    semitransparent = int(np.count_nonzero((alpha > 0) & (alpha < 255)))
    row.alpha_transparent_pct = transparent / total * 100
    row.semitransparent_pct = semitransparent / total * 100
    row.opaque = transparent == 0 and semitransparent == 0

    content = alpha > 8
    if np.any(content):
        ys, xs = np.where(content)
        bbox_area = (xs.max() - xs.min() + 1) * (ys.max() - ys.min() + 1)
        row.content_bbox_pct = bbox_area / total * 100
        row.content_width_pct = (xs.max() - xs.min() + 1) / row.width * 100
        row.content_height_pct = (ys.max() - ys.min() + 1) / row.height * 100

    thumb = image.resize((128, 128), Image.Resampling.BILINEAR).convert("RGB")
    row.unique_sample = len(set(thumb.getdata()))

    gray = cv2.cvtColor(np.asarray(image.convert("RGB")), cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 60, 140)
    denom = max(1, int(np.count_nonzero(content)))
    row.edge_density = float(np.count_nonzero(edges & content) / denom)
    return row


def classify_row(row: AssetRow) -> None:
    if not row.exists:
        row.issues.append("missing")
        return

    is_phase = row.kind == "skill-phase"
    is_catalog_like = row.kind in {
        "exercise-current",
        "exercise-jot",
        "exercise-legacy",
        "mobility-current",
        "required-missing-current",
    }

    if is_phase:
        if (row.width, row.height) != (625, 625):
            row.issues.append("wrong-size")
        if row.file_bytes < 70_000 or row.unique_sample < 650:
            row.issues.append("low-detail-candidate")
    elif row.kind == "skill-icon":
        if row.width != row.height or row.width < 900:
            row.issues.append("wrong-size")
        if row.file_bytes < 70_000 or row.unique_sample < 500:
            row.issues.append("legacy-vector-candidate")
    elif is_catalog_like:
        if (row.width, row.height) != (1024, 1024):
            row.issues.append("wrong-size")
        if row.opaque or row.alpha_transparent_pct < 8:
            row.issues.append("opaque-catalog-bg")
        if row.content_bbox_pct and row.content_bbox_pct < 12:
            row.issues.append("tiny-content")
        if row.file_bytes < 80_000 or row.unique_sample < 500:
            row.issues.append("legacy-vector-candidate")

    if row.width == 1024 and row.content_bbox_pct and row.content_width_pct < 36 and row.content_height_pct < 36:
        row.issues.append("tiny-centered-art")


def collect_asset_rows() -> list[AssetRow]:
    rows: list[AssetRow] = []

    for imageset in sorted(ASSETS.glob("exercise_visual_*.imageset")):
        rows.append(inspect_image(imageset.stem, "exercise-current", imageset))

    for group, kind in [
        (ASSETS / "ExerciseVisualsJot", "exercise-jot"),
        (ASSETS / "ExerciseVisualsLegacy", "exercise-legacy"),
    ]:
        if group.exists():
            for imageset in sorted(group.glob("exercise_visual_*.imageset")):
                rows.append(inspect_image(imageset.stem, kind, imageset))

    for imageset in sorted(ASSETS.glob("mobility_reference_*.imageset")):
        rows.append(inspect_image(imageset.stem, "mobility-reference", imageset))

    skill_root = ASSETS / "SkillIcons"
    if skill_root.exists():
        for imageset in sorted(skill_root.glob("*.imageset")):
            kind = "skill-phase" if re.search(r"_phase[1-4]$", imageset.stem) else "skill-icon"
            rows.append(inspect_image(imageset.stem, kind, imageset))

    for row in rows:
        classify_row(row)
    return rows


def add_missing_required(rows: list[AssetRow]) -> None:
    existing = {row.asset for row in rows}
    for asset, reasons in expected_current_exercise_assets().items():
        if asset not in existing:
            rows.append(
                AssetRow(
                    asset=asset,
                    kind="required-missing-current",
                    path="",
                    required_by="; ".join(sorted(reasons)[:4]),
                    exists=False,
                    issues=["missing"],
                )
            )

    existing_phases = {row.asset for row in rows if row.kind == "skill-phase"}
    for prefix, reasons in expected_phase_prefixes().items():
        for phase in range(1, 5):
            asset = f"{prefix}_phase{phase}"
            if asset not in existing_phases:
                rows.append(
                    AssetRow(
                        asset=asset,
                        kind="required-missing-phase",
                        path="",
                        required_by="; ".join(sorted(reasons)[:4]),
                        exists=False,
                        issues=["missing-phase"],
                    )
                )
    for row in rows:
        if not row.issues:
            classify_row(row)


def write_csv(rows: list[AssetRow], path: Path) -> None:
    fields = [
        "priority",
        "asset",
        "kind",
        "issues",
        "path",
        "required_by",
        "exists",
        "width",
        "height",
        "file_bytes",
        "alpha_transparent_pct",
        "semitransparent_pct",
        "opaque",
        "content_bbox_pct",
        "content_width_pct",
        "content_height_pct",
        "unique_sample",
        "edge_density",
    ]
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in sorted(rows, key=lambda item: (-item.priority, item.kind, item.asset)):
            payload = {field: getattr(row, field) if hasattr(row, field) else "" for field in fields}
            payload["priority"] = row.priority
            payload["issues"] = row.issue_text
            writer.writerow(payload)


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


def make_contact_sheet(rows: list[AssetRow], path: Path, title: str, max_items: int = 80) -> None:
    selected = [
        row
        for row in sorted(rows, key=lambda item: (-item.priority, item.kind, item.asset))
        if row.exists and row.issues and row.path
    ][:max_items]
    if not selected:
        sheet = Image.new("RGB", (900, 220), (8, 10, 12))
        draw = ImageDraw.Draw(sheet)
        font = load_font(18)
        small = load_font(14)
        draw.text((24, 24), title, fill=(230, 245, 242), font=font)
        draw.text((24, 74), "No flagged assets in this category.", fill=(96, 230, 224), font=small)
        draw.text(
            (24, 110),
            "The audit still writes CSV/HTML for the full inspected asset inventory.",
            fill=(168, 188, 184),
            font=small,
        )
        sheet.save(path)
        return

    tile = 180
    label_h = 58
    cols = 5
    rows_count = math.ceil(len(selected) / cols)
    sheet = Image.new("RGB", (cols * tile, rows_count * (tile + label_h) + 36), (8, 10, 12))
    draw = ImageDraw.Draw(sheet)
    font = load_font(14)
    small = load_font(11)
    draw.text((12, 10), title, fill=(230, 245, 242), font=font)
    for index, row in enumerate(selected):
        x = (index % cols) * tile
        y = 36 + (index // cols) * (tile + label_h)
        image = Image.open(ROOT / row.path).convert("RGBA")
        preview = Image.new("RGBA", image.size, (5, 8, 10, 255))
        preview.alpha_composite(image)
        preview.thumbnail((tile - 12, tile - 12), Image.Resampling.LANCZOS)
        px = x + (tile - preview.width) // 2
        py = y + (tile - preview.height) // 2
        sheet.paste(preview.convert("RGB"), (px, py))
        label = row.asset[:28]
        issue = row.issue_text[:34]
        draw.text((x + 6, y + tile + 4), label, fill=(230, 245, 242), font=small)
        draw.text((x + 6, y + tile + 22), issue, fill=(96, 230, 224), font=small)
    sheet.save(path)


def write_markdown(rows: list[AssetRow], path: Path, out_dir: Path) -> None:
    issue_counts = Counter(issue for row in rows for issue in row.issues)
    kind_counts = Counter(row.kind for row in rows)
    flagged = [row for row in rows if row.issues]
    priority = sorted(flagged, key=lambda item: (-item.priority, item.kind, item.asset))

    lines: list[str] = []
    lines.append("# UNBOUND Asset Quality Audit")
    lines.append("")
    lines.append("Generated: 2026-06-10")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Total rows audited: {len(rows)}")
    lines.append(f"- Rows flagged for review/regeneration: {len(flagged)}")
    lines.append("")
    lines.append("### Rows By Kind")
    lines.append("")
    for kind, count in sorted(kind_counts.items()):
        lines.append(f"- {kind}: {count}")
    lines.append("")
    lines.append("### Issue Counts")
    lines.append("")
    for issue, count in sorted(issue_counts.items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"- {issue}: {count}")
    lines.append("")
    lines.append("## Review Artifacts")
    lines.append("")
    lines.append(f"- CSV: `{(out_dir / 'asset-quality-audit.csv').relative_to(ROOT)}`")
    if (out_dir / "flagged-exercise-contact-sheet.png").exists():
        lines.append(f"- Exercise contact sheet: `{(out_dir / 'flagged-exercise-contact-sheet.png').relative_to(ROOT)}`")
    if (out_dir / "flagged-skill-phase-contact-sheet.png").exists():
        lines.append(f"- Skill phase contact sheet: `{(out_dir / 'flagged-skill-phase-contact-sheet.png').relative_to(ROOT)}`")
    if (out_dir / "asset-visual-inventory.html").exists():
        lines.append(f"- Full visual inventory: `{(out_dir / 'asset-visual-inventory.html').relative_to(ROOT)}`")
    lines.append("")
    lines.append("## Top Review Queue")
    lines.append("")
    lines.append("| Priority | Kind | Asset | Issues | Path |")
    lines.append("|---:|---|---|---|---|")
    for row in priority[:140]:
        lines.append(
            "| "
            + " | ".join(
                [
                    str(row.priority),
                    row.kind,
                    row.asset,
                    row.issue_text,
                    row.path,
                ]
            )
            + " |"
        )
    path.write_text("\n".join(lines) + "\n")


def write_html(rows: list[AssetRow], path: Path) -> None:
    flagged = sorted([row for row in rows if row.issues], key=lambda item: (-item.priority, item.kind, item.asset))
    html_rows = []
    for row in flagged:
        img = ""
        if row.exists and row.path:
            img = f'<img src="{html.escape(str(ROOT / row.path))}" loading="lazy">'
        html_rows.append(
            "<tr>"
            f"<td>{row.priority}</td>"
            f"<td>{html.escape(row.kind)}</td>"
            f"<td>{html.escape(row.asset)}</td>"
            f"<td>{html.escape(row.issue_text)}</td>"
            f"<td>{img}</td>"
            f"<td><code>{html.escape(row.path)}</code></td>"
            "</tr>"
        )
    path.write_text(
        """<!doctype html>
<html><head><meta charset="utf-8"><style>
body{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;background:#080a0c;color:#e6f5f2}
table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #243034;padding:6px;vertical-align:top}
img{width:140px;height:140px;object-fit:contain;background:#05080a}
code{font-size:11px;color:#86fff7}
</style></head><body>
<h1>UNBOUND Asset Quality Audit</h1>
<table><thead><tr><th>Priority</th><th>Kind</th><th>Asset</th><th>Issues</th><th>Preview</th><th>Path</th></tr></thead><tbody>
"""
        + "\n".join(html_rows)
        + "\n</tbody></table></body></html>\n"
    )


def write_inventory_html(rows: list[AssetRow], path: Path) -> None:
    sorted_rows = sorted(rows, key=lambda item: (item.kind, item.asset))
    cards = []
    for row in sorted_rows:
        status_class = "bad" if row.issues else "ok"
        status_text = html.escape(row.issue_text or "ok")
        img = ""
        if row.exists and row.path:
            img = f'<img src="{html.escape(str(ROOT / row.path))}" loading="lazy">'
        cards.append(
            f'<article class="card {status_class}" data-kind="{html.escape(row.kind)}">'
            f"{img}"
            f"<h2>{html.escape(row.asset)}</h2>"
            f"<p><b>{html.escape(row.kind)}</b> · {status_text}</p>"
            f"<p>{row.width}x{row.height} · alpha {row.alpha_transparent_pct:.1f}% · {row.file_bytes // 1024} KB</p>"
            f"<code>{html.escape(row.path)}</code>"
            "</article>"
        )

    counts = Counter(row.kind for row in rows)
    issue_counts = Counter(issue for row in rows for issue in row.issues)
    summary = " · ".join(f"{html.escape(kind)}: {count}" for kind, count in sorted(counts.items()))
    issues = " · ".join(f"{html.escape(issue)}: {count}" for issue, count in sorted(issue_counts.items()))
    if not issues:
        issues = "No flagged structural issues."

    path.write_text(
        """<!doctype html>
<html><head><meta charset="utf-8"><style>
body{font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;background:#080a0c;color:#e6f5f2;margin:0;padding:24px}
h1{margin:0 0 8px} .summary{color:#a8bcb8;margin:6px 0}
.toolbar{position:sticky;top:0;background:#080a0cee;backdrop-filter:blur(8px);padding:12px 0 16px;z-index:2}
button{background:#10181a;color:#e6f5f2;border:1px solid #244348;border-radius:6px;padding:7px 10px;margin:0 6px 6px 0;cursor:pointer}
button:hover{border-color:#60e6e0} .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:12px}
.card{background:#0d1113;border:1px solid #203034;border-radius:8px;padding:10px;min-width:0}
.card.ok{border-color:#1b3436}.card.bad{border-color:#6f3b35}
img{width:100%;aspect-ratio:1;object-fit:contain;background:#05080a;border-radius:4px}
h2{font-size:12px;line-height:1.25;word-break:break-word;margin:8px 0 4px}
p{font-size:11px;color:#b8cbc7;margin:3px 0} code{display:block;font-size:10px;color:#86fff7;word-break:break-word;margin-top:6px}
.hidden{display:none}
</style><script>
function filterKind(kind){
  document.querySelectorAll('.card').forEach(card => card.classList.toggle('hidden', kind !== 'all' && card.dataset.kind !== kind));
}
</script></head><body>
"""
        + "<h1>UNBOUND Asset Visual Inventory</h1>\n"
        + f'<p class="summary">{len(rows)} rows · {html.escape(summary)}</p>\n'
        + f'<p class="summary">{issues}</p>\n'
        + '<div class="toolbar"><button onclick="filterKind(\'all\')">All</button>'
        + "".join(
            f"<button onclick=\"filterKind('{html.escape(kind)}')\">{html.escape(kind)}</button>"
            for kind in sorted(counts)
        )
        + "</div>\n"
        + '<main class="grid">\n'
        + "\n".join(cards)
        + "\n</main></body></html>\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows = collect_asset_rows()
    add_missing_required(rows)

    csv_path = args.out_dir / "asset-quality-audit.csv"
    md_path = args.out_dir / "asset-quality-audit.md"
    html_path = args.out_dir / "asset-quality-audit.html"
    write_csv(rows, csv_path)
    make_contact_sheet(
        [row for row in rows if row.kind.startswith("exercise") or row.kind.startswith("mobility")],
        args.out_dir / "flagged-exercise-contact-sheet.png",
        "Flagged Exercise/Mobility Assets",
    )
    make_contact_sheet(
        [row for row in rows if "phase" in row.kind or row.kind == "skill-phase"],
        args.out_dir / "flagged-skill-phase-contact-sheet.png",
        "Flagged Skill Phase Assets",
    )
    write_inventory_html(rows, args.out_dir / "asset-visual-inventory.html")
    write_markdown(rows, md_path, args.out_dir)
    write_html(rows, html_path)

    flagged = [row for row in rows if row.issues]
    print(f"wrote {csv_path}")
    print(f"wrote {md_path}")
    print(f"wrote {html_path}")
    print(f"audited {len(rows)} rows; flagged {len(flagged)}")


if __name__ == "__main__":
    main()
