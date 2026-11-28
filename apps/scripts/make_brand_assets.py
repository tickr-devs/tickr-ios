#!/usr/bin/env python3
"""Write the apps' brand assets: the app icon (Icon Composer `.icon`) and the iOS launch screen.

The mark is "the letter-level": a lowercase t whose crossbar has broken off into a teal price
level, on a dark tile. One description here produces every file, so the macOS and iOS icons and
the launch screen never drift apart:

- `apps/macos/Tickr/AppIcon.icon` and `apps/ios/Tickr/AppIcon.icon`: the layered icon
  (one look in every appearance; the system adds Liquid Glass and the tinted rendering).
- `apps/ios/Tickr/Assets.xcassets`: `LaunchBackground` (the window background, so the launch
  screen hands over to the first screen without a flash) and `LaunchMark` (the wordmark's "t"
  without a tile, in the text colour of each appearance: the launch then slides "ickr" out of it).

Colours come from `apps/shared/Sources/TickrDesign/Palette.swift`. The in-app mark
(`BrandMark` in TickrDesign) draws the same tile, letter and level, and `Wordmark` the same letter
and level without the tile. Files are committed;
`tests/test_brand_assets.py` fails when they differ from this script's output.
Usage: make_brand_assets.py
"""

from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PALETTE = REPO / "apps/shared/Sources/TickrDesign/Palette.swift"
ICON_DIRS = (REPO / "apps/macos/Tickr/AppIcon.icon", REPO / "apps/ios/Tickr/AppIcon.icon")
IOS_ASSETS = REPO / "apps/ios/Tickr/Assets.xcassets"

# Icon canvas in points (Icon Composer draws on 1024 x 1024).
CANVAS = 1024
# The mark, "the letter-level" (owner's choice, 2026-11-25): a lowercase t on a 24-unit grid whose
# crossbar has broken off into a teal price level. Every edge sits on a 1.5-unit step; the hook's
# arcs are concentric (radii 3 and 6); both ends are cut at 45 degrees. BrandMark.swift and
# BrandLetter in apps/shared/Sources/TickrDesign/BrandMark.swift draw the same shapes.
GRID = 24
STEM = "M7.5 7.5 L10.5 4.5 L10.5 15 A3 3 0 0 0 13.5 18 L18 18 L15 21 L13.5 21 A6 6 0 0 1 7.5 15 Z"
STUB = (4.5, 9, 3, 3)
LEVEL = (12, 9, 7.5, 3)
# The grid inside the tile or icon: inset and side as shares of the side (768 of 1024).
GRID_INSET = 0.125
GRID_SIDE = 0.75
# The launch screen's "t": the part of the grid the wordmark shows (x, y, width, height; the boards'
# viewBox "3 3 18 20", `Wordmark.crop`) and its height in points (`Tokens.Size.wordmarkLaunch`).
WORDMARK_CROP = (3, 3, 18, 20)
WORDMARK_LAUNCH = 52

# A role is a Color, or a Swatch when other code needs its raw values (Palette.swift).
COLOR = re.compile(r"static let (\w+) = (?:Color|Swatch)"
                   r"\(light: 0x([0-9A-F]{6}), dark: 0x([0-9A-F]{6})\)")


def palette() -> dict[str, tuple[str, str]]:
    """Each role's light and dark hex value from Palette.swift."""
    return {name: (light, dark) for name, light, dark in COLOR.findall(PALETTE.read_text())}


def pt(share: float, size: float = CANVAS) -> str:
    return f"{share * size:.1f}".rstrip("0").rstrip(".")


def svg(body: str, size: float = CANVAS, defs: str = "") -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{pt(1, size)}" height="{pt(1, size)}" '
            f'viewBox="0 0 {pt(1, size)} {pt(1, size)}">{defs}{body}</svg>\n')


def on_grid(body: str, size: float) -> str:
    """Shapes drawn in grid units, placed on the grid inside a square of `size`."""
    scale = size * GRID_SIDE / GRID
    inset = pt(GRID_INSET, size)
    return f'<g transform="translate({inset} {inset}) scale({scale:g})">{body}</g>'


def rect(x: float, y: float, w: float, h: float, color: str) -> str:
    return f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" fill="#{color}"/>'


