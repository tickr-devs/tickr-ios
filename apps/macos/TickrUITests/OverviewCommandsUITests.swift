import XCTest

/// The bot's commands on Overview in the narrowest window the app allows, on a large display and
/// on small ones: Pause entries and Stop bot on the Safety · bot card, Close all and the position's
/// Close on the Positions card (V4 variant A). The cards sit in a row at least
/// OverviewView.middleRowHeight tall, so every command must still lie inside its card and the
/// window, be hittable, and (except pausing, which acts at once and is never pressed here) open its
/// confirmation on a click; Stop bot, with the fixture's open position, offers its three choices
/// (Close and stop, Leave open, Cancel). Escape withdraws every confirmation, and nothing is sent:
/// no command toast ever shows. The commands that left the Safety card (cancel orders, the per-position and
/// all-positions close, the emergency stop) must not come back there.
/// Run in English and in Spanish, whose labels are the longest; the macOS app has one text size
/// (no Dynamic Type on the Mac, Tokens.Typography). The app reads the contract fixtures.
///
/// Small displays (owner decision 2026-11-16, option A: the window fits the screen, so the
/// safety controls are always reachable): the app pretends a 1280 × 800 or a 1024 × 768 display
/// (`screenKey`, LayoutSweep.screenKey); the Mac's own display settings are never changed. The
/// window must fit that display and the whole card must lie inside the window, never right of
/// it (no sideways scroll).
final class OverviewCommandsUITests: XCTestCase {
  /// Environment variable of the fixture API (PreviewAPI.fixturesKey in the app), and the value
  /// that turns it, `smallestKey` and `safetyFirstKey` on.
  static let fixturesKey = "TICKR_FIXTURES"
  static let fixturesOn = "1"
  /// Launch arguments of each language, without restoring windows saved by an earlier run.
  static let english = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-ApplePersistenceIgnoreState", "YES"]
  static let spanish = ["-AppleLanguages", "(es)", "-AppleLocale", "es_US", "-ApplePersistenceIgnoreState", "YES"]
  /// The Overview's sidebar row and screen (AppSection ids), the Safety · bot card
  /// (SafetyCard.id) and the Positions card (PositionsCard.id).
  static let overviewRow = "sidebar-overview"
  static let overviewScreen = "screen-overview"
  static let safetyCard = "overview-safety"
  static let positionsCard = "overview-positions"
  /// Command ids (BotAction.id, PositionDetail.closePrefix) with the fixture's one open position,
  /// ABCD (status-response-v1.json). Pausing acts at once; the others ask first.
  static let pause = "pause"
  static let safetyConfirmed = ["stop"]
  /// Buttons of each question that offers more than a yes: Stop bot with the fixture's open
  /// position offers Close and stop, Leave open and Cancel (V4 variant A, StopChoice).
  static let choices = ["stop": 3]
  static let positionsConfirmed = ["close-all", "position-close-ABCD"]
  /// Ids of the commands the Safety card no longer has (cancel orders, the per-position and
  /// all-positions close, the emergency stop), nor Close all, which lives on the Positions card.
  static let notOnSafety = ["cancel", "flatten-ABCD", "flatten-all", "emergency", "close-all"]
  /// The narrowest window on the fixtures, in points: TickrMacApp.leastWidth, which this test
  /// target cannot read from the app. The title bar's need is wider than the screens' (1086): the
  /// sidebar's widest 260, AppKit's insets 4 + 4 and gap 8, the fixtures' longest line (Overview,
  /// "tickr — paper trading", no strategy since #783) and the right-hand group (Today), each item
  /// 8.5 wider than its content. Measured by this test on CI (#783, 2026-11-25): 1392 in English,
  /// 1409 in Spanish, whose line and group are the longer (1421 and 1446 with the strategy, #695);
  /// 1369 in English since the lab's line says "model lab" (#855, 2026-11-27), its Spanish line
  /// unchanged ("laboratorio").
  static let minWidthEnglish: CGFloat = 1369
  static let minWidthSpanish: CGFloat = 1409
  /// Environment variable that opens the window at its least size (LayoutSweep.smallestKey).
  static let smallestKey = "TICKR_SMALLEST_WINDOW"
  /// Environment variable that opens Overview with the Safety · bot card at its top
  /// (LayoutSweep.safetyFirstKey): every command is clicked where it stands, never after a
  /// scroll, and away from the screen's bottom edge.
  static let safetyFirstKey = "TICKR_OVERVIEW_SAFETY_FIRST"
  /// The same for the Positions card (LayoutSweep.positionsFirstKey), which wins over
  /// `safetyFirstKey`: on the one-column board the two cards are apart, so its commands are
  /// checked in a second launch with this card at the top.
  static let positionsFirstKey = "TICKR_OVERVIEW_POSITIONS_FIRST"
  /// Environment variable that pretends the display's visible area is at most `<width>x<height>`
  /// points (LayoutSweep.screenKey), and the displays pretended: a 13-inch laptop and a small
  /// display, as `(value, width, height)`.
  static let screenKey = "TICKR_SCREEN"
  static let laptop = (value: "1280x800", width: CGFloat(1280), height: CGFloat(800))
  static let smallDisplay = (value: "1024x768", width: CGFloat(1024), height: CGFloat(768))
  /// The narrowest board (MainNarrow v110, 640 points): one column, the sidebar an icon rail.
  static let narrowest = (value: "640x800", width: CGFloat(640), height: CGFloat(800))
  /// The Live flow card (LiveFlowCard.id): on the one-column board the Bot card comes before it.
  static let liveFlow = "overview-live-flow"
  /// The command toast (CommandToast.id), shown whenever a command is sent; how long it is
  /// watched for after a confirmation is withdrawn, in seconds.
  static let toast = "command-toast"
  static let noToast: TimeInterval = 1
  /// How long an element may take to appear, and how long a moving element must keep still
  /// before it is read or clicked, polled every `settlePoll`, in seconds.
  static let timeout: TimeInterval = 10
  static let settlePoll: TimeInterval = 0.2
  static let settleQuiet: TimeInterval = 1
  /// Frames a "kept moving" failure names, the latest.
  static let movesShown = 12

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testEveryCommandFitsAndAsksInTheNarrowestWindowInEnglish() {
    check(Self.english, minWidth: Self.minWidthEnglish)
  }

