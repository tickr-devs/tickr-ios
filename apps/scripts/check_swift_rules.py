#!/usr/bin/env python3
"""Fail CI when the apps' Swift code breaks the code rules (CLAUDE.md, docs/design-system.md).

Rules, checked in every Swift file of apps/ (tests and Package.swift excepted):

text     No words in code. A string literal holding a letter may appear only
         - in an `L10n.swift` file, the one place per target where user-facing text is defined,
           as the key or `defaultValue:` of `LocalizedStringResource("key", defaultValue: "…")`
           (the key on the same line as `LocalizedStringResource(`); nothing else there;
         - as an SF Symbol name, passed to a `systemName:`, `systemImage:` or `symbol:` label;
         - as an identifier (no whitespace, not a capitalised word such as "Overview") in a
           documented `static let` constant or an enum case raw value (protocol values, keys);
           the one capitalised protocol token allowed is "Bearer" (the HTTP authentication scheme),
           in a documented constant;
         - in an `@available` attribute (messages for developers).
         So `Text("Overview")`, `Button("Quit")`, `return "Flatten All"`,
         `Text(verbatim: "Aperture")` and `case overview = "Overview of the day"` all fail.
         Interpolations and punctuation (" · ") pass.
numbers  No magic numbers: see check_swift_literals.py.
indent   2-space indentation: no tabs, every indent even, and a line indents at most 2 deeper
         than the line before.
legacy   The current Apple stack only (CLAUDE.md, "Swift code rules"): no XCTest outside UI
         tests (Swift Testing instead); no ObservableObject or Combine-era property wrappers
         (Observation instead); no Combine, DispatchQueue, OperationQueue or Thread.sleep
         (async/await instead); no NavigationView, PreviewProvider or NSLocalizedString; no
         deprecated SwiftUI, UIKit and AppKit calls (see LEGACY). Checked in tests too.
catalog  Every key of an `L10n.swift` has a Russian translation in the target's String Catalog
         (`*.xcstrings` next to it), and every user-facing Info.plist text (`NS…UsageDescription`)
         has one in an `InfoPlist.xcstrings` of the same app.

Usage: check_swift_rules.py
"""

from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_swift_literals  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
ROOTS = ("apps/shared", "apps/macos", "apps/ios")
SKIPPED_FILES = {"Package.swift", "Package@swift-6.0.swift"}
SKIPPED_DIRS = {"Tests", ".build", "build", "DerivedData", "SourcePackages"}
L10N_FILE = "L10n.swift"
INDENT = 2

SYMBOL_ARGUMENT = re.compile(r"\b(?:systemName|systemImage|symbol)\s*:\s*$")
L10N_KEY_ARGUMENT = re.compile(r"\bLocalizedStringResource\(\s*$")
L10N_VALUE_ARGUMENT = re.compile(r"\bdefaultValue\s*:\s*$")
L10N_CALL = re.compile(r"\bLocalizedStringResource\(")
IDENTIFIER = re.compile(r"^[A-Za-z0-9_.:/%+\-]+$")
TITLE_WORD = re.compile(r"^[A-Z][a-z]+$")
# Capitalised protocol tokens a documented constant may hold: lower-case header names already pass.
PROTOCOL_TOKENS = {"Bearer"}
USAGE_KEY = re.compile(r"^NS\w*UsageDescription$")
ESCAPE = re.compile(r"\\(?:u\{[0-9A-Fa-f]+\}|.)")
LETTER = re.compile(r"[A-Za-zЀ-ӿ]")
L10N_KEY = re.compile(r'LocalizedStringResource\(\s*"([^"\\]+)"')


# MARK: - string literals


