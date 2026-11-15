#!/usr/bin/env python3
"""Write every String Catalog (`*.xcstrings`) of apps/ exactly the way Xcode writes it.

Xcode rewrites a catalog on every build: `"key" : value` with 2-space indentation, keys in
natural case-insensitive order (digit runs compared as numbers, like Finder), non-ASCII as
raw UTF-8, no escaped slashes and no newline after the closing brace. A catalog committed in any
other form leaves a diff after each build, so check_swift_rules.py (rule `catalog`) refuses one,
and this script rewrites them. Usage: format_xcstrings.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOTS = ("apps/shared", "apps/macos", "apps/ios")
BUILD_DIRS = {".build", "build", "DerivedData", "SourcePackages"}
DIGITS = re.compile(r"(\d+)")
INDENT = "  "


def natural(key: str) -> list[tuple[int, int | str]]:
    """Sort key of Xcode's order: digit runs as numbers, the rest case-insensitive."""
    return [(0, int(part)) if part.isdigit() else (1, part.casefold())
            for part in DIGITS.split(key) if part]


def _value(value: object, depth: int) -> str:
    if isinstance(value, dict):
        if not value:
            return "{\n\n" + INDENT * depth + "}"
        inner = INDENT * (depth + 1)
        items = [f"{inner}{json.dumps(key, ensure_ascii=False)} : {_value(value[key], depth + 1)}"
                 for key in sorted(value, key=natural)]
        return "{\n" + ",\n".join(items) + "\n" + INDENT * depth + "}"
    if isinstance(value, list):
        if not value:
            return "[\n\n" + INDENT * depth + "]"
        inner = INDENT * (depth + 1)
        items = [f"{inner}{_value(item, depth + 1)}" for item in value]
        return "[\n" + ",\n".join(items) + "\n" + INDENT * depth + "]"
    return json.dumps(value, ensure_ascii=False)


def xcode_form(text: str) -> str:
    """The catalog `text` as Xcode would write it."""
    return _value(json.loads(text), 0)


def catalogs() -> list[Path]:
    return [path for root in ROOTS for path in sorted((REPO / root).rglob("*.xcstrings"))
            if not BUILD_DIRS.intersection(path.relative_to(REPO).parts)]


def main() -> int:
    for path in catalogs():
        text = path.read_text(encoding="utf-8")
        formatted = xcode_form(text)
        if formatted != text:
            path.write_text(formatted, encoding="utf-8")
            print(f"rewrote {path.relative_to(REPO).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
