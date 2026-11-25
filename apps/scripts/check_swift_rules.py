#!/usr/bin/env python3
"""Fail CI when the apps' Swift code breaks the code rules (CLAUDE.md, docs/design-system.md).

Rules, checked in every Swift file of apps/ (tests and Package.swift excepted):

text     No words in code. A string literal holding a letter may appear only
         - in an `L10n.swift` file, the one place per target where user-facing text is defined
           (a target may split it into extension files named `L10n+<Part>.swift` beside it),
           as the key or `defaultValue:` of `LocalizedStringResource("key", defaultValue: "…")`
           (the key on the same line as `LocalizedStringResource(`); nothing else there;
         - as an SF Symbol name, passed to a `systemName:`, `systemImage:` or `symbol:` label;
         - as an identifier (no whitespace, not a capitalised word such as "Overview") in a
           documented `static let` constant or an enum case raw value (protocol values, keys);
           the one capitalised protocol token allowed is "Bearer" (the HTTP authentication scheme),
           in a documented constant;
         - in an `@available` attribute (messages for developers).
         So `Text("Overview")`, `Button("Quit")`, `return "Flatten All"`,
         `Text(verbatim: "Tickr")` and `case overview = "Overview of the day"` all fail.
         Interpolations and punctuation (" · ") pass.
numbers  No magic numbers: see check_swift_literals.py.
indent   2-space indentation: no tabs, every indent even, and a line indents at most 2 deeper
         than the line before.
legacy   The current Apple stack only (CLAUDE.md, "Swift code rules"): no XCTest outside UI
         tests (Swift Testing instead); no ObservableObject or Combine-era property wrappers
         (Observation instead); no Combine, DispatchQueue, OperationQueue or Thread.sleep
         (async/await instead); no NavigationView, PreviewProvider or NSLocalizedString; no
         deprecated SwiftUI, UIKit and AppKit calls (see LEGACY); no text measured through the
         string-drawing engine (`size(withAttributes:)`, `NSAttributedString(…).size()`,
         `boundingRect(with:…)`), which threw while another thread measured text (2026-11-19):
         TickrDesign's `TextMeasure` measures with Core Text. Checked in tests too.
catalog  Every key of an `L10n.swift` has a Spanish (`es`) translation in the target's String
         Catalog (`*.xcstrings` next to it), and every user-facing Info.plist text
         (`NS…UsageDescription`) has one in an `InfoPlist.xcstrings` of the same app. Every String
         Catalog is committed in the exact form Xcode writes (format_xcstrings.py), so a build
         leaves no diff. Every app Info.plist lists in `CFBundleLocalizations` each language the
         app's and the shared package's String Catalogs translate (the app follows the system
         language; without the list the SwiftPM-built Mac app opens in English).
result   (apps/macos, apps/ios) A money result's colour comes only from the shared map
         (`Palette.result` / `Tone.result`, zero neutral): no hand-written
         `>= 0 ? … profit : … loss`.
format   (apps/macos, apps/ios) Numbers are formatted only by TickrDesign (`Money`, `Percent`,
         `Volume`, Formatting.swift), the same in both apps and every language: no
         `.formatted(.number|.percent|.currency…)`, `format: .number|.percent|.currency`,
         `FloatingPointFormatStyle`, `NumberFormatter`, `String(format:` or `.currency(code:`.
         A line that sets an `accessibilityValue` may let VoiceOver read a number in the
         person's locale.
         Money is always in dollars (owner rule 2026-11-16, one meaning one look). `Money.signed`,
         `Money.plain` and `Money.number` write a bare figure, so a call that leaves their cents
         default (or passes `Money.centsDigits`) is an amount without its "$": use
         `Money.signedUSD` / `Money.usd`, `Money.price` for a price, or name the digits of a
         figure that is not money; a figure on purpose without "$" (a calendar cell) is marked
         `// figure: <why>` on its line or the line above. The bot's own text of a money or price
         field (`fill.feesUsd?.text`, `"\\(position.lastPrice)"`) is never shown: format its
         `.value`. An L10n text never writes "USD" after an amount: the "$" comes from `Money`.
stopsymbol  (apps/macos, apps/ios) A stop's symbols (every SF Symbol with "shield") come only
         from TickrDesign's `StopState` constants, one symbol per meaning. A shield that means
         something else is marked `// symbol: <meaning>` on its line or the line above.
breath   A skeleton breathes in place (owner 2026-11-19, mockup v121): no sweeping shimmer
         band anywhere, TickrDesign included (no identifier holding "shimmer").
truncation  No text is ever cut (owner rule 2026-11-16, docs/design-system.md "Text is never
         cut"): no `.lineLimit`, `.truncationMode`, `.minimumScaleFactor` or
         `.allowsTightening`. A text that does not fit wraps or its layout adapts; one that must
         stay on one line takes its whole width with `.fixedSize()`.

One look per element (owner rule 2026-11-16: the same element looks the same on every screen of
both apps; docs/design-system.md "One look per element"). Checked in the apps (apps/macos,
apps/ios), not in TickrDesign, where the shared looks live:
styles   No `ButtonStyle`, `PrimitiveButtonStyle`, `ToggleStyle` or `LabelStyle` of an app's own:
         every control look is a TickrDesign component.
system-buttons  No system button look: `.buttonStyle(.bordered | .borderedProminent | .borderless
         | .link)`, their `…ButtonStyle()` types or `.buttonBorderShape`. A label that is its own
         face takes `.buttonStyle(.glyph)`; other buttons `.action`, `.icon`, `.chip`.
controls One segmented switch and one chip (mockup v98): no system segmented `Picker`
         (`.pickerStyle(.segmented)`, `SegmentedPickerStyle`), use TickrDesign's `SegmentSwitch`;
         no chip look of an app's own (a `ViewModifier` named …Chip…), use `.chip(selected:)`,
         `.toggleStyle(.chip)` or `.chipFace(selected:)`.
symbols  One SF Symbol per meaning: a symbol that competes with one of TickrDesign's `Symbols`
         (`chevron.left` for `Symbols.previous`, an outlined triangle for `Symbols.failure`) fails.
loaders  Loading only through TickrDesign's three components (mockup v102, docs/design-system.md
         "Loading"): `Skeleton` for content, `.inFlight(_:)`'s spinner in a command's button,
         `ProgressLine` for an operation of known length. So no `ProgressView` (the system
         spinner), no `TickrLoader` (the radar loader, removed), no `.redacted(reason:
         .placeholder)`, no type of the app's own named …Shimmer…, …Spinner… or …Loader…, and no
         radar (`Radar…(`) outside the empty "no positions" state (RADAR_HOMES).
components  No view or style type name declared in both apps (a cross-file pass): a component
         drawn on both lives once in TickrDesign. A screen or a card of one app (a name ending
         in View, Card, Page, Sheet, Panel, Section, Screen or Chart) is that app's own
         arrangement; the few pairs written before the rule are listed in KNOWN_TWINS until they
         move.

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
import format_xcstrings  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
ROOTS = ("apps/shared", "apps/macos", "apps/ios")
SKIPPED_FILES = {"Package.swift", "Package@swift-6.0.swift"}
# Folders of test targets: only the legacy rule applies inside them. Listed one by one, so a
# product folder can't escape the text and number rules by a name that merely ends in "Tests".
TEST_DIRS = {"Tests", "TickrUITests"}
BUILD_DIRS = {".build", "build", "DerivedData", "SourcePackages"}
SKIPPED_DIRS = TEST_DIRS | BUILD_DIRS
L10N_FILE = "L10n.swift"
L10N_PART = re.compile(r"L10n\+\w+\.swift")
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


def is_l10n(path: Path) -> bool:
    """An L10n.swift, or a part of one (`L10n+<Part>.swift`) in the same folder."""
    return path.name == L10N_FILE or (
        L10N_PART.fullmatch(path.name) is not None and (path.parent / L10N_FILE).exists())


def text_violations(path: Path) -> list[tuple[int, str]]:
    source = path.read_text(encoding="utf-8")
    documented = documented_constant_lines(source.splitlines())
    found = []
    value_lines = l10n_value_lines(source) if is_l10n(path) else set()
    for number, literal, prefix in string_literals(source):
        if not LETTER.search(ESCAPE.sub("", literal)):
            continue
        if is_l10n(path):
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

# The apps' second language beside English: Spanish for the US market, written as plain `es` so
# every Spanish system language (es-US, es-419, es-MX, es-ES) falls back to it.
TRANSLATION = "es"


def catalog_violations(path: Path) -> list[tuple[int, str]]:
    """Keys of an L10n.swift without a Spanish translation in the String Catalog beside it."""
    if not is_l10n(path):
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
        translation = strings.get(key, {}).get("localizations", {}).get(TRANSLATION, {})
        unit = translation.get("stringUnit", {})
        variations = translation.get("variations")
        if not variations and (unit.get("state") != "translated" or not unit.get("value")):
            found.append((number, key))
    return found


def plist_violations(path: Path) -> list[tuple[int, str]]:
    """Info.plist texts a person reads, without a Spanish translation in InfoPlist.xcstrings."""
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
        translation = strings.get(key, {}).get("localizations", {}).get(TRANSLATION, {})
        unit = translation.get("stringUnit", {})
        if unit.get("state") != "translated" or not unit.get("value"):
            found.append((1, key))
    return found


SHARED = "apps/shared"


def catalog_languages(root: Path) -> set[str]:
    """Languages any String Catalog under `root` holds a translation for, the source included."""
    languages: set[str] = set()
    for catalog in sorted(root.rglob("*.xcstrings")):
        if BUILD_DIRS.intersection(catalog.relative_to(root).parts):
            continue
        data = json.loads(catalog.read_text(encoding="utf-8"))
        languages.add(data.get("sourceLanguage", ""))
        for entry in data.get("strings", {}).values():
            languages.update(entry.get("localizations", {}))
    return languages - {""}


def localization_violations(path: Path, shared: Path | None = None) -> list[tuple[int, str]]:
    """Catalog languages (the app's and the shared package's) missing from CFBundleLocalizations."""
    app = path.parent.parent
    languages = catalog_languages(app) | catalog_languages(shared or REPO / SHARED)
    declared = plistlib.loads(path.read_bytes()).get("CFBundleLocalizations", [])
    return [(1, f"CFBundleLocalizations lacks {language}")
            for language in sorted(languages - set(declared))]


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
    (re.compile(r"\.accessibility\(\s*(?:label|hidden|identifier|value|hint|addTraits|removeTraits"
                r"|sortPriority|inputLabels|selectionIdentifier|activationPoint):"),
     "accessibility(label:) and its siblings are deprecated: use accessibilityLabel(_:) etc."),
    (re.compile(r"\bActionSheet\b|\.actionSheet\("),
     "ActionSheet is deprecated: use confirmationDialog"),
    (re.compile(r"\bAlert\("), "Alert is deprecated: use alert(_:isPresented:actions:message:)"),
    (re.compile(r"\.navigationBarItems\(|\.navigationBarHidden\(|\.navigationViewStyle\("),
     "NavigationView bar modifiers are deprecated: use toolbar and toolbarVisibility"),
    (re.compile(r"\.statusBar\(\s*hidden:"),
     "statusBar(hidden:) is deprecated: use statusBarHidden"),
    (re.compile(r"\.disableAutocorrection\("),
     "disableAutocorrection is deprecated: use autocorrectionDisabled"),
    (re.compile(r"\bonEditingChanged:|\bonCommit:"),
     "TextField(onEditingChanged:onCommit:) is deprecated: use focused and onSubmit"),
    # `alignment:` at the call's own level: not the one of a `.frame(…, alignment:)` inside it.
    (re.compile(r"\.(?:overlay|background)\((?!\s*alignment:)"
                r"(?:[^(){}]|\((?:[^()]|\([^()]*\))*\))*,\s*alignment:"),
     "overlay(_:alignment:), background(_:alignment:) are deprecated: use (alignment:) { }"),
    (re.compile(r"\.tabItem\s*[({]"),
     "tabItem is the old TabView form: use Tab(value:) { } label: { }"),
    (re.compile(r"\bUIApplication\.shared\.(?:windows|keyWindow)\b"),
     "UIApplication.windows and keyWindow are deprecated: use the view's window scene"),
    (re.compile(r"\.size\(\s*withAttributes:|\bNSAttributedString\(.*\)\.size\(\)|\.boundingRect\(\s*with:"),
     "string-drawing measurement crashes while another thread measures text: use TextMeasure"),
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


# Modifiers that cut a text (an ellipsis) or shrink it below its font's token.
TRUNCATION = re.compile(r"\.(?:lineLimit|truncationMode|minimumScaleFactor|allowsTightening)\s*\(")


def truncation_violations(path: Path) -> list[tuple[int, str]]:
    """A modifier that may cut or shrink a text, in code (comments ignored)."""
    found, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if TRUNCATION.search(code):
            found.append((number, code.strip()))
    return found


# Project settings of the current stack: Swift 6 language mode and the latest OS releases.
SWIFT_MODE = 6
LATEST_OS = 26
SETTINGS = [
    (re.compile(r"swift-tools-version:\s*(\d+)"), SWIFT_MODE),
    (re.compile(r"\.(?:macOS|iOS)\(\s*(?:\.v|\")(\d+)"), LATEST_OS),
    (re.compile(r"swiftLanguage(?:Modes?|Versions)\b\W*\.v(\d+)"), SWIFT_MODE),
    (re.compile(r"\bSWIFT_VERSION[\s=:]+\"?(\d+)"), SWIFT_MODE),
    (re.compile(r"_DEPLOYMENT_TARGET[\s=:]+\"?(\d+)"), LATEST_OS),
    (re.compile(r"^\s*(?:iOS|macOS):\s*\"?(\d+)"), LATEST_OS),
]
# Settings that weaken strict concurrency: unsafe compiler flags and any checking level below
# complete.
WEAKENED = re.compile(
    r"unsafeFlags|-strict-concurrency=|-swift-version\s+[1-5]\b"
    r"|SWIFT_STRICT_CONCURRENCY[\s=:\"]+(?!complete\b)\w")
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


# Motion that runs on its own clock: a repeating animation or a TimelineView redrawn every frame.
# The owner's rule (docs/design-system.md, "Motion"): anything that reads as data or activity
# moves only when the bot's data changes. Pure decoration (the brand mark, an empty-state
# ornament) may loop, marked `// decorative: <why>` on the same line or the line above.
LOOP = re.compile(
    r"\.repeatForever\(|TimelineView\(\s*\.animation\b"
    r"|\brepeatCount\s*=\s*(?:Float)?\.(?:infinity|greatestFiniteMagnitude)\b"
)
DECORATIVE = "// decorative:"


# A sweeping shimmer band, the loader the owner had replaced (2026-11-19).
SHIMMER = re.compile(r"[Ss]himmer")


def breath_violations(path: Path) -> list[tuple[int, str]]:
    """A shimmer band in code (comments ignored): skeletons breathe in place instead."""
    found, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if SHIMMER.search(code):
            found.append((number, code.strip()))
    return found


def loop_violations(path: Path) -> list[tuple[int, str]]:
    """Self-running motion without a decorative marker (comments ignored)."""
    found, in_block, previous = [], False, ""
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if LOOP.search(code) and DECORATIVE not in raw and DECORATIVE not in previous:
            found.append((number, code.strip()))
        previous = raw
    return found


# MARK: - one meaning, one look (apps/macos and apps/ios only)

# The rules below check the apps only (`is_app_file`, `APP_RULES`), never the shared package
# that holds the one map each rule points to.
# A result's sign picking profit or loss by hand: `x >= 0 ? Palette.profitText : Palette.lossText`,
# `value < 0 ? .loss : .profit`.
RESULT_SIGN = re.compile(r"(?:>=?|<=?)\s*0\s*\?\s*(?:Palette\.|Tone\.|\.)?(?:profit|loss)\w*")
# A number formatted outside TickrDesign.
NUMBER_FORMAT = re.compile(
    r"\.formatted\(\s*\.(?:number|percent|currency)\b|\bformat:\s*\.(?:number|percent|currency)\b"
    r"|\bFloatingPointFormatStyle\b|\bIntegerFormatStyle\b|\bNumberFormatter\b|\bString\(format:"
    r"|\.currency\(code:")
# VoiceOver may read a number in the person's locale.
ACCESSIBILITY_VALUE = "accessibilityValue"
# A bare-figure formatter of `Money` (no "$"); its call text is read to the closing parenthesis.
BARE_FIGURE = re.compile(r"\bMoney\.(?:signed|plain|number)\(")
FIGURE_MARKER = "// figure:"
# The kit's `DecimalString` fields that hold money or a price (`…Usd`, `…USD`, `…Price`, `price`).
DECIMAL_FIELD = re.compile(r"public (?:let|var) (\w+): DecimalString\??")
MONEY_FIELD = re.compile(r"\w*(?:Usd|USD|Price)|price")
# An amount written in an L10n text with "USD" after it.
USD_TEXT = re.compile(r"\\\([^)]*\)\s*USD\b")
# An SF Symbol name with a shield (a string literal's whole text).
SHIELD_SYMBOL = re.compile(r"(?:[a-z]+\.)*shield(?:\.[a-z]+)*")
SYMBOL_MARKER = "// symbol:"


def _code_lines(path: Path) -> list[tuple[int, str, str]]:
    """(line, code without comments, the raw line) for each line."""
    lines, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        lines.append((number, code, raw))
    return lines


def result_violations(path: Path) -> list[tuple[int, str]]:
    """A result's colour picked by its sign by hand instead of `Palette.result` / `Tone.result`."""
    return [(number, code.strip()) for number, code, _ in _code_lines(path)
            if RESULT_SIGN.search(code)]


