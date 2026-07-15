#!/usr/bin/env python3
"""
Generate exercise art for MANY movements at once and install each to the exact
asset slug the app resolves.

Why this exists alongside regen_exercise_art.py:

  1. Correct slug. `ExerciseVisualAsset` builds its candidate from the movement
     *id* (`exercise.<slug(canonical name)>`), so the asset it looks for is
     `exercise_visual_exercise_<slug(canonical name)>`. regen_exercise_art.py
     derives its primary slug from the DISPLAY name, which for a movement like
     "Reverse Curl (EZ-Bar)" / `reverse curl` yields a name nothing ever reads.
     This script keys off the canonical name, so the asset always resolves.

  2. Safe parallelism. codex writes into `$CODEX_HOME/generated_images`, and
     picking "the newest image" there means concurrent jobs steal each other's
     output. Each job here gets its OWN CODEX_HOME, so a batch can run wide
     without cross-contamination.

Input: a JSON list of {"name", "display", "movement"} (canonical name, display
name, and an explicit description of the pose/apparatus).

  python3 scripts/batch_exercise_art.py batch.json --workers 5
  python3 scripts/batch_exercise_art.py batch.json --only "barbell shrug"
  python3 scripts/batch_exercise_art.py batch.json --preview   # stage, don't install
"""
import argparse, glob, json, os, re, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(REPO, "UNBOUND/Assets.xcassets")
AVATAR = os.path.join(REPO, "docs/skill-assets/unbound-movement-avatar-reference.png")
REAL_CODEX_HOME = os.path.expanduser("~/.codex")

STYLE = ("anime/webtoon male athlete, sharp messy BLACK hair, lean calisthenics build, "
         "simple readable low-detail face, black sleeveless top, black pants, black shoes, "
         "black wrist wraps, cyan/teal rim light, subtle teal motion trails. "
         "No purple, NO white hair, no realistic 3D render")

CONTENTS = ('{\n  "images" : [\n    { "filename" : "%s.png", "idiom" : "universal", "scale" : "1x" },\n'
            '    { "idiom" : "universal", "scale" : "2x" },\n    { "idiom" : "universal", "scale" : "3x" }\n  ],\n'
            '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')


def slug(s):
    """Mirror of MovementCatalog.slug: normalize to alphanumerics, join with '-'."""
    s = s.strip().lower().replace("–", "-").replace("−", "-").replace("—", "-")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def asset_name(canonical_name):
    return f"exercise_visual_exercise_{slug(canonical_name)}"


def build_prompt(display, movement):
    return (
        "Generate a UNBOUND exercise visual. The attached reference image is the CHARACTER "
        "identity sheet ONLY - use it for the athlete's face, hair, build, and outfit; do NOT copy its pose.\n"
        f"Style lock: {STYLE}.\n\n"
        f"Subject: {display}.\nMovement: {movement}\n\n"
        "Camera and framing: full body and ALL apparatus fully inside the frame, centered with generous "
        "empty margin so nothing touches or is cut off by the edges.\n"
        "Output: ONE single clean centered full-body figure, 1024x1024. No duplicate limbs, no stray body "
        "parts, no second figure, no floating hands.\n"
        "Background: perfectly flat chroma green #00FF00 only. No shadows, gradients, texture, text, logos, "
        "UI, arrows, or scenery on the background."
    )


def isolated_codex_home(tmp):
    """A private CODEX_HOME so parallel jobs never share generated_images."""
    home = os.path.join(tmp, "codex_home")
    os.makedirs(home, exist_ok=True)
    for f in ("auth.json", "config.toml"):
        src = os.path.join(REAL_CODEX_HOME, f)
        if os.path.exists(src):
            shutil.copy(src, os.path.join(home, f))
    return home


def generate(prompt, tmp):
    home = isolated_codex_home(tmp)
    env = dict(os.environ, CODEX_HOME=home)
    subprocess.run(
        ["codex", "exec", "--image", AVATAR, "--sandbox", "workspace-write", "--skip-git-repo-check"],
        input=prompt, text=True, capture_output=True, env=env, timeout=900,
    )
    pngs = glob.glob(os.path.join(home, "generated_images", "*", "*.png"))
    if not pngs:
        return None
    return max(pngs, key=os.path.getmtime)


