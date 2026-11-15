/// Accessibility identifiers of the controls the UI tests tap. They never reach a person, so the
/// tests can walk every screen in any language. Keep in step with
/// `Tests/TickrUITests/ScreenTourUITests.swift`.
enum AccessibilityID {
  /// Home toolbar button that opens the bot-control sheet.
  static let botControl = "home.botControl"
  /// Home toolbar link to Settings.
  static let settings = "home.settings"
  /// Header of the Home Live flow card, the link to Risk.
  static let risk = "home.risk"
  /// Cancel button of the bot-control sheet.
  static let botControlCancel = "botControl.cancel"
  /// Activity toolbar button that shows or hides the calendar.
  static let calendar = "activity.calendar"
  /// The tab bar's buttons.
  static let tabHome = "tab.home"
  static let tabPositions = "tab.positions"
  static let tabChart = "tab.chart"
  static let tabActivity = "tab.activity"
  static let tabLab = "tab.lab"
  /// A pushed screen's own back button ("‹ Home").
  static let back = "nav.back"
  /// Each pane chip of Activity (Trades, Not taken, Journal).
  static let activitySection = "activity.section"
}
