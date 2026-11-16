import SwiftUI
import TickrDesign
import TickrKit

/// A trading month, Monday to Friday: the month and its total result on top, then a tile per
/// weekday with its gross result, trade count and clean-day dot. Clicking a recorded day (or
/// today) shows it; the arrows step through the months that hold records.
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
      Grid(horizontalSpacing: Tokens.Space.xs + Tokens.Space.xxs, verticalSpacing: Tokens.Space.xs + Tokens.Space.xxs) {
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
    let total = monthTotal(shown)
    return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      if let first = shown.firstDay {
        CardLabel(L10n.Trades.monthLabel(first.formatted(.dateTime.month(.wide).year())))
          .lineLimit(1)
          .contentTransition(.opacity)
      }
      HStack(spacing: Tokens.Space.xxs) {
        Button { month = previous } label: { Image(systemName: "chevron.backward") }
          .disabled(previous == nil)
          .help(Text(L10n.Trades.previousMonth))
          .accessibilityLabel(Text(L10n.Trades.previousMonth))
        Button { month = next } label: { Image(systemName: "chevron.forward") }
          .disabled(next == nil)
          .help(Text(L10n.Trades.nextMonth))
          .accessibilityLabel(Text(L10n.Trades.nextMonth))
      }
      .font(Tokens.Typography.chevron)
      .foregroundStyle(Palette.textQuaternary)
      .buttonStyle(.borderless)
      Spacer(minLength: Tokens.Space.s)
      if let total {
        Text(L10n.Trades.monthTotal(Money.signed(total)))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.result(total))
          .lineLimit(1)
          .fixedSize()
      }
    }
  }

  /// Sum of the month's recorded day results; nil when the month has none.
  private func monthTotal(_ shown: DayCalendar.Month) -> Decimal? {
    let results = model.days.filter { DayCalendar.Month($0.day) == shown }.map(\.resultGrossUsd.value)
    return results.isEmpty ? nil : results.reduce(0, +)
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
/// result to the cent and its trade count.
private struct CalendarDay: View {
  /// Height of a day's tile, in points.
  static let height: CGFloat = 62

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
    let result = summary?.resultGrossUsd.value
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    Button(action: action) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: 0) {
          Text(cell.day.day, format: .number)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
          Spacer(minLength: 0)
          if let clean = summary?.clean, clean.verdict != .unknown {
            CleanDot(verdict: clean.verdict)
          }
        }
        Spacer(minLength: 0)
        if let summary, let result {
          Text(verbatim: Money.signed(result))
            .font(Tokens.Typography.calloutMono.bold())
            .foregroundStyle(Palette.result(result))
          Text(L10n.Trades.tradeCount(summary.trades))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.tight)
      .padding(Tokens.Space.xs + Tokens.Space.xxs)
      .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .topLeading)
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
    .help(Text(verbatim: summary.map { Format.dayLabel(cell.day) + Format.lineSeparator + CleanMark.text($0.clean) }
      ?? Format.dayLabel(cell.day)))
    .accessibilityLabel(Text(verbatim: Format.dayLabel(cell.day)))
    .accessibilityValue(result.map { Text(verbatim: Money.signedUSD($0)) } ?? Text(L10n.Trades.noRecords))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