def money_fields() -> set[str]:
    """The kit's `DecimalString` fields holding money or a price."""
    return {name for path in sorted((REPO / KIT_SOURCES).glob("*.swift"))
            for name in DECIMAL_FIELD.findall(path.read_text(encoding="utf-8"))
            if MONEY_FIELD.fullmatch(name)}


def raw_money_pattern(names: set[str]) -> re.Pattern[str]:
    """The bot's own text of one of `names`: its `.text` / `.description`, or the field
    interpolated whole (`"\\(fill.feesUsd)"`)."""
    alternatives = "|".join(sorted(names)) or "(?!)"
    return re.compile(r"\.(?:" + alternatives + r")\??\.(?:text|description)\b"
                      r"|\\\(\s*[\w.?]*\.(?:" + alternatives + r")\s*[!?]?\s*\)")


def _interpolated_code(line: str) -> str:
    """One line's code with comments dropped and each string literal reduced to the code of its
    interpolations (`"\\(a) \\(Money.signed(b))"` keeps `\\(a)\\(Money.signed(b))`), so a call
    inside a string is checked like any other (`check_swift_literals.strip` drops it whole)."""
    out, i, n = [], 0, len(line)
    while i < n:
        if line.startswith("//", i):
            break
        if line[i] != '"':
            out.append(line[i])
            i += 1
            continue
        i += 1
        while i < n and line[i] != '"':
            if line.startswith("\\(", i):
                depth, j = 1, i + 2
                while j < n and depth:
                    depth += {"(": 1, ")": -1}.get(line[j], 0)
                    j += 1
                out.append(line[i:j])
                i = j
            else:
                i += 2 if line[i] == "\\" else 1
        i += 1
    return "".join(out)


