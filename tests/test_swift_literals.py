"""The apps' magic-number check (apps/scripts/check_swift_literals.py)."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "apps" / "scripts" / "check_swift_literals.py"


def load():
    spec = importlib.util.spec_from_file_location("check_swift_literals", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def check(tmp_path: Path, source: str) -> list[tuple[int, str]]:
    path = tmp_path / "View.swift"
    path.write_text(source, encoding="utf-8")
    return load().violations(path)


def test_flags_numbers_in_code(tmp_path):
    source = "let a = view.padding(12)\nlet b = x.opacity(0.4)\n"
    assert check(tmp_path, source) == [(1, "12"), (2, "0.4")]


def test_allows_zero_one_halving_and_tuple_access(tmp_path):
    source = (
        "let a = [0, 1, 1.0, 0.0]\nlet b = width / 2\nlet c = pairs.map { $0.0 + $0.1 }\n"
        "let d = parts[2] + rows[i][3]\n"
    )
    assert check(tmp_path, source) == []


def test_allows_documented_constants_and_enum_raw_values(tmp_path):
    source = (
        "enum Tokens {\n"
        "  /// Card padding.\n"
        "  public static let padding: CGFloat = 16\n"
        "  /// Fast and slow periods.\n"
        "  static let fast = 9\n"
        "  static let slow = 20\n"
        "}\n"
        "enum Timeframe: Int { case m5 = 5 }\n"
    )
    assert check(tmp_path, source) == []


def test_undocumented_constant_is_flagged(tmp_path):
    source = "func f() {}\nstatic let padding: CGFloat = 16\n"
    assert check(tmp_path, source) == [(2, "16")]


def test_ignores_strings_and_comments(tmp_path):
    source = 'let a = Text("Top 20")  // 20 rows\n/* 30\n 40 */\nlet b = "\\(12)"\n'
    assert check(tmp_path, source) == []


def test_shared_package_is_clean():
    module = load()
    for root in module.DEFAULT_ROOTS:
        for path in module.swift_files(ROOT / root):
            assert module.violations(path) == [], path
