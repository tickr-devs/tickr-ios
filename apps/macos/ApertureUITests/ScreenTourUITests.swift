import XCTest

/// Walks every screen of the app against a running bot API (for example `aperture demo`) and
/// keeps a screenshot of the window on each, for comparing the app with the design. It sends no
/// command: a confirmation is opened and cancelled. Runs only against `aperture demo`: skipped
/// unless TOUR_API is set (so CI, which has no bot, never runs it) and its GET /status names the
/// demo environment, so a wrong port can never point the tour at a real bot.
///
/// Run on the Mac, once per appearance:
///   TEST_RUNNER_TOUR_API=http://127.0.0.1:8776 TEST_RUNNER_TOUR_APPEARANCE=Dark \
///   xcodebuild test -workspace Aperture.xcworkspace -scheme "Aperture macOS" \
///     -only-testing:"Aperture macOS UITests/ScreenTourUITests" -resultBundlePath tour.xcresult
///   xcrun xcresulttool export attachments --path tour.xcresult --output-path tour
/// Environment: TOUR_API (the demo's API) and TOUR_APPEARANCE (Light or Dark, default Light).
/// The app runs in English: the tour finds the standard menus and Cancel by their English titles.
@MainActor
final class ScreenTourUITests: XCTestCase {
  private static let defaultAppearance = "Light"
  /// The only language the tour runs the app in (its labels below are English).
  private static let language = "en"
  /// The environment `aperture demo` runs as (config/demo.toml [demo] environment).
  private static let demoEnvironment = "demo"
  /// GET path of the bot status (APIClient.statusPath).
  private static let statusPath = "status"
  /// Seconds the screens get to load and finish their entrance animations.
  private static let settle: UInt32 = 3
  /// Seconds to wait for an element to appear.
  private static let wait: TimeInterval = 10
  /// Sidebar sections (AppSection raw values) and the id prefixes of their rows and screens.
  private static let sections = ["overview", "chart", "trades", "risk", "lab"]
  private static let rowPrefix = "sidebar-"
  private static let screenPrefix = "screen-"
  /// The Chart's decisions toggle (ChartView.decisionsToggleID).
  private static let decisionsToggle = "chart-decisions"
  /// Prefix of a flatten button id (BotAction.flattenPrefix).
  private static let flattenPrefix = "flatten-"
  /// English texts of the standard menus and buttons the tour uses.
  private enum Label {
    static let windowMenu = "Window"
    static let zoom = "Zoom"
    static let showSidebar = "Show Sidebar"
    static let cancel = "Cancel"
  }

  private let app = XCUIApplication()

  override func setUp() async throws {
    continueAfterFailure = true
    let environment = ProcessInfo.processInfo.environment
    guard let api = environment["TOUR_API"] else {
      throw XCTSkip("TOUR_API is not set: the screen tour needs a running bot API")
    }
    guard try await Self.environment(of: api) == Self.demoEnvironment else {
      throw XCTSkip("TOUR_API \(api) is not `aperture demo`: the tour runs only on the demo")
    }
    let appearance = environment["TOUR_APPEARANCE"] ?? Self.defaultAppearance
    app.launchArguments = ["-apiBaseURL", api, "-AppleInterfaceStyle", appearance,
                           "-AppleLanguages", "(\(Self.language))", "-ApplePersistenceIgnoreState", "YES"]
    app.launch()
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: Self.wait), "no window")
    app.menuBars.menuBarItems[Label.windowMenu].click()
    app.menuItems[Label.zoom].click()
    let showSidebar = app.toolbars.buttons[Label.showSidebar]
    if showSidebar.exists { showSidebar.click() }
    sleep(Self.settle)
  }

  func testTour() {
    for section in Self.sections {
      let row = app.descendants(matching: .any)[Self.rowPrefix + section].firstMatch
      guard row.waitForExistence(timeout: Self.wait) else {
        XCTFail("sidebar row \(section)")
        continue
      }
      row.click()
      _ = app.descendants(matching: .any)[Self.screenPrefix + section].firstMatch
        .waitForExistence(timeout: Self.wait)
      sleep(Self.settle)
      shot(section)
      switch section {
      case "overview": confirmation()
      case "chart": decisions()
      case "trades": tradeRow()
      default: break
      }
    }
    settings()
  }

  // MARK: - screens behind the sections

  /// The confirmation of the first flatten button, cancelled.
  private func confirmation() {
    let flatten = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.flattenPrefix))
      .firstMatch
    guard flatten.waitForExistence(timeout: Self.wait), flatten.isEnabled else { return }
    flatten.click()
    let sheet = app.sheets.firstMatch
    guard sheet.waitForExistence(timeout: Self.wait) else { return }
    sleep(1)
    shot("overview-flatten-confirmation")
    sheet.buttons[Label.cancel].click()
    sleep(1)
  }

  private func decisions() {
    let toggle = app.descendants(matching: .any)[Self.decisionsToggle].firstMatch
    guard toggle.waitForExistence(timeout: Self.wait) else { return }
    toggle.click()
    sleep(Self.settle)
    shot("chart-decisions")
    toggle.click()
  }

  private func tradeRow() {
    let row = app.tables.firstMatch.tableRows.firstMatch
    guard row.waitForExistence(timeout: Self.wait) else { return }
    row.click()
    sleep(1)
    shot("trades-selected")
  }

  /// Every tab of the Settings window (⌘,).
  private func settings() {
    app.typeKey(",", modifierFlags: .command)
    let window = app.windows.element(boundBy: 0)
    guard window.waitForExistence(timeout: Self.wait) else { return }
    sleep(1)
    let tabs = window.toolbars.buttons
    for index in 0..<tabs.count {
      tabs.element(boundBy: index).click()
      sleep(1)
      shot("settings-\(index)", of: window)
    }
  }

  // MARK: - helpers

  /// The environment the bot behind `api` reports in GET /status (`status.environment`).
  private static func environment(of api: String) async throws -> String? {
    guard let url = URL(string: api)?.appending(path: statusPath) else { return nil }
    let (data, _) = try await URLSession.shared.data(from: url)
    let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let status = body?["status"] as? [String: Any]
    return status?["environment"] as? String
  }

  private func shot(_ name: String, of element: XCUIElement? = nil) {
    let screenshot = (element ?? app.windows.firstMatch).screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
