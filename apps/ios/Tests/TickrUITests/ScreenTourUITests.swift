import XCTest

/// Walks every screen of the app against a running bot API (for example `tickr demo`) and
/// keeps a screenshot of each, for comparing the app with the design. It sends no command: the
/// bot-control sheet is opened and cancelled.
///
/// Run on a booted Simulator (light or dark appearance set with `xcrun simctl ui`):
///   xcodebuild test -project apps/ios/Tickr.xcodeproj -scheme "Tickr iOS Screen Tour" \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -resultBundlePath tour.xcresult
///   xcrun xcresulttool export attachments --path tour.xcresult --output-path tour
/// Environment: TOUR_API (default http://127.0.0.1:8776, the demo) and TOUR_LANGUAGE (default en).
@MainActor
final class ScreenTourUITests: XCTestCase {
  private static let defaultAPI = "http://127.0.0.1:8776"
  private static let defaultLanguage = "en"
  /// Seconds the screens get to load and finish their entrance animations.
  private static let settle: UInt32 = 3
  /// Seconds to wait for an element to appear.
  private static let wait: TimeInterval = 10
  /// Most extra screenshots taken while scrolling one screen down.
  private static let maxScrolls = 4
  /// Accessibility identifiers the tour taps, the same in every language (the app's
  /// `AccessibilityID`).
  private enum Identifier {
    static let botControl = "home.botControl"
    static let settings = "home.settings"
    static let risk = "home.risk"
    static let botControlCancel = "botControl.cancel"
    static let calendar = "activity.calendar"
    /// The tab bar's buttons, in order: the app draws the design's own tab bar.
    static let tabs = ["tab.home", "tab.positions", "tab.chart", "tab.activity", "tab.lab"]
    /// Each pane chip of Activity.
    static let activitySection = "activity.section"
    /// A pushed screen's own back button ("‹ Home").
    static let back = "nav.back"
  }

  private var app = XCUIApplication()

  /// One named variable of the test process's environment. Only named reads: the whole
  /// environment is never bound, printed or passed on (CLAUDE.md, hard rule 10).
  private static func variable(_ name: String) -> String? {
    ProcessInfo.processInfo.environment[name]
  }

  override func setUp() async throws {
    continueAfterFailure = true
    let api = Self.variable("TOUR_API") ?? Self.defaultAPI
    let language = Self.variable("TOUR_LANGUAGE") ?? Self.defaultLanguage
    app.launchArguments = ["-apiBaseURL", api, "-AppleLanguages", "(\(language))"]
    app.launch()
    sleep(Self.settle)
  }

  func testTour() {
    let tabs = Identifier.tabs.map { app.buttons[$0] }
    XCTAssertTrue(tabs[0].waitForExistence(timeout: Self.wait))
    for (index, tab) in tabs.enumerated() {
      tab.tap()
      sleep(Self.settle)
      capture(screen: "tab\(index)")
      if index == 0 { homeDetails() }
      if index == 3 { activityDetails() }
    }
  }

  // MARK: - the way back and the header's touch targets

  /// Apple's least comfortable touch target, in points (HIG).
  private static let touchTarget: CGFloat = 44
  /// The largest accessibility text size the header must still fit.
  private static let accessibilityTextSize = "UICTContentSizeCategoryAccessibilityXXXL"

