import Foundation

/// Texts of the window shell (title bar and sidebar) as the design boards word them.
extension L10n.Toolbar {
  /// The title bar's line on a screen with a detail ("tickr — sandbox — chart — ABCD · Day · 1m").
  static func windowLineSection(_ environment: String, _ section: String, _ detail: String) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.windowLineSection", defaultValue: "tickr — \(environment) — \(section) — \(detail)",
      bundle: L10n.bundle)
  }
  /// The same before the screen has its detail ("tickr — sandbox — chart").
  static func windowLineSectionOnly(_ environment: String, _ section: String) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.windowLineSectionOnly", defaultValue: "tickr — \(environment) — \(section)",
      bundle: L10n.bundle)
  }
  /// The Trades & days line's detail: the shown day's closed trades ("3 closed").
  static func closedTrades(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.closedTrades", defaultValue: "\(count) closed", bundle: L10n.bundle)
  }
  /// The bot's address and the age of its status ("127.0.0.1 · age 3 s").
  static func connectionAge(_ host: String, _ age: String) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.connectionAge", defaultValue: "\(host) · age \(age)", bundle: L10n.bundle)
  }
  /// An age in seconds and in minutes ("3 s", "2 min").
  static func ageSeconds(_ seconds: Int) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.ageSeconds", defaultValue: "\(seconds) s", bundle: L10n.bundle)
  }
  static func ageMinutes(_ minutes: Int) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.ageMinutes", defaultValue: "\(minutes) min", bundle: L10n.bundle)
  }
  /// The day stepper's day ("Mon Nov 16"): weekday, month and day of the month.
  static func day(_ weekday: String, _ month: String, _ dayOfMonth: String) -> LocalizedStringResource {
    LocalizedStringResource("toolbar.day", defaultValue: "\(weekday) \(month) \(dayOfMonth)", bundle: L10n.bundle)
  }
  /// The title bar's sidebar button.
  static var hideSidebar: LocalizedStringResource {
    LocalizedStringResource("toolbar.hideSidebar", defaultValue: "Hide Sidebar", bundle: L10n.bundle)
  }
  static var showSidebar: LocalizedStringResource {
    LocalizedStringResource("toolbar.showSidebar", defaultValue: "Show Sidebar", bundle: L10n.bundle)
  }
}