  @MainActor
  func testEveryCommandFitsAndAsksInTheNarrowestWindowInSpanish() {
    check(Self.spanish, minWidth: Self.minWidthSpanish)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1280x800DisplayInEnglish() {
    checkOnDisplay(Self.english, Self.laptop)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1280x800DisplayInSpanish() {
    checkOnDisplay(Self.spanish, Self.laptop)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1024x768DisplayInEnglish() {
    checkOnDisplay(Self.english, Self.smallDisplay)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1024x768DisplayInSpanish() {
    checkOnDisplay(Self.spanish, Self.smallDisplay)
  }

  @MainActor
  func testSafetyComesFirstAndEveryCommandIsReachable640PointsWideInEnglish() {
    checkOnDisplay(Self.english, Self.narrowest, safetyBeforeFlow: true)
  }

  @MainActor
  func testSafetyComesFirstAndEveryCommandIsReachable640PointsWideInSpanish() {
    checkOnDisplay(Self.spanish, Self.narrowest, safetyBeforeFlow: true)
  }

  /// The narrowest window on the pretended display: never larger than it (its least size is
  /// capped to the display, `WindowFit`), as wide as it (the display is narrower than the
  /// comfortable least width), and every command reachable inside it. On the one-column board
  /// (`safetyBeforeFlow`) the Positions card is checked in a second launch with it at the top.
  @MainActor
  private func checkOnDisplay(
    _ arguments: [String], _ display: (value: String, width: CGFloat, height: CGFloat), safetyBeforeFlow: Bool = false
  ) {
    let app = launch(arguments, screen: display.value)
    let window = app.windows.firstMatch
    XCTAssertEqual(window.frame.width, display.width, accuracy: 1, "the window is not as wide as the display")
    XCTAssertLessThanOrEqual(window.frame.height, display.height + 1, "the window is taller than the display")
    openOverview(in: app)
    checkSafety(in: app, window: window)
    if !safetyBeforeFlow { checkPositions(in: app, window: window) }
    if safetyBeforeFlow {
      // One column: the Safety · bot card sits above the Live flow card, first after the header
      // and the day's result.
      let card = app.descendants(matching: .any)[Self.safetyCard].firstMatch
      let flow = app.descendants(matching: .any)[Self.liveFlow].firstMatch
      XCTAssertTrue(flow.waitForExistence(timeout: Self.timeout), "live flow\n\(app.debugDescription)")
      XCTAssertLessThanOrEqual(card.frame.maxY, flow.frame.minY,
        "the Safety card \(card.frame) is not above the flow \(flow.frame)")
      app.terminate()
      let again = launch(arguments, screen: display.value, positionsFirst: true)
      openOverview(in: again)
      checkPositions(in: again, window: again.windows.firstMatch)
    }
  }

  @MainActor
  private func check(_ arguments: [String], minWidth: CGFloat) {
    let app = launch(arguments, screen: nil)
    let window = app.windows.firstMatch
    XCTAssertEqual(window.frame.width, minWidth, accuracy: 1, "the window is not at its least width")
    openOverview(in: app)
    checkSafety(in: app, window: window)
    checkPositions(in: app, window: window)
  }

  /// Launches the app on the fixtures at its least window, Overview showing the Safety · bot card
  /// (or, with `positionsFirst`, the Positions card) at its top, on the display `screen` pretends
  /// (`screenKey`) or the real one.
  ///
  /// An instance still running (a test before left it) is quit first and the launch waits until
  /// it has gone, instead of XCUITest terminating it inside the launch: both stalls seen in CI
  /// ("Lost connection to the application" on #787, "Unable to monitor event loop" on #805) came on
  /// the first window check of a launch that had just terminated an earlier instance.
  @MainActor
  private func launch(_ arguments: [String], screen: String?, positionsFirst: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    if app.state != .notRunning {
      app.terminate()
      XCTAssertTrue(app.wait(for: .notRunning, timeout: Self.timeout), "the earlier instance did not quit")
    }
    app.launchArguments = arguments + TickrUITests.developmentAddress
    app.launchEnvironment[Self.fixturesKey] = Self.fixturesOn
    app.launchEnvironment[Self.smallestKey] = Self.fixturesOn
    app.launchEnvironment[Self.safetyFirstKey] = Self.fixturesOn
    if positionsFirst { app.launchEnvironment[Self.positionsFirstKey] = Self.fixturesOn }
    if let screen { app.launchEnvironment[Self.screenKey] = screen }
    app.launch()
    let window = app.windows.firstMatch
    // The app's state in the message tells a crash at launch (notRunning) from a lost connection.
    XCTAssertTrue(window.waitForExistence(timeout: Self.timeout), "no window after launch, app state \(app.state.rawValue)")
    waitUntilStill(window, "window", in: app)
    return app
  }

  /// Opens Overview from the sidebar.
  @MainActor
  private func openOverview(in app: XCUIApplication) {
    let row = app.descendants(matching: .any)[Self.overviewRow].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "sidebar row\n\(app.debugDescription)")
    row.click()
    let screen = app.descendants(matching: .any)[Self.overviewScreen].firstMatch
    XCTAssertTrue(screen.waitForExistence(timeout: Self.timeout), "overview screen")
  }

  /// The Safety · bot card lies wholly inside the window, holds Pause entries and Stop bot and none
  /// of the commands that left it; Stop bot asks before it acts.
  @MainActor
  private func checkSafety(in app: XCUIApplication, window: XCUIElement) {
    let card = app.descendants(matching: .any)[Self.safetyCard].firstMatch
    waitUntilStill(card, "safety card", in: app)
    XCTAssertTrue(window.frame.contains(card.frame), "the card \(card.frame) is not wholly in the window \(window.frame)")
    let pause = card.buttons[Self.pause].firstMatch
    XCTAssertTrue(pause.waitForExistence(timeout: Self.timeout), "pause\n\(app.debugDescription)")
    assertInside(pause, card, Self.pause)
    for id in Self.notOnSafety {
      XCTAssertFalse(card.buttons[id].firstMatch.exists, "\(id) is back on the Safety card")
    }
    checkConfirmed(Self.safetyConfirmed, in: card, app: app, window: window)
  }

  /// Close all and the position's Close on the Positions card: each inside the card and the window,
  /// and each asks before it acts.
  @MainActor
  private func checkPositions(in app: XCUIApplication, window: XCUIElement) {
    let card = app.descendants(matching: .any)[Self.positionsCard].firstMatch
    waitUntilStill(card, "positions card", in: app)
    checkConfirmed(Self.positionsConfirmed, in: card, app: app, window: window)
  }

  /// Each command lies inside its card and the window and is on; a click opens its question,
  /// Escape withdraws it, and nothing is sent.
  @MainActor
  private func checkConfirmed(_ ids: [String], in card: XCUIElement, app: XCUIApplication, window: XCUIElement) {
    for id in ids {
      let button = card.buttons[id].firstMatch
      XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "\(id)\n\(app.debugDescription)")
      waitUntilStill(button, id, in: app)
      assertInside(button, card, id)
      XCTAssertTrue(window.frame.contains(button.frame), "\(id) \(button.frame) is not in the window \(window.frame)")
      XCTAssertTrue(button.isEnabled, "\(id) is off")
      button.click()
      let sheet = app.sheets.firstMatch
      XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout), "\(id) asks for confirmation")
      if let count = Self.choices[id] {
        // Every choice is there and can be pressed; none is pressed here.
        XCTAssertEqual(sheet.buttons.count, count, "\(id) offers its choices\n\(sheet.debugDescription)")
        for index in 0..<sheet.buttons.count {
          let choice = sheet.buttons.element(boundBy: index)
          XCTAssertTrue(choice.isHittable && choice.isEnabled, "\(id): choice \(choice.label) cannot be pressed")
        }
      }
      // Escape is the confirmation's cancel in every language.
      app.typeKey(.escape, modifierFlags: [])
      XCTAssertTrue(sheet.waitForNonExistence(timeout: Self.timeout), "\(id): the confirmation stays open")
      // A sent command always shows its toast (AppModel.send): none may come after a withdrawal.
      XCTAssertFalse(app.descendants(matching: .any)[Self.toast].firstMatch.waitForExistence(timeout: Self.noToast),
        "\(id) was sent without a confirmation")
    }
  }

