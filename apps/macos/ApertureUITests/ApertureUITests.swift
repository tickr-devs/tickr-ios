import XCTest

/// End-to-end checks of the operator app with no bot running: the app is launched with the
/// fixture API (PreviewAPI.fixturesKey), so every screen shows the contract fixtures in
/// tests/api/fixtures, the same data as the previews. Commands are never confirmed here.
final class ApertureUITests: XCTestCase {
  /// Environment variable of the fixture API (PreviewAPI.fixturesKey in the app) and its value.
  static let fixturesKey = "APERTURE_FIXTURES"
  static let fixturesOn = "1"
  /// Pins the app to English so the texts below match the String Catalog's English values.
  /// Also starts without restoring windows saved by an earlier run.
  static let languageArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                  "-ApplePersistenceIgnoreState", "YES"]
  /// Sidebar sections (AppSection raw values) and the accessibility id prefixes of their rows
  /// and screens (AppSection.rowIDPrefix, AppSection.screenIDPrefix).
  static let sections = ["overview", "chart", "trades", "risk", "lab"]
  static let rowPrefix = "sidebar-"
  static let screenPrefix = "screen-"
  /// The open position in status-response-v1.json and its flatten button id (BotAction.id).
  static let flattenButton = "flatten-ABCD"
  /// English texts from the catalog: the confirmation's cancel button, the account badge for a
  /// broker read that matches the bot's records (account-response-v1.json), and the observer in
  /// observers-v1.json.
  static let cancel = "Cancel"
  static let matches = "MATCHES"
  static let observer = "price-action-v1"
  /// English titles of the standard Window menu and its Zoom item.
  static let windowMenu = "Window"
  static let zoomItem = "Zoom"
  /// English label of the toolbar's sidebar button while the sidebar is hidden.
  static let showSidebar = "Show Sidebar"
  /// How long an element may take to appear, in seconds (the app polls every few seconds).
  static let timeout: TimeInterval = 10

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The app, started on the fixture API in English.
  @MainActor
  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = Self.languageArguments
    app.launchEnvironment[Self.fixturesKey] = Self.fixturesOn
    app.launch()
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: Self.timeout), "no window after launch")
    // The first window size can be larger than a small display; Zoom fits it to the screen so
    // every control is on screen and hittable.
    app.menuBars.menuBarItems[Self.windowMenu].click()
    app.menuItems[Self.zoomItem].click()
    // A window as narrow as a small display can start with the sidebar collapsed.
    let showSidebar = app.toolbars.buttons[Self.showSidebar]
    if showSidebar.exists {
      showSidebar.click()
    }
    return app
  }

  @MainActor
  private func open(_ section: String, in app: XCUIApplication) {
    let row = app.descendants(matching: .any)[Self.rowPrefix + section].firstMatch
    // On a miss the message carries the app's accessibility tree, so CI logs show what was there.
    XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "sidebar row \(section)\n\(app.debugDescription)")
    row.click()
    let screen = app.descendants(matching: .any)[Self.screenPrefix + section].firstMatch
    XCTAssertTrue(screen.waitForExistence(timeout: Self.timeout), "screen \(section)")
  }

  @MainActor
  func testEverySectionOpensItsScreen() {
    let app = launch()
    for section in Self.sections {
      open(section, in: app)
    }
  }

  @MainActor
  func testFlattenAsksBeforeSending() {
    let app = launch()
    open(Self.sections[0], in: app)
    let flatten = app.buttons[Self.flattenButton].firstMatch
    XCTAssertTrue(flatten.waitForExistence(timeout: Self.timeout))
    let enabled = NSPredicate(format: "isEnabled == true")
    expectation(for: enabled, evaluatedWith: flatten)
    waitForExpectations(timeout: Self.timeout)
    flatten.click()
    let sheet = app.sheets.firstMatch
    XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout), "flatten asks for confirmation")
    sheet.buttons[Self.cancel].click()
    let gone = NSPredicate(format: "exists == false")
    expectation(for: gone, evaluatedWith: sheet)
    waitForExpectations(timeout: Self.timeout)
  }

  @MainActor
  func testRiskShowsTheBrokerAccount() {
    let app = launch()
    open(Self.sections[3], in: app)
    XCTAssertTrue(app.staticTexts[Self.matches].firstMatch.waitForExistence(timeout: Self.timeout))
  }

  @MainActor
  func testLabShowsTheObservers() {
    let app = launch()
    open(Self.sections[4], in: app)
    XCTAssertTrue(app.staticTexts[Self.observer].firstMatch.waitForExistence(timeout: Self.timeout))
  }
}
