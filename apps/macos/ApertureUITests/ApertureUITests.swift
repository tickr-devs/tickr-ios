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
  /// The Overview badge for fixture data (overview.fixtures, upper-cased as every badge is).
  static let fixturesBadge = "FIXTURES"
  /// The toolbar's connection status (ConnectionStatus.id).
  static let connectionItem = "toolbar-connection"
  /// The start of the refusal cause in skipped-v1.json.
  static let refusalCause = "POSITION_LIMIT_REACHED"
  /// The selected trade's detail card and a label it shows only for a selected trade.
  static let tradeDetail = "trades-detail"
  static let stopConfirmedAfter = "Stop confirmed after"
  /// The first trade in day-v1.json.
  static let tradeSymbol = "WXYZ"
  /// The performance card (PerformanceCard.id) and the start of its exclusion line.
  static let performanceCard = "trades-performance"
  static let excludedPrefix = "Left out: 1"
  /// The Overview's screener chips (ScreenerChips.id) and watching card (WatchingCard.id).
  static let screenerChips = "overview-screener-chips"
  static let watchingCard = "overview-watching"
  /// The month calendar of Trades & days (MonthCalendar.id).
  static let calendar = "trades-calendar"
  /// The fixtures' live day (2026-11-16) as the calendar names it (Format.dayLabel).
  static let fixtureDayLabel = "Mon, Nov 16"
  /// The Chart's decisions toggle (ChartView.decisionsToggleID) and a rule from decisions-v1.json.
  static let decisionsToggle = "chart-decisions"
  static let decisionRule = "ask_above_trigger"
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
  func testOverviewSaysItShowsFixtures() {
    let app = launch()
    open(Self.sections[0], in: app)
    XCTAssertTrue(app.staticTexts[Self.fixturesBadge].firstMatch.waitForExistence(timeout: Self.timeout))
    // The title bar names the bot's address (the fixture API answers as 127.0.0.1).
    let connection = app.descendants(matching: .any)[Self.connectionItem].firstMatch
    XCTAssertTrue(connection.waitForExistence(timeout: Self.timeout), "connection\n\(app.debugDescription)")
  }

  @MainActor
  func testChartShowsTheDecisions() {
    let app = launch()
    open(Self.sections[1], in: app)
    let toggle = app.descendants(matching: .any)[Self.decisionsToggle].firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: Self.timeout))
    toggle.click()
    // A check row reads as one accessibility element, so its rule is part of a longer value.
    let check = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", Self.decisionRule))
    XCTAssertTrue(check.firstMatch.waitForExistence(timeout: Self.timeout), "decision check\n\(app.debugDescription)")
    // The open inspector fits beside the chart: nothing is pushed off screen.
    XCTAssertTrue(app.descendants(matching: .any)[Self.rowPrefix + Self.sections[0]].firstMatch.isHittable,
      "sidebar pushed off screen\n\(app.debugDescription)")
  }

  @MainActor
  func testTradesShowTheSkippedSignals() {
    let app = launch()
    open(Self.sections[2], in: app)
    // A skipped row is one button, so the cause is part of its longer label.
    let cause = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.refusalCause))
    XCTAssertTrue(cause.firstMatch.waitForExistence(timeout: Self.timeout), "refusal cause\n\(app.debugDescription)")
  }

  @MainActor
  func testTradesShowTheSelectedTradeDetail() {
    let app = launch()
    open(Self.sections[2], in: app)
    // SwiftUI's Table reads as an outline; clicking the symbol's cell selects its row.
    let symbol = app.outlineRows.staticTexts.matching(NSPredicate(format: "value == %@", Self.tradeSymbol)).firstMatch
    XCTAssertTrue(symbol.waitForExistence(timeout: Self.timeout), "trade row\n\(app.debugDescription)")
    symbol.click()
    let detail = app.descendants(matching: .any)[Self.tradeDetail].firstMatch
    XCTAssertTrue(detail.staticTexts[Self.stopConfirmedAfter].waitForExistence(timeout: Self.timeout),
      "trade detail\n\(app.debugDescription)")
  }

  @MainActor
  func testTradesShowThePerformance() {
    let app = launch()
    open(Self.sections[2], in: app)
    let card = app.descendants(matching: .any)[Self.performanceCard].firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: Self.timeout), "performance card\n\(app.debugDescription)")
    // The fixture leaves one trade out; the card says so next to the totals.
    let excluded = card.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", Self.excludedPrefix))
    XCTAssertTrue(excluded.firstMatch.waitForExistence(timeout: Self.timeout), "exclusion\n\(app.debugDescription)")
  }

  @MainActor
  func testOverviewShowsTheFlowAndWatchedSymbols() {
    let app = launch()
    let chips = app.descendants(matching: .any)[Self.screenerChips].firstMatch
    XCTAssertTrue(chips.waitForExistence(timeout: Self.timeout), "screener chips\n\(app.debugDescription)")
    let watching = app.descendants(matching: .any)[Self.watchingCard].firstMatch
    let check = watching.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", Self.decisionRule))
    XCTAssertTrue(check.firstMatch.waitForExistence(timeout: Self.timeout), "watched symbol\n\(app.debugDescription)")
  }

  @MainActor
  func testTradesShowTheMonthCalendar() {
    let app = launch()
    open(Self.sections[2], in: app)
    let calendar = app.descendants(matching: .any)[Self.calendar].firstMatch
    XCTAssertTrue(calendar.waitForExistence(timeout: Self.timeout), "calendar\n\(app.debugDescription)")
    // The fixture's live day is a cell of the month grid, named by its date.
    XCTAssertTrue(calendar.buttons[Self.fixtureDayLabel].waitForExistence(timeout: Self.timeout),
      "calendar day\n\(app.debugDescription)")
  }

  @MainActor
  func testLabShowsTheObservers() {
    let app = launch()
    open(Self.sections[4], in: app)
    XCTAssertTrue(app.staticTexts[Self.observer].firstMatch.waitForExistence(timeout: Self.timeout))
  }
}
