import AppKit
import SwiftUI
import Testing
import TickrDesign
import TickrKit
@testable import TickrMac

/// Pictures of every screen for the truncation check (owner rule 2026-11-16: no text is ever cut):
/// each section of the main window at the window's least and first sizes and on the two narrow
/// boards (1024 and 640 points), and as tall as its whole content at those widths, the Chart with its inspector and every study too, every Settings pane
/// and the menu-bar panel, on the contract fixtures, drawn offscreen in windows that are never
/// shown, in the light and the dark appearance (`<folder>/<language>/<appearance>/`).
/// `apps/scripts/find_truncated_text.swift` then reads them for an ellipsis
/// (.github/workflows/ui-tests.yml, job `no-truncated-text`). Runs only with
/// `TICKR_SCREEN_PICTURES=<folder>`; `TICKR_SCREEN_PICTURES_LANGUAGE` (en, es) picks the language
/// and the locale, given to the process as a launch argument would be (the argument domain, which
/// `StringsBundle` reads at the first text), so run it once per language, each in its own process:
///   TICKR_SCREEN_PICTURES=/tmp/pictures TICKR_SCREEN_PICTURES_LANGUAGE=es \
///     swift test --filter ScreenPicturesTests
@MainActor
@Suite(.serialized)
struct ScreenPicturesTests {
  static let folderKey = "TICKR_SCREEN_PICTURES"
  static let languageKey = "TICKR_SCREEN_PICTURES_LANGUAGE"
  static let defaultLanguage = "en"
  /// The preference keys of the process's languages and locale (Foundation's own names).
  static let languagesKey = "AppleLanguages"
  static let localeKey = "AppleLocale"
  /// One text in every language the pictures are drawn in: the pass fails when the catalogs
  /// answer in another language (a Spanish pass that draws English checks nothing).
  static let quitText = ["en": "Quit", "es": "Salir"]
  /// The appearances every screen is drawn in, with the folder each one's pictures go to.
  static let appearances: [(folder: String, name: NSAppearance.Name)] = [
    ("light", .aqua), ("dark", .darkAqua),
  ]
  /// Widths of the narrow pictures, in points: a 1024 × 768 display and the narrowest board.
  static let narrowWidth: CGFloat = 1024
  static let narrowestWidth: CGFloat = 640
  /// Height of a "tall" picture, in points: every screen's whole content at the fixture data.
  static let tallHeight: CGFloat = 2600
  /// Height of the Settings window as the design draws it (MacSystem), in points.
  static let settingsHeight: CGFloat = 655
  /// Size the menu-bar panel is drawn in, in points: its own width, and room for its content.
  static let menuBarHeight: CGFloat = 760
  /// Seconds a screen gets to read the fixtures and finish its entrance animations.
  static let settle: Duration = .seconds(3)
  /// How often the fixtures' status is looked for before the least width is read.
  static let statusPoll: Duration = .milliseconds(100)
  /// Where the windows are drawn: far off every display.
  static let offscreen = CGPoint(x: -20000, y: -20000)

  @Test func pictures() async throws {
    // Named reads only: the whole environment is never bound, printed or passed on.
    guard let path = ProcessInfo.processInfo.environment[Self.folderKey] else { return }
    let language = ProcessInfo.processInfo.environment[Self.languageKey] ?? Self.defaultLanguage
    // Before any text is looked up: the process's language and locale, as `-AppleLanguages` and
    // `-AppleLocale` at launch would give them, in memory only.
    UserDefaults.standard.setVolatileDomain(
      [Self.languagesKey: [language], Self.localeKey: language], forName: UserDefaults.argumentDomain)
    #expect(String(localized: L10n.App.quit) == Self.quitText[language])
    for appearance in Self.appearances {
      let folder = URL(fileURLWithPath: path, isDirectory: true)
        .appending(path: language).appending(path: appearance.folder)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      NSApplication.shared.appearance = NSAppearance(named: appearance.name)
      try await pictures(in: folder)
    }
  }

