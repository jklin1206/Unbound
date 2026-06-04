#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
from scipy import ndimage
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BODYMAP_DIR = PROJECT_ROOT / "UNBOUND" / "Resources" / "BodyMap"

SOURCE_IMAGES = {
    "front": Path("/Users/jlin/Downloads/frontmap.png"),
    "back": Path("/Users/jlin/Downloads/backmap.png"),
}

REFERENCE_COPIES = {
    "front": BODYMAP_DIR / "source_frontmap.png",
    "back": BODYMAP_DIR / "source_backmap.png",
}

CLEAN_CHARACTER_COPIES = {
    "front": BODYMAP_DIR / "source_frontmap_character_base.png",
    "back": BODYMAP_DIR / "source_backmap_character_base.png",
}


@dataclass(frozen=True)
class PaletteLayer:
    key: str
    label: str
    region: str
    rgb: tuple[int, int, int]

    @property
    def hex(self) -> str:
        return "#{:02x}{:02x}{:02x}".format(*self.rgb)


PALETTE = [
    PaletteLayer("red", "Red marker", "chest_traps", (237, 28, 36)),
    PaletteLayer("green", "Green marker", "shoulders_triceps", (34, 177, 76)),
    PaletteLayer("orange", "Orange marker", "biceps_lats", (255, 127, 39)),
    PaletteLayer("yellow", "Yellow marker", "quads_forearms", (255, 242, 0)),
    PaletteLayer("blue", "Blue marker", "abs_core", (63, 72, 204)),
    PaletteLayer("cyan", "Cyan marker", "lower_back", (0, 162, 232)),
    PaletteLayer("purple", "Purple marker", "obliques_glutes", (163, 73, 164)),
    PaletteLayer("maroon", "Maroon marker", "forearms_hamstrings", (136, 0, 21)),
    PaletteLayer("pink", "Pink marker", "calves", (255, 174, 201)),
]

VIEW_REGION_OVERRIDES = {
    "front": {
        "red": "chest",
        "green": "deltoids",
        "orange": "biceps",
        "yellow": "quads",
        "blue": "abs",
        "cyan": "lower_back",
        "purple": "obliques",
        "maroon": "forearms",
        "pink": "calves",
    },
    "back": {
        "red": "traps_upper_back",
        "green": "triceps",
        "orange": "lats",
        "yellow": "forearms",
        "blue": "abs_core",
        "cyan": "lower_back",
        "purple": "glutes",
        "maroon": "hamstrings",
        "pink": "calves",
    },
}

CLEAN_CENTER_X = 640
CLEAN_VIEWBOX = (1280, 1908)

