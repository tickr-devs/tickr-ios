import XCTest

/// End-to-end checks of the operator app with no bot running: the app is launched with the
/// fixture API (PreviewAPI.fixturesKey), so every screen shows the contract fixtures in
/// tests/api/fixtures, the same data as the previews. Commands are never confirmed here.
final class TickrUITests: XCTestCase {
  /// Environment variable of the fixture API (PreviewAPI.fixturesKey in the app) and its value.
  static let fixturesKey = "TICKR_FIXTURES"
  static let fixturesOn = "1"
  /// Environment variable that opens Overview with the Safety · bot card at its top
  /// (LayoutSweep.safetyFirstKey), turned on with `fixturesOn`'s value.
  static let safetyFirstKey = "TICKR_OVERVIEW_SAFETY_FIRST"
  /// Pins the app to English so the texts below match the String Catalog's English values.
  /// Also starts without restoring windows saved by an earlier run.
  static let languageArguments = [
    "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-ApplePersistenceIgnoreState", "YES",
  ]
  /// Sidebar sections (AppSection raw values) and the accessibility id prefixes of their rows
  /// and screens (AppSection.rowIDPrefix, AppSection.screenIDPrefix).
  static let sections = ["overview", "chart", "trades", "risk", "lab"]
  static let rowPrefix = "sidebar-"
  static let screenPrefix = "screen-"
  /// The open position in status-response-v1.json and its flatten button id (BotAction.id).
  static let flattenButton = "flatten-ABCD"
  /// English texts from the catalog: the confirmation's cancel button and the account badge for a
  /// broker read that matches the bot's records (account-response-v1.json).
  static let cancel = "Cancel"
  static let matches = "MATCHES"
  /// The first observer in observers-v1.json (price-action-v1, version 2, three decisions), as its
  /// row on Strategy lab's versions card reads: its name and the English note of its decision
  /// count (lab.observerNote). The active strategy (status-response-v1.json) is price-action-v1
  /// too, so the name alone also matches the active version's row.
  static let observer = "price-action-v1"
  static let observerNote = "observer · decisions: 3"
  /// The Overview header's one environment badge for the fixtures' environment (sandbox in
  /// status-response-v1.json), as its English text reads (environmentLabel, upper-cased as every
  /// badge is).
  static let environmentBadge = "ENVIRONMENT: SANDBOX"
  /// The toolbar's connection status (ConnectionStatus.id).
  static let connectionItem = "toolbar-connection"
  /// The refusal detail of the first signal in skipped-v1.json, as the English app words it
  /// (kit.refusal.POSITION_LIMIT_REACHED with open 1, limit 1).
  static let refusalCause = "1 open, limit 1"
  /// The selected trade's detail card and a label it shows only for a selected trade.
  static let tradeDetail = "trades-detail"
  static let stopConfirmedAfter = "Stop confirmed after"
  /// The first trade in day-v1.json.
  static let tradeSymbol = "WXYZ"
  /// Id of an open position's row on Trades (OpenPositionRow.id), and the fixture position's symbol.
  static let openPosition = "trades-open-position"
  static let openSymbol = "ABCD"
  /// The performance card (PerformanceCard.id) and the start of its exclusion line.
  static let performanceCard = "trades-performance"
  static let excludedPrefix = "Left out: 1"
  /// The Overview's latest-event line (LatestEvent.id) and watching card (WatchingCard.id).
  static let latestEvent = "overview-latest-event"
  static let watchingCard = "overview-watching"
  /// The month calendar of Trades & days (MonthCalendar.id).
  static let calendar = "trades-calendar"
  /// The fixtures' live day (2026-11-16) as the calendar names it (DayText.day, no comma).
  static let fixtureDayLabel = "Mon Nov 16"
  /// A recorded past day without trades (day-v1.empty.json, PreviewAPI.dayFiles), its English
  /// "no trades" title (trades.noTradesOn), and the ids of the shown day's title
  /// (TradesView.dayTitleID) and of the empty table's message (TradesTable.emptyID).
  static let emptyDayLabel = "Fri Nov 13"
  static let emptyDayMessage = "No trades on Fri Nov 13"
  static let dayTitle = "trades-day-title"
  static let tradesEmpty = "trades-empty"
  /// The Chart's decisions toggle (ChartView.decisionsToggleID) and a rule from decisions-v1.json
  /// (ask_above_trigger), as the English app shows it (ApiText.rule).
  static let decisionsToggle = "chart-decisions"
  static let decisionRule = "Ask above trigger"
  /// English titles of the standard Window menu and its Zoom item.
  static let windowMenu = "Window"
  static let zoomItem = "Zoom"
  /// English label of the toolbar's sidebar button while the sidebar is hidden.
  static let showSidebar = "Show Sidebar"
  /// Chart settings (ChartView.Keys) passed as launch arguments: the decisions inspector open
  /// with every study, the set that once crashed the app in an endless layout loop.
  static let everyStudyWithInspector = ["-chart.decisions", "YES", "-chart.movingAverages", "YES",
    "-chart.bollinger", "YES", "-chart.macd", "YES", "-chart.rsi", "YES", "-chart.stochastic", "YES",
    "-chart.atr", "YES"]
  /// How long the loaded chart is watched for a crash, in seconds.
  static let settleSeconds: TimeInterval = 8
  /// Pointer sweeps across the chart, and where across it each starts and ends (fractions).
  static let sweeps = 6
  static let sweepStart = 0.15
  static let sweepEnd = 0.85
  /// How long the window takes to narrow, in seconds.
  static let dragSeconds: TimeInterval = 0.5
  /// How far the window narrows from its zoomed width, as a fraction of it.
  static let narrowShare = 0.35
  /// How long an element may take to appear, in seconds (the app polls every few seconds).
  static let timeout: TimeInterval = 10
  /// How often a moving element's frame is read, and how long it must keep still before it is
  /// clicked, in seconds: cards rise in one after another and a screen reflows as its reads
  /// arrive, so a click aimed at a frame read a moment earlier can land beside the element.
  static let settlePoll: TimeInterval = 0.2
  static let settleQuiet: TimeInterval = 1

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// The app, started on the fixture API in English.
  @MainActor
  private func launch(settings: [String] = [], environment: [String: String] = [:]) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = Self.languageArguments + settings
    app.launchEnvironment[Self.fixturesKey] = Self.fixturesOn
    app.launchEnvironment.merge(environment) { _, given in given }
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