# The shipped set sits at ~1024px on its longest edge (median 1026). codex can
# hand back a larger canvas, so cap it — otherwise the art is ~20% oversized for
# no visible gain (it renders into a 62pt row) and just inflates the bundle.
MAX_EDGE = 1024


def chromakey_and_crop(raw, out_png, margin=0.06):
    """Green -> transparent, frame-fill crop to the alpha bbox + margin, cap size."""
    from PIL import Image
    import numpy as np

    im = Image.open(raw).convert("RGBA")
    a = np.array(im).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # Green screen: green clearly dominant over both other channels.
    green = (g > 90) & (g - r > 40) & (g - b > 40)
    a[..., 3] = np.where(green, 0, 255)
    # Despill: pull the green fringe on kept edge pixels down to its neighbours,
    # otherwise the cutout keeps a lime rim against the app's dark surfaces.
    edge = (~green) & (g - np.maximum(r, b) > 12)
    a[..., 1] = np.where(edge, np.maximum(r, b), g)
    # Zero the RGB under fully-transparent pixels. The shipped set does this
    # (transparent RGB == 0,0,0); leaving green there bleeds a halo wherever the
    # image is downscaled and the filter samples across the alpha edge.
    a[..., :3] = np.where(green[..., None], 0, a[..., :3])

    im = Image.fromarray(a.astype(np.uint8), "RGBA")
    bb = im.split()[3].getbbox()
    if bb:
        w, h = im.size
        bw, bh = bb[2] - bb[0], bb[3] - bb[1]
        mx, my = int(bw * margin), int(bh * margin)
        im = im.crop((max(0, bb[0] - mx), max(0, bb[1] - my),
                      min(w, bb[2] + mx), min(h, bb[3] + my)))
    if max(im.size) > MAX_EDGE:
        im.thumbnail((MAX_EDGE, MAX_EDGE), Image.LANCZOS)
    im.save(out_png, optimize=True)
    return im.size


def install(asset, png):
    d = os.path.join(ASSETS, f"{asset}.imageset")
    os.makedirs(d, exist_ok=True)
    shutil.copy(png, os.path.join(d, f"{asset}.png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write(CONTENTS % asset)


def run_one(item, stage_dir, preview):
    name, display = item["name"], item["display"]
    asset = asset_name(name)
    tmp = tempfile.mkdtemp(prefix="exart_")
    try:
        raw = generate(build_prompt(display, item["movement"]), tmp)
        if not raw:
            return (name, asset, "FAILED: codex produced no image", None)
        out = os.path.join(stage_dir, f"{asset}.png")
        size = chromakey_and_crop(raw, out)
        if not preview:
            install(asset, out)
        return (name, asset, "ok", size)
    except Exception as e:  # keep one bad job from killing the batch
        return (name, asset, f"FAILED: {e}", None)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("batch", help="JSON list of {name, display, movement}")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--only", default="", help="only this canonical name")
    ap.add_argument("--preview", action="store_true", help="stage only, do not install")
    ap.add_argument("--stage", default=os.path.join(REPO, "build/batch-exercise-art"))
    a = ap.parse_args()

    items = json.load(open(a.batch))
    if a.only:
        items = [i for i in items if i["name"] == a.only]
    os.makedirs(a.stage, exist_ok=True)

    print(f"generating {len(items)} exercise visuals with {a.workers} workers -> {a.stage}")
    results = []
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        futures = {ex.submit(run_one, i, a.stage, a.preview): i for i in items}
        for f in as_completed(futures):
            name, asset, status, size = f.result()
            results.append((name, asset, status, size))
            mark = "ok  " if status == "ok" else "FAIL"
            print(f"  [{len(results):>3}/{len(items)}] {mark} {name:<38} {asset}  {size or status}")

    failed = [r for r in results if r[2] != "ok"]
    print(f"\ndone: {len(results) - len(failed)} ok, {len(failed)} failed")
    for name, _, status, _ in failed:
        print(f"  FAILED {name}: {status}")
    if not a.preview:
        print("\nVERIFY: Read each installed PNG, then run ExerciseVisualCoverageTests + MovementResolverTests.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
