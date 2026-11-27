#!/usr/bin/env python3
"""Fail when a tracked text file holds git conflict markers.

A merge that is "resolved" by committing the file as git left it puts its conflict markers on main
(docs/decisions.md, 2026-11-16), and no compiler or test reads a markdown table. This check reads
every tracked file and reports each line that opens or closes a conflict (seven `<` or seven `>`,
alone or followed by a space and the side's name). The middle line of seven `=` is not reported:
on its own it is also a heading underline, and it never appears without the other two.

Run from anywhere inside the repository: `python3 .github/scripts/check_conflict_markers.py`.
Run by the `swift-lint` job (.github/workflows/swift-rules.yml), a required check that runs on
every pull request whatever it touches. Exit status: 0 clean, 1 markers found.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

# Git writes a conflict marker as this many repeats of one character at the start of a line.
MARKER_LENGTH = 7
# The characters that open ("ours") and close ("theirs") a conflict.
MARKERS = tuple(character * MARKER_LENGTH for character in "<>")
# A file with a NUL byte is binary (git's own rule) and is not read as text.
NUL = b"\0"


def marker_lines(text: str) -> list[int]:
    """The 1-based numbers of the lines that open or close a conflict."""
    found: list[int] = []
    for number, line in enumerate(text.splitlines(), start=1):
        for marker in MARKERS:
            rest = line[len(marker) :]
            if line.startswith(marker) and (not rest or rest[0] == " "):
                found.append(number)
    return found


def tracked_files(root: Path) -> list[Path]:
    """Every file git tracks under `root`."""
    listed = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, check=True, capture_output=True
    ).stdout
    return [root / name.decode() for name in listed.split(NUL) if name]


def problems(root: Path) -> list[str]:
    """One `path:line` entry per conflict marker in the tracked text files under `root`."""
    found: list[str] = []
    for path in tracked_files(root):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if NUL in data:
            continue
        text = data.decode("utf-8", errors="replace")
        found.extend(f"{path.relative_to(root)}:{number}" for number in marker_lines(text))
    return found


def main() -> int:
    root = Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"], check=True, capture_output=True, text=True
        ).stdout.strip()
    )
    found = problems(root)
    for entry in found:
        print(f"{entry}: git conflict marker")
    if found:
        print("Resolve the conflict: keep the right lines and delete the marker lines.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
