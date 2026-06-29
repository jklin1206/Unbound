#!/usr/bin/env python3
"""
Regenerate one exercise's visual art end-to-end and install it to the asset
slug(s) the app actually reads.

Pipeline (the vetted flow):
  1. Build a style-locked prompt (anime by default, or realistic/legacy).
  2. Generate on flat chroma green via codex image_gen (`codex exec --image <ref>`).
  3. Chroma-key the green to transparent (scripts/chromakey_generated_assets.py).
  4. Frame-fill crop to the alpha bbox + ~6% margin (matches the shipped set).
  5. Install to EVERY existing asset-slug variant for the movement, so the
     app's resolver (which may pick the display-name slug, the id-tail slug, or
     the exercise-name slug) always lands on the new art.  This is the fix for
     the "explosive-pullup vs explosive-pull-up" slug-mismatch class of bug.

Examples:
  # anime regen, character locked to the avatar, pose described in text
  python3 scripts/regen_exercise_art.py --name "Seated Leg Curl" --id exercise.leg-curl-seated \
      --movement "Seated on a leg-curl machine, thighs under the lap pad, curling the shins DOWN and back (knee flexion, hamstrings). NOT a leg extension."

  # hard pose: feed a clean reference image of the pose, force the UNBOUND character
  python3 scripts/regen_exercise_art.py --name "Tuck Handstand" --id hs.tuck-handstand \
      --pose-ref /tmp/tuck_ref.png \
      --movement "Inverted on straight arms, hips bent ~90 deg, thighs folded forward, shins tucked over the glutes."

  # realistic / legacy-set style instead of anime
  python3 scripts/regen_exercise_art.py --name "Machine Lateral Raise" --id exercise.machine-lateral-raise \
      --pose-ref <legacy-asset.png> --style realistic \
      --movement "Seated lateral-raise machine, arms driving up and out to the sides against the pads."

  # skip generation, just re-key/crop/install an existing green PNG (testing or manual gen)
  python3 scripts/regen_exercise_art.py --name "Foo" --id exercise.foo --reuse /path/raw_green.png

  --preview        stage only, do not write into Assets.xcassets
  --rebuild-html   regenerate docs/movement-library.html after install (needs /tmp/gen_library.py)
"""
import argparse, os, re, subprocess, sys, shutil, glob, json, time

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(REPO, "UNBOUND/Assets.xcassets")
AVATAR = os.path.join(REPO, "docs/skill-assets/unbound-movement-avatar-reference.png")
GEN_DIR = os.path.expanduser("~/.codex/generated_images")
KEY_OUT = os.path.join(REPO, "build/generated-transparent-assets")

STYLE_ANIME = ("anime/webtoon male athlete, sharp messy BLACK hair, lean calisthenics build, "
    "simple readable low-detail face, black sleeveless top, black pants, black shoes, black wrist wraps, "
    "cyan/teal rim light, subtle teal motion trails. No purple, NO white hair, no realistic 3D render")
STYLE_REALISTIC = ("realistic 3D ANATOMICAL fitness-illustration render - a realistic muscular male figure, "
    "neutral skin tones, realistic proportions and smooth 3D shading, the worked muscles subtly highlighted. "
    "NOT anime, NOT a cartoon: no anime face, no black anime hair, no teal rim light, no manga shading")

def slug(s):
    s = s.strip().lower().replace("–", "-").replace("—", "-")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")

def build_prompt(name, movement, style, pose_ref):
    style_lock = STYLE_REALISTIC if style == "realistic" else STYLE_ANIME
    if pose_ref:
        head = ("Generate a UNBOUND exercise visual. The attached reference shows the EXACT body "
                "position/pose to reproduce - copy this exact pose precisely.\n"
                f"Render the figure in this style: {style_lock}.")
    else:
        head = ("Generate a UNBOUND exercise visual. The attached reference image is the CHARACTER "
                "identity sheet ONLY - use it for the athlete's face, hair, build, and outfit; do NOT copy its pose.\n"
                f"Style lock: {style_lock}.")
    return (f"{head}\n\nSubject: {name}.\nMovement: {movement}\n\n"
        "Camera and framing: full body and ALL apparatus fully inside the frame, centered with generous "
        "empty margin so nothing touches or is cut off by the edges.\n"
        "Output: ONE single clean centered full-body figure, 1024x1024. No duplicate limbs, no stray body "
        "parts, no second figure, no floating hands.\n"
        "Background: perfectly flat chroma green #00FF00 only. No shadows, gradients, texture, text, logos, "
        "UI, arrows, or scenery on the background.")

def newest_codex_png(before):
    after = set(glob.glob(os.path.join(GEN_DIR, "*/")))
    new = sorted(after - before)
    search = new[-1] if new else max(glob.glob(os.path.join(GEN_DIR, "*/")), key=os.path.getmtime)
    pngs = sorted(glob.glob(os.path.join(search, "*.png")), key=os.path.getmtime)
    return pngs[-1] if pngs else None

