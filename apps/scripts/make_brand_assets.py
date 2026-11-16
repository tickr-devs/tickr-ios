#!/usr/bin/env python3
"""Write the apps' brand assets: the app icon (Icon Composer `.icon`) and the iOS launch screen.

The mark is a price line drawn as a tick (the name Tickr) that breaks upward, with a spark at
its end. One description here produces every file, so the macOS and iOS icons and the launch
screen never drift apart:

- `apps/macos/Tickr/AppIcon.icon` and `apps/ios/Tickr/AppIcon.icon`: the layered icon
  (light, dark and tinted appearances; the system adds Liquid Glass and the tinted rendering).
- `apps/ios/Tickr/Assets.xcassets`: `LaunchBackground` (the window background, so the launch
  screen hands over to the first screen without a flash) and `LaunchMark` (the mark).

Colours come from `apps/shared/Sources/TickrDesign/Palette.swift`. The in-app mark
(`BrandMark` in TickrDesign) draws the same line from the same points. Files are committed;
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
# The tick: points of the price line as shares of the canvas, left to right. Same as
# BrandMark.points in apps/shared/Sources/TickrDesign/BrandMark.swift.
POINTS = ((0.205, 0.51), (0.39, 0.70), (0.50, 0.575), (0.565, 0.625), (0.81, 0.285))
# Line width, spark radius and the bottom of the fading area under the line, as canvas shares.
LINE_WIDTH = 0.084
SPARK_RADIUS = 0.045
AREA_BOTTOM = 0.86
# Opacity of the area under the line at its top (it fades to nothing at the bottom).
AREA_OPACITY = 0.45
# Launch-screen mark size in points (the image is drawn at this size, centred).
LAUNCH_MARK = 160

# A role is a Color, or a Swatch when other code needs its raw values (Palette.swift).
COLOR = re.compile(r"static let (\w+) = (?:Color|Swatch)"
                   r"\(light: 0x([0-9A-F]{6}), dark: 0x([0-9A-F]{6})\)")


def palette() -> dict[str, tuple[str, str]]:
    """Each role's light and dark hex value from Palette.swift."""
    return {name: (light, dark) for name, light, dark in COLOR.findall(PALETTE.read_text())}


def pt(share: float, size: float = CANVAS) -> str:
    return f"{share * size:.1f}".rstrip("0").rstrip(".")


def line_path(size: float) -> str:
    return "M" + " L".join(f"{pt(x, size)},{pt(y, size)}" for x, y in POINTS)


def svg(body: str, size: float = CANVAS, defs: str = "") -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{pt(1, size)}" height="{pt(1, size)}" '
            f'viewBox="0 0 {pt(1, size)} {pt(1, size)}">{defs}{body}</svg>\n')


def gradient(ident: str, top: str, bottom: str,
             top_opacity: float = 1, bottom_opacity: float = 1) -> str:
    return (f'<linearGradient id="{ident}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#{top}" stop-opacity="{top_opacity}"/>'
            f'<stop offset="1" stop-color="#{bottom}" stop-opacity="{bottom_opacity}"/>'
            '</linearGradient>')


def layers(colors: dict[str, tuple[str, str]], size: float = CANVAS) -> dict[str, str]:
    """The mark's three layers as SVG: the fading area, the line and the spark."""
    profit_light, profit_dark = colors["profit"]
    accent = colors["accent"][0]
    (last_x, last_y), first_x = POINTS[-1], POINTS[0][0]
    area = (line_path(size) + f" L{pt(last_x, size)},{pt(AREA_BOTTOM, size)}"
            f" L{pt(first_x, size)},{pt(AREA_BOTTOM, size)} Z")
    stroke = (f'stroke-width="{pt(LINE_WIDTH, size)}" stroke-linecap="round" '
              f'stroke-linejoin="round" fill="none"')
    return {
        "area": svg(f'<path d="{area}" fill="url(#a)"/>', size,
                    gradient("a", accent, accent, AREA_OPACITY, 0)),
        "line": svg(f'<path d="{line_path(size)}" stroke="url(#l)" {stroke}/>', size,
                    gradient("l", profit_dark, profit_light)),
        "spark": svg(f'<circle cx="{pt(last_x, size)}" cy="{pt(last_y, size)}" '
                     f'r="{pt(SPARK_RADIUS, size)}" fill="#FFFFFF"/>', size),
    }


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
    background_light = colors["background"][0]
    surface_dark = colors["surface"][1]
    return xcode_json({
        "fill": {"automatic-gradient": srgb(background_light)},
        "fill-specializations": [
            {"appearance": "dark", "value": {"automatic-gradient": srgb(surface_dark)}},
        ],
        # Front to back.
        "groups": [
            group("Spark", "spark", True, "neutral", False),
            group("Line", "line", True, "layer-color", False),
            group("Area", "area", False, "none", True),
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
    small = layers(colors, LAUNCH_MARK)
    body = "".join(re.sub(r"</?svg[^>]*>\n?", "", small[k]) for k in ("area", "line", "spark"))
    mark = svg(body, LAUNCH_MARK)
    info = {"info": {"author": "xcode", "version": 1}}
    files[IOS_ASSETS / "Contents.json"] = xcode_json(info)
    files[IOS_ASSETS / "LaunchBackground.colorset/Contents.json"] = colorset(*colors["background"])
    files[IOS_ASSETS / "LaunchMark.imageset/LaunchMark.svg"] = mark
    files[IOS_ASSETS / "LaunchMark.imageset/Contents.json"] = xcode_json({
        "images": [{"filename": "LaunchMark.svg", "idiom": "universal"}],
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
