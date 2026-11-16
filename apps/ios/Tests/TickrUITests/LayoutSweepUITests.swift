import XCTest

/// Layout sweep: every tab, Risk, Settings and Activity's panes, scrolled to their end, in
/// English and Russian at the default and at large Dynamic Type sizes, for checking that nothing
/// slides under the bars, overlaps or gets clipped. CI reads every picture for truncated text
/// (apps/scripts/find_truncated_text.swift). Run on each iPhone size (CI: .github/workflows/layout-sweep.yml runs it
/// on an iPhone SE, a standard and a Pro Max against `tickr demo`):
///   xcodebuild test -project apps/ios/Tickr.xcodeproj -scheme "Tickr iOS Screen Tour" \
///     -destination 'platform=iOS Simulator,name=iPhone 17' \
///     -only-testing:TickrUITests/LayoutSweepUITests -resultBundlePath sweep.xcresult
///   xcrun xcresulttool export attachments --path sweep.xcresult --output-path sweep
/// Skipped unless SWEEP_API is set (the demo's API, http://127.0.0.1:8776). Sends no command.
@MainActor
final class LayoutSweepUITests: XCTestCase {
  /// Languages of the sweep: English, and Russian, whose texts are the longest.
  private static let languages = ["en", "ru"]
  /// Dynamic Type sizes (UIContentSizeCategory raw values): the default, the largest standard one
  /// and the largest accessibility size, where text is likeliest to be cut.
  private static let textSizes = [
    "UICTContentSizeCategoryL",
    "UICTContentSizeCategoryXXXL",
    "UICTContentSizeCategoryAccessibilityXXXL",
  ]
  /// Seconds a tab gets to load and finish its entrance animations.
  private static let settle: UInt32 = 3
  /// Seconds to wait for the tab bar.
  private static let wait: TimeInterval = 15
  /// Accessibility identifiers of the tab bar's buttons, in order (the app's `AccessibilityID`):
  /// the app draws the design's own tab bar, so the tabs are found by identifier.
  private static let tabs = ["tab.home", "tab.positions", "tab.chart", "tab.activity", "tab.lab"]
  /// Screens pushed from Home (Risk, Settings), the way back from them, and Activity's panes.
  private static let homeScreens = ["home.risk", "home.settings"]
  private static let back = "nav.back"
  private static let activitySection = "activity.section"
  /// Most extra pictures taken while scrolling one tab down.
  private static let maxScrolls = 6

  override func setUp() async throws {
    continueAfterFailure = true
    guard ProcessInfo.processInfo.environment["SWEEP_API"] != nil else {
      throw XCTSkip("SWEEP_API is not set: the layout sweep needs `tickr demo`")
    }
  }

  func testSweep() {
    let api = ProcessInfo.processInfo.environment["SWEEP_API"] ?? ""
    for language in Self.languages {
      for size in Self.textSizes {
        let app = XCUIApplication()
        app.launchArguments = [
          "-apiBaseURL", api, "-AppleLanguages", "(\(language))", "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        let tabs = Self.tabs.map { app.buttons[$0] }
        guard tabs[0].waitForExistence(timeout: Self.wait) else {
          XCTFail("no tab bar (\(language), \(size))")
          app.terminate()
          continue
        }
        sleep(Self.settle)
        let prefix = "\(language)-\(size.replacingOccurrences(of: "UICTContentSizeCategory", with: ""))"
        for (index, tab) in tabs.enumerated() {
          tab.tap()
          sleep(Self.settle)
          capture(app, "\(prefix)-tab\(index)")
          if index == 0 { home(app, prefix) }
          if index == 3 { activity(app, prefix) }
        }
        app.terminate()
      }
    }
  }

  /// Risk and Settings, each scrolled through, then back to Home.
  private func home(_ app: XCUIApplication, _ prefix: String) {
    for (index, id) in Self.homeScreens.enumerated() {
      let button = app.buttons[id]
      guard reach(button, in: app) else { continue }
      button.tap()
      sleep(Self.settle)
      capture(app, "\(prefix)-tab0-screen\(index)")
      // The screen's own back button scrolls with it: back to the top first.
      let back = app.buttons[Self.back].firstMatch
      if reach(back, in: app) { back.tap() }
      sleep(Self.settle)
    }
  }

  /// Scrolls back up until `element` is on the screen; false when it never is.
  private func reach(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    for _ in 0...Self.maxScrolls where !onScreen(element, in: app) {
      app.swipeDown()
    }
    return onScreen(element, in: app)
  }

  /// Whether `element` exists inside the window (a scrolled-away one has no point to tap).
  private func onScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    guard element.exists else { return false }
    let frame = element.frame
    return !frame.isEmpty && app.windows.firstMatch.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
  }

  /// Each of Activity's panes, scrolled through.
  private func activity(_ app: XCUIApplication, _ prefix: String) {
    let panes = app.buttons.matching(identifier: Self.activitySection)
    for index in 0..<panes.count {
      let pane = panes.element(boundBy: index)
      guard reach(pane, in: app) else { continue }
      pane.tap()
      sleep(Self.settle)
      capture(app, "\(prefix)-tab3-section\(index)")
    }
  }

  /// A picture of the screen, then more while it scrolls, until the picture stops changing.
  private func capture(_ app: XCUIApplication, _ name: String) {
    var last = shot(name)
    for page in 1...Self.maxScrolls {
      app.swipeUp()
      sleep(1)
      let next = XCUIScreen.main.screenshot().pngRepresentation
      if next == last { break }
      last = shot("\(name)-scroll\(page)")
    }
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
