import XCTest

/// The bot's commands on Overview in the narrowest window the app allows, on a large display and
/// on small ones. The Safety · bot card sits in a row at least OverviewView.middleRowHeight tall,
/// so every command must still lie inside the card, be hittable, and (except pausing, which acts
/// at once and is never pressed here) open its confirmation; the emergency stop only after a held
/// press. Escape withdraws every confirmation, and nothing is sent: no command toast ever shows.
/// Run in English and in Russian, whose labels are the longest; the macOS app has one text size
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
  static let russian = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU", "-ApplePersistenceIgnoreState", "YES"]
  /// The Overview's sidebar row and screen (AppSection ids), and the Safety · bot card
  /// (SafetyCard.id).
  static let overviewRow = "sidebar-overview"
  static let overviewScreen = "screen-overview"
  static let safetyCard = "overview-safety"
  /// Command ids (BotAction.id) with the fixture's one open position, ABCD
  /// (status-response-v1.json). Pausing acts at once; the others ask first.
  static let pause = "pause"
  static let confirmed = ["cancel", "flatten-ABCD", "flatten-all", "stop", "emergency"]
  /// The emergency stop (BotAction.emergency) asks only after a press held this long
  /// (Tokens.Command.holdSeconds, 1.5 s, plus a margin), in seconds; a plain click asks nothing.
  static let emergency = "emergency"
  static let hold: TimeInterval = 2
  /// How long a plain click on the emergency stop is watched for a question that must not come.
  static let noQuestion: TimeInterval = 2
  /// The narrowest window on the fixtures, in points: TickrMacApp.leastWidth, which this test
  /// target cannot read from the app. The title bar's need is wider than the screens' (1086): the
  /// sidebar's widest 260, AppKit's insets 4 + 4 and gap 8, the fixtures' longest line (Overview,
  /// 572 points in English, 535 in Russian) and the right-hand group (512 and 528, Today and
  /// Сегодня), each item 8.5 wider than its content.
  static let minWidthEnglish: CGFloat = 1377
  static let minWidthRussian: CGFloat = 1356
  /// Environment variable that opens the window at its least size (LayoutSweep.smallestKey).
  static let smallestKey = "TICKR_SMALLEST_WINDOW"
  /// Environment variable that opens Overview with the Safety · bot card at its top
  /// (LayoutSweep.safetyFirstKey): every command is clicked where it stands, never after a
  /// scroll, and away from the screen's bottom edge.
  static let safetyFirstKey = "TICKR_OVERVIEW_SAFETY_FIRST"
  /// Environment variable that pretends the display's visible area is at most `<width>x<height>`
  /// points (LayoutSweep.screenKey), and the displays pretended: a 13-inch laptop and a small
  /// display, as `(value, width, height)`.
  static let screenKey = "TICKR_SCREEN"
  static let laptop = (value: "1280x800", width: CGFloat(1280), height: CGFloat(800))
  static let smallDisplay = (value: "1024x768", width: CGFloat(1024), height: CGFloat(768))
  /// The narrowest board (MainNarrow v110, 640 points): one column, the sidebar an icon rail.
  static let narrowest = (value: "640x800", width: CGFloat(640), height: CGFloat(800))
  /// The live flow's latest event (LatestEvent.id), inside the Live flow card: on the one-column
  /// board the Safety · bot card comes before it.
  static let latestEvent = "overview-latest-event"
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
  func testEveryCommandFitsAndAsksInTheNarrowestWindowInRussian() {
    check(Self.russian, minWidth: Self.minWidthRussian)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1280x800DisplayInEnglish() {
    checkOnDisplay(Self.english, Self.laptop)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1280x800DisplayInRussian() {
    checkOnDisplay(Self.russian, Self.laptop)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1024x768DisplayInEnglish() {
    checkOnDisplay(Self.english, Self.smallDisplay)
  }

  @MainActor
  func testEveryCommandIsReachableOnA1024x768DisplayInRussian() {
    checkOnDisplay(Self.russian, Self.smallDisplay)
  }

  @MainActor
  func testSafetyComesFirstAndEveryCommandIsReachable640PointsWideInEnglish() {
    checkOnDisplay(Self.english, Self.narrowest, safetyBeforeFlow: true)
  }

  @MainActor
  func testSafetyComesFirstAndEveryCommandIsReachable640PointsWideInRussian() {
    checkOnDisplay(Self.russian, Self.narrowest, safetyBeforeFlow: true)
  }

  /// The narrowest window on the pretended display: never larger than it (its least size is
  /// capped to the display, `WindowFit`), as wide as it (the display is narrower than the
  /// comfortable least width), and every command reachable inside it.
  @MainActor
  private func checkOnDisplay(
    _ arguments: [String], _ display: (value: String, width: CGFloat, height: CGFloat), safetyBeforeFlow: Bool = false
  ) {
    let app = launch(arguments, screen: display.value)
    let window = app.windows.firstMatch
    XCTAssertEqual(window.frame.width, display.width, accuracy: 1, "the window is not as wide as the display")
    XCTAssertLessThanOrEqual(window.frame.height, display.height + 1, "the window is taller than the display")
    checkCommands(in: app, window: window)
    if safetyBeforeFlow {
      // One column: the Safety · bot card sits above the Live flow card, first after the header
      // and the day's result.
      let card = app.descendants(matching: .any)[Self.safetyCard].firstMatch
      let flow = app.descendants(matching: .any)[Self.latestEvent].firstMatch
      XCTAssertTrue(flow.waitForExistence(timeout: Self.timeout), "latest event\n\(app.debugDescription)")
      XCTAssertLessThanOrEqual(card.frame.maxY, flow.frame.minY,
        "the Safety card \(card.frame) is not above the flow \(flow.frame)")
    }
  }

  @MainActor
  private func check(_ arguments: [String], minWidth: CGFloat) {
    let app = launch(arguments, screen: nil)
    let window = app.windows.firstMatch
    XCTAssertEqual(window.frame.width, minWidth, accuracy: 1, "the window is not at its least width")
    checkCommands(in: app, window: window)
  }

  /// Launches the app on the fixtures at its least window, Overview showing the Safety · bot card
  /// at its top, on the display `screen` pretends (`screenKey`) or the real one.
  @MainActor
  private func launch(_ arguments: [String], screen: String?) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = arguments
    app.launchEnvironment[Self.fixturesKey] = Self.fixturesOn
    app.launchEnvironment[Self.smallestKey] = Self.fixturesOn
    app.launchEnvironment[Self.safetyFirstKey] = Self.fixturesOn
    if let screen { app.launchEnvironment[Self.screenKey] = screen }
    app.launch()
    let window = app.windows.firstMatch
    XCTAssertTrue(window.waitForExistence(timeout: Self.timeout), "no window after launch")
    waitUntilStill(window, "window", in: app)
    return app
  }

  /// Every command of the Safety · bot card lies inside the card, which lies wholly inside the
  /// window; each asks before it acts, Escape withdraws the question, and nothing is sent.
  @MainActor
  private func checkCommands(in app: XCUIApplication, window: XCUIElement) {
    let row = app.descendants(matching: .any)[Self.overviewRow].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: Self.timeout), "sidebar row\n\(app.debugDescription)")
    row.click()
    let screen = app.descendants(matching: .any)[Self.overviewScreen].firstMatch
    XCTAssertTrue(screen.waitForExistence(timeout: Self.timeout), "overview screen")
    let card = app.descendants(matching: .any)[Self.safetyCard].firstMatch
    waitUntilStill(card, "safety card", in: app)
    XCTAssertTrue(window.frame.contains(card.frame), "the card \(card.frame) is not wholly in the window \(window.frame)")

    let pause = card.buttons[Self.pause].firstMatch
    XCTAssertTrue(pause.waitForExistence(timeout: Self.timeout), "pause\n\(app.debugDescription)")
    assertInside(pause, card, Self.pause)
    for id in Self.confirmed {
      let button = card.buttons[id].firstMatch
      XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "\(id)\n\(app.debugDescription)")
      waitUntilStill(button, id, in: app)
      assertInside(button, card, id)
      XCTAssertTrue(button.isEnabled, "\(id) is off")
      if id == Self.emergency {
        // A click alone never starts the emergency stop: only a held press opens its question.
        button.click()
        XCTAssertFalse(app.sheets.firstMatch.waitForExistence(timeout: Self.noQuestion),
          "a plain click on the emergency stop asks")
        button.click(forDuration: Self.hold, thenDragTo: button)
      } else {
        button.click()
      }
      let sheet = app.sheets.firstMatch
      XCTAssertTrue(sheet.waitForExistence(timeout: Self.timeout), "\(id) asks for confirmation")
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