  /// Waits until `element` exists and has kept the same frame for `settleQuiet` seconds, so a
  /// click lands on it. Fails if it is still moving after `timeout`.
  @MainActor
  private func waitUntilStill(_ element: XCUIElement, _ name: String, in app: XCUIApplication) {
    XCTAssertTrue(element.waitForExistence(timeout: Self.timeout), "\(name)\n\(app.debugDescription)")
    let deadline = Date.now.addingTimeInterval(Self.timeout)
    var frame = element.frame
    var stillSince = Date.now
    while Date.now < deadline {
      _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settlePoll)
      let now = element.frame
      if now != frame {
        frame = now
        stillSince = .now
      } else if Date.now.timeIntervalSince(stillSince) >= Self.settleQuiet {
        return
      }
    }
    XCTFail("\(name) kept moving\n\(app.debugDescription)")
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
    // Overview opens with the Safety · bot card at its top: the click lands where the button
    // stands, never after XCUITest's own scroll, which could leave it at the screen's bottom edge
    // under a hidden Dock rising at the pointer.
    let app = launch(environment: [Self.safetyFirstKey: Self.fixturesOn])
    open(Self.sections[0], in: app)
    let flatten = app.buttons[Self.flattenButton].firstMatch
    XCTAssertTrue(flatten.waitForExistence(timeout: Self.timeout))
    let enabled = NSPredicate(format: "isEnabled == true")
    expectation(for: enabled, evaluatedWith: flatten)
    waitForExpectations(timeout: Self.timeout)
    // Cards rise in and the screen reflows as reads arrive: click only once the button is still.
    waitUntilStill(flatten, "flatten button", in: app)
    XCTAssertTrue(flatten.isHittable, "flatten is not hittable\n\(app.debugDescription)")
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
  func testOverviewSaysWhereItsDataComesFrom() {
    let app = launch()
    open(Self.sections[0], in: app)
    // The header's one environment badge names the environment the data comes from (#543 removed
    // the separate FIXTURES badge: one badge, no second tag beside it).
    XCTAssertTrue(app.staticTexts[Self.environmentBadge].firstMatch.waitForExistence(timeout: Self.timeout),
      "environment badge\n\(app.debugDescription)")
    // The title bar names the bot's address (the fixture API answers as 127.0.0.1).
    let connection = app.descendants(matching: .any)[Self.connectionItem].firstMatch
    XCTAssertTrue(connection.waitForExistence(timeout: Self.timeout), "connection\n\(app.debugDescription)")
  }

