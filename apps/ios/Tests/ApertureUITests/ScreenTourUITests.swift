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
  /// English labels the tour taps (the app's L10n default values).
  private enum Label {
    static let settings = "Settings"
    static let botControl = "Bot control"
    static let cancel = "Cancel"
    static let dailyLossRoom = "Daily loss room"
    static let calendar = "Calendar"
  }

  private var app = XCUIApplication()
  private var english = true

  override func setUp() async throws {
    continueAfterFailure = true
    let environment = ProcessInfo.processInfo.environment
    let api = environment["TOUR_API"] ?? Self.defaultAPI
    let language = environment["TOUR_LANGUAGE"] ?? Self.defaultLanguage
    english = language == Self.defaultLanguage
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
    if english, tap(app.buttons[Label.botControl]) {
      shot("tab0-bot-control")
      _ = tap(app.buttons[Label.cancel].firstMatch)
    }
    if english, tap(app.buttons[Label.dailyLossRoom].firstMatch) {
      capture(screen: "tab0-risk")
      back()
    }
    if english, tap(app.buttons[Label.settings]) {
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
    if english, tap(app.buttons[Label.calendar]) {
      shot("tab3-calendar")
      _ = tap(app.buttons[Label.calendar])
    }
  }

  // MARK: - helpers

  private func tap(_ element: XCUIElement) -> Bool {
    guard element.waitForExistence(timeout: Self.wait), element.isHittable else { return false }
    element.tap()
    sleep(Self.settle)
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
