"""No git conflict markers in tracked files (.github/scripts/check_conflict_markers.py)."""

from __future__ import annotations

import importlib.util
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / ".github" / "scripts" / "check_conflict_markers.py"
WORKFLOW = ROOT / ".github" / "workflows" / "swift-rules.yml"


def load():
    spec = importlib.util.spec_from_file_location("check_conflict_markers", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


CHECK = load()
# Built here, so this file holds no marker of its own.
OURS, THEIRS = CHECK.MARKERS
MIDDLE = "=" * CHECK.MARKER_LENGTH


def test_reports_the_lines_that_open_and_close_a_conflict():
    text = f"| a |\n{OURS} HEAD\n| b |\n{MIDDLE}\n| c |\n{THEIRS} origin/main\n| d |\n"
    assert CHECK.marker_lines(text) == [2, 6]
    assert CHECK.marker_lines(f"{OURS}\n{THEIRS}\n") == [1, 2]


def test_leaves_ordinary_text_alone():
    heading = f"Title\n{MIDDLE}\n"
    longer = f"{OURS}< eight\n{THEIRS}> eight\n"
    indented = f"  {OURS} HEAD\n"
    glued = f"{OURS}HEAD\n"
    for text in (heading, longer, indented, glued, "a << b >> c\n"):
        assert CHECK.marker_lines(text) == []


def test_reads_tracked_text_files_only(tmp_path):
    def git(*arguments: str) -> None:
        subprocess.run(["git", *arguments], cwd=tmp_path, check=True, capture_output=True)

    git("init", "-q")
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "notes.md").write_text(f"one\n{OURS} HEAD\ntwo\n", encoding="utf-8")
    (tmp_path / "clean.py").write_text("x = 1\n", encoding="utf-8")
    (tmp_path / "image.bin").write_bytes(b"\0\n" + f"{OURS} HEAD\n".encode())
    git("add", ".")
    (tmp_path / "untracked.md").write_text(f"{THEIRS} theirs\n", encoding="utf-8")
    assert CHECK.problems(tmp_path) == ["docs/notes.md:2"]


def test_this_repository_has_no_conflict_markers():
    assert CHECK.problems(ROOT) == []


def test_the_always_running_required_job_runs_the_check():
    assert "python3 .github/scripts/check_conflict_markers.py" in WORKFLOW.read_text(
        encoding="utf-8"
    )