def string_literals(text: str) -> list[tuple[int, str, str]]:
    """(line, literal text without interpolations, code before it on its line) for each literal.

    Skips comments; reads string interpolations as code, so literals nested in them count too.
    """
    found: list[tuple[int, str, str]] = []
    i, line, n = 0, 1, len(text)
    line_start = 0

    def read_string(start: int, hashes: int, multiline: bool) -> int:
        """Read a literal whose opening quote(s) end at `start`; return the index after it."""
        nonlocal line, line_start
        literal_line, prefix = line, text[line_start:start].rstrip('"#')
        closing = ('"""' if multiline else '"') + "#" * hashes
        parts: list[str] = []
        j = start
        while j < n:
            if text.startswith(closing, j):
                found.append((literal_line, "".join(parts), prefix))
                return j + len(closing)
            ch = text[j]
            if ch == "\\" and text.startswith("#" * hashes, j + 1):
                k = j + 1 + hashes
                if k < n and text[k] == "(":
                    j = read_code(k + 1, close=")")
                    continue
                parts.append(text[j:k + 1])
                j = k + 1
                continue
            if ch == "\n":
                line += 1
                line_start = j + 1
            parts.append(ch)
            j += 1
        return j

    def read_code(start: int, close: str | None) -> int:
        nonlocal line, line_start
        j, depth = start, 0
        while j < n:
            if text.startswith("//", j):
                end = text.find("\n", j)
                j = n if end < 0 else end
                continue
            if text.startswith("/*", j):
                end = text.find("*/", j)
                end = n if end < 0 else end + 2
                line += text.count("\n", j, end)
                if "\n" in text[j:end]:
                    line_start = text.rfind("\n", j, end) + 1
                j = end
                continue
            ch = text[j]
            if ch == '"' or (ch == "#" and re.match(r'#+"', text[j:])):
                hashes = 0
                while text[j] == "#":
                    hashes += 1
                    j += 1
                multiline = text.startswith('"""', j)
                j = read_string(j + (3 if multiline else 1), hashes, multiline)
                continue
            if ch == "\n":
                line += 1
                line_start = j + 1
            elif close and ch == "(":
                depth += 1
            elif close and ch == close:
                if depth == 0:
                    return j + 1
                depth -= 1
            j += 1
        return j

    read_code(i, close=None)
    return found


def text_violations(path: Path) -> list[tuple[int, str]]:
    source = path.read_text(encoding="utf-8")
    documented = documented_constant_lines(source.splitlines())
    found = []
    value_lines = l10n_value_lines(source) if path.name == L10N_FILE else set()
    for number, literal, prefix in string_literals(source):
        if not LETTER.search(ESCAPE.sub("", literal)):
            continue
        if path.name == L10N_FILE:
            if not (L10N_KEY_ARGUMENT.search(prefix) or (
                    L10N_VALUE_ARGUMENT.search(prefix) and number in value_lines)):
                found.append((number, literal))
            continue
        if "@available(" in prefix or SYMBOL_ARGUMENT.search(prefix):
            continue
        is_identifier = bool(IDENTIFIER.match(literal)) and not TITLE_WORD.match(literal)
        named = number in documented or check_swift_literals.ENUM_CASE.search(prefix)
        if named and is_identifier:
            continue
        if number in documented and literal in PROTOCOL_TOKENS:
            continue
        found.append((number, literal))
    return found


def l10n_value_lines(source: str) -> set[int]:
    """Lines inside a `LocalizedStringResource(…)` call, where its `defaultValue:` may stand.

    String contents are masked first so parentheses in text do not count."""
    def blank(match: re.Match) -> str:
        return '"' + "x" * (len(match.group()) - 2) + '"'

    masked = re.sub(r'"(?:[^"\\\n]|\\.)*"', blank, source)
    lines: set[int] = set()
    for call in L10N_CALL.finditer(masked):
        depth, j = 1, call.end()
        while j < len(masked) and depth:
            depth += {"(": 1, ")": -1}.get(masked[j], 0)
            j += 1
        first = masked.count("\n", 0, call.start()) + 1
        lines.update(range(first, masked.count("\n", 0, j) + 2))
    return lines


def documented_constant_lines(lines: list[str]) -> set[int]:
    """Line numbers of `static let` constants documented with `///` (same rule as numbers)."""
    result, documented = set(), False
    for number, raw in enumerate(lines, start=1):
        stripped = raw.strip()
        if stripped.startswith("///"):
            documented = True
            continue
        is_constant = bool(check_swift_literals.CONSTANT.match(raw))
        if is_constant and documented:
            result.add(number)
            continue
        if stripped and not is_constant:
            documented = False
    return result


