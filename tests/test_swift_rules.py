"""The apps' Swift code rules (apps/scripts/check_swift_rules.py): words, indentation, catalog."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "apps" / "scripts"


def load():
    sys.path.insert(0, str(SCRIPTS))
    script = SCRIPTS / "check_swift_rules.py"
    spec = importlib.util.spec_from_file_location("check_swift_rules", script)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def write(tmp_path: Path, source: str, name: str = "View.swift") -> Path:
    path = tmp_path / name
    path.write_text(source, encoding="utf-8")
    return path


def test_flags_words_in_ui_code(tmp_path):
    source = (
        'Text("Overview")\n'
        'Button("Quit") {}\n'
        'Text(verbatim: "Tickr")\n'
        'var title: String { return "Flatten All" }\n'
        'let s = String(localized: "Pause entries?")\n'
    )
    found = load().text_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5]


def test_allows_symbols_constants_raw_values_and_punctuation(tmp_path):
    source = (
        'Image(systemName: "gearshape")\n'
        'Label(L10n.general, systemImage: "bell.badge")\n'
        '.init(symbol: "chart.xyaxis.line")\n'
        "/// User-defaults key of the API address.\n"
        'static let apiBaseURL = "apiBaseURL"\n'
        'enum Kind: String { case foreignExposure = "foreign_exposure" }\n'
        'let line = "\\(day) · \\(name)"\n'
        'let minus = "\\u{2212}"\n'
        '@available(*, deprecated, renamed: "surface") var card: Color\n'
        '// Text("in a comment")\n'
        "let empty = \"\"\n"
    )
    assert load().text_violations(write(tmp_path, source)) == []


def test_reads_literals_inside_interpolations(tmp_path):
    source = 'let a = "\\(ok ? "\\(n)" : "none")"\n'
    assert load().text_violations(write(tmp_path, source)) == [(1, "none")]


def test_l10n_file_is_the_one_place_for_words(tmp_path):
    source = (
        'static let quit = LocalizedStringResource("app.quit", defaultValue: "Quit")\n'
        'static func open(_ name: String) -> LocalizedStringResource {\n'
        '  LocalizedStringResource("app.open",\n'
        '    defaultValue: "Open \\(name)")\n'
        "}\n"
    )
    assert load().text_violations(write(tmp_path, source, "L10n.swift")) == []


def test_l10n_file_holds_only_localized_entries(tmp_path):
    source = (
        'static let quit = "Quit"\nlet title = Text("Quit now")\n'
        'static let all = make(defaultValue: "Flatten every position")\n'
    )
    found = load().text_violations(write(tmp_path, source, "L10n.swift"))
    assert found == [(1, "Quit"), (2, "Quit now"), (3, "Flatten every position")]


def test_l10n_part_files_beside_an_l10n_file_hold_words_too(tmp_path):
    source = 'static let quit = LocalizedStringResource("app.quit", defaultValue: "Quit")\n'
    part = write(tmp_path, source, "L10n+Codes.swift")
    # Without an L10n.swift beside it, a file named like a part is ordinary code.
    assert load().text_violations(part) == [(1, "app.quit"), (1, "Quit")]
    write(tmp_path, "", "L10n.swift")
    assert load().text_violations(part) == []


def test_words_cannot_hide_in_constants_raw_values_or_symbol_shapes(tmp_path):
    source = (
        'enum Section: String { case overview = "Overview of the day" }\n'
        'enum Tab: String { case home = "Home" }\n'
        "/// The window title.\n"
        'static let title = "Strategy lab"\n'
        'Text("settings.window")\n'
        'case .lab: return "sparkles"\n'
    )
    found = load().text_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 4, 5, 6]


def test_indentation_is_two_spaces(tmp_path):
    source = "struct A {\n  var b: Int {\n      1\n  }\n\tlet c = 2\n   let d = 3\n}\n"
    found = load().indent_violations(write(tmp_path, source))
    assert found == [(3, "1"), (5, "tab"), (6, "let d = 3")]


def test_every_l10n_key_needs_a_spanish_translation(tmp_path):
    l10n = write(
        tmp_path,
        'static let quit = LocalizedStringResource("app.quit", defaultValue: "Quit")\n'
        'static let open = LocalizedStringResource("app.open", defaultValue: "Open")\n',
        "L10n.swift",
    )

    def unit(language: str, value: str) -> dict:
        string_unit = {"stringUnit": {"state": "translated", "value": value}}
        return {"localizations": {language: string_unit}}

    catalog = {
        "sourceLanguage": "en",
        "strings": {
            "app.quit": unit("es", "Salir"),
            "app.open": unit("en", "Open"),
        },
    }
    (tmp_path / "Localizable.xcstrings").write_text(json.dumps(catalog), encoding="utf-8")
    assert load().catalog_violations(l10n) == [(2, "app.open")]


def test_repository_follows_the_rules():
    assert load().main([]) == 0


def test_any_violation_fails(tmp_path, monkeypatch):
    module = load()
    write(tmp_path, 'Text("Brand new")\n')
    monkeypatch.setattr(module, "REPO", tmp_path)
    monkeypatch.setattr(module, "ROOTS", (".",))
    assert module.main([]) == 1


def test_only_the_bearer_scheme_may_be_a_capitalised_constant(tmp_path):
    source = (
        'static let undocumentedScheme = "Bearer"\n'
        "/// The authentication scheme.\n"
        'static let bearerScheme = "Bearer"\n'
        "/// The header that carries it.\n"
        'static let authorizationHeader = "Authorization"\n'
        "/// A section header.\n"
        'static let tradesHeader = "Trades"\n'
        "/// A capitalised word that is not a protocol token.\n"
        'static let title = "Overview"\n'
    )
    found = load().text_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 5, 7, 9]


def test_info_plist_texts_need_a_spanish_translation(tmp_path):
    import plistlib

    support = tmp_path / "App" / "Support"
    support.mkdir(parents=True)
    plist = support / "Info.plist"
    plist.write_bytes(plistlib.dumps({"NSFaceIDUsageDescription": "Confirms commands."}))
    assert load().plist_violations(plist) == [(1, "NSFaceIDUsageDescription")]
    catalog = {
        "strings": {
            "NSFaceIDUsageDescription": {
                "localizations": {"es": {"stringUnit": {"state": "translated", "value": "Sí"}}}
            }
        }
    }
    (tmp_path / "App" / "InfoPlist.xcstrings").write_text(json.dumps(catalog), encoding="utf-8")
    assert load().plist_violations(plist) == []


def test_info_plist_declares_every_catalog_language(tmp_path):
    import plistlib

    def catalog(path: Path, language: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        unit = {"stringUnit": {"state": "translated", "value": "x"}}
        data = {"sourceLanguage": "en", "strings": {"k": {"localizations": {language: unit}}}}
        path.write_text(json.dumps(data), encoding="utf-8")

    support = tmp_path / "App" / "Support"
    support.mkdir(parents=True)
    plist = support / "Info.plist"
    catalog(tmp_path / "App" / "Sources" / "Localizable.xcstrings", "es")
    catalog(tmp_path / "Shared" / "Localizable.xcstrings", "uk")
    shared = tmp_path / "Shared"
    plist.write_bytes(plistlib.dumps({"CFBundleName": "Tickr"}))
    assert load().localization_violations(plist, shared) == [
        (1, "CFBundleLocalizations lacks en"),
        (1, "CFBundleLocalizations lacks es"),
        (1, "CFBundleLocalizations lacks uk"),
    ]
    plist.write_bytes(plistlib.dumps({"CFBundleLocalizations": ["en", "es"]}))
    assert load().localization_violations(plist, shared) == [(1, "CFBundleLocalizations lacks uk")]
    plist.write_bytes(plistlib.dumps({"CFBundleLocalizations": ["en", "es", "uk"]}))
    assert load().localization_violations(plist, shared) == []


def test_app_info_plists_declare_their_languages():
    module = load()
    for plist in module.plist_files():
        assert module.localization_violations(plist) == [], plist


def test_flags_outdated_apple_apis(tmp_path):
    source = (
        "import XCTest\n"
        "final class Model: ObservableObject {\n"
        "  @Published var value = 0\n"
        "}\n"
        "// NavigationView in a comment is fine\n"
        "let view = NavigationView { EmptyView() }\n"
        'Text("NavigationView in a string is fine")\n'
        "DispatchQueue.main.async {}\n"
        "NSApplication.shared.activate(ignoringOtherApps: true)\n"
        "Text(title).foregroundColor(.red)\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 6, 8, 9, 10]


def test_current_apple_apis_pass(tmp_path):
    source = (
        "import Testing\n"
        "@Observable final class Model { var value = 0 }\n"
        "let view = NavigationStack { EmptyView() }\n"
        "NSApplication.shared.activate()\n"
        "Text(title).foregroundStyle(.red)\n"
    )
    assert load().legacy_violations(write(tmp_path, source)) == []


def test_ui_tests_may_use_xctest(tmp_path):
    folder = tmp_path / "TickrUITests"
    folder.mkdir()
    assert load().legacy_violations(write(folder, "import XCTest\n", "LaunchTests.swift")) == []


def test_ui_test_targets_get_only_the_legacy_rule(tmp_path, monkeypatch):
    module = load()
    folder = tmp_path / "TickrUITests"
    folder.mkdir()
    write(folder, 'import XCTest\nlet cancel = button("Cancel")\n', "FlowTests.swift")
    monkeypatch.setattr(module, "REPO", tmp_path)
    monkeypatch.setattr(module, "ROOTS", (".",))
    assert module.swift_files() == []
    assert [path.name for path in module.test_swift_files()] == ["FlowTests.swift"]


def test_an_unlisted_folder_ending_in_tests_gets_every_rule(tmp_path, monkeypatch):
    module = load()
    folder = tmp_path / "ScreenTests"
    folder.mkdir()
    write(folder, 'let cancel = button("Cancel")\n', "Screen.swift")
    monkeypatch.setattr(module, "REPO", tmp_path)
    monkeypatch.setattr(module, "ROOTS", (".",))
    assert [path.name for path in module.swift_files()] == ["Screen.swift"]
    assert module.test_swift_files() == []


def test_every_form_of_an_outdated_import_fails(tmp_path):
    source = (
        "@preconcurrency import Combine\n"
        "public import XCTest\n"
        "@testable import XCTest\n"
        "import class Combine.AnyCancellable\n"
        "@preconcurrency internal import Combine\n"
        "import Testing\n"
        "@testable import TickrKit\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5]


def test_combine_without_its_import_fails(tmp_path):
    source = (
        "let timer = Timer.publish(every: interval, on: .main, in: .common).autoconnect()\n"
        "let changes = NotificationCenter.default.publisher(for: name)\n"
        "let token = changes.sink { _ in }\n"
        "var bag: Set<AnyCancellable> = []\n"
        "let subject = PassthroughSubject<Int, Never>()\n"
        "let value = CurrentValueSubject<Int, Never>(0)\n"
        "view.onReceive(timer) { _ in }\n"
        "for await note in NotificationCenter.default.notifications(named: name) {}\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5, 6, 7]


def test_deprecated_swiftui_uikit_and_concurrency_calls_fail(tmp_path):
    source = (
        "list.navigationBarTitle(title)\n"
        "back.edgesIgnoringSafeArea(.all)\n"
        "button.accentColor(color)\n"
        "field.autocapitalization(.none)\n"
        "@Environment(\\.presentationMode) var mode\n"
        "NavigationLink(destination: Detail(), isActive: $shown) { row }\n"
        "view.onChange(of: value, perform: update)\n"
        "view.animation(.easeOut)\n"
        "let width = UIScreen.main.bounds.width\n"
        "@UIApplicationMain final class Delegate {}\n"
        "let group = DispatchGroup()\n"
        "let queue = OperationQueue()\n"
        "Thread.sleep(forTimeInterval: pause)\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == list(range(1, 14))


def test_current_forms_of_those_calls_pass(tmp_path):
    source = (
        "list.navigationTitle(title)\n"
        "back.ignoresSafeArea()\n"
        "button.tint(color)\n"
        "field.textInputAutocapitalization(.never)\n"
        "@Environment(\\.dismiss) private var dismiss\n"
        "view.onChange(of: value) { old, new in update(new) }\n"
        "view.animation(Tokens.Motion.quick, value: value)\n"
        "view.animation(.spring(response: response, dampingFraction: damping), value: value)\n"
        "TimelineView(.animation(paused: reduceMotion)) { context in }\n"
        "try await Task.sleep(for: .seconds(pause))\n"
    )
    assert load().legacy_violations(write(tmp_path, source)) == []


def test_more_deprecated_swiftui_and_uikit_calls_fail(tmp_path):
    source = (
        "image.accessibility(label: Text(title))\n"
        "row.accessibility(hidden: true)\n"
        "view.actionSheet(isPresented: $shown) { sheet }\n"
        "view.alert(isPresented: $shown) { Alert(title: Text(title)) }\n"
        "list.navigationBarItems(trailing: button)\n"
        "list.navigationBarHidden(true)\n"
        "stack.navigationViewStyle(.stack)\n"
        "view.statusBar(hidden: true)\n"
        "field.disableAutocorrection(true)\n"
        "TextField(title, text: $text, onEditingChanged: edit, onCommit: send)\n"
        "card.overlay(Circle(), alignment: .topTrailing)\n"
        "card.background(Color.clear, alignment: .top)\n"
        "let window = UIApplication.shared.windows.first\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == list(range(1, 14))


def test_current_forms_of_the_newer_checks_pass(tmp_path):
    source = (
        "image.accessibilityLabel(Text(title))\n"
        "row.accessibilityHidden(true)\n"
        "view.confirmationDialog(title, isPresented: $shown) { actions }\n"
        "view.alert(title, isPresented: $shown) { actions } message: { message }\n"
        "list.toolbarVisibility(.hidden, for: .navigationBar)\n"
        "view.statusBarHidden()\n"
        "field.autocorrectionDisabled()\n"
        "TextField(title, text: $text).onSubmit(send)\n"
        "card.overlay(alignment: .topTrailing) { Circle() }\n"
        "card.overlay(Text(title).frame(maxWidth: .infinity, alignment: .leading))\n"
        "card.background(alignment: .top) { Color.clear.frame(height: h, alignment: .top) }\n"
        "card.overlay(Capsule().strokeBorder(color, lineWidth: width))\n"
    )
    assert load().legacy_violations(write(tmp_path, source)) == []


def test_on_change_with_perform_over_several_lines_fails(tmp_path):
    source = (
        "view.onChange(\n"
        "  of: value,\n"
        "  perform: update)\n"
        "view.onChange(of: value) { old, new in\n"
        "  perform(new)\n"
        "}\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [3]


def test_combine_through_swiftui_fails(tmp_path):
    source = (
        "let one = Just(value)\n"
        "let stream: AnyPublisher<Int, Never> = one.eraseToAnyPublisher()\n"
        "one.eraseToAnyPublisher()\n"
        "one.assign(to: &$value)\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4]


def test_string_drawing_measurement_fails(tmp_path):
    source = (
        "let a = (word as NSString).size(withAttributes: [.font: font]).width\n"
        "let b = NSAttributedString(string: word, attributes: attributes).size().width\n"
        "let c = text.boundingRect(with: size, options: [], context: nil)\n"
        "let d = TextMeasure.width(word, font: font)\n"
        "let e = CGSize(width: 1, height: 1)\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3]


def test_settings_below_swift_6_or_os_26_fail(tmp_path):
    package = (
        "// swift-tools-version:5.9\n"
        "platforms: [.macOS(.v14), .iOS(.v26)],\n"
        "// swift-tools-version:6.2\n"
        "platforms: [.macOS(.v26), .iOS(.v26)],\n"
    )
    found = load().settings_violations(write(tmp_path, package, "Package.swift"))
    assert [line for line, _ in found] == [1, 2]
    modes = (
        'platforms: [.macOS("15.0")],\n'
        "swiftLanguageModes: [.v5],\n"
        "swiftSettings: [.swiftLanguageMode(.v5)],\n"
        "swiftLanguageVersions: [.v5],\n"
        'platforms: [.macOS("26.0")],\n'
        "swiftLanguageModes: [.v6],\n"
    )
    found = load().settings_violations(write(tmp_path, modes, "Package.swift"))
    assert [line for line, _ in found] == [1, 2, 3, 4]
    project = (
        "SWIFT_VERSION = 5.0;\n"
        "MACOSX_DEPLOYMENT_TARGET = 14.0;\n"
        "IPHONEOS_DEPLOYMENT_TARGET = 17.0;\n"
        "SWIFT_VERSION = 6.0;\n"
        "MACOSX_DEPLOYMENT_TARGET = 26.0;\n"
        '    iOS: "17.0"\n'
        '    SWIFT_VERSION: "6.0"\n'
    )
    found = load().settings_violations(write(tmp_path, project, "project.pbxproj"))
    assert [line for line, _ in found] == [1, 2, 3, 6]


def test_strict_concurrency_escape_hatches_fail(tmp_path):
    source = (
        "nonisolated(unsafe) static var cache = [String: Int]()\n"
        "final class Box: @unchecked Sendable {}\n"
        "@preconcurrency import Network\n"
        "extension Model: @preconcurrency Delegate {}\n"
        "nonisolated func read() -> Int { 0 }\n"
        "struct Value: Sendable {}\n"
    )
    found = load().legacy_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4]


def test_settings_that_weaken_strict_concurrency_fail(tmp_path):
    source = (
        'swiftSettings: [.unsafeFlags(["-strict-concurrency=minimal"])]\n'
        "SWIFT_STRICT_CONCURRENCY = minimal;\n"
        '    SWIFT_STRICT_CONCURRENCY: "targeted"\n'
        "SWIFT_STRICT_CONCURRENCY = complete;\n"
        "// unsafeFlags are not allowed\n"
        'OTHER_SWIFT_FLAGS = "-swift-version 5";\n'
        'OTHER_SWIFT_FLAGS = "-swift-version 6";\n'
    )
    found = load().settings_violations(write(tmp_path, source, "project.pbxproj"))
    assert [line for line, _ in found] == [1, 2, 3, 6]


def test_catalogs_must_be_in_xcode_form(tmp_path):
    rules = load()
    xcode = (
        '{\n  "sourceLanguage" : "en",\n  "strings" : {\n'
        '    "a.m5" : {\n      "comment" : "Пять"\n    },\n'
        '    "a.m15" : {\n      "comment" : "x/y"\n    },\n'
        '    "B" : {\n      "comment" : "b"\n    }\n'
        '  },\n  "version" : "1.0"\n}'
    )
    assert rules.format_xcstrings.xcode_form(xcode) == xcode
    assert rules.catalog_form_violations(write(tmp_path, xcode, "Localizable.xcstrings")) == []
    plain = json.dumps(json.loads(xcode), indent=2, sort_keys=True) + "\n"
    found = rules.catalog_form_violations(write(tmp_path, plain, "Localizable.xcstrings"))
    assert [line for line, _ in found] == [1]


def test_loop_rule_flags_self_running_motion(tmp_path):
    source = (
        "withAnimation(.easeInOut.repeatForever()) { on = true }\n"
        "TimelineView(.animation) { context in Text(\"\") }\n"
        "TimelineView(.periodic(from: .now, by: 1)) { context in Text(\"\") }\n"
        "// .repeatForever() in a comment\n"
        "layer.repeatCount = .infinity\n"
        "animation.repeatCount = Float.greatestFiniteMagnitude\n"
        "animation.repeatCount = 3\n"
    )
    found = load().loop_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 5, 6]


def test_loop_rule_allows_a_decorative_marker(tmp_path):
    source = (
        "// decorative: the brand mark's spark\n"
        "withAnimation(.easeOut.repeatForever()) { on = true }\n"
        "TimelineView(.animation) { c in Text(\"\") } // decorative: radar ornament\n"
        "// decorative: the ticker scrolls as an ornament\n"
        "scroll.repeatCount = .infinity\n"
    )
    assert load().loop_violations(write(tmp_path, source)) == []


def test_truncation_rule_flags_modifiers_that_cut_or_shrink_text(tmp_path):
    source = (
        "Text(title).lineLimit(1)\n"
        "  .truncationMode(.middle)\n"
        "  .minimumScaleFactor(0.7)\n"
        "  .allowsTightening(true)\n"
        "  .lineLimit(typeSize.large ? nil : 2)\n"
        "// .lineLimit(1) in a comment\n"
        "Text(title).fixedSize()\n"
        "Text(verbatim: \".lineLimit(1)\")\n"
    )
    found = load().truncation_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5]


def test_result_rule_flags_a_hand_picked_result_colour(tmp_path):
    source = (
        "Text(t).foregroundStyle(value >= 0 ? Palette.profitText : Palette.lossText)\n"
        "let tone: Tone = result < 0 ? .loss : .profit\n"
        "color: amount <= 0 ? Palette.loss : Palette.profit\n"
        "x > 0 ? .profit : x < 0 ? .loss : nil\n"
        "Text(t).foregroundStyle(Palette.result(value))\n"
        "let tone = Tone.result(value)\n"
        "candle.isUp ? Palette.profit : Palette.loss\n"
        "// value >= 0 ? Palette.profit : Palette.loss in a comment\n"
        "reachable ? Palette.profitText : Palette.lossText\n"
    )
    found = load().result_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4]


def test_format_rule_flags_numbers_formatted_outside_the_design_system(tmp_path):
    source = (
        "Text(change.formatted(.percent.precision(.fractionLength(2))))\n"
        "value.formatted(.number.notation(.compactName))\n"
        "value.formatted(.currency(code: \"USD\"))\n"
        "Text(cell.day, format: .number)\n"
        "static let price = FloatingPointFormatStyle<Double>.number\n"
        "let f = NumberFormatter()\n"
        "String(format: \"%.2f\", x)\n"
        "Text(Money.price(x)) + Text(Percent.signed(fraction: f))\n"
        ".accessibilityValue(Text(share, format: .percent.precision(.fractionLength(0))))\n"
        "date.formatted(.dateTime.month())\n"
        "// value.formatted(.number) in a comment\n"
    )
    found = load().format_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5, 6, 7]


def test_money_is_written_with_its_dollar_sign(tmp_path):
    """The figures that slipped past the number rule (2026-11-16): a bare `Money.signed/plain` at
    cents (also inside a string interpolation), the bot's raw text of a money or price field, and
    "USD" written after an amount."""
    source = (
        "Text(verbatim: Money.signed(value))\n"
        'text: "\\(trade.symbol) \\(Money.signed(result))"\n'
        "value: risk.map { Money.plain($0) }\n"
        "Text(verbatim: Money.signed(r, fractionDigits: Money.centsDigits))\n"
        "Text(verbatim: fill.feesUsd?.text ?? Format.missing)\n"
        "Text(verbatim: position.avgPrice?.description ?? missing)\n"
        'Text(verbatim: "fee \\(fill.feesUsd)")\n'
        "Text(verbatim: Money.signedUSD(value) + Money.usd(room) + Money.price(p.value))\n"
        "Text(verbatim: Money.signed(r, fractionDigits: 1))\n"
        "// figure: a calendar cell without $, as the board\n"
        "Text(verbatim: Money.signed(day, fractionDigits: Money.centsDigits))\n"
        "Text(verbatim: position.quantity.text)\n"
        "Text(verbatim: Money.priceChange(change.value, at: price?.value))\n"
    )
    found = load().format_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5, 6, 7]


def test_l10n_text_never_writes_usd_after_an_amount(tmp_path):
    source = (
        'LocalizedStringResource("a", defaultValue: "of \\(limit) USD left", bundle: b)\n'
        'LocalizedStringResource("b", defaultValue: "Gross USD by trade close", bundle: b)\n'
    )
    found = load().format_violations(write(tmp_path, source, "L10n.swift"))
    assert [line for line, _ in found] == [1]


def test_stop_symbol_rule_wants_the_shared_stop_symbols(tmp_path):
    source = (
        'static let verifiedSymbol = "checkmark.shield.fill"\n'
        'Image(systemName: "shield")\n'
        'Label("x", systemImage: "xmark.shield")\n'
        "Image(systemName: StopState.levelSymbol)\n"
        'static let environment = "shield" // symbol: the environment, not a stop\n'
        "// symbol: a lock screen badge\n"
        'Image(systemName: "lock.shield")\n'
        'Image(systemName: "hourglass")\n'
    )
    found = load().stop_symbol_violations(write(tmp_path, source))
    assert found == [(1, "checkmark.shield.fill"), (2, "shield"), (3, "xmark.shield")]


def test_meaning_rules_apply_to_the_apps_only(tmp_path, monkeypatch):
    module = load()
    for folder in ("apps/macos/Tickr", "apps/ios/Tickr", "apps/shared/Sources/TickrDesign"):
        (tmp_path / folder).mkdir(parents=True)
        source = 'let c = v >= 0 ? Palette.profit : Palette.loss\nlet s = "shield"\n'
        write(tmp_path / folder, source)
    monkeypatch.setattr(module, "REPO", tmp_path)
    found = module.collect()
    apps = ["apps/ios/Tickr/View.swift", "apps/macos/Tickr/View.swift"]
    assert sorted(found["result"]) == apps
    assert sorted(found["stopsymbol"]) == apps


def test_apps_have_no_control_look_of_their_own(tmp_path):
    source = (
        "struct TitleBarButtonStyle: ButtonStyle {\n"
        "private struct Press: PrimitiveButtonStyle {\n"
        "struct Switchy: ToggleStyle {\n"
        "struct Tight<T>: LabelStyle where T: View {\n"
        "extension Wide: ButtonStyle {}\n"
        "// struct Commented: ButtonStyle {\n"
        "extension ButtonStyle where Self == ActionButtonStyle {\n"
        ".buttonStyle(.action(.ghost))\n"
    )
    found = load().style_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5]


def test_apps_use_no_system_button_look(tmp_path):
    source = (
        ".buttonStyle(.borderless)\n"
        ".buttonStyle(.bordered)\n"
        ".buttonStyle( .borderedProminent )\n"
        ".buttonStyle(.link)\n"
        ".buttonStyle(BorderlessButtonStyle())\n"
        ".buttonBorderShape(.capsule)\n"
        ".buttonStyle(.plain)\n"
        ".buttonStyle(.glyph)\n"
        ".buttonStyle(.action(.secondary, size: .compact))\n"
        "// .buttonStyle(.borderless)\n"
    )
    found = load().system_button_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5, 6]


def test_apps_use_one_segmented_switch_and_one_chip(tmp_path):
    source = (
        ".pickerStyle(.segmented)\n"
        ".pickerStyle( .segmented )\n"
        ".pickerStyle(SegmentedPickerStyle())\n"
        "private struct ChipLook: ViewModifier {\n"
        "struct RangeChips<T>: ViewModifier where T: Hashable {\n"
        ".pickerStyle(.menu)\n"
        "private struct SymbolChips: View {\n"
        ".buttonStyle(.chip(selected: true))\n"
        "// .pickerStyle(.segmented)\n"
    )
    found = load().control_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5]


def test_one_symbol_per_meaning(tmp_path):
    source = (
        'static let previousSymbol = "chevron.left"\n'
        'Image(systemName: "chevron.right")\n'
        'Label { Text(title) } icon: { Image(systemName: "exclamationmark.triangle") }\n'
        'static let refused = "xmark.octagon.fill"\n'
        'Image(systemName: Symbols.previous)\n'
        'Image(systemName: "exclamationmark.triangle.fill")\n'
        '// Image(systemName: "chevron.left")\n'
    )
    found = load().symbol_violations(write(tmp_path, source))
    assert found == [
        (1, "chevron.left -> Symbols.previous"),
        (2, "chevron.right -> Symbols.next"),
        (3, "exclamationmark.triangle -> Symbols.failure"),
        (4, "xmark.octagon.fill -> Symbols.failed"),
    ]


def test_competing_symbols_point_at_shared_ones():
    module = load()
    shared = (ROOT / "apps/shared/Sources/TickrDesign/Symbols.swift").read_text(encoding="utf-8")
    for replacement in module.COMPETING_SYMBOLS.values():
        name = replacement.removeprefix("Symbols.")
        assert f"public static let {name} = " in shared, replacement
    # A shared symbol never competes with itself.
    values = [line.split('"')[1] for line in shared.splitlines() if "public static let" in line]
    assert not set(values) & set(module.COMPETING_SYMBOLS)


def app_file(module, tmp_path: Path, app: str, name: str, source: str) -> Path:
    folder = tmp_path / "apps" / app / "Tickr"
    folder.mkdir(parents=True, exist_ok=True)
    return write(folder, source, name)


def test_a_component_written_in_both_apps_fails(tmp_path, monkeypatch):
    module = load()
    monkeypatch.setattr(module, "REPO", tmp_path)
    files = [
        app_file(module, tmp_path, "macos", "Rows.swift",
                 "struct StatusRow: View {\nstruct SettingsView: View {\nstruct Dot: View {\n"),
        app_file(module, tmp_path, "ios", "Rows.swift",
                 "private struct StatusRow<Value: View>: View {\nstruct SettingsView: View {\n"
                 "struct Spot: View {\nstruct Model: Identifiable {\n"),
    ]
    found = module.twin_violations(files)
    assert found == {"apps/macos/Tickr/Rows.swift": [(1, "StatusRow")],
                     "apps/ios/Tickr/Rows.swift": [(1, "StatusRow")]}


def test_app_rules_skip_the_shared_package(tmp_path, monkeypatch):
    module = load()
    monkeypatch.setattr(module, "REPO", tmp_path)
    shared = tmp_path / "apps" / "shared" / "Sources" / "TickrDesign"
    shared.mkdir(parents=True)
    write(shared, "public struct ChipStyle: ButtonStyle {\n}\n", "Chip.swift")
    app = app_file(module, tmp_path, "ios", "Chip.swift", "struct ChipStyle: ButtonStyle {\n}\n")
    monkeypatch.setattr(module, "ROOTS", ("apps/shared", "apps/ios"))
    found = module.collect()["styles"]
    assert list(found) == [app.relative_to(tmp_path).as_posix()]


def test_known_twins_are_still_written_twice():
    module = load()
    files = module.swift_files()
    declared = {app: set() for app in module.APPS}
    for path in files:
        relative = path.relative_to(module.REPO).as_posix()
        for app in module.APPS:
            if relative.startswith(app + "/"):
                declared[app] |= set(module.component_names(path))
    # A pair that moved into TickrDesign leaves the list in the same change.
    assert module.KNOWN_TWINS <= declared["apps/macos"] & declared["apps/ios"]


def test_loaders_only_through_the_shared_components(tmp_path):
    source = (
        "ProgressView()\n"
        "ProgressView(value: 0.4)\n"
        "TickrLoader(L10n.Common.loading)\n"
        "card.redacted(reason: .placeholder)\n"
        "private struct RowShimmer: View {}\n"
        "struct BusySpinner: View {}\n"
        "final class ChartLoaderView: NSView {}\n"
        "Radar().frame(width: side)\n"
        "RadarSweep(moving: true)\n"
        "// ProgressView() in a comment\n"
        "Skeleton(L10n.Common.loading) { SkeletonBlock(.line) }\n"
        "Button {} label: {}.inFlight(Text(L10n.Bot.closing))\n"
        "ProgressLine(fraction: 0.4, label: L10n.Lab.replayProgress)\n"
        "struct SymbolsSkeleton: View {}\n"
    )
    found = load().loader_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2, 3, 4, 5, 6, 7, 8, 9]


def test_the_radar_stays_in_the_empty_positions_state(tmp_path, monkeypatch):
    module = load()
    monkeypatch.setattr(module, "REPO", tmp_path)
    radar = "Radar().frame(width: side)\n"
    home = app_file(module, tmp_path, "macos", "OverviewView.swift", radar)
    elsewhere = app_file(module, tmp_path, "macos", "ChartView.swift", radar)
    module.RADAR_HOMES = {"apps/macos/Tickr/OverviewView.swift"}
    assert module.loader_violations(home) == []
    assert [line for line, _ in module.loader_violations(elsewhere)] == [1]


def test_the_loader_rule_is_an_app_rule():
    assert "loaders" in load().APP_RULES


def test_cause_rule_flags_a_coded_cause_shown_in_the_bots_words(tmp_path):
    module = load()
    assert {"rulesCause", "sessionCause", "unavailableCause", "agreementCause", "excludedCause",
            "changeCause", "bindingCause", "fencesCause"} <= module.coded_causes()
    module.RAW_CAUSE = module.raw_cause_pattern({"rulesCause", "sessionCause"})
    source = (
        "Text(verbatim: movers.rulesCause ?? Format.missing)\n"
        "let note = jobs?.sessionCause\n"
        "Text(verbatim: movers.rulesCauseText ?? Format.missing)\n"
        "if movers.rulesCause == nil { }\n"
        "rulesCause = try c.decodeNullable(String.self, forKey: .rulesCause)\n"
        "ApiText.prose(movers.rulesCauseCodes, text: movers.rulesCause)\n"
        "// movers.rulesCause in a comment\n"
    )
    found = module.cause_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2]


def test_scroll_indicators_are_hidden_once_per_scene(tmp_path):
    module = load()
    own = write(tmp_path, (
        "Marquee(showsIndicators: false) { row }\n"
        "list.scrollIndicators(.hidden)\n"
        "// .scrollIndicators(.never) in a comment\n"
        "ScrollView(.horizontal) { row }.withoutScrollIndicators()\n"
        "ScrollView(.horizontal) { row }.withoutScrollIndicators()\n"
    ))
    assert [line for line, _ in module.scrollbar_violations(own)] == [1, 2]
    source = (
        "ScrollView { rows }\n"
        "ScrollView(.vertical) { rows }\n"
        "Form { rows }\n"
        "ScrollView(.horizontal) { chips }.withoutScrollIndicators()\n"
        "  .scrollEdgeHints()\n"
    )
    assert [line for line, _ in module.scrollbar_violations(write(tmp_path, source))] == [1, 2, 3]
    hinted = source.replace(
        "Form { rows }\n", "Form { rows }.scrollEdgeHints(position: $scroll)\n")
    assert [line for line, _ in module.scrollbar_violations(write(tmp_path, hinted))] == [3]
    faded = source.replace("Form { rows }\n", "Form { rows }.scrollEdgeFades()\n")
    faded += "  .scrollEdgeHints(position: $scroll)\n"
    assert module.scrollbar_violations(write(tmp_path, faded)) == []
    app = (
        "struct TickrApp: App {\n"
        "  var body: some Scene {\n"
        "    WindowGroup {\n"
        "      RootView()\n"
        "        .withoutScrollIndicators()\n"
        "    }\n"
        "    Settings {\n"
        "      SettingsView()\n"
        "    }\n"
        "  }\n"
        "}\n"
    )
    assert [line for line, _ in module.scrollbar_violations(write(tmp_path, app))] == [3, 7]
    fixed = app.replace(
        "      SettingsView()\n", "      SettingsView()\n        .withoutScrollIndicators()\n")
    assert module.scrollbar_violations(write(tmp_path, fixed)) == []


def test_sideways_scrolls_and_tables_hide_their_own_indicators(tmp_path):
    module = load()
    source = (
        "ScrollView(.horizontal) { chips }\n"
        "Table(rows, selection: $selection) { columns }\n"
        "Chart { marks }.chartScrollableAxes(.horizontal)\n"
        "SymbolsTable(rows: rows)\n"
    )
    assert [line for line, _ in module.scrollbar_violations(write(tmp_path, source))] == [1, 2]
    hidden = source + "  .withoutScrollIndicators()\n" * 2
    assert module.scrollbar_violations(write(tmp_path, hidden)) == []


def test_the_scrollbar_rule_is_an_app_rule():
    assert "scrollbars" in load().APP_RULES


def test_sheets_fit_their_content_instead_of_a_detent_of_their_own(tmp_path):
    module = load()
    source = (
        "sheet.presentationDetents([.medium, .large])\n"
        "// .presentationDetents([.large]) in a comment\n"
        "sheet.sheetFitsContent()\n"
    )
    assert [line for line, _ in module.sheet_violations(write(tmp_path, source))] == [1]
    assert "sheets" in module.APP_RULES


def test_breath_rule_rejects_a_shimmer_anywhere(tmp_path):
    source = (
        "struct ShimmerBand {}\n"
        "let width = Tokens.Loading.shimmerWidth\n"
        "// the old shimmer, in a comment\n"
        "Skeleton(nil) { SkeletonBlock(.line) }\n"
    )
    found = load().breath_violations(write(tmp_path, source))
    assert [line for line, _ in found] == [1, 2]
