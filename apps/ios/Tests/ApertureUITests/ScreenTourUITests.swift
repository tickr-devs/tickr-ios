import XCTest

/// Walks every screen of the app against a running bot API (for example `aperture demo`) and
/// keeps a screenshot of each, for comparing the app with the design. It sends no command: the
/// bot-control sheet is opened and cancelled.
///
/// Run on a booted Simulator (light or dark appearance set with `xcrun simctl ui`):
///   xcodebuild test -project apps/ios/Aperture.xcodeproj -scheme "Aperture iOS Screen Tour" \
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
  }

  private var app = XCUIApplication()

  override func setUp() async throws {
    continueAfterFailure = true
    let environment = ProcessInfo.processInfo.environment
    let api = environment["TOUR_API"] ?? Self.defaultAPI
    let language = environment["TOUR_LANGUAGE"] ?? Self.defaultLanguage
    app.launchArguments = ["-apiBaseURL", api, "-AppleLanguages", "(\(language))"]
    app.launch()
    sleep(Self.settle)
  }

  func testTour() {
    let tabs = app.tabBars.buttons
    XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: Self.wait))
    for index in 0..<tabs.count {
      tabs.element(boundBy: index).tap()
      sleep(Self.settle)
      capture(screen: "tab\(index)")
      if index == 0 { homeDetails() }
      if index == 3 { activityDetails() }
      tabs.element(boundBy: index).tap()
    }
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
    for index in 0..<app.segmentedControls.buttons.count {
      app.segmentedControls.buttons.element(boundBy: index).tap()
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

  private func back() {
    app.navigationBars.buttons.element(boundBy: 0).tap()
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
