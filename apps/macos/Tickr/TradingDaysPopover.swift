import SwiftUI
import TickrDesign
import TickrKit

/// The recorded trading days under the toolbar's day (owner-approved 2026-11-28, mockup v202, page
/// p-days, boards MacDayPicker and IPadDayPicker): a popover, not a system menu. Trading days only
/// (Saturdays and Sundays never trade), newest first and tagged LAST; each row the day, its counts
/// and its result in the result's colour; the shown day checked and tinted. `Lists.dayPickerRows`
/// rows, then the shared footer row to Trades & days. On the Mac ↑ ↓ move between rows and Return
/// shows the one moved to.
struct TradingDaysPopover: View {
  @Environment(AppModel.self) private var model
  /// The row ↑ ↓ moved to; the shown day at first.
  @State private var highlighted: WireDate?
  @FocusState private var focused: Bool
  /// Closes the popover.
  let close: () -> Void

  /// The popover's width (the boards' 340 px).
  static let width: CGFloat = 340
  /// Width kept for the check, so the days line up whether checked or not.
  static let checkWidth: CGFloat = 18
  /// SF Symbol of the shown day's check.
  static let checkSymbol = "checkmark"
  /// Accessibility id of the popover, for the UI tests.
  static let id = "day-picker"

  /// `days` without the weekend's (the bot records a row for any date it ran on).
  static func tradingDays(_ days: [DaySummary]) -> [DaySummary] {
    days.filter { !$0.day.isWeekend }
  }

  var body: some View {
    let days = Self.tradingDays(model.days)
    let shown = Array(days.prefix(Tokens.Lists.dayPickerRows))
    VStack(alignment: .leading, spacing: .zero) {
      HStack {
        Text(L10n.Toolbar.tradingDays)
        Spacer(minLength: Tokens.Space.s)
        Text(L10n.Overview.dayResult)
      }
      .textCase(.uppercase)
      .font(Tokens.Typography.label)
      .tracking(Tokens.Typography.labelTracking)
      .foregroundStyle(Palette.textLabel)
      .padding(.horizontal, Tokens.Space.l)
      .padding(.top, Tokens.Space.l)
      .padding(.bottom, Tokens.Space.s)
      ForEach(Array(shown.enumerated()), id: \.element.id) { index, day in
        if index > 0 { Divider().overlay(Palette.separator) }
        row(day, last: index == 0)
      }
      if days.count > shown.count {
        CardFooterLink(L10n.Toolbar.showAllDays, count: days.count) {
          close()
          model.section = .trades
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.m)
      }
    }
    .frame(width: Self.width)
    .focusable()
    .focused($focused)
    .focusEffectDisabled()
    .onKeyPress(.upArrow) { move(-1, in: shown) }
    .onKeyPress(.downArrow) { move(1, in: shown) }
    .onKeyPress(.return) {
      guard let day = highlighted else { return .ignored }
      pick(day)
      return .handled
    }
    .onAppear {
      highlighted = model.shownDay
      focused = true
    }
    .accessibilityIdentifier(Self.id)
  }

  private func row(_ day: DaySummary, last: Bool) -> some View {
    let selected = day.day == model.shownDay
    let result = day.resultUsd.value
    return Button { pick(day.day) } label: {
      HStack(spacing: Tokens.Space.m) {
        Image(systemName: Self.checkSymbol)
          .font(Tokens.Typography.chevron)
          .foregroundStyle(Palette.infoText)
          .frame(width: Self.checkWidth)
          .opacity(selected ? 1 : .zero)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          HStack(spacing: Tokens.Space.s) {
            Text(verbatim: DayText.day(day.day))
              .font(Tokens.Typography.symbol)
              .foregroundStyle(Palette.textPrimary)
            if last { Badge(L10n.Toolbar.lastDay, tone: .accent) }
          }
          Text(day.trades == .zero ? L10n.Toolbar.noTrades : L10n.Overview.dayCounts(day.trades, day.wins, day.losses))
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textTertiary)
        }
        Spacer(minLength: Tokens.Space.s)
        Text(verbatim: Money.signedUSD(result))
          .font(Tokens.Typography.figure)
          .foregroundStyle(Palette.result(result))
          .fixedSize()
      }
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.s)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(background(selected: selected, highlighted: highlighted == day.day))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func background(selected: Bool, highlighted: Bool) -> Color {
    if selected { return Palette.info.opacity(Tokens.Opacity.wash) }
    return highlighted ? Palette.textTertiary.opacity(Tokens.Opacity.wash) : .clear
  }

  private func move(_ step: Int, in days: [DaySummary]) -> KeyPress.Result {
    guard !days.isEmpty else { return .ignored }
    let index = days.firstIndex { $0.day == highlighted } ?? (step > 0 ? -1 : days.count)
    highlighted = days[min(max(index + step, .zero), days.count - 1)].day
    return .handled
  }

  private func pick(_ day: WireDate) {
    if day == model.today { model.showToday() } else { model.selectedDay = day }
    close()
  }
}