def generate(prompt, ref):
    before = set(glob.glob(os.path.join(GEN_DIR, "*/")))
    print(f"  generating via codex (ref={os.path.basename(ref)}) ...")
    subprocess.run(["codex", "exec", "--image", ref, "--sandbox", "workspace-write", "--skip-git-repo-check"],
                   input=prompt, text=True, capture_output=True)
    png = newest_codex_png(before)
    if not png:
        sys.exit("  FAILED: no codex output PNG found")
    return png

def frame_fill(path, margin=0.06):
    from PIL import Image
    im = Image.open(path).convert("RGBA"); bb = im.split()[3].getbbox()
    if not bb: return im
    w, h = im.size; bw, bh = bb[2]-bb[0], bb[3]-bb[1]; mx, my = int(bw*margin), int(bh*margin)
    return im.crop((max(0, bb[0]-mx), max(0, bb[1]-my), min(w, bb[2]+mx), min(h, bb[3]+my)))

CONTENTS = ('{\n  "images" : [\n    { "filename" : "%s.png", "idiom" : "universal", "scale" : "1x" },\n'
    '    { "idiom" : "universal", "scale" : "2x" },\n    { "idiom" : "universal", "scale" : "3x" }\n  ],\n'
    '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')

def candidate_assets(name, mid):
    """Every asset name the app's resolver might land on, in priority-ish order."""
    slugs = [slug(name)]
    if mid:
        slugs.append(mid.split(".")[-1])           # id tail (skill node / exercise)
        slugs.append(mid.replace("exercise.", "").replace("skill.", ""))
    seen, out = set(), []
    for s in slugs:
        if s and s not in seen:
            seen.add(s); out.append(s)
    prefixes = ["exercise", "mobility", "carry"]
    return [f"exercise_visual_{p}_{s}" for s in out for p in prefixes]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True, help="display name, e.g. 'Seated Leg Curl'")
    ap.add_argument("--id", default="", help="movement/skill id, e.g. exercise.leg-curl-seated or hs.tuck-handstand")
    ap.add_argument("--movement", default="", help="explicit movement/pose description (strongly recommended)")
    ap.add_argument("--ref", default=AVATAR, help="character reference (default: UNBOUND avatar)")
    ap.add_argument("--pose-ref", default="", help="a pose reference image; copies the pose, renders UNBOUND char")
    ap.add_argument("--style", choices=["anime", "realistic"], default="anime")
    ap.add_argument("--reuse", default="", help="skip codex; use this existing flat-green PNG")
    ap.add_argument("--preview", action="store_true", help="stage only, do not install into Assets.xcassets")
    ap.add_argument("--rebuild-html", action="store_true")
    a = ap.parse_args()
    os.makedirs(KEY_OUT, exist_ok=True)

    ref = a.pose_ref or a.ref
    prompt = build_prompt(a.name, a.movement or a.name, a.style, bool(a.pose_ref))
    raw = a.reuse if a.reuse else generate(prompt, ref)
    print(f"  raw green: {raw}")

    # chroma-key via the shared script (writes to build/generated-transparent-assets/<name>.png)
    primary = candidate_assets(a.name, a.id)[0]
    stage = os.path.join("/tmp", "regen_key_in"); shutil.rmtree(stage, ignore_errors=True); os.makedirs(stage)
    shutil.copy(raw, os.path.join(stage, f"{primary}.png"))
    subprocess.run(["python3", os.path.join(REPO, "scripts/chromakey_generated_assets.py"), stage, "--size", "1024"],
                   cwd=REPO, capture_output=True)
    keyed = os.path.join(KEY_OUT, f"{primary}.png")
    if not os.path.exists(keyed):
        sys.exit(f"  FAILED: chroma-key produced no output at {keyed}")
    cropped = frame_fill(keyed)
    preview_path = os.path.join("/tmp", f"PREVIEW_{primary}.png")
    cropped.save(preview_path)
    print(f"  keyed + cropped preview: {preview_path}  size={cropped.size}")

    if a.preview:
        print("  --preview set: not installing. Review the preview, then re-run without --preview.")
        return

    # install to EVERY existing candidate imageset (slug-mismatch insurance), else create the primary one
    installed = []
    for asset in candidate_assets(a.name, a.id):
        dd = os.path.join(ASSETS, f"{asset}.imageset")
        if os.path.isdir(dd):
            cropped.save(os.path.join(dd, f"{asset}.png")); installed.append(asset)
    if not installed:
        dd = os.path.join(ASSETS, f"{primary}.imageset"); os.makedirs(dd, exist_ok=True)
        cropped.save(os.path.join(dd, f"{primary}.png"))
        open(os.path.join(dd, "Contents.json"), "w").write(CONTENTS % primary)
        installed.append(primary + " (new imageset)")
    print("  installed ->")
    for i in installed: print(f"    {i}")
    if len(installed) > 1:
        print("  (installed to multiple slug variants on purpose - the resolver may read any of them)")

    if a.rebuild_html:
        gl = "/tmp/gen_library.py"
        if os.path.exists(gl):
            subprocess.run(["python3", gl], cwd=REPO)
            print("  rebuilt docs/movement-library.html")
        else:
            print("  --rebuild-html skipped (/tmp/gen_library.py not found)")

    print("\n  VERIFY: run scripts/audit_exercise_visual_backgrounds.py and the ExerciseVisualCoverageTests suite.")

if __name__ == "__main__":
    main()