def _call_text(code: str, start: int) -> str:
    """The text of the call whose "(" ends at `start` - 1, to its matching ")" (or the end)."""
    depth, index = 1, start
    while index < len(code) and depth:
        depth += {"(": 1, ")": -1}.get(code[index], 0)
        index += 1
    return code[start:index]


def _bare_money(code: str) -> bool:
    """A `Money.signed/plain/number` call at the cents default: an amount without its "$"."""
    for match in BARE_FIGURE.finditer(code):
        call = _call_text(code, match.end())
        if "fractionDigits:" not in call or "Money.centsDigits" in call:
            return True
    return False


def format_violations(path: Path) -> list[tuple[int, str]]:
    """A number formatted outside TickrDesign (a line setting an accessibilityValue excepted);
    money without its "$" (unless marked `// figure:`); the bot's raw text of a money or price
    field; "USD" written after an amount in an L10n text."""
    found, previous = [], ""
    raw_money = raw_money_pattern(money_fields())
    l10n = is_l10n(path)
    for number, code, raw in _code_lines(path):
        full = _interpolated_code(raw) if code.strip() else ""
        if NUMBER_FORMAT.search(code) and ACCESSIBILITY_VALUE not in raw:
            found.append((number, code.strip()))
        elif _bare_money(full) and FIGURE_MARKER not in raw and FIGURE_MARKER not in previous:
            found.append((number, raw.strip()))
        elif raw_money.search(full):
            found.append((number, raw.strip()))
        elif l10n and USD_TEXT.search(raw):
            found.append((number, raw.strip()))
        previous = raw
    return found


