import Foundation

/// Texts of the demo day the apps carry (DemoSource), in English with their Spanish translation in
/// Resources/Localizable.xcstrings.
extension L10n {
  /// The demo day's recording is not in the app (a broken build).
  static var demoMissing: LocalizedStringResource {
    LocalizedStringResource("kit.demo.missing", defaultValue: "the demo day's recording is missing from the app",
      bundle: bundle)
  }
  /// The demo day's recording has a layout this app does not read; argument: its layout version.
  static func demoFormat(_ version: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.demo.format",
      defaultValue: "the demo day's recording has layout \(version), which this app does not read", bundle: bundle)
  }
  /// A read the demo day's recording does not hold; argument: the API path.
  static func demoNotRecorded(_ path: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.demo.notRecorded", defaultValue: "the demo day has no recording of \(path)",
      bundle: bundle)
  }
}