  @MainActor
  func testChartShowsTheDecisions() {
    let app = launch()
    open(Self.sections[1], in: app)
    // The rail is shown by default: its explain card lists the latest decision's checks. A check
    // row reads as one accessibility element, so its rule is part of a longer value.
    let check = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", Self.decisionRule)).firstMatch
    XCTAssertTrue(check.waitForExistence(timeout: Self.timeout), "decision check\n\(app.debugDescription)")
    // The open rail fits beside the chart: nothing is pushed off screen.
    XCTAssertTrue(app.descendants(matching: .any)[Self.rowPrefix + Self.sections[0]].firstMatch.isHittable,
      "sidebar pushed off screen\n\(app.debugDescription)")
    // The toggle hides the rail and shows it again.
    let toggle = app.descendants(matching: .any)[Self.decisionsToggle].firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: Self.timeout))
    toggle.click()
    XCTAssertTrue(check.waitForNonExistence(timeout: Self.timeout), "rail still shown\n\(app.debugDescription)")
    toggle.click()
    XCTAssertTrue(check.waitForExistence(timeout: Self.timeout), "rail not shown again\n\(app.debugDescription)")
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
  func testTradesListTheOpenPosition() {
    let app = launch()
    open(Self.sections[2], in: app)
    // The fixture's live day holds one open position; it is listed above the closed trades.
    let row = app.buttons[Self.openPosition].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "open position\n\(app.debugDescription)")
    XCTAssertTrue(row.label.contains(Self.openSymbol), "open position symbol\n\(row.label)")
  }

  @MainActor
  func testTradesShowTheSelectedTradeDetail() {
    let app = launch()
    open(Self.sections[2], in: app)
    // SwiftUI's Table reads as an outline; clicking the symbol's cell selects its row.
    let symbol = app.outlineRows.staticTexts.matching(NSPredicate(format: "value == %@", Self.tradeSymbol)).firstMatch
    // The table rises in with its card; clicked while it moved, the click once landed in the table
    // beside the row (the table took focus, no row was selected).
    waitUntilStill(symbol, "trade row", in: app)
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
    let event = app.descendants(matching: .any)[Self.latestEvent].firstMatch
    XCTAssertTrue(event.waitForExistence(timeout: Self.timeout), "latest event\n\(app.debugDescription)")
    let watching = app.descendants(matching: .any)[Self.watchingCard].firstMatch
    // Each row is a button that opens the Chart, so its texts are read in the button's label.
    let check = watching.buttons.matching(NSPredicate(format: "label CONTAINS %@", Self.decisionRule))
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
  func testPickingAPastDayInTheCalendarShowsThatDay() {
    let app = launch()
    open(Self.sections[2], in: app)
    let calendar = app.descendants(matching: .any)[Self.calendar].firstMatch
    XCTAssertTrue(calendar.waitForExistence(timeout: Self.timeout), "calendar\n\(app.debugDescription)")
    // Today first: its trade WXYZ is listed.
    let trade = app.outlineRows.staticTexts.matching(NSPredicate(format: "value == %@", Self.tradeSymbol)).firstMatch
    XCTAssertTrue(trade.waitForExistence(timeout: Self.timeout), "today's trade\n\(app.debugDescription)")
    let day = calendar.buttons[Self.emptyDayLabel]
    waitUntilStill(day, "calendar day", in: app)
    day.click()
    // The empty table names the picked day, and the day's title (a heading, so any element
    // type) says it too.
    let message = app.descendants(matching: .any).matching(
      NSPredicate(format: "label == %@ OR value == %@", Self.emptyDayMessage, Self.emptyDayMessage)).firstMatch
    XCTAssertTrue(message.waitForExistence(timeout: Self.timeout), "no-trades message\n\(app.debugDescription)")
    let title = app.descendants(matching: .any)[Self.dayTitle].firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: Self.timeout), "day title\n\(app.debugDescription)")
    let text = [title.label, title.value as? String ?? ""]
    XCTAssertTrue(text.contains(Self.emptyDayLabel), "day title \(text)\n\(app.debugDescription)")
    XCTAssertFalse(trade.exists, "today's trade still listed\n\(app.debugDescription)")
  }

  @MainActor
  func testLabShowsTheObservers() {
    let app = launch()
    open(Self.sections[4], in: app)
    // A version's row reads as one text element (its texts combined into its value), so the
    // observer's name and note are parts of a longer value. The day chart's legend names an
    // observer by what sets it apart ("v2 · rel vol 1.5×"), not by its name.
    let row = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@ AND value CONTAINS %@",
      Self.observer, Self.observerNote)).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "observer row\n\(app.debugDescription)")
  }

  /// The chart with every study and the decisions inspector opens, survives a narrower window
  /// and pointer sweeps: this set once looped AppKit's layout until it threw.
  @MainActor
  func testChartWithEveryStudyAndTheInspectorStaysUp() {
    let app = launch(settings: Self.everyStudyWithInspector)
    open(Self.sections[1], in: app)
    let window = app.windows.firstMatch
    // Narrow the window by dragging its right edge, the inspector still open.
    let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
    edge.press(forDuration: Self.dragSeconds,
      thenDragTo: edge.withOffset(CGVector(dx: -window.frame.width * Self.narrowShare, dy: 0)))
    let screen = app.descendants(matching: .any)[Self.screenPrefix + Self.sections[1]].firstMatch
    for _ in 0..<Self.sweeps {
      screen.coordinate(withNormalizedOffset: CGVector(dx: Self.sweepStart, dy: 0.5)).hover()
      screen.coordinate(withNormalizedOffset: CGVector(dx: Self.sweepEnd, dy: 0.5)).hover()
    }
    // The screen must still be there after the watch; a crash takes it away early.
    XCTAssertFalse(screen.waitForNonExistence(timeout: Self.settleSeconds), "the chart screen went away")
    XCTAssertEqual(app.state, .runningForeground, "the app quit on the chart")
  }
}