# MARK: - indentation


def indent_violations(path: Path) -> list[tuple[int, str]]:
    found = []
    previous = 0
    in_multiline = False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if raw.count('"""') % 2 == 1:
            in_multiline = not in_multiline
            if not in_multiline:
                continue
        elif in_multiline or not raw.strip():
            continue
        leading = raw[: len(raw) - len(raw.lstrip())]
        if "\t" in leading:
            found.append((number, "tab"))
            continue
        width = len(leading)
        if width % INDENT or width > previous + INDENT:
            found.append((number, raw.strip()))
        previous = width
    return found


# MARK: - String Catalog


def catalog_violations(path: Path) -> list[tuple[int, str]]:
    """Keys of an L10n.swift without a Russian translation in the String Catalog beside it."""
    if path.name != L10N_FILE:
        return []
    catalogs = sorted(path.parent.rglob("*.xcstrings"))
    lines = path.read_text(encoding="utf-8").splitlines()
    keys = [(n, m.group(1)) for n, raw in enumerate(lines, 1) for m in L10N_KEY.finditer(raw)]
    if not catalogs:
        return [(1, "no String Catalog (*.xcstrings) next to L10n.swift")] if keys else []
    strings: dict = {}
    for catalog in catalogs:
        strings.update(json.loads(catalog.read_text(encoding="utf-8")).get("strings", {}))
    found = []
    for number, key in keys:
        unit = strings.get(key, {}).get("localizations", {}).get("ru", {}).get("stringUnit", {})
        variations = strings.get(key, {}).get("localizations", {}).get("ru", {}).get("variations")
        if not variations and (unit.get("state") != "translated" or not unit.get("value")):
            found.append((number, key))
    return found


def plist_violations(path: Path) -> list[tuple[int, str]]:
    """Info.plist texts a person reads, without a Russian translation in InfoPlist.xcstrings."""
    texts = [key for key, value in plistlib.loads(path.read_bytes()).items()
             if USAGE_KEY.match(key) and isinstance(value, str)]
    if not texts:
        return []
    app = path.parent.parent
    strings: dict = {}
    for catalog in sorted(app.rglob("InfoPlist.xcstrings")):
        strings.update(json.loads(catalog.read_text(encoding="utf-8")).get("strings", {}))
    found = []
    for key in texts:
        unit = strings.get(key, {}).get("localizations", {}).get("ru", {}).get("stringUnit", {})
        if unit.get("state") != "translated" or not unit.get("value"):
            found.append((1, key))
    return found


# MARK: - running


