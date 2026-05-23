#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "UNBOUND" / "Assets.xcassets"
INFO_ROOT = ASSETS / "SkillInfographics"
ICON_ROOT = ASSETS / "SkillIcons"

SHEET = 1254
PANEL = 625
GAP = 4
BG = (5, 8, 10)
PANEL_BG = (9, 14, 17)
CYAN = (68, 231, 224)
CYAN_DARK = (22, 105, 112)
WHITE = (228, 245, 242)
SKIN = (207, 154, 104)
CLOTH = (12, 15, 18)
SHOE = (20, 23, 26)
HAIR = (8, 10, 12)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Helvetica.ttf",
        "/System/Library/Fonts/Supplemental/Impact.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


FONT_LABEL = font(38, True)
FONT_NUM = font(22, True)


def contents(filename: str) -> dict:
    return {
        "images": [
            {"idiom": "universal", "filename": filename, "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }


def ensure_imageset(path: Path, filename: str) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(contents(filename), indent=2) + "\n")


def panel_origin(index: int) -> tuple[int, int]:
    return ((PANEL + GAP) * (index % 2), (PANEL + GAP) * (index // 2))


def line(draw: ImageDraw.ImageDraw, pts, fill, width=11) -> None:
    draw.line(pts, fill=fill, width=width, joint="curve")


def joint(draw: ImageDraw.ImageDraw, x: float, y: float, r: int, fill) -> None:
    draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def athlete(draw: ImageDraw.ImageDraw, pts: dict[str, tuple[float, float]], head_angle: float = 0) -> None:
    # Cyan rim pass.
    bones = [
        ("neck", "hip"), ("neck", "lhand"), ("neck", "rhand"), ("hip", "lknee"), ("lknee", "lfoot"),
        ("hip", "rknee"), ("rknee", "rfoot"),
    ]
    for a, b in bones:
        if a in pts and b in pts:
            line(draw, [pts[a], pts[b]], CYAN_DARK, 18)

    # Clothing/body pass.
    if "neck" in pts and "hip" in pts:
        line(draw, [pts["neck"], pts["hip"]], CLOTH, 24)
    for a, b in [("neck", "lhand"), ("neck", "rhand")]:
        if a in pts and b in pts:
            line(draw, [pts[a], pts[b]], SKIN, 14)
            joint(draw, *pts[b], 10, SKIN)
    for a, b in [("hip", "lknee"), ("lknee", "lfoot"), ("hip", "rknee"), ("rknee", "rfoot")]:
        if a in pts and b in pts:
            line(draw, [pts[a], pts[b]], CLOTH, 17)

    for k in ("lfoot", "rfoot"):
        if k in pts:
            x, y = pts[k]
            draw.rounded_rectangle((x - 22, y - 8, x + 22, y + 9), radius=6, fill=SHOE)
    for k in ("lhand", "rhand"):
        if k in pts:
            joint(draw, *pts[k], 9, SKIN)

    if "head" in pts:
        x, y = pts["head"]
        joint(draw, x, y, 25, SKIN)
        spikes = []
        for i in range(9):
            ang = -math.pi * 0.85 + i * math.pi / 5
            spikes.append((x + math.cos(ang) * 32, y - 5 + math.sin(ang) * 28))
        draw.polygon([(x - 25, y - 17), *spikes, (x + 25, y - 15), (x + 20, y + 6), (x - 18, y + 5)], fill=HAIR)


def label(draw: ImageDraw.ImageDraw, ox: int, oy: int, text: str, number: int) -> None:
    draw.rounded_rectangle((ox + 22, oy + 20, ox + 70, oy + 68), radius=24, fill=(13, 54, 58), outline=CYAN, width=2)
    draw.text((ox + 38, oy + 30), str(number), fill=WHITE, font=FONT_NUM, anchor="mm")
    draw.text((ox + 86, oy + 24), text.upper(), fill=WHITE, font=FONT_LABEL)


def apparatus(draw: ImageDraw.ImageDraw, ox: int, oy: int, kind: str) -> None:
    if kind in {"bar", "rings"}:
        y = oy + 118
        draw.line((ox + 70, y, ox + PANEL - 70, y), fill=(80, 90, 95), width=10)
        draw.line((ox + 70, y - 8, ox + PANEL - 70, y - 8), fill=CYAN_DARK, width=2)
        if kind == "rings":
            for x in (ox + 235, ox + 390):
                draw.line((x, y, x, y + 110), fill=(95, 102, 105), width=4)
                draw.ellipse((x - 30, y + 100, x + 30, y + 160), outline=(150, 154, 154), width=7)
    elif kind == "parallettes":
        for x1, x2 in ((ox + 170, ox + 300), (ox + 345, ox + 475)):
            y = oy + 425
            draw.line((x1, y, x2, y), fill=(130, 140, 142), width=9)
            draw.line((x1 + 15, y, x1 + 15, y + 65), fill=(90, 96, 98), width=6)
            draw.line((x2 - 15, y, x2 - 15, y + 65), fill=(90, 96, 98), width=6)
    elif kind == "bench":
        y = oy + 420
        draw.rounded_rectangle((ox + 120, y, ox + 510, y + 34), radius=8, fill=(50, 57, 60), outline=CYAN_DARK, width=2)
    elif kind == "floor":
        draw.line((ox + 72, oy + 485, ox + PANEL - 72, oy + 485), fill=(32, 45, 48), width=4)
    elif kind == "dumbbells":
        draw.line((ox + 78, oy + 490, ox + PANEL - 78, oy + 490), fill=(32, 45, 48), width=4)
        for x in (ox + 210, ox + 420):
            draw.rounded_rectangle((x - 48, oy + 438, x + 48, oy + 468), radius=10, fill=(45, 51, 54), outline=CYAN_DARK, width=2)
            draw.rounded_rectangle((x - 65, oy + 430, x - 46, oy + 476), radius=6, fill=(80, 90, 92))
            draw.rounded_rectangle((x + 46, oy + 430, x + 65, oy + 476), radius=6, fill=(80, 90, 92))
    elif kind == "sled":
        draw.line((ox + 80, oy + 505, ox + PANEL - 70, oy + 505), fill=(32, 45, 48), width=5)
        draw.line((ox + 360, oy + 430, ox + 520, oy + 430), fill=(92, 102, 105), width=12)
        draw.line((ox + 382, oy + 430, ox + 382, oy + 315), fill=(92, 102, 105), width=9)
        draw.line((ox + 500, oy + 430, ox + 500, oy + 315), fill=(92, 102, 105), width=9)
        draw.line((ox + 350, oy + 470, ox + 535, oy + 470), fill=CYAN_DARK, width=4)
    elif kind == "erg":
        draw.line((ox + 95, oy + 485, ox + 530, oy + 485), fill=(70, 80, 84), width=8)
        draw.ellipse((ox + 410, oy + 325, ox + 530, oy + 445), outline=(85, 96, 100), width=10)
        draw.rounded_rectangle((ox + 165, oy + 432, ox + 292, oy + 470), radius=9, fill=(52, 60, 64), outline=CYAN_DARK, width=2)
        draw.line((ox + 285, oy + 450, ox + 410, oy + 385), fill=(92, 102, 105), width=5)
        draw.line((ox + 360, oy + 320, ox + 388, oy + 255), fill=(92, 102, 105), width=5)
        draw.rounded_rectangle((ox + 360, oy + 230, ox + 430, oy + 260), radius=5, fill=(45, 52, 55), outline=CYAN_DARK, width=2)
    elif kind == "bike":
        draw.ellipse((ox + 90, oy + 390, ox + 230, oy + 530), outline=(85, 96, 100), width=8)
        draw.ellipse((ox + 385, oy + 390, ox + 525, oy + 530), outline=(85, 96, 100), width=8)
        draw.line((ox + 160, oy + 460, ox + 310, oy + 360), fill=(92, 102, 105), width=7)
        draw.line((ox + 310, oy + 360, ox + 455, oy + 460), fill=(92, 102, 105), width=7)
        draw.line((ox + 310, oy + 360, ox + 330, oy + 270), fill=(92, 102, 105), width=6)
        draw.line((ox + 330, oy + 285, ox + 420, oy + 250), fill=(92, 102, 105), width=6)
        draw.rounded_rectangle((ox + 258, oy + 315, ox + 342, oy + 340), radius=8, fill=(48, 54, 58), outline=CYAN_DARK, width=2)


def pose_points(ox: int, oy: int, family: str, phase: int) -> dict[str, tuple[float, float]]:
    # Local coordinates tuned for side-view silhouettes.
    if family == "hollow":
        y = oy + 365
        lift = [0, -30, -55, -35][phase]
        leg = [0, -30, -75, -20][phase]
        return {
            "head": (ox + 215, y - 38 + lift),
            "neck": (ox + 250, y + lift),
            "hip": (ox + 330, y + 35 + lift),
            "lhand": (ox + 130, y - 75 + lift),
            "rhand": (ox + 145, y - 62 + lift),
            "lknee": (ox + 430, y + leg),
            "rknee": (ox + 432, y + leg + 16),
            "lfoot": (ox + 535, y + leg - 4),
            "rfoot": (ox + 536, y + leg + 14),
        }
    if family == "plank":
        reach = phase >= 2
        return {
            "head": (ox + 210, oy + 322),
            "neck": (ox + 245, oy + 342),
            "hip": (ox + 385, oy + 360),
            "lhand": (ox + (145 if not reach else 108), oy + (452 if not reach else 300)),
            "rhand": (ox + 170, oy + 455),
            "lknee": (ox + 470, oy + 395),
            "rknee": (ox + 470, oy + (395 if not reach else 315)),
            "lfoot": (ox + 560, oy + 455),
            "rfoot": (ox + 560, oy + (455 if not reach else 275)),
        }
    if family == "raise":
        heights = [440, 365, 300, 380]
        foot_y = oy + heights[phase]
        knee_y = oy + (390 if phase == 1 else foot_y + 20)
        return {
            "head": (ox + 310, oy + 170),
            "neck": (ox + 315, oy + 205),
            "hip": (ox + 318, oy + 330),
            "lhand": (ox + 250, oy + 118),
            "rhand": (ox + 375, oy + 118),
            "lknee": (ox + 360, knee_y),
            "rknee": (ox + 340, knee_y + 10),
            "lfoot": (ox + 430, foot_y),
            "rfoot": (ox + 410, foot_y + 18),
        }
    if family == "row":
        top = phase == 2
        brace = phase == 1
        neck_x = ox + (275 if top else 235)
        hip_x = ox + 385
        y = oy + (315 if not brace else 325)
        return {
            "head": (neck_x - 35, y - 12),
            "neck": (neck_x, y),
            "hip": (hip_x, y + 42),
            "lhand": (ox + 268, oy + 118),
            "rhand": (ox + 346, oy + 118),
            "lknee": (ox + 465, y + 66),
            "rknee": (ox + 470, y + 80),
            "lfoot": (ox + 555, y + 116),
            "rfoot": (ox + 558, y + 132),
        }
    if family == "forearm_plank":
        y = oy + 390
        sag = [0, 0, -6, 12][phase]
        return {
            "head": (ox + 168, y - 20),
            "neck": (ox + 208, y),
            "hip": (ox + 380, y + 8 + sag),
            "lhand": (ox + 176, y + 72),
            "rhand": (ox + 220, y + 72),
            "lknee": (ox + 470, y + 24 + sag),
            "rknee": (ox + 475, y + 38 + sag),
            "lfoot": (ox + 565, y + 72),
            "rfoot": (ox + 568, y + 88),
        }
    if family == "crunch":
        curl = [0, -14, -44, -12][phase]
        return {
            "head": (ox + 205, oy + 394 + curl),
            "neck": (ox + 245, oy + 420 + curl),
            "hip": (ox + 335, oy + 448),
            "lhand": (ox + 168, oy + 388 + curl),
            "rhand": (ox + 184, oy + 410 + curl),
            "lknee": (ox + 410, oy + 385),
            "rknee": (ox + 435, oy + 400),
            "lfoot": (ox + 500, oy + 482),
            "rfoot": (ox + 530, oy + 482),
        }
    if family == "reverse_crunch":
        lift = [0, 0, -55, -12][phase]
        return {
            "head": (ox + 190, oy + 430),
            "neck": (ox + 230, oy + 450),
            "hip": (ox + 330, oy + 448 + lift),
            "lhand": (ox + 155, oy + 468),
            "rhand": (ox + 280, oy + 475),
            "lknee": (ox + 405, oy + 350 + lift),
            "rknee": (ox + 430, oy + 365 + lift),
            "lfoot": (ox + 395, oy + 270 + lift),
            "rfoot": (ox + 445, oy + 285 + lift),
        }
    if family == "levitation":
        compact = phase in {1, 2}
        return {
            "head": (ox + (215 if compact else 185), oy + (360 if compact else 400)),
            "neck": (ox + (255 if compact else 235), oy + (390 if compact else 425)),
            "hip": (ox + 338, oy + 438),
            "lhand": (ox + (220 if compact else 120), oy + (345 if compact else 375)),
            "rhand": (ox + (235 if compact else 135), oy + (365 if compact else 395)),
            "lknee": (ox + (405 if compact else 440), oy + (360 if compact else 405)),
            "rknee": (ox + (420 if compact else 445), oy + (382 if compact else 420)),
            "lfoot": (ox + (430 if compact else 545), oy + (330 if compact else 395)),
            "rfoot": (ox + (455 if compact else 548), oy + (350 if compact else 414)),
        }
    if family == "decline_situp":
        up = phase == 2
        lower = phase == 3
        return {
            "head": (ox + (286 if up else 210), oy + (260 if up else 345 + (20 if lower else 0))),
            "neck": (ox + (318 if up else 248), oy + (300 if up else 378 + (12 if lower else 0))),
            "hip": (ox + 366, oy + 438),
            "lhand": (ox + (268 if up else 175), oy + (255 if up else 340)),
            "rhand": (ox + (285 if up else 190), oy + (275 if up else 360)),
            "lknee": (ox + 458, oy + 400),
            "rknee": (ox + 478, oy + 418),
            "lfoot": (ox + 552, oy + 458),
            "rfoot": (ox + 562, oy + 478),
        }
    if family == "inverted_situp":
        curl = phase == 2
        return {
            "head": (ox + (300 if curl else 305), oy + (305 if curl else 380)),
            "neck": (ox + (318 if curl else 315), oy + (340 if curl else 420)),
            "hip": (ox + 318, oy + 500),
            "lhand": (ox + (265 if curl else 250), oy + (330 if curl else 430)),
            "rhand": (ox + (370 if curl else 380), oy + (330 if curl else 430)),
            "lknee": (ox + 285, oy + 158),
            "rknee": (ox + 350, oy + 158),
            "lfoot": (ox + 250, oy + 118),
            "rfoot": (ox + 385, oy + 118),
        }
    if family == "carry":
        lean = [0, 0, 8, 0][phase]
        return {
            "head": (ox + 310 + lean, oy + 228),
            "neck": (ox + 315 + lean, oy + 270),
            "hip": (ox + 320 + lean, oy + 380),
            "lhand": (ox + 245 + lean, oy + 405),
            "rhand": (ox + 395 + lean, oy + 405),
            "lknee": (ox + 285 + lean, oy + 462),
            "rknee": (ox + 365 + lean, oy + 462),
            "lfoot": (ox + 255 + lean, oy + 510),
            "rfoot": (ox + 395 + lean, oy + 510),
        }
    if family == "sled":
        drive = [0, 18, 34, 48][phase]
        return {
            "head": (ox + 205 + drive, oy + 285),
            "neck": (ox + 240 + drive, oy + 315),
            "hip": (ox + 320 + drive, oy + 405),
            "lhand": (ox + 382, oy + 330),
            "rhand": (ox + 500, oy + 330),
            "lknee": (ox + 262 + drive, oy + 485),
            "rknee": (ox + 382 + drive, oy + 465),
            "lfoot": (ox + 210 + drive, oy + 520),
            "rfoot": (ox + 432 + drive, oy + 505),
        }
    if family == "erg":
        catch = phase in {0, 1}
        finish = phase in {2, 3}
        return {
            "head": (ox + (250 if catch else 302), oy + 285),
            "neck": (ox + (275 if catch else 330), oy + 325),
            "hip": (ox + (245 if catch else 265), oy + 430),
            "lhand": (ox + (400 if catch else 342), oy + (330 if catch else 345)),
            "rhand": (ox + (410 if catch else 352), oy + (345 if catch else 360)),
            "lknee": (ox + (350 if catch else 430), oy + (440 if catch else 455)),
            "rknee": (ox + (365 if catch else 438), oy + (458 if catch else 470)),
            "lfoot": (ox + 500, oy + 472),
            "rfoot": (ox + 520, oy + 490),
        }
    if family == "run":
        stride = phase % 2 == 0
        return {
            "head": (ox + 300, oy + 250),
            "neck": (ox + 312, oy + 295),
            "hip": (ox + 315, oy + 385),
            "lhand": (ox + (250 if stride else 380), oy + 330),
            "rhand": (ox + (380 if stride else 250), oy + 345),
            "lknee": (ox + (255 if stride else 370), oy + (455 if stride else 435)),
            "rknee": (ox + (385 if stride else 260), oy + (430 if stride else 465)),
            "lfoot": (ox + (220 if stride else 430), oy + (505 if stride else 488)),
            "rfoot": (ox + (435 if stride else 215), oy + (488 if stride else 510)),
        }
    if family == "bike":
        push = phase in {1, 2}
        return {
            "head": (ox + 310, oy + 205),
            "neck": (ox + 325, oy + 250),
            "hip": (ox + 315, oy + 330),
            "lhand": (ox + 405, oy + 252),
            "rhand": (ox + 388, oy + 292),
            "lknee": (ox + (245 if push else 355), oy + (420 if push else 405)),
            "rknee": (ox + (390 if push else 275), oy + (405 if push else 430)),
            "lfoot": (ox + (205 if push else 405), oy + (465 if push else 455)),
            "rfoot": (ox + (430 if push else 235), oy + (455 if push else 475)),
        }
    if family == "lsit":
        leg_y = [430, 405, 388, 372][phase]
        open_leg = phase >= 2
        return {
            "head": (ox + 252, oy + 332),
            "neck": (ox + 275, oy + 365),
            "hip": (ox + 315, oy + 420),
            "lhand": (ox + 245, oy + 425),
            "rhand": (ox + 340, oy + 425),
            "lknee": (ox + 420, leg_y),
            "rknee": (ox + 420, leg_y + (45 if open_leg else 8)),
            "lfoot": (ox + 540, leg_y),
            "rfoot": (ox + 535, leg_y + (85 if open_leg else 18)),
        }
    if family == "front":
        tuck = phase <= 1
        straddle = phase == 2
        return {
            "head": (ox + 240, oy + 310),
            "neck": (ox + 275, oy + 310),
            "hip": (ox + 360, oy + 315),
            "lhand": (ox + 255, oy + 118),
            "rhand": (ox + 340, oy + 118),
            "lknee": (ox + (415 if tuck else 500), oy + (360 if tuck else 315)),
            "rknee": (ox + (415 if tuck else 500), oy + (345 if tuck else 315)),
            "lfoot": (ox + (390 if tuck else 570), oy + (410 if tuck else (275 if straddle else 315))),
            "rfoot": (ox + (390 if tuck else 570), oy + (385 if tuck else (355 if straddle else 328))),
        }
    if family == "back":
        tuck = phase == 1
        straddle = phase == 2
        return {
            "head": (ox + 240, oy + 310),
            "neck": (ox + 275, oy + 310),
            "hip": (ox + 365, oy + 315),
            "lhand": (ox + 250, oy + 118),
            "rhand": (ox + 335, oy + 118),
            "lknee": (ox + (420 if tuck else 500), oy + (265 if tuck else 315)),
            "rknee": (ox + (420 if tuck else 500), oy + (285 if tuck else 315)),
            "lfoot": (ox + (390 if tuck else 570), oy + (225 if tuck else (275 if straddle else 315))),
            "rfoot": (ox + (390 if tuck else 570), oy + (245 if tuck else (355 if straddle else 328))),
        }
    if family == "german":
        depth = [0, 22, 38, 12][phase]
        return {
            "head": (ox + 304, oy + 382 + depth),
            "neck": (ox + 318, oy + 420 + depth),
            "hip": (ox + 360, oy + 492 + depth),
            "lhand": (ox + 235, oy + 270),
            "rhand": (ox + 390, oy + 270),
            "lknee": (ox + 410, oy + 535 + depth),
            "rknee": (ox + 430, oy + 528 + depth),
            "lfoot": (ox + 468, oy + 570 + depth),
            "rfoot": (ox + 490, oy + 560 + depth),
        }
    if family == "skin":
        if phase == 0:
            return {
                "head": (ox + 310, oy + 315), "neck": (ox + 315, oy + 350), "hip": (ox + 318, oy + 455),
                "lhand": (ox + 235, oy + 270), "rhand": (ox + 390, oy + 270),
                "lknee": (ox + 345, oy + 510), "rknee": (ox + 315, oy + 515),
                "lfoot": (ox + 370, oy + 570), "rfoot": (ox + 300, oy + 570),
            }
        if phase == 1:
            return {
                "head": (ox + 310, oy + 292), "neck": (ox + 315, oy + 325), "hip": (ox + 320, oy + 270),
                "lhand": (ox + 235, oy + 270), "rhand": (ox + 390, oy + 270),
                "lknee": (ox + 275, oy + 210), "rknee": (ox + 365, oy + 210),
                "lfoot": (ox + 250, oy + 160), "rfoot": (ox + 390, oy + 160),
            }
        if phase == 2:
            return pose_points(ox, oy, "german", 2)
        return {
            "head": (ox + 310, oy + 300), "neck": (ox + 315, oy + 335), "hip": (ox + 318, oy + 430),
            "lhand": (ox + 235, oy + 270), "rhand": (ox + 390, oy + 270),
            "lknee": (ox + 345, oy + 485), "rknee": (ox + 315, oy + 490),
            "lfoot": (ox + 370, oy + 535), "rfoot": (ox + 300, oy + 535),
        }
    if family == "three":
        if phase == 0:
            return {
                "head": (ox + 312, oy + 292), "neck": (ox + 315, oy + 330), "hip": (ox + 318, oy + 430),
                "lhand": (ox + 260, oy + 118), "rhand": (ox + 365, oy + 118),
                "lknee": (ox + 350, oy + 500), "rknee": (ox + 315, oy + 505),
                "lfoot": (ox + 375, oy + 560), "rfoot": (ox + 295, oy + 560),
            }
        if phase == 1:
            return {
                "head": (ox + 312, oy + 185), "neck": (ox + 315, oy + 220), "hip": (ox + 318, oy + 330),
                "lhand": (ox + 260, oy + 118), "rhand": (ox + 365, oy + 118),
                "lknee": (ox + 360, oy + 382), "rknee": (ox + 310, oy + 388),
                "lfoot": (ox + 388, oy + 438), "rfoot": (ox + 285, oy + 438),
            }
        if phase == 2:
            return {
                "head": (ox + 332, oy + 212), "neck": (ox + 300, oy + 250), "hip": (ox + 365, oy + 282),
                "lhand": (ox + 245, oy + 250), "rhand": (ox + 392, oy + 245),
                "lknee": (ox + 355, oy + 230), "rknee": (ox + 395, oy + 315),
                "lfoot": (ox + 405, oy + 190), "rfoot": (ox + 460, oy + 335),
            }
        return {
            "head": (ox + 312, oy + 240), "neck": (ox + 315, oy + 275), "hip": (ox + 318, oy + 380),
            "lhand": (ox + 260, oy + 118), "rhand": (ox + 365, oy + 118),
            "lknee": (ox + 350, oy + 445), "rknee": (ox + 315, oy + 450),
            "lfoot": (ox + 375, oy + 505), "rfoot": (ox + 295, oy + 505),
        }
    if family == "dragon":
        angles = [310, 255, 198, 280]
        foot_y = oy + angles[phase]
        return {
            "head": (ox + 190, oy + 395),
            "neck": (ox + 225, oy + 400),
            "hip": (ox + 330, oy + 360),
            "lhand": (ox + 145, oy + 420),
            "rhand": (ox + 160, oy + 392),
            "lknee": (ox + 430, (oy + 330 + foot_y) / 2),
            "rknee": (ox + 430, (oy + 350 + foot_y) / 2),
            "lfoot": (ox + 545, foot_y),
            "rfoot": (ox + 545, foot_y + 20),
        }
    raise ValueError(family)


ASSET_SPECS = [
    ("pp_row", "row", "bar", ["SET ANGLE", "BRACE", "ROW", "LOWER"]),
    ("cal_plank-30", "forearm_plank", "floor", ["STACK", "BRACE", "HOLD", "EXIT"]),
    ("cl_crunch", "crunch", "floor", ["SET", "EXHALE", "CURL", "UNCURL"]),
    ("cl_reverse-crunch", "reverse_crunch", "floor", ["TABLETOP", "BRACE", "CURL", "CONTROL"]),
    ("cl_levitation-crunch", "levitation", "floor", ["HOLLOW", "GATHER", "COMPRESS", "REOPEN"]),
    ("cl_inverted-situp", "inverted_situp", "bar", ["ANCHOR", "BRACE", "CURL", "LOWER"]),
    ("cl_decline-situp", "decline_situp", "bench", ["LOCK IN", "BRACE", "RISE", "DESCEND"]),
    ("co_bw-farmer-carry", "carry", "dumbbells", ["GRIP BASE", "BW LOAD", "WALK", "CALM CARRY"]),
    ("co_1_5x-farmer-carry", "carry", "dumbbells", ["HEAVY SETUP", "LOAD BRIDGE", "1.5X", "PROOF"]),
    ("co_2x-farmer-carry", "carry", "dumbbells", ["MAX BRACE", "HEAVY HOLDS", "2X WALK", "FINISH"]),
    ("co_dead-hang-45", "raise", "bar", ["FIND BAR", "STACK TIME", "45 SEC", "QUIET HANG"]),
    ("co_dead-hang-60", "raise", "bar", ["45 BASE", "GRIP RESERVE", "60 SEC", "DURABLE"]),
    ("co_sled-push", "sled", "sled", ["LEAN LINE", "MOVE SLED", "SUSTAIN", "FINISH"]),
    ("co_400m-row", "erg", "erg", ["SET ERG", "LENGTH", "SPRINT", "LAST 100"]),
    ("co_mile-sub-7", "run", "floor", ["PACE LOCK", "LAP TWO", "MIDDLE", "SUB-7"]),
    ("co_5k-sub-22", "run", "floor", ["GOAL PACE", "START", "MIDRACE", "SUB-22"]),
    ("co_assault-bike-30", "bike", "bike", ["BIKE FIT", "SMOOTH RPM", "30-CAL", "FINAL PUSH"]),
    ("cl_hollow-body-30", "hollow", "floor", ["BRACE", "SHORT HOLLOW", "LONG HOLLOW", "TRANSFER"]),
    ("cl_bird-dog-plank", "plank", "floor", ["STACK", "BRACE", "REACH", "RETURN"]),
    ("cl_superman-plank", "plank", "floor", ["STACK", "BRACE", "LONG LEVER", "RETURN"]),
    ("cl_extended-plank", "plank", "floor", ["REACH", "EXTEND", "END RANGE", "EXIT"]),
    ("cl_knee-ab-rollout", "plank", "floor", ["START", "EXTEND", "END RANGE", "RETURN"]),
    ("cl_standing-ab-rollout", "plank", "floor", ["START", "EXTEND", "END RANGE", "RETURN"]),
    ("cl_knee-raise", "raise", "parallettes", ["SET", "TUCK", "CURL", "LOWER"]),
    ("cl_leg-raise", "raise", "floor", ["SET", "LIFT", "CURL", "LOWER"]),
    ("cl_hanging-knee-raise", "raise", "bar", ["ACTIVE HANG", "TUCK", "CURL", "LOWER"]),
    ("cl_hanging-leg-raise", "raise", "bar", ["ACTIVE HANG", "LIFT", "CURL", "LOWER"]),
    ("cl_toes-to-bar", "raise", "bar", ["ACTIVE HANG", "LIFT", "TOUCH", "LOWER"]),
    ("cal_l-sit-10", "lsit", "parallettes", ["SUPPORT", "TUCK", "EXTEND", "HOLD"]),
    ("cl_semi-straddle-l-sit", "lsit", "parallettes", ["SUPPORT", "TUCK", "OPEN", "HOLD"]),
    ("cl_straddle-l-sit", "lsit", "parallettes", ["SUPPORT", "TUCK", "OPEN", "HOLD"]),
    ("cl_v-sit", "lsit", "parallettes", ["SUPPORT", "TUCK", "EXTEND", "HOLD"]),
    ("cl_vertical-l-sit", "lsit", "parallettes", ["SUPPORT", "TUCK", "EXTEND", "HOLD"]),
    ("cl_tuck-front-lever", "front", "bar", ["TUCK", "OPEN TUCK", "LINE CHECK", "EXIT"]),
    ("cl_straddle-front-lever", "front", "bar", ["TUCK", "OPEN TUCK", "STRADDLE", "EXIT"]),
    ("cl_full-front-lever", "front", "bar", ["TUCK", "OPEN TUCK", "STRADDLE", "FULL LEVER"]),
    ("cl_german-hang", "german", "rings", ["ENTER", "OPEN", "BREATHE", "EXIT"]),
    ("cl_skin-the-cat", "skin", "rings", ["HANG", "INVERT", "PASS", "RETURN"]),
    ("cl_straddle-back-lever", "back", "rings", ["GERMAN HANG", "TUCK", "STRADDLE", "EXIT"]),
    ("cl_full-back-lever", "back", "rings", ["GERMAN HANG", "TUCK", "STRADDLE", "FULL LEVER"]),
    ("cl_three-sixty-pulls", "three", "bar", ["LOAD", "EXPLODE", "ROTATE", "RE-CATCH"]),
    ("cl_dragon-flag-hip-raise", "dragon", "bench", ["ANCHOR", "LIFT", "HIP LINE", "RESET"]),
    ("cl_dragon-flag", "dragon", "bench", ["ANCHOR", "LIFT", "LOWER", "RESET"]),
]


def draw_sheet(prefix: str, family: str, app: str, labels: list[str]) -> Image.Image:
    img = Image.new("RGB", (SHEET, SHEET), BG)
    draw = ImageDraw.Draw(img)
    for i, text in enumerate(labels):
        ox, oy = panel_origin(i)
        draw.rectangle((ox, oy, ox + PANEL, oy + PANEL), fill=PANEL_BG)
        draw.rectangle((ox + 10, oy + 10, ox + PANEL - 10, oy + PANEL - 10), outline=CYAN_DARK, width=2)
        apparatus(draw, ox, oy, app)
        athlete(draw, pose_points(ox, oy, family, i))
        label(draw, ox, oy, text, i + 1)
    draw.line((PANEL + 2, 0, PANEL + 2, SHEET), fill=(11, 30, 34), width=4)
    draw.line((0, PANEL + 2, SHEET, PANEL + 2), fill=(11, 30, 34), width=4)
    return img


def write_asset(prefix: str, family: str, app: str, labels: list[str]) -> None:
    sheet = draw_sheet(prefix, family, app, labels)
    info_dir = INFO_ROOT / f"{prefix}_info.imageset"
    info_name = f"{prefix}_info.png"
    ensure_imageset(info_dir, info_name)
    sheet.save(info_dir / info_name)

    crops = [(0, 0), (PANEL + GAP, 0), (0, PANEL + GAP), (PANEL + GAP, PANEL + GAP)]
    for i, (x, y) in enumerate(crops, start=1):
        phase_dir = ICON_ROOT / f"{prefix}_phase{i}.imageset"
        phase_name = f"{prefix}_phase{i}.png"
        ensure_imageset(phase_dir, phase_name)
        sheet.crop((x, y, x + PANEL, y + PANEL)).save(phase_dir / phase_name)


def main() -> None:
    for spec in ASSET_SPECS:
        write_asset(*spec)
    print(f"Generated {len(ASSET_SPECS)} UNBOUND core/lever sheets and {len(ASSET_SPECS) * 4} phase panels.")


if __name__ == "__main__":
    main()
