import AppKit
import TickrDesign

/// The width the title bar needs to show everything whole: the sidebar at its widest, the window
/// line (`WindowLine`) and the right-hand group (`DayStepper`), with AppKit's toolbar spacing.
///
/// Owner rule (2026-11-16): no text in the title bar is cut with "…" or moved into the toolbar's
/// "»" overflow menu, so the window is never narrower than this (`TickrMacApp.leastWidth`).
/// Every part is a text width measured with the font it is drawn in, or a fixed constant: none
/// depends on the window's size, so nothing is read back from a layout pass and the minimum never
/// moves during a resize. It follows the data the line shows (the environment, the strategy, the
/// chart's symbol), so it changes only when that data does.
enum TitleBarWidth {
  /// AppKit's toolbar geometry in the compact unified title bar, in points, read with
  /// Accessibility on macOS 27 (2026-11-16, 1440-point window, sidebar at 260): an item group
  /// starts `edgeInset` after the screen column's leading edge (the sidebar's hairline) and ends
  /// `edgeInset` before the window's trailing edge; each SwiftUI item is `itemPadding` wider than
  /// its content on each side (the line's 571.5-point text in a 580-point group); two items keep
  /// at least `itemGap` between them, and a narrower window moved the right-hand group into the
  /// overflow menu (1376 points fit, 1375 overflowed).
  static let edgeInset: CGFloat = 4
  static let itemPadding: CGFloat = 4.25
  static let itemGap: CGFloat = 8

  /// The window width at which the line `lineWidth` wide and the right-hand group `groupWidth`
  /// wide both fit beside the sidebar at its widest. With the sidebar hidden the line starts
  /// after the sidebar button (about 130 points in), well inside the sidebar's 260.
  static func need(lineWidth: CGFloat, groupWidth: CGFloat) -> CGFloat {
    RootView.sidebarMax + edgeInset + item(lineWidth) + itemGap + item(groupWidth) + edgeInset
  }

  /// A toolbar item's width around content `width` wide.
  static func item(_ width: CGFloat) -> CGFloat {
    width + itemPadding * CardArrangement.paddedEdges
  }

  /// The title-bar need for the shown data: the longest of the five sections' lines, so moving
  /// between sections never changes the window's least width.
  @MainActor
  static func need(model: AppModel, chart: ChartModel) -> CGFloat {
    let group = DayStepper.width(
      today: String(localized: L10n.Common.today),
      demoDay: String(localized: L10n.Toolbar.dayDemo(DayText.day(model.today))))
    return need(lineWidth: lineWidth(code: true, model: model, chart: chart), groupWidth: group)
  }

  /// Where the toolbar's items start while the sidebar is hidden (the icon rail of a narrow
  /// window), in points: after the window buttons and the sidebar button, about 130 points in
  /// (see `need(lineWidth:groupWidth:)`), with a margin.
  static let hiddenSidebarLead: CGFloat = 150

  /// The window width at which the title bar holds `tier` (`TitleBarFit`) whole, its toolbar
  /// starting `lead` points in: the line, then the connection status as text or as its dot.
  @MainActor
  static func need(_ tier: TitleBarFit, lead: CGFloat, model: AppModel, chart: ChartModel) -> CGFloat {
    let status = tier.statusText ? ConnectionStatus.width : Tokens.Size.dot
    return lead + edgeInset + item(lineWidth(code: tier.code, model: model, chart: chart)) + itemGap + item(status)
      + edgeInset
  }

  /// Width of the longest of the five sections' lines, with or without the code version.
  @MainActor
  static func lineWidth(code: Bool, model: AppModel, chart: ChartModel) -> CGFloat {
    let lines = AppSection.allCases.map {
      String(localized: WindowLine.line(for: $0, model: model, chart: chart, now: model.botTime(.now), code: code))
    }
    return lines.map { TextMeasure.width($0, font: Fonts.line) }.max() ?? 0
  }

  /// The AppKit fonts the title bar's texts are drawn in (`Tokens.Typography` on the Mac).
  enum Fonts {
    /// `calloutMono`: the window line.
    static var line: NSFont { NSFont.monospacedSystemFont(ofSize: callout, weight: .regular) }
    /// `buttonCompact`: the title of Today.
    static var button: NSFont { NSFont.systemFont(ofSize: callout, weight: .semibold) }
    /// `dayStepper`: the shown day.
    static var day: NSFont { NSFont.monospacedSystemFont(ofSize: Tokens.Typography.dayStepperSize, weight: .regular) }
    private static var callout: CGFloat { NSFont.preferredFont(forTextStyle: .callout).pointSize }
  }
}