# An import with any attributes and access modifier: `@testable import`, `@preconcurrency public
# import`, `import class Combine.AnyCancellable`.
ACCESS = r"(?:public|package|internal|fileprivate|private)"
IMPORT = r"^\s*(?:@\w+\s+)*(?:" + ACCESS + r"\s+)?import\s+(?:\w+\s+)?"
# One unlabelled argument, no comma at the top level: `.animation(.easeOut)`, not
# `.animation(.easeOut, value: x)` or the TimelineView schedule `.animation(paused:)`.
ONE_ARGUMENT = r"\((?!\s*\w+:)(?:[^(),]|\([^()]*\))*\)"
XCTEST = "XCTest: use Swift Testing (import Testing, @Test, #expect)"
COMBINE = "Combine: use async/await, AsyncSequence and Observation"
CONCURRENCY = "use async/await, Task and actors"
UNSAFE = "strict-concurrency escape hatch: make the type Sendable or isolate it to an actor"
LEGACY = [
    (re.compile(IMPORT + r"XCTest\b"), XCTEST),
    (re.compile(IMPORT + r"Combine\b"), COMBINE),
    (re.compile(r"\b(?:AnyCancellable|PassthroughSubject|CurrentValueSubject)\b"), COMBINE),
    (re.compile(r"\b(?:Just|AnyPublisher)\b|\.eraseToAnyPublisher\(|\.assign\(to:"), COMBINE),
    (re.compile(r"\bTimer\.publish\(|\.publisher\(|\.sink\s*[({]|\.onReceive\("), COMBINE),
    (re.compile(r"\bObservableObject\b"), "ObservableObject: use @Observable"),
    (re.compile(r"@(?:Published|StateObject|ObservedObject|EnvironmentObject)\b"),
     "Combine-era property wrapper: use @Observable with @State, @Environment, @Bindable"),
    (re.compile(r"\bNavigationView\b"), "NavigationView: use NavigationStack or SplitView"),
    (re.compile(r"\bNavigationLink\b.*\bisActive:"),
     "NavigationLink(isActive:): navigationDestination"),
    (re.compile(r"\bpresentationMode\b"), "presentationMode: use @Environment(\\.dismiss)"),
    (re.compile(r"\bDispatch(?:Queue|Group)\b|\bOperationQueue\b|\bThread\.sleep\b"), CONCURRENCY),
    (re.compile(r"\bPreviewProvider\b"), "PreviewProvider: use #Preview"),
    (re.compile(r"\bNSLocalizedString\b"),
     "NSLocalizedString: use L10n.swift and a String Catalog"),
    (re.compile(r"@(?:UI|NS)ApplicationMain\b"),
     "@UIApplicationMain / @NSApplicationMain: use @main"),
    (re.compile(r"\bUIScreen\.main\b"), "UIScreen.main is deprecated: use the view's window scene"),
    (re.compile(r"\.foregroundColor\("), "foregroundColor is deprecated: use foregroundStyle"),
    (re.compile(r"\.cornerRadius\("),
     "cornerRadius is deprecated: use clipShape(.rect(cornerRadius:))"),
    (re.compile(r"\.navigationBarTitle\("),
     "navigationBarTitle is deprecated: use navigationTitle"),
    (re.compile(r"\.edgesIgnoringSafeArea\("),
     "edgesIgnoringSafeArea is deprecated: use ignoresSafeArea"),
    (re.compile(r"\.accentColor\("), "accentColor is deprecated: use tint"),
    (re.compile(r"\.autocapitalization\("),
     "autocapitalization is deprecated: use textInputAutocapitalization"),
    (re.compile(r"\.onChange\(of:.*\bperform:"),
     "onChange(of:perform:) is deprecated: use onChange(of:) { old, new in }"),
    (re.compile(r"\.animation" + ONE_ARGUMENT),
     "animation(_:) without value: is deprecated: pass value:"),
    (re.compile(r"\bnonisolated\(unsafe\)|@unchecked\s+Sendable\b|@preconcurrency\b"), UNSAFE),
    (re.compile(r"ignoringOtherApps"),
     "activate(ignoringOtherApps:) is deprecated: use NSApp.activate()"),
]
# `.onChange(of: value, perform: action)` spread over several lines.
ON_CHANGE = ".onChange("
PERFORM = re.compile(r"\bperform:")
UI_TESTS = re.compile(r"UITests?$")


def legacy_violations(path: Path) -> list[tuple[int, str]]:
    """Outdated APIs, in code (comments ignored). UI test targets may still use XCTest."""
    ui_tests = any(UI_TESTS.search(part) for part in path.parts)
    found, in_block = [], False
    # Open parentheses of an `.onChange(of:` call that continues over several lines (0 = none).
    on_change = 0
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        start = code.find(ON_CHANGE) if not on_change else 0
        if start >= 0:
            tail = code[start:]
            if on_change and PERFORM.search(tail):
                found.append((number, code.strip()))
                on_change = 0
                continue
            on_change = max(on_change + tail.count("(") - tail.count(")"), 0)
        for pattern, reason in LEGACY:
            if pattern.search(code) and not (ui_tests and reason == XCTEST):
                found.append((number, code.strip()))
                break
    return found


# Project settings of the current stack: Swift 6 language mode and the latest OS releases.
SWIFT_MODE = 6
LATEST_OS = 26
SETTINGS = [
    (re.compile(r"swift-tools-version:\s*(\d+)"), SWIFT_MODE),
    (re.compile(r"\.(?:macOS|iOS)\(\.v(\d+)"), LATEST_OS),
    (re.compile(r"\bSWIFT_VERSION[\s=:]+\"?(\d+)"), SWIFT_MODE),
    (re.compile(r"_DEPLOYMENT_TARGET[\s=:]+\"?(\d+)"), LATEST_OS),
    (re.compile(r"^\s*(?:iOS|macOS):\s*\"?(\d+)"), LATEST_OS),
]
# Settings that weaken strict concurrency: unsafe compiler flags and any checking level below
# complete.
WEAKENED = re.compile(
    r"unsafeFlags|-strict-concurrency=|SWIFT_STRICT_CONCURRENCY[\s=:\"]+(?!complete\b)\w")