def stop_symbol_violations(path: Path) -> list[tuple[int, str]]:
    """A shield symbol written in an app instead of taken from `StopState`, unless marked."""
    source = path.read_text(encoding="utf-8")
    lines = source.splitlines()
    found = []
    for number, literal, _ in string_literals(source):
        if not SHIELD_SYMBOL.fullmatch(literal):
            continue
        nearby = (lines[index] for index in (number - 2, number - 1) if index >= 0)
        marked = any(SYMBOL_MARKER in line for line in nearby)
        if not marked:
            found.append((number, literal))
    return found


def number_violations(path: Path) -> list[tuple[int, str]]:
    if path.name in check_swift_literals.SKIPPED_FILES:
        return []
    return check_swift_literals.violations(path)


def catalog_form_violations(path: Path) -> list[tuple[int, str]]:
    """A String Catalog not in the form Xcode writes: the next build would rewrite it."""
    text = path.read_text(encoding="utf-8")
    if format_xcstrings.xcode_form(text) == text:
        return []
    return [(1, "not in Xcode's form; run apps/scripts/format_xcstrings.py")]


# MARK: - one look per element


APPS = ("apps/macos", "apps/ios")
# An app's own control look: a type conforming to one of SwiftUI's style protocols.
STYLE_CONFORMANCE = re.compile(
    r"\b(?:struct|class|enum|extension)\s+[\w.]+(?:<[^{]*?>)?\s*:[^{]*?"
    r"\b(?:PrimitiveButtonStyle|ButtonStyle|ToggleStyle|LabelStyle)\b")