  /// The command lies wholly inside the card, so the card's fixed row cuts none of it off, and a
  /// click on it reaches it.
  @MainActor
  private func assertInside(_ button: XCUIElement, _ card: XCUIElement, _ id: String) {
    XCTAssertTrue(card.frame.contains(button.frame), "\(id) \(button.frame) runs out of the card \(card.frame)")
    XCTAssertTrue(button.isHittable, "\(id) is not hittable")
  }

  /// Waits until `element` exists and has kept the same frame for `settleQuiet` seconds.
  @MainActor
  private func waitUntilStill(_ element: XCUIElement, _ name: String, in app: XCUIApplication) {
    XCTAssertTrue(element.waitForExistence(timeout: Self.timeout), "\(name)\n\(app.debugDescription)")
    let deadline = Date.now.addingTimeInterval(Self.timeout)
    var frame = element.frame
    var stillSince = Date.now
    // The frames it moved through, so a failure says how it moved.
    var moves = [frame]
    while Date.now < deadline {
      _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: Self.settlePoll)
      let now = element.frame
      if now != frame {
        frame = now
        stillSince = .now
        moves.append(now)
      } else if Date.now.timeIntervalSince(stillSince) >= Self.settleQuiet {
        return
      }
    }
    XCTFail("\(name) kept moving through \(moves.suffix(Self.movesShown))\n\(app.debugDescription)")
  }
}