  /// A pushed screen has the app's own back button, named "Back" for VoiceOver; it goes back, and
  /// so does the swipe from the screen's left edge.
  func testBackButtonAndEdgeSwipe() {
    let settings = app.buttons[Identifier.settings]
    XCTAssertTrue(settings.waitForExistence(timeout: Self.wait))
    settings.tap()
    let back = app.buttons[Identifier.back].firstMatch
    XCTAssertTrue(back.waitForExistence(timeout: Self.wait), "Settings has no back button")
    XCTAssertEqual(back.label, "Back")
    XCTAssertGreaterThanOrEqual(back.frame.height, Self.touchTarget)
    // The edge swipe: from the very left edge, quickly, to past the middle.
    let window = app.windows.firstMatch
    let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
    edge.press(forDuration: 0.01, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)),
      withVelocity: .fast, thenHoldForDuration: 0)
    XCTAssertTrue(back.waitForNonExistence(timeout: Self.wait), "the edge swipe did not go back")
    XCTAssertTrue(settings.waitForExistence(timeout: Self.wait))
    settings.tap()
    XCTAssertTrue(back.waitForExistence(timeout: Self.wait))
    back.tap()
    XCTAssertTrue(back.waitForNonExistence(timeout: Self.wait), "the back button did not go back")
  }

  /// At the largest accessibility text size every header button keeps a 44-point touch target.
  func testHeaderTouchTargetsAtAccessibilitySize() {
    app.terminate()
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", Self.accessibilityTextSize]
    app.launch()
    let settings = app.buttons[Identifier.settings]
    XCTAssertTrue(settings.waitForExistence(timeout: Self.wait))
    for element in [app.buttons[Identifier.botControl], settings] {
      XCTAssertGreaterThanOrEqual(element.frame.width, Self.touchTarget)
      XCTAssertGreaterThanOrEqual(element.frame.height, Self.touchTarget)
    }
    shot("a11y-home-header")
    settings.tap()
    let back = app.buttons[Identifier.back].firstMatch
    XCTAssertTrue(back.waitForExistence(timeout: Self.wait))
    XCTAssertGreaterThanOrEqual(back.frame.height, Self.touchTarget)
    shot("a11y-settings-back")
  }

  // MARK: - screens behind Home and Activity

  private func homeDetails() {
    if tap(app.buttons[Identifier.botControl]) {
      shot("tab0-bot-control")
      guard dismiss() else { return }
    }
    if tap(app.buttons[Identifier.risk]) {
      capture(screen: "tab0-risk")
      back()
    }
    if tap(app.buttons[Identifier.settings]) {
      capture(screen: "tab0-settings")
      back()
    }
  }

  private func activityDetails() {
    let panes = app.buttons.matching(identifier: Identifier.activitySection)
    for index in 0..<panes.count {
      panes.element(boundBy: index).tap()
      sleep(Self.settle)
      capture(screen: "tab3-section\(index)")
    }
    if tap(app.buttons[Identifier.calendar]) {
      shot("tab3-calendar")
      _ = tap(app.buttons[Identifier.calendar])
    }
  }

  // MARK: - helpers

  private func tap(_ element: XCUIElement) -> Bool {
    guard element.waitForExistence(timeout: Self.wait), element.isHittable else { return false }
    element.tap()
    sleep(Self.settle)
    return true
  }

  /// Closes the bot-control sheet with its own Cancel button, never with a tap elsewhere: the
  /// sheet's other buttons send commands. At the medium height Cancel can sit below the fold, so
  /// the sheet is scrolled (a swipe presses nothing) until Cancel can be tapped. Fails the step,
  /// and leaves the remaining Home screens out, if Cancel cannot be reached or the sheet stays.
  @discardableResult
  private func dismiss() -> Bool {
    let cancel = app.buttons[Identifier.botControlCancel].firstMatch
    guard cancel.waitForExistence(timeout: Self.wait) else {
      XCTFail("the bot-control sheet has no Cancel button")
      return false
    }
    var scrolls = 0
    while !cancel.isHittable && scrolls < Self.maxScrolls {
      app.scrollViews.firstMatch.swipeUp()
      scrolls += 1
    }
    guard cancel.isHittable else {
      XCTFail("Cancel of the bot-control sheet cannot be reached")
      return false
    }
    cancel.tap()
    sleep(Self.settle)
    guard !cancel.exists else {
      XCTFail("the bot-control sheet stayed open after Cancel")
      return false
    }
    return true
  }

  /// Back with the screen's own "‹ Home" button (the app hides the system bar).
  private func back() {
    let button = app.buttons[Identifier.back].firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: Self.wait), "the pushed screen has no back button")
    button.tap()
    sleep(Self.settle)
  }

  /// A screenshot of the screen, then more while it scrolls, until the picture stops changing.
  private func capture(screen name: String) {
    var last = shot(name)
    for page in 1...Self.maxScrolls {
      app.swipeUp()
      sleep(1)
      let next = XCUIScreen.main.screenshot().pngRepresentation
      if next == last { break }
      last = shot("\(name)-scroll\(page)")
    }
    for _ in 0..<Self.maxScrolls { app.swipeDown() }
  }

  @discardableResult
  private func shot(_ name: String) -> Data {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
    return screenshot.pngRepresentation
  }
}