SYSTEM_BUTTONS = re.compile(
    r"\.buttonStyle\(\s*\.(?:bordered|borderedProminent|borderless|link)\s*\)"
    r"|\b(?:Bordered|BorderedProminent|Borderless|Link)ButtonStyle\s*\("
    r"|\.buttonBorderShape\s*\(")
# The system's segmented picker, and a chip look of an app's own (a view modifier named for a chip).
SEGMENTED = re.compile(r"\.pickerStyle\(\s*\.segmented\s*\)|\bSegmentedPickerStyle\b")
OWN_CHIP = re.compile(
    r"\b(?:struct|class|enum)\s+\w*Chip\w*(?:<[^{]*?>)?\s*:[^{]*?\bViewModifier\b")
# Symbols that compete with TickrDesign's `Symbols` (apps/shared/Sources/TickrDesign/Symbols.swift)
# for a meaning, and the shared one to use instead.
COMPETING_SYMBOLS = {
    "chevron.left": "Symbols.previous",
    "chevron.right": "Symbols.next",
    "exclamationmark.triangle": "Symbols.failure",
    "xmark.octagon": "Symbols.failed",
    "xmark.octagon.fill": "Symbols.failed",
    "checkmark.seal": "Symbols.passed",
    "pause.circle.fill": "Symbols.pause",
}


