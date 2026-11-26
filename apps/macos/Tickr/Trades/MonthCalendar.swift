import SwiftUI
import TickrDesign
import TickrKit

/// A trading month, Monday to Friday: the month and its total result on top, then a tile per
/// weekday with its gross result, trade count, wins and losses and clean-day dot. Clicking a
/// recorded day (or today) shows it; the arrows step through the months that hold records. It is
/// the screen's only day picker (the separate all-days list duplicated it).
struct MonthCalendar: View {
  @Environment(AppModel.self) private var model
  @State private var month: DayCalendar.Month?

  /// Accessibility id of the calendar, for the UI tests.
  static let id = "trades-calendar"

  var body: some View {
    let shown = month ?? DayCalendar.Month(model.shownDay)
    let months = DayCalendar.months(model.days, including: model.today)
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      header(shown, months: months)
      // The board's 4-point gap between tiles (MacTrades v106), so a 378-point column leaves each
      // tile room for "−$1,234.56".
      Grid(horizontalSpacing: Tokens.Space.xs, verticalSpacing: Tokens.Space.xs) {
        GridRow {
          ForEach(weekdays, id: \.self) { name in
            Text(verbatim: name)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
              .frame(maxWidth: .infinity)
          }
        }
        ForEach(Array(DayCalendar.weeks(of: shown, days: model.days).enumerated()), id: \.offset) { row, week in
          GridRow {
            ForEach(Array(week.enumerated()), id: \.offset) { column, cell in
              if let cell {
                CalendarDay(cell: cell, isToday: cell.day == model.today, selected: cell.day == model.shownDay,
                  todayEvent: model.todayEvent) {
                  select(cell.day)
                }
                // The tiles fade up one after another, as the design fills a month in.
                .rise(Double(row * week.count + column) * Tokens.Motion.cellStagger)
              } else {
                Color.clear.frame(height: CalendarDay.height)
              }
            }
          }
        }
      }
      // A new identity per month: another month's tiles fill in afresh.
      .id(shown)
      legend
    }
    .animation(Tokens.Motion.standard, value: shown)
    .onChange(of: model.shownDay) { _, day in month = DayCalendar.Month(day) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  /// What the cells' corner dots mean.
  private var legend: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) { cleanItem; lookItem }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) { cleanItem; lookItem }
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var cleanItem: some View {
    HStack(spacing: Tokens.Space.xs) {
      CleanDot(verdict: .clean)
      Text(L10n.Trades.cleanLegend)
    }
  }

  private var lookItem: some View {
    HStack(spacing: Tokens.Space.xs) {
      CleanDot(verdict: .notClean)
      Text(L10n.Trades.needsLook)
    }
  }

  /// "NOVEMBER 2026 · DAY RESULT" with the month arrows, and the month's total on the right.
  private func header(_ shown: DayCalendar.Month, months: [DayCalendar.Month]) -> some View {
    // Months run newest first: the previous one is later in the list.
    let index = months.firstIndex(of: shown)
    let previous = index.flatMap { months.indices.contains($0 + 1) ? months[$0 + 1] : nil }
    let next = index.flatMap { $0 > 0 ? months[$0 - 1] : nil }
    let total = DayCalendar.total(of: shown, days: model.days)
    return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      if let first = shown.firstDay {
        CardLabel(L10n.Trades.monthLabel(first.formatted(.dateTime.month(.wide).year())))
          .contentTransition(.opacity)
      }
      // Always shown, so earlier months stay reachable; the arrow that leads nowhere is dimmed
      // (its own colour kept it looking active).
      HStack(spacing: Tokens.Space.xxs) {
        Button { month = previous } label: { arrow(Symbols.previous) }
          .disabled(previous == nil)
          .help(Text(L10n.Trades.previousMonth))
          .accessibilityLabel(Text(L10n.Trades.previousMonth))
        Button { month = next } label: { arrow(Symbols.next) }
          .disabled(next == nil)
          .help(Text(L10n.Trades.nextMonth))
          .accessibilityLabel(Text(L10n.Trades.nextMonth))
      }
      .font(Tokens.Typography.chevron)
      .buttonStyle(.glyph)
      Spacer(minLength: Tokens.Space.s)
      if let total {
        Text(L10n.Trades.monthTotal(Money.signedUSD(total)))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.result(total))
          .fixedSize()
      }
    }
  }

  /// A month arrow: the chevron in `textQuaternary`, dimmed while it leads nowhere.
  private func arrow(_ symbol: String) -> some View {
    Image(systemName: symbol).foregroundStyle(Palette.textQuaternary).dimmedWhenDisabled()
  }

  private func select(_ day: WireDate) {
    if day == model.today {
      model.showToday()
    } else {
      model.selectedDay = day
    }
  }

  /// Short weekday names, Monday to Friday, in the user's language.
  private var weekdays: [String] {
    let names = Calendar.current.shortStandaloneWeekdaySymbols
    return Array(names[(DayCalendar.monday - 1)...(DayCalendar.friday - 1)])
  }
}