def layers(colors: dict[str, tuple[str, str]], size: float = CANVAS) -> dict[str, str]:
    """The mark's two icon layers as SVG: the letter (stem, hook and stub) and the level."""
    letter, teal = colors["brandLetter"][0], colors["brandLine"][0]
    return {
        "letter": svg(on_grid(f'<path d="{STEM}" fill="#{letter}"/>' + rect(*STUB, letter), size),
                      size),
        "level": svg(on_grid(rect(*LEVEL, teal), size), size),
    }


def launch_glyph(letter: str, teal: str) -> str:
    """The wordmark's "t" for the launch screen: as `WordmarkGlyph` draws it in the apps."""
    x, y, w, h = WORDMARK_CROP
    width = WORDMARK_LAUNCH * w / h
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:g}" height="{WORDMARK_LAUNCH}" '
            f'viewBox="{x} {y} {w} {h}">'
            f'<path d="{STEM}" fill="#{letter}"/>{rect(*STUB, letter)}{rect(*LEVEL, teal)}</svg>\n')


def srgb(hex_value: str) -> str:
    channels = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return "srgb:" + ",".join(f"{c:.5f}" for c in [*channels, 1])


def xcode_json(value: object) -> str:
    """JSON the way Xcode writes asset files: `"key" : value`, 2-space indent."""
    return json.dumps(value, indent=2, separators=(",", " : ")) + "\n"


def group(name: str, image: str, glass: bool, shadow: str, translucent: bool) -> dict:
    return {
        "layers": [{"glass": glass, "image-name": f"{image}.svg", "name": name}],
        "name": name,
        "shadow": {"kind": shadow, "opacity": 0.5},
        "specular": glass,
        "translucency": {"enabled": translucent, "value": 0.5},
    }


def icon_json(colors: dict[str, tuple[str, str]]) -> str:
    # The tile is the brand's and the same in every appearance: the system lightens it towards
    # the top (the site's tile gradient) and makes the tinted rendering from it.
    return xcode_json({
        "fill": {"automatic-gradient": srgb(colors["brandTileTop"][0])},
        # Front to back.
        "groups": [
            group("Level", "level", True, "layer-color", False),
            group("Letter", "letter", True, "neutral", False),
        ],
        "supported-platforms": {"squares": "shared"},
    })


def colorset(light: str, dark: str) -> str:
    def entry(hex_value: str, appearance: str | None) -> dict:
        r, g, b = (f"0x{hex_value[i:i + 2]}" for i in (0, 2, 4))
        item: dict = {"color": {"color-space": "srgb",
                                "components": {"alpha": "1.000", "blue": b, "green": g, "red": r}},
                      "idiom": "universal"}
        if appearance:
            item["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        return item
    return xcode_json({"colors": [entry(light, None), entry(dark, "dark")],
                       "info": {"author": "xcode", "version": 1}})


def outputs() -> dict[Path, str]:
    """Every generated file and its content."""
    colors = palette()
    files: dict[Path, str] = {}
    for icon in ICON_DIRS:
        files[icon / "icon.json"] = icon_json(colors)
        for name, content in layers(colors).items():
            files[icon / "Assets" / f"{name}.svg"] = content
    teal = colors["brandLine"][0]
    light, dark = colors["textPrimary"]
    info = {"info": {"author": "xcode", "version": 1}}
    files[IOS_ASSETS / "Contents.json"] = xcode_json(info)
    files[IOS_ASSETS / "LaunchBackground.colorset/Contents.json"] = colorset(*colors["background"])
    files[IOS_ASSETS / "LaunchMark.imageset/LaunchMark.svg"] = launch_glyph(light, teal)
    files[IOS_ASSETS / "LaunchMark.imageset/LaunchMark-dark.svg"] = launch_glyph(dark, teal)
    files[IOS_ASSETS / "LaunchMark.imageset/Contents.json"] = xcode_json({
        "images": [
            {"filename": "LaunchMark.svg", "idiom": "universal"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}],
             "filename": "LaunchMark-dark.svg", "idiom": "universal"},
        ],
        **info,
        "properties": {"preserves-vector-representation": True},
    })
    return files


def main() -> int:
    for icon in ICON_DIRS:
        shutil.rmtree(icon, ignore_errors=True)
    for path, content in outputs().items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        print(path.relative_to(REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main())
