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
  /// Stop bot in the bot-control sheet while positions are open, and the two answers it offers.
  static let botControlStop = "botControl.stop"
  static let stopCloseAndStop = "botControl.closeAndStop"
  static let stopLeaveOpen = "botControl.leaveOpen"
  /// The command notice floating at the top of the screen.
  static let notice = "notice"
  /// Activity toolbar button that shows or hides the calendar.
  static let calendar = "activity.calendar"
  /// Activity's unavailable state of a picked past day whose trades could not be read.
  static let dayUnavailable = "activity.dayUnavailable"
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
  /// Home's funnel row, the button that opens the "Funnel today" sheet.
  static let funnel = "home.funnel"
  /// Each stage's bar in the "Funnel today" sheet (its symbols, or the broker check's detail).
  static let funnelStage = "funnel.stage"
  /// Home's day capsule ("Today ▾"), the button that opens the day sheet.
  static let daySwitch = "home.daySwitch"
  /// The Chart top bar's button that opens the "Chart options" sheet (landscape only).
  static let chartOptions = "chart.options"
}