/// A day's clean-day mark: a green dot when clean, an amber ring when it needs a look.
struct CleanDot: View {
  let verdict: CleanVerdict

  var body: some View {
    Group {
      if verdict == .clean {
        Circle().fill(Palette.profit)
      } else {
        Circle().strokeBorder(Palette.warning, lineWidth: Tokens.Stroke.regular)
      }
    }
    .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
  }
}

/// One weekday tile: its number and clean dot on top, then, when the bot recorded it, its gross
/// result to the cent, a list glyph with its trade count and its wins and losses ("3 trades" is
/// its tooltip and accessibility value), as the board draws it (MacTrades v106).
private struct CalendarDay: View {
  /// Least height of a day's tile, in points: the board's 46 (`.cell` min-height); a tile grows
  /// when its text needs more.
  static let height: CGFloat = 46
  /// Inset of a tile's content, in points: the board's 5 (top, bottom) and 4 (sides) on the
  /// spacing scale.
  static let inset: CGFloat = Tokens.Space.xs

  let cell: DayCalendar.Cell
  let isToday: Bool
  let selected: Bool
  /// Today's trading (`AppModel.todayEvent`): today's tile pulses once per change, as the design's
  /// today ring, never on a timer.
  let todayEvent: [Int]?
  let action: () -> Void
  @State private var hovered = false

  /// Whether a click opens the day: it has records, or it is today.
  private var opens: Bool { cell.summary != nil || isToday }
  private var lifted: Bool { hovered && opens }

  var body: some View {
    let summary = cell.summary
    let result = summary?.resultUsd.value
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    Button(action: action) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: 0) {
          Text(verbatim: String(cell.day.day))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
          Spacer(minLength: 0)
          if let clean = summary?.clean, clean.verdict != .unknown {
            CleanDot(verdict: clean.verdict)
          }
        }
        Spacer(minLength: 0)
        if let result {
          // The largest size that holds the whole result: never cut, never scaled down.
          ViewThatFits(in: .horizontal) {
            ForEach(Tokens.Typography.calendarResultFonts.indices, id: \.self) { index in
              Text(verbatim: Money.signedUSD(result))
                .font(Tokens.Typography.calendarResultFonts[index])
                .fixedSize()
            }
          }
          .foregroundStyle(Palette.result(result))
        }
      }
      .padding(Self.inset)
      .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .topLeading)
      .background {
        if let result {
          shape.fill(Palette.result(result).opacity(Tokens.Opacity.wash))
        } else {
          shape.fill(Palette.surface)
        }
      }
      .overlay {
        if selected {
          shape.strokeBorder(Palette.info, lineWidth: Tokens.Stroke.bold)
        } else if lifted {
          shape.strokeBorder(Palette.info, lineWidth: Tokens.Stroke.thin)
        } else if isToday {
          shape.strokeBorder(Palette.accent, lineWidth: Tokens.Stroke.thin)
        } else {
          shape.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
        }
      }
      .shadow(color: selected ? Palette.info.opacity(Tokens.Opacity.border) : .clear, radius: Tokens.Space.xs)
      .eventPulse(shape, color: Palette.accent, scale: Tokens.Motion.glyphPulseScale,
        event: isToday ? todayEvent.map(AnyHashable.init) : nil)
      .contentShape(shape)
      // Under the pointer a day it can open lifts a little and outlines, as the design's tiles.
      .offset(y: lifted ? -Tokens.Motion.cellLift : 0)
      .animation(Tokens.Motion.quick, value: lifted)
    }
    .buttonStyle(.plain)
    .onHover { hovered = $0 }
    .disabled(!opens)
    .help(Text(verbatim: summary.map(Self.tooltip) ?? DayText.day(cell.day)))
    .accessibilityLabel(Text(verbatim: DayText.day(cell.day)))
    .accessibilityValue(Text(verbatim: summary.map(Self.figures) ?? String(localized: L10n.Trades.noRecords)))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// A recorded day's result, trade count, wins and losses on one line.
  private static func figures(_ summary: DaySummary) -> String {
    [Money.signedUSD(summary.resultUsd.value), String(localized: L10n.Trades.tradeCount(summary.trades)),
      String(localized: L10n.Trades.winsLosses(summary.wins, summary.losses))]
      .joined(separator: Format.itemSeparator)
  }

  /// A recorded day's tooltip: the day and its figures, its clean-day verdict, and a note when it
  /// has no bars for the Chart.
  private static func tooltip(_ summary: DaySummary) -> String {
    let lines = [DayText.day(summary.day) + Format.itemSeparator + figures(summary), CleanMark.text(summary.clean)]
    return (lines + (summary.hasBars ? [] : [String(localized: L10n.Trades.noBarsHelp)]))
      .joined(separator: Format.lineSeparator)
  }
}