SETTINGS_FILES = ("Package.swift", "project.pbxproj", "project.yml")


def settings_violations(path: Path) -> list[tuple[int, str]]:
    """Package and Xcode project settings older than Swift 6 or the latest OS releases."""
    found = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if WEAKENED.search(line) and not line.lstrip().startswith(("//", "#")):
            found.append((number, line.strip()))
            continue
        for pattern, least in SETTINGS:
            if any(int(value) < least for value in pattern.findall(line)):
                found.append((number, line.strip()))
                break
    return found


def number_violations(path: Path) -> list[tuple[int, str]]:
    if path.name in check_swift_literals.SKIPPED_FILES:
        return []
    return check_swift_literals.violations(path)


RULES = {
    "text": (text_violations, "words in code; define them in L10n.swift, translated to Russian"),
    "numbers": (number_violations, "magic number; use a token or a documented constant"),
    "indent": (indent_violations, "indent with 2 spaces"),
    "catalog": (catalog_violations, "text without a Russian translation in a String Catalog"),
    "legacy": (legacy_violations, "outdated API: use the current Apple stack (CLAUDE.md)"),
}


def swift_files() -> list[Path]:
    files = []
    for root in ROOTS:
        for path in sorted((REPO / root).rglob("*.swift")):
            relative = path.relative_to(REPO)
            if path.name in SKIPPED_FILES or SKIPPED_DIRS.intersection(relative.parts):
                continue
            files.append(path)
    return files


def test_swift_files() -> list[Path]:
    """Swift files in test targets: only the legacy rule applies to them."""
    files = []
    for root in ROOTS:
        for path in sorted((REPO / root).rglob("*.swift")):
            parts = path.relative_to(REPO).parts
            if "Tests" in parts or any(part.endswith("Tests") for part in parts):
                if not ({".build", "build", "DerivedData", "SourcePackages"} & set(parts)):
                    files.append(path)
    return files


def settings_files() -> list[Path]:
    return [path for root in ROOTS for name in SETTINGS_FILES
            for path in sorted((REPO / root).rglob(name))
            if not ({".build", "build", "DerivedData", "SourcePackages"}
                    & set(path.relative_to(REPO).parts))]


def plist_files() -> list[Path]:
    return [path for root in ROOTS for path in sorted((REPO / root).rglob("Info.plist"))
            if not SKIPPED_DIRS.intersection(path.relative_to(REPO).parts)]


def collect() -> dict[str, dict[str, list[tuple[int, str]]]]:
    result: dict[str, dict[str, list[tuple[int, str]]]] = {rule: {} for rule in RULES}
    for path in swift_files():
        key = path.relative_to(REPO).as_posix()
        for rule, (check, _) in RULES.items():
            found = check(path)
            if found:
                result[rule][key] = found
    for path in test_swift_files():
        found = legacy_violations(path)
        if found:
            result["legacy"][path.relative_to(REPO).as_posix()] = found
    for path in settings_files():
        found = settings_violations(path)
        if found:
            result["legacy"][path.relative_to(REPO).as_posix()] = found
    for path in plist_files():
        found = plist_violations(path)
        if found:
            result["catalog"][path.relative_to(REPO).as_posix()] = found
    return result


def main(argv: list[str]) -> int:
    found = collect()
    failures = 0
    for rule, (_, message) in RULES.items():
        for path, items in sorted(found[rule].items()):
            for line, detail in items:
                failures += 1
                print(f"{path}:{line}: {rule}: {detail!r}: {message}")
    if failures:
        print("Swift code rules failed; see CLAUDE.md (Swift code rules) and docs/design-system.md")
        return 1
    print("Swift code rules pass")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