def is_app_file(path: Path) -> bool:
    """A file of the macOS or the iOS app (not the shared package)."""
    try:
        relative = path.relative_to(REPO).as_posix()
    except ValueError:
        return False
    return any(relative.startswith(app + "/") for app in APPS)


def style_violations(path: Path) -> list[tuple[int, str]]:
    """A control look of the app's own (comments ignored)."""
    found, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if STYLE_CONFORMANCE.search(code):
            found.append((number, code.strip()))
    return found


def system_button_violations(path: Path) -> list[tuple[int, str]]:
    """A system button look (comments ignored)."""
    found, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if SYSTEM_BUTTONS.search(code):
            found.append((number, code.strip()))
    return found


def control_violations(path: Path) -> list[tuple[int, str]]:
    """A system segmented picker or a chip look of the app's own (comments ignored)."""
    found, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if SEGMENTED.search(code) or OWN_CHIP.search(code):
            found.append((number, code.strip()))
    return found


def symbol_violations(path: Path) -> list[tuple[int, str]]:
    """A string literal naming a symbol that competes with a shared `Symbols` one."""
    source = path.read_text(encoding="utf-8")
    return [(number, f"{literal} -> {COMPETING_SYMBOLS[literal]}")
            for number, literal, _ in string_literals(source) if literal in COMPETING_SYMBOLS]


# A view or style type: `struct Name<…>: …View…` (private ones too).
COMPONENT = re.compile(
    r"^\s*(?:@\w+\s+)*(?:(?:public|package|internal|fileprivate|private|final)\s+)*struct\s+(\w+)"
    r"(?:<[^{]*?>)?\s*:[^{]*?\b(?:View|ViewModifier|ButtonStyle|ToggleStyle|LabelStyle)\b")
# Names of one app's own arrangements, which the other app may name alike.
ARRANGEMENT = re.compile(r"(?:View|Card|Page|Sheet|Panel|Section|Screen|Chart)$")
# Components written in both apps before the rule (2026-11-16), each to move into TickrDesign
# (or be renamed) in its own change; never add a name here.
KNOWN_TWINS = {
    "CauseText", "EventStrip", "PositionDetail", "SettingsRow",
    "SkippedRow", "StatTile", "WatchingRow",
}


# Loading pieces an app may not draw itself: the system spinner, the removed radar loader, the
# system placeholder look, and a shimmer, spinner or loader type of its own.
LOADER = re.compile(
    r"\bProgressView\b|\bTickrLoader\b|\.redacted\(\s*reason:\s*\.placeholder\b"
    r"|\b(?:struct|class|enum|actor)\s+\w*(?:Shimmer|Spinner|Loader)\w*")
# The radar is the empty "no positions" state's ornament only (mockup v102).
RADAR = re.compile(r"\bRadar\w*\s*\(")
RADAR_HOMES = {"apps/macos/Tickr/OverviewView.swift", "apps/macos/Tickr/RadarSweep.swift"}


def loader_violations(path: Path) -> list[tuple[int, str]]:
    """A loader that is not one of TickrDesign's three (comments ignored)."""
    try:
        relative = path.relative_to(REPO).as_posix()
    except ValueError:
        relative = path.as_posix()
    radar_home = relative in RADAR_HOMES
    found, in_block = [], False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        if LOADER.search(code) or (RADAR.search(code) and not radar_home):
            found.append((number, code.strip()))
    return found


def component_names(path: Path) -> dict[str, int]:
    """Component type names declared in a file, with the line of each (comments ignored)."""
    found: dict[str, int] = {}
    in_block = False
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, in_block = check_swift_literals.strip(raw, in_block)
        match = COMPONENT.match(code)
        if match and not ARRANGEMENT.search(match.group(1)):
            found.setdefault(match.group(1), number)
    return found


