import XCTest

/// Walks every screen of the app against a running bot API (for example `tickr demo`) and
/// keeps a screenshot of the window on each, for comparing the app with the design. It sends no
/// command: a confirmation is opened and cancelled. Runs only against `tickr demo`: skipped
/// unless TOUR_API is set (so CI, which has no bot, never runs it) and its GET /status names the
/// demo environment, so a wrong port can never point the tour at a real bot.
///
/// Pictures: macOS grants screen recording per app and a test runner is a new app on every build,
/// so the tour does not take them itself. `apps/scripts/tour_capture.swift`, started from a
/// terminal that already has the Screen Recording permission, takes each one when the tour asks.
/// Run on the Mac, once per appearance:
///   swift apps/scripts/tour_capture.swift \
///     ~/Library/Containers/bot.tickr.mac.uitests.xctrunner/Data/tmp/tour-dark &
///   TEST_RUNNER_TOUR_API=http://127.0.0.1:8776 TEST_RUNNER_TOUR_APPEARANCE=Dark \
///   TEST_RUNNER_TOUR_CAPTURE=tour-dark \
///   xcodebuild test -workspace Tickr.xcworkspace -scheme "Tickr macOS" \
///     -only-testing:"Tickr macOS UITests/ScreenTourUITests"
/// Environment: TOUR_API (the demo's API), TOUR_APPEARANCE (Light or Dark, default Light) and
/// TOUR_CAPTURE (the name of the capture folder; without it the tour keeps XCUIScreen
/// attachments, which need the runner itself to have Screen Recording). The runner is sandboxed,
/// so the folder is in its own temporary directory, the path given to the script above.
/// The app runs in English: the tour finds the standard menus and Cancel by their English titles.
@MainActor
final class ScreenTourUITests: XCTestCase {
  private static let defaultAppearance = "Light"
  /// The only language the tour runs the app in (its labels below are English).
  private static let language = "en"
  /// The environment `tickr demo` runs as (config/demo.toml [demo] environment).
  private static let demoEnvironment = "demo"
  /// GET path of the bot status (APIClient.statusPath).
  private static let statusPath = "status"
  /// Seconds the screens get to load and finish their entrance animations.
  private static let settle: UInt32 = 3
  /// Seconds to wait for an element to appear, and for the capture script to take a picture.
  private static let wait: TimeInterval = 10
  /// Microseconds between looks for the capture script's answer.
  private static let capturePoll: useconds_t = 200_000
  /// Sidebar sections (AppSection raw values) and the id prefixes of their rows and screens.
  private static let sections = ["overview", "chart", "trades", "risk", "lab"]
  private static let rowPrefix = "sidebar-"
  private static let screenPrefix = "screen-"
  /// The Chart's decisions toggle (ChartView.decisionsToggleID).
  private static let decisionsToggle = "chart-decisions"
  /// The Chart rail's explain card (ChartExplainCard.contentID): present while the rail is shown.
  private static let explainCard = "chart-decisions-list"
  /// Prefix of a flatten button id (BotAction.flattenPrefix).
  private static let flattenPrefix = "flatten-"
  /// English texts of the standard buttons the tour uses.
  private enum Label {
    static let showSidebar = "Show Sidebar"
    static let cancel = "Cancel"
  }

  private let app = XCUIApplication()
  private var captureDir: URL?

  /// One named variable of the test process's environment. Only named reads: the whole
  /// environment is never bound, printed or passed on (CLAUDE.md, hard rule 10).
  private static func variable(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
  }

  override func setUp() async throws {
    continueAfterFailure = true
    guard let api = Self.variable("TOUR_API") else {
      throw XCTSkip("TOUR_API is not set: the screen tour needs a running bot API")
    }
    guard try await Self.environment(of: api) == Self.demoEnvironment else {
      throw XCTSkip("TOUR_API \(api) is not `tickr demo`: the tour runs only on the demo")
    }
    captureDir = Self.variable("TOUR_CAPTURE").map {
      FileManager.default.temporaryDirectory.appending(path: $0, directoryHint: .isDirectory)
    }
    let appearance = Self.variable("TOUR_APPEARANCE") ?? Self.defaultAppearance
    // Defaults.appearance of the app: `-AppleInterfaceStyle Light` is not a value macOS knows,
    // so on a Mac in dark mode it would still be dark.
    app.launchArguments = [
      "-apiBaseURL", api, "-appearance", appearance.lowercased(),
      "-AppleLanguages", "(\(Self.language))", "-ApplePersistenceIgnoreState", "YES",
    ]
    app.launch()
    let window = app.windows.firstMatch
    XCTAssertTrue(window.waitForExistence(timeout: Self.wait), "no window")
    // Option-click on the green button zooms with no menu, so no menu is left open to swallow
    // the next click (TickrUITests.launch).
    let zoom = window.buttons[XCUIIdentifierFullScreenWindow]
    XCTAssertTrue(zoom.waitForExistence(timeout: Self.wait), "no zoom button")
    XCUIElement.perform(withKeyModifiers: .option) { zoom.click() }
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

  override func tearDown() async throws {
    // Each run starts a new copy of the app; close it, or copies pile up between runs.
    app.terminate()
    if let captureDir {  // ends tour_capture.swift, also after a failure
      FileManager.default.createFile(atPath: captureDir.appending(path: "stop").path, contents: nil)
    }
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
    // The rail is shown by default (ChartView.Keys.decisions): open it only while it is hidden.
    let hidden = !app.descendants(matching: .any)[Self.explainCard].firstMatch.exists
    if hidden {
      toggle.click()
      sleep(Self.settle)
    }
    shot("chart-decisions")
    if hidden { toggle.click() }
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
    // The design's own tab strip (SettingsTabBar), not a toolbar: its buttons by their ids.
    let tabs = window.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings-tab-"))
    for index in 0..<tabs.count {
      tabs.element(boundBy: index).click()
      sleep(1)
      shot("settings-\(index)", of: window, front: true)
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

  /// A picture of the app's window (`front`: its frontmost window, such as Settings).
  private func shot(_ name: String, of element: XCUIElement? = nil, front: Bool = false) {
    if let captureDir {
      requestCapture(name, front: front, in: captureDir)
      return
    }
    let screenshot = (element ?? app.windows.firstMatch).screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// Asks tour_capture.swift for a picture and waits until it is taken.
  private func requestCapture(_ name: String, front: Bool, in folder: URL) {
    let kind = front ? "front" : "main"
    let done = folder.appending(path: "\(name).done").path
    let failed = folder.appending(path: "\(name).failed").path
    try? FileManager.default.removeItem(atPath: done)
    try? FileManager.default.removeItem(atPath: failed)
    FileManager.default.createFile(
      atPath: folder.appending(path: "\(name).request").path, contents: Data(kind.utf8))
    let deadline = Date().addingTimeInterval(Self.wait)
    while Date() < deadline {
      if FileManager.default.fileExists(atPath: done) { return }
      if FileManager.default.fileExists(atPath: failed) { break }
      usleep(Self.capturePoll)
    }
    XCTFail("no picture of \(name): is apps/scripts/tour_capture.swift running on \(folder.path)?")
  }
}
