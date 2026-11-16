import AppKit
import SwiftUI
import Testing
import TickrDesign
import TickrKit
@testable import TickrMac

/// Pictures of every screen for the truncation check (owner rule 2026-11-16: no text is ever cut):
/// each section of the main window at the window's least and first sizes, and as tall as its whole
/// content at those widths, the Chart with its inspector and every study too, every Settings pane
/// and the menu-bar panel, on the contract fixtures, drawn offscreen in windows that are never
/// shown. `apps/scripts/find_truncated_text.swift` then reads them for an ellipsis
/// (.github/workflows/ui-tests.yml, job `no-truncated-text`). Runs only with
/// `TICKR_SCREEN_PICTURES=<folder>`; `TICKR_SCREEN_PICTURES_LANGUAGE` (en, ru) picks the language,
/// so run it once per language, each in its own process:
///   TICKR_SCREEN_PICTURES=/tmp/pictures TICKR_SCREEN_PICTURES_LANGUAGE=ru \
///     swift test --filter ScreenPicturesTests
@MainActor
@Suite(.serialized)
struct ScreenPicturesTests {
  static let folderKey = "TICKR_SCREEN_PICTURES"
  static let languageKey = "TICKR_SCREEN_PICTURES_LANGUAGE"
  static let defaultLanguage = "en"
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
    // Before any text is looked up: the process's language, in memory only.
    UserDefaults.standard.setVolatileDomain(["AppleLanguages": [language]], forName: UserDefaults.argumentDomain)
    let folder = URL(fileURLWithPath: path, isDirectory: true).appending(path: language)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)

    let model = PreviewAPI.model()
    Container.shared.appModel.register { model }
    let chart = Container.shared.chartModel()
    let advisor = PreviewAPI.advisor()
    // The least width holds the title bar's line, which shows the status: read it first.
    while model.status == nil { try await Task.sleep(for: Self.statusPoll) }
    let leastWidth = TickrMacApp.leastWidth(model: model, chart: chart)
    let least = CGSize(width: leastWidth, height: TickrMacApp.minHeight)
    let first = CGSize(width: TickrMacApp.defaultWidth, height: TickrMacApp.defaultHeight)
    let sizes = [
      ("least", least), ("first", first),
      ("least-tall", CGSize(width: least.width, height: Self.tallHeight)),
      ("first-tall", CGSize(width: first.width, height: Self.tallHeight)),
    ]
    for (name, size) in sizes {
      for section in AppSection.allCases {
        for inspector in section == .chart ? [false, true] : [false] {
          for key in LayoutSweep.fullChartKeys { UserDefaults.standard.set(inspector, forKey: key) }
          model.section = section
          let root = RootView()
            .environment(model).environment(chart).environment(advisor)
            .tint(Palette.info)
            .frame(minWidth: leastWidth, maxWidth: .infinity,
              minHeight: TickrMacApp.minHeight, maxHeight: .infinity)
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