def twin_violations(files: list[Path]) -> dict[str, list[tuple[int, str]]]:
    """Component names declared in both apps, at each declaration."""
    declared: dict[str, dict[str, list[tuple[Path, int]]]] = {app: {} for app in APPS}
    for path in files:
        relative = path.relative_to(REPO).as_posix()
        app = next((app for app in APPS if relative.startswith(app + "/")), None)
        if app is None:
            continue
        for name, number in component_names(path).items():
            declared[app].setdefault(name, []).append((path, number))
    found: dict[str, list[tuple[int, str]]] = {}
    twins = set.intersection(*(set(names) for names in declared.values())) - KNOWN_TWINS
    for name in sorted(twins):
        for app in APPS:
            for path, number in declared[app][name]:
                found.setdefault(path.relative_to(REPO).as_posix(), []).append((number, name))
    return found


# MARK: - a cause shown only in the person's language


KIT_SOURCES = "apps/shared/Sources/TickrKit"
# `public let <name>Cause<Codes>: [ReasonV1]`: a cause field that comes with its codes.
CODED_CAUSE = re.compile(r"public let (\w+Cause)Codes: \[ReasonV1\]")


def coded_causes() -> set[str]:
    """The cause fields (`xxxCause`) of the kit's contract models that carry codes."""
    return {name for path in sorted((REPO / KIT_SOURCES).glob("*.swift"))
            for name in CODED_CAUSE.findall(path.read_text(encoding="utf-8"))}


def raw_cause_pattern(names: set[str]) -> re.Pattern[str]:
    """A read of one of `names` that is not a nil test or a coding key: the bot's own words."""
    alternatives = "|".join(sorted(names)) or "(?!)"
    return re.compile(r"(?<!forKey: )(?<!cause: )\.(?:" + alternatives + r")\b(?!\s*[!=]=\s*nil)")


# Where a coded cause may be read as text: the call that puts it in the person's language.
PROSE_CALL = "ApiText.prose("


RAW_CAUSE = raw_cause_pattern(coded_causes())


def cause_violations(path: Path) -> list[tuple[int, str]]:
    """A coded cause read as the bot's text (comments ignored): show its `…Text` accessor (the
    person's language) instead; only a nil test may read the raw field."""
    return [(number, code.strip()) for number, code, _ in _code_lines(path)
            if RAW_CAUSE.search(code) and PROSE_CALL not in code]



# Scroll indicators: the owner wants none, anywhere (2026-11-18). Each scene's root hides them once
# with TickrDesign's `withoutScrollIndicators()`; an app never sets them view by view.
OWN_INDICATORS = re.compile(r"\bshowsIndicators\s*:|\.scrollIndicators\s*\(")
# A scene of an app: its root view must hide the indicators.
SCENE = re.compile(
    r"\b(?:WindowGroup|Window|Settings|MenuBarExtra|DocumentGroup|UtilityWindow)\s*[({]")
APP_TYPE = re.compile(r":\s*App\s*\{")
NO_INDICATORS = ".withoutScrollIndicators()"
# In place of the indicators (owner's pick, 2026-11-18): a scroll view that may scroll vertically
# shows TickrDesign's `scrollEdgeHints()` (edge fade and chevron); a form or a list, which a scroll
# position cannot move, `scrollEdgeFades()` (the fade only).
VERTICAL_SCROLL = re.compile(r"\bScrollView\s*(?:\((?!\s*\.horizontal\b)|\{)")
EDGE_HINTS = ".scrollEdgeHints("
FORM_SCROLL = re.compile(r"\b(?:Form|List)\s*[({]")
EDGE_FADES = ".scrollEdgeFades("
# A scroll that shows no edge hints (a sideways scroll view, a table) hides its indicators itself:
# on the Mac a scene root's `withoutScrollIndicators()` did not reach the screens' scroll views
# (owner, 2026-11-19). A scrolling chart is left out: on the Mac chart with every study the
# modifier kept the chart screen from appearing in the UI tests (#711).
PLAIN_SCROLL = re.compile(r"\bScrollView\s*\(\s*\.horizontal\b|\bTable\s*[({<]")


def scrollbar_violations(path: Path) -> list[tuple[int, str]]:
    """Scroll indicators set by an app's own view; a vertical scroll view, form or list without its
    edge hints; or a scene, sideways scroll view or table that does not hide its indicators
    itself."""
    lines = _code_lines(path)
    found = [(number, code.strip()) for number, code, _ in lines if OWN_INDICATORS.search(code)]
    for opener, hint in ((VERTICAL_SCROLL, EDGE_HINTS), (FORM_SCROLL, EDGE_FADES)):
        scrolls = [(number, code.strip()) for number, code, _ in lines if opener.search(code)]
        if sum(code.count(hint) for _, code, _ in lines) < len(scrolls):
            found.extend(scrolls)
    plain = [(number, code.strip()) for number, code, _ in lines if PLAIN_SCROLL.search(code)]
    if any(APP_TYPE.search(code) for _, code, _ in lines):
        plain += [(number, code.strip()) for number, code, _ in lines if SCENE.search(code)]
    if sum(code.count(NO_INDICATORS) for _, code, _ in lines) < len(plain):
        found.extend(plain)
    return found