  /// Every screen's pictures, in the current appearance, into `folder`.
  private func pictures(in folder: URL) async throws {
    let model = PreviewAPI.model()
    Container.shared.appModel.register { model }
    let chart = Container.shared.chartModel()
    // The least width holds the title bar's line, which shows the status: read it first.
    while model.status == nil { try await Task.sleep(for: Self.statusPoll) }
    let leastWidth = TickrMacApp.leastWidth(model: model, chart: chart)
    let least = CGSize(width: leastWidth, height: TickrMacApp.minHeight)
    let first = CGSize(width: TickrMacApp.defaultWidth, height: TickrMacApp.defaultHeight)
    let sizes = [
      ("least", least), ("first", first),
      ("least-tall", CGSize(width: least.width, height: Self.tallHeight)),
      ("first-tall", CGSize(width: first.width, height: Self.tallHeight)),
      // A window capped to a small display (owner decision 2026-11-16, option A; MainNarrow
      // v110): the two-column board and the one-column board with the icon rail.
      ("narrow-tall", CGSize(width: Self.narrowWidth, height: Self.tallHeight)),
      ("narrowest-tall", CGSize(width: Self.narrowestWidth, height: Self.tallHeight)),
    ]
    for (name, size) in sizes {
      for section in AppSection.allCases {
        for inspector in section == .chart ? [false, true] : [false] {
          for key in LayoutSweep.fullChartKeys { UserDefaults.standard.set(inspector, forKey: key) }
          model.section = section
          let root = RootView()
            .environment(model).environment(chart)
            .tint(Palette.info)
            .frame(minWidth: min(leastWidth, size.width), maxWidth: .infinity,
              minHeight: min(TickrMacApp.minHeight, size.height), maxHeight: .infinity)
          let parts = [name, section.rawValue] + (inspector ? [LayoutSweep.inspectorSuffix] : [])
          try await picture(root, size: size, toolbar: true,
            file: folder.appending(path: parts.joined(separator: LayoutSweep.separator)))
        }
      }
    }
    for key in LayoutSweep.fullChartKeys { UserDefaults.standard.set(false, forKey: key) }
    for tab in SettingsTab.allCases {
      try await picture(SettingsView(tab: tab).environment(model).tint(Palette.info),
        size: CGSize(width: SettingsView.width, height: Self.settingsHeight), toolbar: false,
        file: folder.appending(path: "settings-\(tab.rawValue)"))
    }
    try await picture(MenuBarPanel().environment(model).tint(Palette.info),
      size: CGSize(width: MenuBarPanel.width, height: Self.menuBarHeight), toolbar: false,
      file: folder.appending(path: "menu-bar"))
  }

  /// Draws `view` in a window of `size` that is never shown, and writes it as `<file>.png`.
  private func picture(_ view: some View, size: CGSize, toolbar: Bool, file: URL) async throws {
    let frame = CGRect(origin: Self.offscreen, size: size)
    let window = NSWindow(contentRect: frame, styleMask: [.titled, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    if toolbar { window.toolbarStyle = .unifiedCompact }
    window.contentViewController = NSHostingController(rootView: view)
    window.setFrame(frame, display: true)
    try await Task.sleep(for: Self.settle)
    window.setFrame(frame, display: true)
    defer {
      window.contentViewController = nil
      window.close()
    }
    guard let drawn = window.contentView?.superview ?? window.contentView,
      let bitmap = drawn.bitmapImageRepForCachingDisplay(in: drawn.bounds) else {
      Issue.record("no picture of \(file.lastPathComponent)")
      return
    }
    drawn.cacheDisplay(in: drawn.bounds, to: bitmap)
    let png = try #require(bitmap.representation(using: .png, properties: [:]))
    try png.write(to: file.appendingPathExtension(LayoutSweep.pictureExtension))
  }
}
