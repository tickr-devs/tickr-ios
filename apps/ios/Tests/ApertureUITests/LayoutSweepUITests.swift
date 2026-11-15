import XCTest

/// Layout sweep: every tab, scrolled to its end, in English and Russian at the default and at
/// large Dynamic Type sizes, for checking that nothing slides under the bars, overlaps or gets
/// clipped. Run on each iPhone size (CI: .github/workflows/layout-sweep.yml runs it
/// on an iPhone SE, a standard and a Pro Max against `aperture demo`):
///   xcodebuild test -project apps/ios/Aperture.xcodeproj -scheme "Aperture iOS Screen Tour" \
///     -destination 'platform=iOS Simulator,name=iPhone 17' \
///     -only-testing:ApertureUITests/LayoutSweepUITests -resultBundlePath sweep.xcresult
///   xcrun xcresulttool export attachments --path sweep.xcresult --output-path sweep
/// Skipped unless SWEEP_API is set (the demo's API, http://127.0.0.1:8776). Sends no command.
@MainActor
final class LayoutSweepUITests: XCTestCase {
  /// Languages of the sweep: English, and Russian, whose texts are the longest.
  private static let languages = ["en", "ru"]
  /// Dynamic Type sizes (UIContentSizeCategory raw values): the default, the largest standard one
  /// and a mid accessibility size.
  private static let textSizes = [
    "UICTContentSizeCategoryL",
    "UICTContentSizeCategoryXXXL",
    "UICTContentSizeCategoryAccessibilityL",
  ]
  /// Seconds a tab gets to load and finish its entrance animations.
  private static let settle: UInt32 = 3
  /// Seconds to wait for the tab bar.
  private static let wait: TimeInterval = 15
  /// Most extra pictures taken while scrolling one tab down.
  private static let maxScrolls = 6

  override func setUp() async throws {
    continueAfterFailure = true
    guard ProcessInfo.processInfo.environment["SWEEP_API"] != nil else {
      throw XCTSkip("SWEEP_API is not set: the layout sweep needs `aperture demo`")
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
        let tabs = app.tabBars.buttons
        guard tabs.firstMatch.waitForExistence(timeout: Self.wait) else {
          XCTFail("no tab bar (\(language), \(size))")
          app.terminate()
          continue
        }
        sleep(Self.settle)
        let prefix = "\(language)-\(size.replacingOccurrences(of: "UICTContentSizeCategory", with: ""))"
        for index in 0..<tabs.count {
          tabs.element(boundBy: index).tap()
          sleep(Self.settle)
          capture(app, "\(prefix)-tab\(index)")
        }
        app.terminate()
      }
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