CLEAN_REGIONS = {
    "front": [
        {
            "region": "deltoids",
            "color": "#22b14c",
            "opacity": "0.78",
            "paths": [
                {
                    "side": "left",
                    "d": "M 510 340 C 462 323 410 343 374 380 C 341 414 333 462 355 495 C 385 486 409 455 421 417 C 434 377 469 350 510 340 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "chest",
            "color": "#ed1c24",
            "opacity": "0.78",
            "paths": [
                {
                    "side": "left",
                    "d": "M 501 373 C 458 374 424 397 410 434 C 395 473 416 509 455 528 C 499 548 560 526 608 482 C 621 464 621 415 600 391 C 572 376 535 371 501 373 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "biceps",
            "color": "#ff7f27",
            "opacity": "0.74",
            "paths": [
                {
                    "side": "left",
                    "d": "M 346 471 C 315 506 303 570 317 621 C 332 649 374 632 398 582 C 421 534 410 487 379 468 C 367 462 356 464 346 471 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "forearms",
            "color": "#880015",
            "opacity": "0.78",
            "paths": [
                {
                    "side": "left",
                    "d": "M 286 614 C 258 684 254 789 279 870 C 300 889 342 858 357 802 C 365 726 344 647 313 609 C 302 596 292 600 286 614 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "obliques",
            "color": "#a349a4",
            "opacity": "0.62",
            "paths": [
                {
                    "side": "left",
                    "d": "M 434 548 C 474 576 497 617 503 666 C 509 722 488 765 456 792 C 423 764 406 704 405 654 C 403 604 414 568 434 548 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "abs",
            "color": "#3f48cc",
            "opacity": "0.66",
            "paths": [
                {"side": "left-top", "d": "M 523 533 C 555 519 594 522 625 536 L 619 587 C 584 582 551 575 523 562 Z"},
                {"side": "right-top", "d": "M 757 533 C 725 519 686 522 655 536 L 661 587 C 696 582 729 575 757 562 Z"},
                {"side": "left-mid", "d": "M 521 612 C 552 604 587 606 620 617 L 620 668 C 586 670 553 663 522 649 Z"},
                {"side": "right-mid", "d": "M 759 612 C 728 604 693 606 660 617 L 660 668 C 694 670 727 663 758 649 Z"},
                {"side": "left-low", "d": "M 524 702 C 556 695 589 699 620 711 L 619 763 C 588 760 560 748 533 728 Z"},
                {"side": "right-low", "d": "M 756 702 C 724 695 691 699 660 711 L 661 763 C 692 760 720 748 747 728 Z"},
                {"side": "center-low", "d": "M 560 785 C 588 801 615 809 640 809 C 665 809 692 801 720 785 C 704 823 678 847 640 854 C 602 847 576 823 560 785 Z"},
            ],
        },
        {
            "region": "quads",
            "color": "#fff200",
            "opacity": "0.70",
            "paths": [
                {
                    "side": "left",
                    "d": "M 478 826 C 435 889 407 984 402 1082 C 397 1170 429 1246 470 1253 C 503 1265 536 1240 545 1186 C 550 1081 522 940 478 826 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "calves",
            "color": "#ffaec9",
            "opacity": "0.70",
            "paths": [
                {
                    "side": "left",
                    "d": "M 518 1348 C 550 1411 561 1504 539 1583 C 522 1642 474 1667 464 1616 C 469 1527 487 1421 518 1348 Z",
                    "mirror": True,
                },
            ],
        },
    ],
    "back": [
        {
            "region": "traps_upper_back",
            "color": "#ed1c24",
            "opacity": "0.72",
            "paths": [
                {
                    "side": "center",
                    "d": "M 580 244 C 560 287 511 318 458 348 C 414 373 376 395 344 416 C 386 432 424 456 455 489 C 498 535 563 562 625 565 L 640 587 L 655 565 C 717 562 782 535 825 489 C 856 456 894 432 936 416 C 904 395 866 373 822 348 C 769 318 720 287 700 244 C 665 236 615 236 580 244 Z",
                }
            ],
        },
        {
            "region": "triceps",
            "color": "#22b14c",
            "opacity": "0.74",
            "paths": [
                {
                    "side": "left",
                    "d": "M 407 439 C 351 449 315 511 311 588 C 309 646 342 678 384 657 C 420 598 436 511 407 439 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "lats",
            "color": "#ff7f27",
            "opacity": "0.66",
            "paths": [
                {
                    "side": "left",
                    "d": "M 432 548 C 477 565 532 566 580 548 C 586 633 560 735 509 808 C 463 750 427 642 432 548 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "forearms",
            "color": "#fff200",
            "opacity": "0.70",
            "paths": [
                {
                    "side": "left",
                    "d": "M 298 694 C 333 725 352 791 351 856 C 350 913 327 950 292 939 C 276 866 274 765 298 694 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "lower_back",
            "color": "#00a2e8",
            "opacity": "0.66",
            "paths": [
                {
                    "side": "center",
                    "d": "M 576 650 C 614 636 666 636 704 650 C 733 704 724 765 677 815 C 657 834 623 834 603 815 C 556 765 547 704 576 650 Z",
                }
            ],
        },
        {
            "region": "glutes",
            "color": "#a349a4",
            "opacity": "0.68",
            "paths": [
                {
                    "side": "left",
                    "d": "M 631 852 C 558 853 495 890 457 953 C 484 1008 561 1030 631 994 C 641 950 642 892 631 852 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "hamstrings",
            "color": "#880015",
            "opacity": "0.72",
            "paths": [
                {
                    "side": "left",
                    "d": "M 421 1034 C 478 1049 526 1095 540 1152 C 550 1228 528 1313 499 1359 C 456 1356 416 1328 407 1273 C 394 1187 398 1104 421 1034 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "calves",
            "color": "#ffaec9",
            "opacity": "0.70",
            "paths": [
                {
                    "side": "left",
                    "d": "M 470 1360 C 435 1423 423 1517 446 1599 C 464 1648 515 1652 532 1598 C 547 1507 525 1409 470 1360 Z",
                    "mirror": True,
                },
            ],
        },
    ],
}

CRISP_REGIONS = {
    "front": [
        {
            "region": "deltoids",
            "color": "#22b14c",
            "paths": [
                {
                    "side": "left",
                    "d": "M 505 341 C 460 326 405 346 365 386 C 329 421 323 467 349 501 C 381 490 407 457 421 414 C 434 374 466 350 505 341 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "chest",
            "color": "#ed1c24",
            "paths": [
                {
                    "side": "left",
                    "d": "M 498 376 C 454 378 417 400 402 437 C 384 482 411 523 457 541 C 508 561 571 534 614 488 C 626 461 621 416 594 393 C 567 380 530 374 498 376 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "biceps",
            "color": "#ff7f27",
            "paths": [
                {
                    "side": "left",
                    "d": "M 356 466 C 323 496 306 558 314 613 C 322 652 360 661 394 623 C 428 580 433 516 398 478 C 386 466 370 461 356 466 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "forearms",
            "color": "#880015",
            "paths": [
                {
                    "side": "left",
                    "d": "M 286 593 C 254 660 247 782 274 884 C 302 903 348 868 363 805 C 374 731 353 641 316 592 C 304 578 293 580 286 593 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "obliques",
            "color": "#a349a4",
            "paths": [
                {
                    "side": "left",
                    "d": "M 438 520 C 472 545 498 588 508 641 C 519 699 498 758 462 797 C 426 765 405 706 403 650 C 401 594 415 549 438 520 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "abs",
            "color": "#3f48cc",
            "paths": [
                {"side": "outer", "d": "M 515 523 C 556 504 606 506 640 529 C 674 506 724 504 765 523 C 767 640 752 745 718 822 C 691 857 667 871 640 875 C 613 871 589 857 562 822 C 528 745 513 640 515 523 Z"},
                {"side": "left-top", "d": "M 525 541 C 557 525 594 528 624 543 L 619 598 C 585 593 552 585 524 569 Z"},
                {"side": "right-top", "d": "M 755 541 C 723 525 686 528 656 543 L 661 598 C 695 593 728 585 756 569 Z"},
                {"side": "left-mid", "d": "M 520 618 C 553 609 587 611 621 623 L 621 681 C 586 684 553 676 522 661 Z"},
                {"side": "right-mid", "d": "M 760 618 C 727 609 693 611 659 623 L 659 681 C 694 684 727 676 758 661 Z"},
                {"side": "left-low", "d": "M 526 705 C 557 697 590 700 621 714 L 620 773 C 590 769 562 756 535 733 Z"},
                {"side": "right-low", "d": "M 754 705 C 723 697 690 700 659 714 L 660 773 C 690 769 718 756 745 733 Z"},
            ],
        },
        {
            "region": "quads",
            "color": "#fff200",
            "paths": [
                {
                    "side": "left",
                    "d": "M 478 811 C 430 873 403 980 398 1085 C 394 1178 428 1254 470 1270 C 506 1264 539 1222 548 1162 C 547 1054 522 925 478 811 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "calves",
            "color": "#ffaec9",
            "paths": [
                {
                    "side": "left",
                    "d": "M 519 1324 C 555 1387 569 1498 543 1595 C 525 1653 470 1680 459 1618 C 465 1517 484 1406 519 1324 Z",
                    "mirror": True,
                },
            ],
        },
    ],
    "back": [
        {
            "region": "traps_upper_back",
            "color": "#ed1c24",
            "paths": [
                {
                    "side": "center",
                    "d": "M 584 320 L 540 322 C 505 345 451 371 400 402 C 361 426 333 449 321 473 C 373 493 421 522 458 568 C 498 618 529 684 608 714 C 627 722 653 722 672 714 C 751 684 782 618 822 568 C 859 522 907 493 959 473 C 947 449 919 426 880 402 C 829 371 775 345 740 322 L 696 320 C 690 362 672 405 640 452 C 608 405 590 362 584 320 Z",
                },
            ],
        },
        {
            "region": "triceps",
            "color": "#22b14c",
            "paths": [
                {
                    "side": "left",
                    "d": "M 405 443 C 352 454 317 513 313 590 C 310 649 342 681 385 658 C 420 601 435 515 405 443 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "lats",
            "color": "#ff7f27",
            "paths": [
                {
                    "side": "left",
                    "d": "M 430 520 C 478 542 540 543 590 518 C 603 620 577 733 510 825 C 463 761 426 638 430 520 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "forearms",
            "color": "#fff200",
            "paths": [
                {
                    "side": "left",
                    "d": "M 294 650 C 334 684 359 766 360 850 C 360 922 333 970 289 956 C 268 876 265 745 294 650 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "lower_back",
            "color": "#00a2e8",
            "paths": [
                {
                    "side": "center",
                    "d": "M 571 624 C 612 608 668 608 709 624 C 744 685 733 761 680 824 C 658 846 622 846 600 824 C 547 761 536 685 571 624 Z",
                },
            ],
        },
        {
            "region": "glutes",
            "color": "#a349a4",
            "paths": [
                {
                    "side": "left",
                    "d": "M 637 810 C 557 806 488 855 452 936 C 482 1008 559 1037 637 1001 C 652 951 653 862 637 810 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "hamstrings",
            "color": "#880015",
            "paths": [
                {
                    "side": "left",
                    "d": "M 421 960 C 478 986 536 1036 552 1107 C 568 1192 538 1289 505 1368 C 458 1369 407 1337 395 1276 C 381 1178 386 1047 421 960 Z",
                    "mirror": True,
                },
            ],
        },
        {
            "region": "calves",
            "color": "#ffaec9",
            "paths": [
                {
                    "side": "left",
                    "d": "M 468 1326 C 429 1385 413 1517 439 1605 C 458 1660 525 1665 544 1607 C 563 1504 538 1378 468 1326 Z",
                    "mirror": True,
                },
            ],
        },
    ],
}

MIRRORED_TRACE_SOURCE_HALF = {
    "front": "right",
    "back": "right",
}

FILLED_REGION_PATH_OVERRIDES = {}

ANATOMY_DETAIL_COLORS = {
    "front": {
        "chest": "#ed1c24",
        "deltoids": "#22b14c",
        "biceps": "#ff7f27",
        "forearm": "#880015",
        "abs": "#3f48cc",
        "obliques": "#a349a4",
        "quadriceps": "#fff200",
        "tibialis": "#ffaec9",
        "calves": "#ffaec9",
    },
    "back": {
        "trapezius": "#ed1c24",
        "upper-back": "#ff7f27",
        "lower-back": "#00a2e8",
        "deltoids": "#22b14c",
        "triceps": "#22b14c",
        "forearm": "#fff200",
        "gluteal": "#a349a4",
        "hamstring": "#880015",
        "calves": "#ffaec9",
    },
}

ANATOMY_REGION_NAMES = {
    "chest": "chest",
    "deltoids": "deltoids",
    "biceps": "biceps",
    "triceps": "triceps",
    "forearm": "forearms",
    "abs": "abs",
    "obliques": "obliques",
    "quadriceps": "quads",
    "adductors": "adductors",
    "tibialis": "calves",
    "calves": "calves",
    "trapezius": "traps_upper_back",
    "upper-back": "lats_upper_back",
    "lower-back": "lower_back",
    "gluteal": "glutes",
    "hamstring": "hamstrings",
}


def escape_attr(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace('"', "&quot;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def normalize_svg_path(path_data: str) -> str:
    tokens: list[str] = []
    index = 0
    length = len(path_data)

    while index < length:
        char = path_data[index]
        if char.isspace() or char == ",":
            index += 1
            continue

        if char.isalpha():
            tokens.append(char)
            index += 1
            continue

        number = ""
        if char in "+-":
            number += char
            index += 1

        has_dot = False
        has_exponent = False
        while index < length:
            next_char = path_data[index]

            if next_char.isdigit():
                number += next_char
                index += 1
                continue

            if next_char == "." and not has_dot and not has_exponent:
                has_dot = True
                number += next_char
                index += 1
                continue

            if next_char in "eE" and not has_exponent:
                has_exponent = True
                number += next_char
                index += 1
                if index < length and path_data[index] in "+-":
                    number += path_data[index]
                    index += 1
                continue

            break

        if number in {"", "+", "-"}:
            # Preserve unusual characters rather than failing the full asset build.
            tokens.append(char)
            index += 1
        else:
            tokens.append(number)

    return " ".join(tokens)


def contour_to_path(contour: np.ndarray, epsilon: float) -> str:
    approx = cv2.approxPolyDP(contour, epsilon, True)
    points = approx.reshape(-1, 2)
    if len(points) < 3:
        return ""

    start = points[0]
    commands = [f"M {int(start[0])} {int(start[1])}"]
    commands.extend(f"L {int(x)} {int(y)}" for x, y in points[1:])
    commands.append("Z")
    return " ".join(commands)


def mask_for_layer(image_rgb: np.ndarray, layer: PaletteLayer) -> np.ndarray:
    hsv = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2HSV)
    saturation = hsv[:, :, 1]
    value = hsv[:, :, 2]
    candidates = (saturation > 55) & (value > 35)

    palette_rgb = np.array([item.rgb for item in PALETTE], dtype=np.float32)
    pixels = image_rgb.astype(np.float32)
    distances = np.sqrt(((pixels[:, :, None, :] - palette_rgb[None, None, :, :]) ** 2).sum(axis=3))
    nearest = distances.argmin(axis=2)
    min_distance = distances.min(axis=2)
    layer_index = next(index for index, item in enumerate(PALETTE) if item.key == layer.key)

    mask = candidates & (nearest == layer_index) & (min_distance < 115)
    mask = (mask.astype(np.uint8) * 255)
    mask = cv2.medianBlur(mask, 3)

    close_kernel = np.ones((5, 5), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, close_kernel, iterations=1)
    return mask


def mirror_mask_half(mask: np.ndarray, source_half: str, center_x: int = CLEAN_CENTER_X) -> np.ndarray:
    height, width = mask.shape
    if center_x * 2 != width:
        raise ValueError(f"Expected centered source width, got width={width}, center_x={center_x}")

    mirrored = np.zeros_like(mask)
    if source_half == "right":
        source = mask[:, center_x:width]
        mirrored[:, center_x:width] = source
        mirrored[:, :center_x] = np.fliplr(source)
        return mirrored

    if source_half == "left":
        source = mask[:, :center_x]
        mirrored[:, :center_x] = source
        mirrored[:, center_x:width] = np.fliplr(source)
        return mirrored

    raise ValueError(f"Unsupported source_half={source_half!r}")


def marker_mask(image_rgb: np.ndarray) -> np.ndarray:
    combined = np.zeros(image_rgb.shape[:2], dtype=np.uint8)
    for layer in PALETTE:
        combined = cv2.bitwise_or(combined, mask_for_layer(image_rgb, layer))

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    combined = cv2.dilate(combined, kernel, iterations=2)
    combined = cv2.morphologyEx(combined, cv2.MORPH_CLOSE, kernel, iterations=1)
    return combined


def write_clean_character_base(view: str, image_rgb: np.ndarray) -> None:
    mask = marker_mask(image_rgb)
    cleaned = cv2.inpaint(image_rgb, mask, 5, cv2.INPAINT_TELEA)

    gray = cv2.cvtColor(cleaned, cv2.COLOR_RGB2GRAY)
    linework = (gray < 105).astype(np.uint8) * 255
    linework = cv2.dilate(linework, np.ones((3, 3), np.uint8), iterations=1)
    passable = np.where(linework > 0, 0, 255).astype(np.uint8)
    flood = passable.copy()

    height, width = flood.shape
    seeds = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    for x, y in seeds:
        if flood[y, x] == 255:
            cv2.floodFill(flood, None, (x, y), 128)

    # Sweep each border to catch checkerboard islands that are not connected to a corner.
    for x in range(width):
        if flood[0, x] == 255:
            cv2.floodFill(flood, None, (x, 0), 128)
        if flood[height - 1, x] == 255:
            cv2.floodFill(flood, None, (x, height - 1), 128)
    for y in range(height):
        if flood[y, 0] == 255:
            cv2.floodFill(flood, None, (0, y), 128)
        if flood[y, width - 1] == 255:
            cv2.floodFill(flood, None, (width - 1, y), 128)

    background = flood == 128
    background = cv2.dilate(background.astype(np.uint8), np.ones((2, 2), np.uint8), iterations=1).astype(bool)
    alpha = np.full((height, width), 255, dtype=np.uint8)
    alpha[background] = 0
    rgba = np.dstack([cleaned, alpha])
    Image.fromarray(rgba).save(CLEAN_CHARACTER_COPIES[view])


def contours_for_mask(mask: np.ndarray, faithful_strokes: bool) -> list[np.ndarray]:
    mode = cv2.RETR_CCOMP if faithful_strokes else cv2.RETR_EXTERNAL
    contours, _hierarchy = cv2.findContours(mask, mode, cv2.CHAIN_APPROX_SIMPLE)
    min_area = 35 if faithful_strokes else 120
    return [contour for contour in contours if cv2.contourArea(contour) >= min_area]


def layer_path_data(mask: np.ndarray, faithful_strokes: bool) -> str:
    if not faithful_strokes:
        close_kernel = np.ones((13, 13), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, close_kernel, iterations=2)
        mask = ndimage.binary_fill_holes(mask > 0).astype(np.uint8) * 255
        open_kernel = np.ones((3, 3), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, open_kernel, iterations=1)

    contours = contours_for_mask(mask, faithful_strokes)
    epsilon = 1.25 if faithful_strokes else 2.2
    paths = [contour_to_path(contour, epsilon) for contour in contours]
    return " ".join(path for path in paths if path)


def filled_region_path_data(mask: np.ndarray) -> str:
    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, close_kernel, iterations=2)
    mask = ndimage.binary_fill_holes(mask > 0).astype(np.uint8) * 255
    open_kernel = np.ones((3, 3), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, open_kernel, iterations=1)

    contours = contours_for_mask(mask, faithful_strokes=False)
    paths = [contour_to_path(contour, epsilon=2.1) for contour in contours]
    return " ".join(path for path in paths if path)


def render_svg(
    *,
    view: str,
    width: int,
    height: int,
    paths_by_layer: dict[str, str],
    faithful_strokes: bool,
    include_reference: bool,
) -> str:
    mode = "stroke trace" if faithful_strokes else "filled region trace"
    title = f"{view.title()} source bodymap {mode}"
    reference = ""
    if include_reference:
        href = REFERENCE_COPIES[view].name
        reference = (
            f'  <image class="source-reference" href="./{href}" x="0" y="0" '
            f'width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        )

    body = []
    for layer in PALETTE:
        d = paths_by_layer.get(layer.key)
        if not d:
            continue

        region = VIEW_REGION_OVERRIDES[view].get(layer.key, layer.region)
        opacity = "0.92" if faithful_strokes else "0.58"
        body.append(
            f'  <path id="{view}-{layer.key}-{region}" class="source-region" '
            f'data-view="{view}" data-color="{layer.key}" data-region="{region}" '
            f'fill="{layer.hex}" fill-opacity="{opacity}" fill-rule="evenodd" '
            f'd="{escape_attr(d)}">\n'
            f"    <title>{view.title()} {region.replace('_', ' ')}</title>\n"
            f"  </path>"
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="{view}-source-title {view}-source-desc">\n'
        f'  <title id="{view}-source-title">{escape_attr(title)}</title>\n'
        f'  <desc id="{view}-source-desc">Vectorized marker-color layers traced from the supplied {view} PNG.</desc>\n'
        "  <style>\n"
        "    .source-reference { opacity: 0.24; }\n"
        "    .source-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f"{reference}"
        + "\n".join(body)
        + "\n</svg>\n"
    )


def render_character_trace_svg(
    *,
    view: str,
    width: int,
    height: int,
    paths_by_layer: dict[str, str],
) -> str:
    base_href = CLEAN_CHARACTER_COPIES[view].name
    body = []
    for layer in PALETTE:
        d = paths_by_layer.get(layer.key)
        if not d:
            continue

        region = VIEW_REGION_OVERRIDES[view].get(layer.key, layer.region)
        body.append(
            f'  <path id="character-trace-{view}-{layer.key}-{region}" class="character-trace-region" '
            f'data-view="{view}" data-color="{layer.key}" data-region="{region}" '
            f'fill="{layer.hex}" fill-opacity="0.92" fill-rule="evenodd" '
            f'd="{escape_attr(d)}">\n'
            f"    <title>{view.title()} {region.replace('_', ' ')}</title>\n"
            f"  </path>"
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="character-trace-{view}-title character-trace-{view}-desc">\n'
        f'  <title id="character-trace-{view}-title">Marker-style {view} heatmap on supplied character</title>\n'
        f'  <desc id="character-trace-{view}-desc">Vectorized marker-style heatmap regions over the supplied {view} body character.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-trace-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <image class="character-base" href="./{base_href}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        + "\n".join(body)
        + "\n</svg>\n"
    )


def render_pair_preview(front_svg_body: str, back_svg_body: str, width: int, height: int) -> str:
    gap = 120
    pair_width = width * 2 + gap
    # Extract only image/path content from generated documents.
    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="source-pair-title source-pair-desc">\n'
        '  <title id="source-pair-title">Source bodymap SVG trace pair</title>\n'
        '  <desc id="source-pair-desc">Front and back marker-color traces over faint references from the supplied PNGs.</desc>\n'
        "  <style>\n"
        "    .source-reference { opacity: 0.20; }\n"
        "    .source-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <g id="front-source-trace">\n{content(front_svg_body)}\n  </g>\n'
        f'  <g id="back-source-trace" transform="translate({width + gap} 0)">\n{content(back_svg_body)}\n  </g>\n'
        "</svg>\n"
    )


def render_character_trace_pair_preview(front_svg_body: str, back_svg_body: str, width: int, height: int) -> str:
    gap = 120
    pair_width = width * 2 + gap

    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="character-trace-pair-title character-trace-pair-desc">\n'
        '  <title id="character-trace-pair-title">Marker-style body heatmap on supplied character pair</title>\n'
        '  <desc id="character-trace-pair-desc">Front and back vectorized marker-style heatmaps over the supplied character images.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-trace-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <g id="character-trace-front-map">\n{content(front_svg_body)}\n  </g>\n'
        f'  <g id="character-trace-back-map" transform="translate({width + gap} 0)">\n{content(back_svg_body)}\n  </g>\n'
        "</svg>\n"
    )


def render_character_mirrored_trace_svg(
    *,
    view: str,
    width: int,
    height: int,
    paths_by_layer: dict[str, str],
    source_half: str,
) -> str:
    base_href = CLEAN_CHARACTER_COPIES[view].name
    body = []
    for layer in PALETTE:
        d = paths_by_layer.get(layer.key)
        if not d:
            continue

        region = VIEW_REGION_OVERRIDES[view].get(layer.key, layer.region)
        body.append(
            f'  <path id="character-mirrored-trace-{view}-{layer.key}-{region}" '
            f'class="character-mirrored-trace-region" data-view="{view}" '
            f'data-color="{layer.key}" data-region="{region}" data-source-half="{source_half}" '
            f'fill="{layer.hex}" fill-opacity="0.92" fill-rule="evenodd" '
            f'd="{escape_attr(d)}">\n'
            f"    <title>{view.title()} mirrored {region.replace('_', ' ')}</title>\n"
            f"  </path>"
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="character-mirrored-trace-{view}-title character-mirrored-trace-{view}-desc">\n'
        f'  <title id="character-mirrored-trace-{view}-title">Mirrored marker-style {view} heatmap on supplied character</title>\n'
        f'  <desc id="character-mirrored-trace-{view}-desc">The supplied {view} marker strokes with the {source_half} half mirrored for left-right consistency.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-mirrored-trace-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <image class="character-base" href="./{base_href}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        + "\n".join(body)
        + "\n</svg>\n"
    )


def render_character_mirrored_trace_pair_preview(front_svg_body: str, back_svg_body: str, width: int, height: int) -> str:
    gap = 120
    pair_width = width * 2 + gap

    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="character-mirrored-trace-pair-title character-mirrored-trace-pair-desc">\n'
        '  <title id="character-mirrored-trace-pair-title">Mirrored marker-style body heatmap on supplied character pair</title>\n'
        '  <desc id="character-mirrored-trace-pair-desc">Front and back supplied marker strokes with the cleaner half mirrored for consistency.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-mirrored-trace-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <g id="character-mirrored-trace-front-map">\n{content(front_svg_body)}\n  </g>\n'
        f'  <g id="character-mirrored-trace-back-map" transform="translate({width + gap} 0)">\n{content(back_svg_body)}\n  </g>\n'
        "</svg>\n"
    )


def render_character_mirrored_filled_svg(
    *,
    view: str,
    width: int,
    height: int,
    filled_paths_by_layer: dict[str, str],
    stroke_paths_by_layer: dict[str, str],
    source_half: str,
) -> str:
    base_href = CLEAN_CHARACTER_COPIES[view].name
    fills = []
    strokes = []
    for layer in PALETTE:
        region = VIEW_REGION_OVERRIDES[view].get(layer.key, layer.region)
        override_paths = FILLED_REGION_PATH_OVERRIDES.get((view, layer.key))
        fill_opacity = "1" if override_paths else "0.42"
        filled_paths = override_paths if override_paths else [filled_paths_by_layer.get(layer.key)]
        for fill_index, filled_d in enumerate((path for path in filled_paths if path), 1):
            fill_suffix = f"fill-{fill_index}" if len(filled_paths) > 1 else "fill"
            fills.append(
                f'  <path id="character-mirrored-filled-{view}-{layer.key}-{region}-{fill_suffix}" '
                f'class="character-mirrored-filled-region" data-view="{view}" '
                f'data-color="{layer.key}" data-region="{region}" data-source-half="{source_half}" '
                f'fill="{layer.hex}" fill-opacity="{fill_opacity}" stroke="none" '
                f'd="{escape_attr(filled_d)}">\n'
                f"    <title>{view.title()} filled {region.replace('_', ' ')}</title>\n"
                f"  </path>"
            )

        stroke_d = stroke_paths_by_layer.get(layer.key)
        if stroke_d:
            strokes.append(
                f'  <path id="character-mirrored-filled-{view}-{layer.key}-{region}-stroke" '
                f'class="character-mirrored-filled-stroke" data-view="{view}" '
                f'data-color="{layer.key}" data-region="{region}" data-source-half="{source_half}" '
                f'fill="{layer.hex}" fill-opacity="0.94" fill-rule="evenodd" '
                f'd="{escape_attr(stroke_d)}" />'
            )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="character-mirrored-filled-{view}-title character-mirrored-filled-{view}-desc">\n'
        f'  <title id="character-mirrored-filled-{view}-title">Filled mirrored marker-style {view} heatmap on supplied character</title>\n'
        f'  <desc id="character-mirrored-filled-{view}-desc">The supplied {view} marker strokes filled in after mirroring the {source_half} half for left-right consistency.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-mirrored-filled-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "    .character-mirrored-filled-stroke { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <image class="character-base" href="./{base_href}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        '  <g id="filled-region-layer">\n'
        + "\n".join(fills)
        + "\n  </g>\n"
        '  <g id="mirrored-stroke-layer">\n'
        + "\n".join(strokes)
        + "\n  </g>\n"
        "</svg>\n"
    )


def render_character_mirrored_filled_pair_preview(front_svg_body: str, back_svg_body: str, width: int, height: int) -> str:
    gap = 120
    pair_width = width * 2 + gap

    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="character-mirrored-filled-pair-title character-mirrored-filled-pair-desc">\n'
        '  <title id="character-mirrored-filled-pair-title">Filled mirrored marker-style body heatmap on supplied character pair</title>\n'
        '  <desc id="character-mirrored-filled-pair-desc">Front and back supplied marker strokes filled in after mirroring the cleaner half for consistency.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-mirrored-filled-region { stroke: none; shape-rendering: geometricPrecision; }\n"
        "    .character-mirrored-filled-stroke { stroke: none; shape-rendering: geometricPrecision; }\n"
        "  </style>\n"
        f'  <g id="character-mirrored-filled-front-map">\n{content(front_svg_body)}\n  </g>\n'
        f'  <g id="character-mirrored-filled-back-map" transform="translate({width + gap} 0)">\n{content(back_svg_body)}\n  </g>\n'
        "</svg>\n"
    )


def render_clean_region_path(view: str, item: dict, path_item: dict, index: int) -> str:
    side = path_item["side"]
    region = item["region"]
    transform = ""
    rendered_side = side
    if path_item.get("mirrored"):
        rendered_side = "right" if side == "left" else f"{side}-mirrored"
        transform = f' transform="translate({CLEAN_CENTER_X * 2} 0) scale(-1 1)"'

    return (
        f'    <path id="clean-{view}-{region}-{rendered_side}-{index}" '
        f'data-view="{view}" data-region="{region}" data-side="{rendered_side}" '
        f'fill="{item["color"]}" fill-opacity="{item["opacity"]}" '
        f'stroke="rgba(255,255,255,0.72)" stroke-width="5" stroke-linejoin="round" '
        f'stroke-linecap="round"{transform} d="{escape_attr(path_item["d"])}" />'
    )


def render_clean_svg(view: str, include_reference: bool = False) -> str:
    width, height = CLEAN_VIEWBOX
    reference = ""
    if include_reference:
        href = REFERENCE_COPIES[view].name
        reference = (
            f'  <image class="source-reference" href="./{href}" x="0" y="0" '
            f'width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        )

    groups = []
    for item in CLEAN_REGIONS[view]:
        paths = []
        for index, path_item in enumerate(item["paths"], 1):
            paths.append(render_clean_region_path(view, item, path_item, index))
            if path_item.get("mirror"):
                mirrored = {**path_item, "mirrored": True}
                paths.append(render_clean_region_path(view, item, mirrored, index + 100))

        groups.append(
            f'  <g id="clean-{view}-{item["region"]}" class="clean-region-group" '
            f'data-view="{view}" data-region="{item["region"]}">\n'
            + "\n".join(paths)
            + "\n  </g>"
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="clean-{view}-title clean-{view}-desc">\n'
        f'  <title id="clean-{view}-title">Clean symmetric {view} body heatmap regions</title>\n'
        f'  <desc id="clean-{view}-desc">Smoothed and mirrored SVG heatmap regions redrawn from the supplied {view} sketch.</desc>\n'
        "  <style>\n"
        "    .source-reference { opacity: 0.18; }\n"
        "    .clean-region-group path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f"{reference}"
        + "\n".join(groups)
        + "\n</svg>\n"
    )


def render_clean_pair_preview() -> str:
    width, height = CLEAN_VIEWBOX
    gap = 120
    pair_width = width * 2 + gap

    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    front = content(render_clean_svg("front", include_reference=True))
    back = content(render_clean_svg("back", include_reference=True))

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="clean-pair-title clean-pair-desc">\n'
        '  <title id="clean-pair-title">Clean symmetric body heatmap pair</title>\n'
        '  <desc id="clean-pair-desc">Front and back cleaned heatmap regions over faint references from the supplied PNGs.</desc>\n'
        "  <style>\n"
        "    .source-reference { opacity: 0.18; }\n"
        "    .clean-region-group path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f'  <g id="clean-front-map">\n{front}\n  </g>\n'
        f'  <g id="clean-back-map" transform="translate({width + gap} 0)">\n{back}\n  </g>\n'
        "</svg>\n"
    )


def render_character_region_path(view: str, item: dict, path_item: dict, index: int) -> str:
    side = path_item["side"]
    region = item["region"]
    transform = ""
    rendered_side = side
    if path_item.get("mirrored"):
        rendered_side = "right" if side == "left" else f"{side}-mirrored"
        transform = f' transform="translate({CLEAN_CENTER_X * 2} 0) scale(-1 1)"'

    return (
        f'    <path id="character-{view}-{region}-{rendered_side}-{index}" '
        f'data-view="{view}" data-region="{region}" data-side="{rendered_side}" '
        f'fill="{item["color"]}" fill-opacity="0.16" '
        f'stroke="{item["color"]}" stroke-opacity="0.96" stroke-width="9" '
        f'stroke-linejoin="round" stroke-linecap="round"{transform} '
        f'd="{escape_attr(path_item["d"])}" />'
    )


def render_character_clean_svg(view: str) -> str:
    width, height = CLEAN_VIEWBOX
    base_href = CLEAN_CHARACTER_COPIES[view].name
    groups = []

    for item in CLEAN_REGIONS[view]:
        paths = []
        for index, path_item in enumerate(item["paths"], 1):
            paths.append(render_character_region_path(view, item, path_item, index))
            if path_item.get("mirror"):
                mirrored = {**path_item, "mirrored": True}
                paths.append(render_character_region_path(view, item, mirrored, index + 100))

        groups.append(
            f'  <g id="character-{view}-{item["region"]}" class="character-region-group" '
            f'data-view="{view}" data-region="{item["region"]}">\n'
            + "\n".join(paths)
            + "\n  </g>"
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="character-{view}-title character-{view}-desc">\n'
        f'  <title id="character-{view}-title">Clean {view} heatmap on supplied character</title>\n'
        f'  <desc id="character-{view}-desc">Cleaned SVG heatmap regions over the supplied {view} body character.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-region-group path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f'  <image class="character-base" href="./{base_href}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        + "\n".join(groups)
        + "\n</svg>\n"
    )


def render_character_clean_pair_preview() -> str:
    width, height = CLEAN_VIEWBOX
    gap = 120
    pair_width = width * 2 + gap

    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    front = content(render_character_clean_svg("front"))
    back = content(render_character_clean_svg("back"))

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="character-pair-title character-pair-desc">\n'
        '  <title id="character-pair-title">Clean body heatmap on supplied character pair</title>\n'
        '  <desc id="character-pair-desc">Front and back clean SVG heatmap regions over the supplied character images.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-region-group path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f'  <g id="character-front-map">\n{front}\n  </g>\n'
        f'  <g id="character-back-map" transform="translate({width + gap} 0)">\n{back}\n  </g>\n'
        "</svg>\n"
    )


def render_character_crisp_region_path(view: str, item: dict, path_item: dict, index: int) -> str:
    side = path_item["side"]
    region = item["region"]
    transform = ""
    rendered_side = side
    if path_item.get("mirrored"):
        rendered_side = "right" if side == "left" else f"{side}-mirrored"
        transform = f' transform="translate({CLEAN_CENTER_X * 2} 0) scale(-1 1)"'

    path_id = f"character-crisp-{view}-{region}-{rendered_side}-{index}"
    d = escape_attr(path_item["d"])
    color = item["color"]

    return (
        f'    <g id="{path_id}" data-view="{view}" data-region="{region}" data-side="{rendered_side}"{transform}>\n'
        f'      <path class="character-crisp-halo" fill="none" stroke="#f6f8f8" '
        f'stroke-opacity="0.32" stroke-width="5.4" stroke-linejoin="round" stroke-linecap="round" '
        f'd="{d}" />\n'
        f'      <path class="character-crisp-line" fill="none" '
        f'stroke="{color}" stroke-opacity="0.98" stroke-width="3.4" '
        f'stroke-linejoin="round" stroke-linecap="round" d="{d}" />\n'
        "    </g>"
    )


def render_character_crisp_svg(view: str) -> str:
    width, height = CLEAN_VIEWBOX
    base_href = CLEAN_CHARACTER_COPIES[view].name
    groups = []

    for item in CRISP_REGIONS[view]:
        paths = []
        for index, path_item in enumerate(item["paths"], 1):
            paths.append(render_character_crisp_region_path(view, item, path_item, index))
            if path_item.get("mirror"):
                mirrored = {**path_item, "mirrored": True}
                paths.append(render_character_crisp_region_path(view, item, mirrored, index + 100))

        groups.append(
            f'  <g id="character-crisp-{view}-{item["region"]}" class="character-crisp-region-group" '
            f'data-view="{view}" data-region="{item["region"]}">\n'
            + "\n".join(paths)
            + "\n  </g>"
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="character-crisp-{view}-title character-crisp-{view}-desc">\n'
        f'  <title id="character-crisp-{view}-title">Crisp {view} heatmap on supplied character</title>\n'
        f'  <desc id="character-crisp-{view}-desc">Crisp SVG heatmap contours over the supplied {view} body character.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-crisp-region-group path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f'  <image class="character-base" href="./{base_href}" x="0" y="0" width="{width}" height="{height}" preserveAspectRatio="xMidYMid meet" />\n'
        + "\n".join(groups)
        + "\n</svg>\n"
    )


def render_character_crisp_pair_preview() -> str:
    width, height = CLEAN_VIEWBOX
    gap = 120
    pair_width = width * 2 + gap

    def content(svg: str) -> str:
        start = svg.index("  <style>")
        after_style = svg.index("  </style>", start) + len("  </style>\n")
        return svg[after_style : svg.rindex("</svg>")].strip()

    front = content(render_character_crisp_svg("front"))
    back = content(render_character_crisp_svg("back"))

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="character-crisp-pair-title character-crisp-pair-desc">\n'
        '  <title id="character-crisp-pair-title">Crisp body heatmap on supplied character pair</title>\n'
        '  <desc id="character-crisp-pair-desc">Front and back crisp SVG heatmap contours over the supplied character images.</desc>\n'
        "  <style>\n"
        "    .character-base { opacity: 1; }\n"
        "    .character-crisp-region-group path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f'  <g id="character-crisp-front-map">\n{front}\n  </g>\n'
        f'  <g id="character-crisp-back-map" transform="translate({width + gap} 0)">\n{back}\n  </g>\n'
        "</svg>\n"
    )


def body_path_items(part: dict) -> list[tuple[str, str]]:
    items: list[tuple[str, str]] = []
    for side in ("left", "right", "common"):
        for path_data in part.get("sides", {}).get(side, []):
            items.append((side, normalize_svg_path(path_data)))
    return items


def render_anatomy_detail_figure(view: str, body_paths: dict, transform: str = "") -> str:
    colors = ANATOMY_DETAIL_COLORS[view]
    transform_attr = f' transform="{transform}"' if transform else ""
    neutral_groups = []
    color_groups = []

    for part in body_paths[view]:
        slug = part["slug"]
        neutral_paths = []
        for index, (side, path_data) in enumerate(body_path_items(part), 1):
            neutral_paths.append(
                f'    <path id="detail-{view}-{slug}-{side}-{index}-base" '
                f'data-view="{view}" data-part="{slug}" data-side="{side}" '
                f'fill="#d9dbd8" fill-opacity="0.72" stroke="#171b1c" stroke-opacity="0.45" '
                f'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" '
                f'd="{escape_attr(path_data)}" />'
            )

        neutral_groups.append(
            f'  <g id="detail-{view}-{slug}-base" class="anatomy-base" data-part="{slug}">\n'
            + "\n".join(neutral_paths)
            + "\n  </g>"
        )

        color = colors.get(slug)
        if not color:
            continue

        region = ANATOMY_REGION_NAMES.get(slug, slug)
        color_paths = []
        for index, (side, path_data) in enumerate(body_path_items(part), 1):
            color_paths.append(
                f'    <path id="detail-{view}-{region}-{side}-{index}" '
                f'data-view="{view}" data-part="{slug}" data-region="{region}" data-side="{side}" '
                f'fill="{color}" fill-opacity="0.12" stroke="{color}" stroke-opacity="0.95" '
                f'stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round" '
                f'd="{escape_attr(path_data)}" />'
            )

        color_groups.append(
            f'  <g id="detail-{view}-{region}" class="anatomy-region" data-region="{region}">\n'
            + "\n".join(color_paths)
            + "\n  </g>"
        )

    return (
        f'<g id="detail-{view}-figure" class="anatomy-detail-figure" data-view="{view}"{transform_attr}>\n'
        + "\n".join(neutral_groups)
        + "\n"
        + "\n".join(color_groups)
        + "\n</g>"
    )


def render_anatomy_detail_svg(view: str) -> str:
    body_paths = json.loads((BODYMAP_DIR / "body_paths.json").read_text())
    width = int(body_paths["viewBox"]["width"])
    height = int(body_paths["viewBox"]["height"])
    transform = "translate(-724 0)" if view == "back" else ""

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'role="img" aria-labelledby="detail-{view}-title detail-{view}-desc">\n'
        f'  <title id="detail-{view}-title">Detailed clean {view} body heatmap</title>\n'
        f'  <desc id="detail-{view}-desc">Anatomy-contoured clean SVG heatmap using the supplied sketch color map.</desc>\n'
        "  <style>\n"
        "    .anatomy-detail-figure path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f"{render_anatomy_detail_figure(view, body_paths, transform)}\n"
        "</svg>\n"
    )


def render_anatomy_detail_pair_preview() -> str:
    body_paths = json.loads((BODYMAP_DIR / "body_paths.json").read_text())
    width = int(body_paths["viewBox"]["width"])
    height = int(body_paths["viewBox"]["height"])
    gap = 84
    pair_width = width * 2 + gap

    front = render_anatomy_detail_figure("front", body_paths)
    back = render_anatomy_detail_figure("back", body_paths, f"translate({width + gap - 724} 0)")

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {pair_width} {height}" role="img" '
        'aria-labelledby="detail-pair-title detail-pair-desc">\n'
        '  <title id="detail-pair-title">Detailed clean body heatmap pair</title>\n'
        '  <desc id="detail-pair-desc">Front and back anatomy-contoured clean SVG heatmaps using the supplied sketch color map.</desc>\n'
        "  <style>\n"
        "    .anatomy-detail-figure path { shape-rendering: geometricPrecision; vector-effect: non-scaling-stroke; }\n"
        "  </style>\n"
        f"{front}\n{back}\n"
        "</svg>\n"
    )


def main() -> None:
    BODYMAP_DIR.mkdir(parents=True, exist_ok=True)

    outputs: list[Path] = []
    manifest = {
        "source_images": {},
        "palette": [
            {
                "key": layer.key,
                "hex": layer.hex,
                "default_region": layer.region,
            }
            for layer in PALETTE
        ],
        "views": {},
    }

    rendered_for_preview = {}
    character_trace_for_preview = {}
    character_mirrored_trace_for_preview = {}
    character_mirrored_filled_for_preview = {}
    width = height = 0

    for view, source in SOURCE_IMAGES.items():
        if not source.exists():
            raise FileNotFoundError(source)

        shutil.copyfile(source, REFERENCE_COPIES[view])
        image = Image.open(source).convert("RGB")
        image_rgb = np.array(image)
        write_clean_character_base(view, image_rgb)
        outputs.append(CLEAN_CHARACTER_COPIES[view])
        width, height = image.size
        manifest["source_images"][view] = str(source)

        paths_by_layer = {}
        counts_by_layer = {}
        for layer in PALETTE:
            mask = mask_for_layer(image_rgb, layer)
            paths_by_layer[layer.key] = layer_path_data(mask, faithful_strokes=True)
            counts_by_layer[layer.key] = int((mask > 0).sum())

        trace_svg = render_svg(
            view=view,
            width=width,
            height=height,
            paths_by_layer=paths_by_layer,
            faithful_strokes=True,
            include_reference=False,
        )
        trace_file = BODYMAP_DIR / f"source_{view}map_trace.svg"
        trace_file.write_text(trace_svg)
        outputs.append(trace_file)

        character_trace_svg = render_character_trace_svg(
            view=view,
            width=width,
            height=height,
            paths_by_layer=paths_by_layer,
        )
        character_trace_for_preview[view] = character_trace_svg
        character_trace_file = BODYMAP_DIR / f"source_{view}map_character_trace.svg"
        character_trace_file.write_text(character_trace_svg)
        outputs.append(character_trace_file)

        mirrored_paths_by_layer = {}
        mirrored_filled_paths_by_layer = {}
        mirrored_source_half = MIRRORED_TRACE_SOURCE_HALF[view]
        for layer in PALETTE:
            mask = mask_for_layer(image_rgb, layer)
            mirrored_mask = mirror_mask_half(mask, mirrored_source_half)
            mirrored_paths_by_layer[layer.key] = layer_path_data(mirrored_mask, faithful_strokes=True)
            mirrored_filled_paths_by_layer[layer.key] = filled_region_path_data(mirrored_mask)

        character_mirrored_trace_svg = render_character_mirrored_trace_svg(
            view=view,
            width=width,
            height=height,
            paths_by_layer=mirrored_paths_by_layer,
            source_half=mirrored_source_half,
        )
        character_mirrored_trace_for_preview[view] = character_mirrored_trace_svg
        character_mirrored_trace_file = BODYMAP_DIR / f"source_{view}map_character_mirrored_trace.svg"
        character_mirrored_trace_file.write_text(character_mirrored_trace_svg)
        outputs.append(character_mirrored_trace_file)

        character_mirrored_filled_svg = render_character_mirrored_filled_svg(
            view=view,
            width=width,
            height=height,
            filled_paths_by_layer=mirrored_filled_paths_by_layer,
            stroke_paths_by_layer=mirrored_paths_by_layer,
            source_half=mirrored_source_half,
        )
        character_mirrored_filled_for_preview[view] = character_mirrored_filled_svg
        character_mirrored_filled_file = BODYMAP_DIR / f"source_{view}map_character_mirrored_filled.svg"
        character_mirrored_filled_file.write_text(character_mirrored_filled_svg)
        outputs.append(character_mirrored_filled_file)

        filled_paths = {}
        for layer in PALETTE:
            mask = mask_for_layer(image_rgb, layer)
            filled_paths[layer.key] = layer_path_data(mask, faithful_strokes=False)

        filled_svg = render_svg(
            view=view,
            width=width,
            height=height,
            paths_by_layer=filled_paths,
            faithful_strokes=False,
            include_reference=False,
        )
        filled_file = BODYMAP_DIR / f"source_{view}map_filled_regions.svg"
        filled_file.write_text(filled_svg)
        outputs.append(filled_file)

        preview_svg = render_svg(
            view=view,
            width=width,
            height=height,
            paths_by_layer=paths_by_layer,
            faithful_strokes=True,
            include_reference=True,
        )
        rendered_for_preview[view] = preview_svg
        preview_file = BODYMAP_DIR / f"source_{view}map_trace_preview.svg"
        preview_file.write_text(preview_svg)
        outputs.append(preview_file)

        manifest["views"][view] = {
            "width": width,
            "height": height,
            "regions": VIEW_REGION_OVERRIDES[view],
            "colored_pixel_counts": counts_by_layer,
        }

    pair_file = BODYMAP_DIR / "source_bodymap_trace_pair_preview.svg"
    pair_file.write_text(render_pair_preview(rendered_for_preview["front"], rendered_for_preview["back"], width, height))
    outputs.append(pair_file)

    character_trace_pair_file = BODYMAP_DIR / "source_bodymap_character_trace_pair_preview.svg"
    character_trace_pair_file.write_text(
        render_character_trace_pair_preview(
            character_trace_for_preview["front"],
            character_trace_for_preview["back"],
            width,
            height,
        )
    )
    outputs.append(character_trace_pair_file)

    character_mirrored_trace_pair_file = BODYMAP_DIR / "source_bodymap_character_mirrored_trace_pair_preview.svg"
    character_mirrored_trace_pair_file.write_text(
        render_character_mirrored_trace_pair_preview(
            character_mirrored_trace_for_preview["front"],
            character_mirrored_trace_for_preview["back"],
            width,
            height,
        )
    )
    outputs.append(character_mirrored_trace_pair_file)

    character_mirrored_filled_pair_file = BODYMAP_DIR / "source_bodymap_character_mirrored_filled_pair_preview.svg"
    character_mirrored_filled_pair_file.write_text(
        render_character_mirrored_filled_pair_preview(
            character_mirrored_filled_for_preview["front"],
            character_mirrored_filled_for_preview["back"],
            width,
            height,
        )
    )
    outputs.append(character_mirrored_filled_pair_file)

    clean_front_file = BODYMAP_DIR / "source_frontmap_clean_regions.svg"
    clean_front_file.write_text(render_clean_svg("front"))
    outputs.append(clean_front_file)

    clean_back_file = BODYMAP_DIR / "source_backmap_clean_regions.svg"
    clean_back_file.write_text(render_clean_svg("back"))
    outputs.append(clean_back_file)

    clean_front_preview_file = BODYMAP_DIR / "source_frontmap_clean_preview.svg"
    clean_front_preview_file.write_text(render_clean_svg("front", include_reference=True))
    outputs.append(clean_front_preview_file)

    clean_back_preview_file = BODYMAP_DIR / "source_backmap_clean_preview.svg"
    clean_back_preview_file.write_text(render_clean_svg("back", include_reference=True))
    outputs.append(clean_back_preview_file)

    clean_pair_file = BODYMAP_DIR / "source_bodymap_clean_pair_preview.svg"
    clean_pair_file.write_text(render_clean_pair_preview())
    outputs.append(clean_pair_file)

    character_front_file = BODYMAP_DIR / "source_frontmap_character_clean.svg"
    character_front_file.write_text(render_character_clean_svg("front"))
    outputs.append(character_front_file)

    character_back_file = BODYMAP_DIR / "source_backmap_character_clean.svg"
    character_back_file.write_text(render_character_clean_svg("back"))
    outputs.append(character_back_file)

    character_pair_file = BODYMAP_DIR / "source_bodymap_character_clean_pair_preview.svg"
    character_pair_file.write_text(render_character_clean_pair_preview())
    outputs.append(character_pair_file)

    character_crisp_front_file = BODYMAP_DIR / "source_frontmap_character_crisp.svg"
    character_crisp_front_file.write_text(render_character_crisp_svg("front"))
    outputs.append(character_crisp_front_file)

    character_crisp_back_file = BODYMAP_DIR / "source_backmap_character_crisp.svg"
    character_crisp_back_file.write_text(render_character_crisp_svg("back"))
    outputs.append(character_crisp_back_file)

    character_crisp_pair_file = BODYMAP_DIR / "source_bodymap_character_crisp_pair_preview.svg"
    character_crisp_pair_file.write_text(render_character_crisp_pair_preview())
    outputs.append(character_crisp_pair_file)

    detail_front_file = BODYMAP_DIR / "source_frontmap_clean_detailed.svg"
    detail_front_file.write_text(render_anatomy_detail_svg("front"))
    outputs.append(detail_front_file)

    detail_back_file = BODYMAP_DIR / "source_backmap_clean_detailed.svg"
    detail_back_file.write_text(render_anatomy_detail_svg("back"))
    outputs.append(detail_back_file)

    detail_pair_file = BODYMAP_DIR / "source_bodymap_clean_detailed_pair_preview.svg"
    detail_pair_file.write_text(render_anatomy_detail_pair_preview())
    outputs.append(detail_pair_file)

    manifest_file = BODYMAP_DIR / "source_bodymap_trace_manifest.json"
    manifest["clean_symmetric"] = {
        "width": CLEAN_VIEWBOX[0],
        "height": CLEAN_VIEWBOX[1],
        "front_regions": [item["region"] for item in CLEAN_REGIONS["front"]],
        "back_regions": [item["region"] for item in CLEAN_REGIONS["back"]],
        "mirror_axis_x": CLEAN_CENTER_X,
    }
    manifest["clean_detailed"] = {
        "width": 724,
        "height": 1448,
        "front_parts": sorted(ANATOMY_DETAIL_COLORS["front"].keys()),
        "back_parts": sorted(ANATOMY_DETAIL_COLORS["back"].keys()),
        "source": "body_paths.json anatomy contours styled with the supplied sketch color map",
    }
    manifest["character_clean"] = {
        "width": CLEAN_VIEWBOX[0],
        "height": CLEAN_VIEWBOX[1],
        "front_base": str(CLEAN_CHARACTER_COPIES["front"].relative_to(PROJECT_ROOT)),
        "back_base": str(CLEAN_CHARACTER_COPIES["back"].relative_to(PROJECT_ROOT)),
        "source": "supplied PNG character with marker colors inpainted, plus cleaned SVG heatmap regions",
    }
    manifest["character_crisp"] = {
        "width": CLEAN_VIEWBOX[0],
        "height": CLEAN_VIEWBOX[1],
        "front_file": "UNBOUND/Resources/BodyMap/source_frontmap_character_crisp.svg",
        "back_file": "UNBOUND/Resources/BodyMap/source_backmap_character_crisp.svg",
        "pair_preview": "UNBOUND/Resources/BodyMap/source_bodymap_character_crisp_pair_preview.svg",
        "front_base": str(CLEAN_CHARACTER_COPIES["front"].relative_to(PROJECT_ROOT)),
        "back_base": str(CLEAN_CHARACTER_COPIES["back"].relative_to(PROJECT_ROOT)),
        "source": "supplied PNG character with marker colors inpainted, plus crisp SVG contour heatmap regions",
    }
    manifest["character_trace"] = {
        "width": width,
        "height": height,
        "front_file": "UNBOUND/Resources/BodyMap/source_frontmap_character_trace.svg",
        "back_file": "UNBOUND/Resources/BodyMap/source_backmap_character_trace.svg",
        "source": "supplied PNG character with marker colors inpainted, plus vectorized marker-style SVG regions",
    }
    manifest["character_mirrored_trace"] = {
        "width": width,
        "height": height,
        "front_file": "UNBOUND/Resources/BodyMap/source_frontmap_character_mirrored_trace.svg",
        "back_file": "UNBOUND/Resources/BodyMap/source_backmap_character_mirrored_trace.svg",
        "pair_preview": "UNBOUND/Resources/BodyMap/source_bodymap_character_mirrored_trace_pair_preview.svg",
        "source_halves": MIRRORED_TRACE_SOURCE_HALF,
        "source": "supplied marker strokes vectorized after mirroring the selected half for consistency",
    }
    manifest["character_mirrored_filled"] = {
        "width": width,
        "height": height,
        "front_file": "UNBOUND/Resources/BodyMap/source_frontmap_character_mirrored_filled.svg",
        "back_file": "UNBOUND/Resources/BodyMap/source_backmap_character_mirrored_filled.svg",
        "pair_preview": "UNBOUND/Resources/BodyMap/source_bodymap_character_mirrored_filled_pair_preview.svg",
        "source_halves": MIRRORED_TRACE_SOURCE_HALF,
        "source": "supplied marker strokes filled after mirroring the selected half for consistency",
    }
    manifest_file.write_text(json.dumps(manifest, indent=2) + "\n")
    outputs.append(manifest_file)

    for output in outputs:
        print(output.relative_to(PROJECT_ROOT))


if __name__ == "__main__":
    main()