# A sheet's height (owner, 2026-11-20: the bot actions opened at half height, scrolled, and the
# chevron sat on Cancel): every sheet is as tall as its content through TickrDesign's
# `sheetFitsContent()`; an app never picks a detent of its own.
OWN_DETENT = re.compile(r"\.presentationDetents\s*\(")


def sheet_violations(path: Path) -> list[tuple[int, str]]:
    """A sheet height picked by an app's own view instead of `sheetFitsContent()`."""
    lines = _code_lines(path)
    return [(number, code.strip()) for number, code, _ in lines if OWN_DETENT.search(code)]


RULES = {
    "text": (text_violations, "words in code; define them in L10n.swift, translated to Spanish"),
    "numbers": (number_violations, "magic number; use a token or a documented constant"),
    "indent": (indent_violations, "indent with 2 spaces"),
    "catalog": (catalog_violations,
      "text without a Spanish translation, or a language missing from an Info.plist"),
    "legacy": (legacy_violations, "outdated API: use the current Apple stack (CLAUDE.md)"),
    "breath": (breath_violations,
      "a shimmer band; a skeleton breathes in place (Skeleton, docs/design-system.md Loading)"),
    "truncation": (truncation_violations,
      "text may be cut or shrunk; let it wrap or give it room (docs/design-system.md)"),
    "loop": (loop_violations,
      "motion on its own clock; move only on a real data change, "
      "or mark it `// decorative: <why>`"),
  "styles": (style_violations,
      "a control look of the app's own; use or add a TickrDesign style (docs/design-system.md)"),
  "system-buttons": (system_button_violations,
      "a system button look; use .glyph, .action, .icon or .chip (TickrDesign)"),
  "controls": (control_violations,
      "a segmented Picker or a chip look of the app's own; use SegmentSwitch or the .chip styles"),
  "symbols": (symbol_violations, "a symbol competing with a shared one; use TickrDesign's Symbols"),
  "loaders": (loader_violations,
      "a loader of the app's own; use Skeleton, .inFlight(_:) or ProgressLine "
      "(docs/design-system.md)"),
  "components": (lambda path: [],
      "a component written in both apps; move it into TickrDesign (or name each app's own)"),
  "result": (result_violations,
      "result colour by hand; use Palette.result or Tone.result (zero is neutral)"),
  "format": (format_violations,
      "number formatted outside TickrDesign, or money without its \"$\"; use Money.signedUSD, "
      "Money.usd, Money.price, Percent or Volume (Formatting.swift)"),
  "stopsymbol": (stop_symbol_violations,
      "stop symbol written by hand; use StopState's symbols, or mark another meaning `// symbol:`"),
  "scrollbars": (scrollbar_violations,
      "scroll indicators set by hand, a vertical scroll without scrollEdgeHints() (a Form or "
      "List: scrollEdgeFades()), or a scene, sideways scroll or Table without "
      "withoutScrollIndicators(); docs/design-system.md, Scrolling"),
  "sheets": (sheet_violations,
      "a sheet height of the app's own; use sheetFitsContent() (docs/design-system.md, Sheets)"),
  "cause": (cause_violations,
      "a cause shown in the bot's words; use its `…Text` accessor (the person's language)"),
}
# Rules of the apps only: TickrDesign is where the shared looks and the one map of each meaning
# are defined.
APP_RULES = {
    "styles", "system-buttons", "controls", "symbols", "result", "format", "stopsymbol", "loaders",
    "scrollbars", "sheets",
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
            if TEST_DIRS.intersection(parts) and not BUILD_DIRS.intersection(parts):
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
    files = swift_files()
    for path in files:
        key = path.relative_to(REPO).as_posix()
        app = is_app_file(path)
        for rule, (check, _) in RULES.items():
            if rule in APP_RULES and not app:
                continue
            found = check(path)
            if found:
                result[rule][key] = found
    result["components"].update(twin_violations(files))
    for path in test_swift_files():
        found = legacy_violations(path)
        if found:
            result["legacy"][path.relative_to(REPO).as_posix()] = found
    for path in settings_files():
        found = settings_violations(path)
        if found:
            result["legacy"][path.relative_to(REPO).as_posix()] = found
    for path in plist_files():
        found = plist_violations(path) + localization_violations(path)
        if found:
            result["catalog"][path.relative_to(REPO).as_posix()] = found
    for path in format_xcstrings.catalogs():
        found = catalog_form_violations(path)
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
