"""The committed brand files (app icons, iOS launch screen) are exactly what the script writes."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "apps" / "scripts" / "make_brand_assets.py"


def load():
    spec = importlib.util.spec_from_file_location("make_brand_assets", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_committed_files_match_the_script():
    stale = [str(path.relative_to(ROOT)) for path, content in load().outputs().items()
             if not path.exists() or path.read_text(encoding="utf-8") != content]
    assert not stale, f"run apps/scripts/make_brand_assets.py and commit: {stale}"


def test_icon_has_no_files_the_script_does_not_write():
    module = load()
    written = set(module.outputs())
    for icon in module.ICON_DIRS:
        extra = [p for p in icon.rglob("*") if p.is_file() and p not in written]
        assert not extra


def test_icon_layers_exist_and_the_tile_is_one_look():
    module = load()
    for icon in module.ICON_DIRS:
        spec = json.loads((icon / "icon.json").read_text())
        for group in spec["groups"]:
            for layer in group["layers"]:
                assert (icon / "Assets" / layer["image-name"]).is_file()
        # The brand tile is the same in every appearance (the site's), the system tints it.
        assert "fill-specializations" not in spec
        tile = module.palette()["brandTileTop"][0]
        assert spec["fill"]["automatic-gradient"] == module.srgb(tile)


def test_launch_background_is_the_window_background():
    module = load()
    light, dark = module.palette()["background"]
    path = module.IOS_ASSETS / "LaunchBackground.colorset" / "Contents.json"
    colorset = json.loads(path.read_text())
    reds = [c["color"]["components"]["red"] for c in colorset["colors"]]
    assert reds == [f"0x{light[:2]}", f"0x{dark[:2]}"]


def test_opening_animation_starts_from_the_launch_mark_size():
    """LaunchHandoff starts the wordmark at Tokens.Size.wordmarkLaunch: the launch image's height."""
    module = load()
    tokens = (ROOT / "apps/shared/Sources/TickrDesign/Tokens+Wordmark.swift").read_text()
    assert f"public static let wordmarkLaunch: CGFloat = {module.WORDMARK_LAUNCH}\n" in tokens


def test_wordmark_shows_the_launch_images_part_of_the_grid():
    """Wordmark cuts the mark's grid where the launch image does, so the launch hands over in place."""
    module = load()
    swift = (ROOT / "apps/shared/Sources/TickrDesign/Wordmark.swift").read_text()
    x, y, w, h = module.WORDMARK_CROP
    assert f"static let crop = CGRect(x: {x:g}, y: {y:g}, width: {w:g}, height: {h:g})" in swift


def test_in_app_mark_uses_the_scripts_geometry():
    """BrandMark draws the same letter, level and grid as the icon and the launch screen."""
    module = load()
    swift = (ROOT / "apps/shared/Sources/TickrDesign/BrandMark.swift").read_text()
    x, y, w, h = module.LEVEL
    assert f"level = CGRect(x: {x:g}, y: {y:g}, width: {w:g}, height: {h:g})" in swift
    x, y, w, h = module.STUB
    assert f"stub = CGRect(x: {x:g}, y: {y:g}, width: {w:g}, height: {h:g})" in swift
    assert f"static let gridInset = {module.GRID_INSET:g}\n" in swift
    assert f"static let gridSide = {module.GRID_SIDE:g}\n" in swift
    # Every corner of the stem's outline is a point of BrandLetter.
    numbers = [float(n) for n in __import__("re").findall(r"[-\d.]+", module.STEM)]
    for value in numbers:
        assert f"{value:g}" in swift
