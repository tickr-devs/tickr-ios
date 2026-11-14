#!/usr/bin/env python3
"""Fail when the apps' Swift code holds a magic number.

Rule (docs/design-system.md): a number other than 0 and 1 may appear only
- in a named constant: a `static let` whose line is directly preceded by a `///` doc comment, or
  that sits in a block of `static let` lines under one doc comment;
- as an enum case raw value (`case m5 = 5`);
- as the halving divisor `/ 2`, or a subscript index (`parts[2]`);
- in Palette.swift (colour definitions) and in tests.
Comments and string literals are ignored. Usage: check_swift_literals.py [root ...]
(default: the roots in DEFAULT_ROOTS; each app joins when its code has moved onto the
design system). Prints file:line: literal for each violation.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

DEFAULT_ROOTS = ("apps/shared",)
SKIPPED_FILES = {"Palette.swift", "Package.swift"}
SKIPPED_DIRS = {"Tests", ".build", "build", "DerivedData"}
NUMBER = re.compile(
    r"(?<![\w.$])(0x[0-9A-Fa-f_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][-+]?\d+)?)(?![\w.])"
)
CONSTANT = re.compile(
    r"^\s*(?:@\w+\s+)*"
    r"(?:(?:public|private|fileprivate|internal|nonisolated)\s+)*static\s+let\s+\w+"
)
ENUM_CASE = re.compile(r"(?:^|[{;])\s*case\s+\w+\s*=")
ALLOWED = {"0", "1", "0.0", "1.0"}


def strip(line: str, in_block: bool) -> tuple[str, bool]:
    """Remove string literals and comments from one line; track /* */ blocks across lines."""
    out = []
    i = 0
    while i < len(line):
        if in_block:
            end = line.find("*/", i)
            if end < 0:
                return "".join(out), True
            i, in_block = end + 2, False
            continue
        if line.startswith("//", i):
            break
        if line.startswith("/*", i):
            in_block = True
            i += 2
            continue
        if line[i] == '"':
            j = i + 1
            while j < len(line) and line[j] != '"':
                j += 2 if line[j] == "\\" else 1
            out.append('""')
            i = j + 1
            continue
        out.append(line[i])
        i += 1
    return "".join(out), in_block


def violations(path: Path) -> list[tuple[int, str]]:
    found = []
    in_block = False
    documented = False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = raw.strip()
        if stripped.startswith("///"):
            documented = True
            continue
        code, in_block = strip(raw, in_block)
        is_constant = bool(CONSTANT.match(code))
        if is_constant and documented:
            continue
        if stripped and not is_constant:
            documented = False
        if ENUM_CASE.search(code):
            continue
        code = re.sub(r"/\s*2(?![\w.])", "/", code)
        code = re.sub(r"(?<=[\w)\]])\[\s*\d+\s*\]", "[]", code)
        for match in NUMBER.finditer(code):
            if match.group(1) not in ALLOWED:
                found.append((number, match.group(1)))
    return found


def swift_files(root: Path) -> list[Path]:
    return sorted(
        path
        for path in root.rglob("*.swift")
        if path.name not in SKIPPED_FILES and not SKIPPED_DIRS.intersection(path.parts)
    )


def main(argv: list[str]) -> int:
    roots = [Path(arg) for arg in argv] or [Path(root) for root in DEFAULT_ROOTS]
    problems = 0
    for root in roots:
        for path in swift_files(root):
            for line, literal in violations(path):
                print(f"{path}:{line}: magic number {literal}: "
                      "use a token (Tokens.swift) or a documented constant")
                problems += 1
    if problems:
        print(f"{problems} magic number(s); see docs/design-system.md")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
