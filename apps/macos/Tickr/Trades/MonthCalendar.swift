import SwiftUI
import TickrDesign
import TickrKit

/// A trading month, Monday to Friday, each recorded day tinted by its gross result. Clicking a
/// recorded day (or today) shows it; the arrows step through the months that hold records.
struct MonthCalendar: View {
  @Environment(AppModel.self) private var model
  @State private var month: DayCalendar.Month?

  /// Accessibility id of the calendar, for the UI tests.
  static let id = "trades-calendar"

  var body: some View {
    let shown = month ?? DayCalendar.Month(model.shownDay)
    let months = DayCalendar.months(model.days, including: model.today)
    VStack(spacing: Tokens.Space.s) {
      header(shown, months: months)
      Grid(horizontalSpacing: Tokens.Space.xxs, verticalSpacing: Tokens.Space.xxs) {
        GridRow {
          ForEach(weekdays, id: \.self) { name in
            Text(verbatim: name)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
              .frame(maxWidth: .infinity)
          }
        }
        ForEach(Array(DayCalendar.weeks(of: shown, days: model.days).enumerated()), id: \.offset) { _, week in
          GridRow {
            ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
              if let cell {
                CalendarDay(cell: cell, isToday: cell.day == model.today, selected: cell.day == model.shownDay) {
                  select(cell.day)
                }
              } else {
                Color.clear.frame(height: CalendarDay.height)
              }
            }
          }
        }
      }
      legend
    }
    .animation(Tokens.Motion.standard, value: shown)
    .onChange(of: model.shownDay) { _, day in month = DayCalendar.Month(day) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.id)
  }

  /// What the cells' corner dots mean.
  private var legend: some View {
    // One line per dot, so a narrow column wraps the words instead of clipping them.
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(spacing: Tokens.Space.xs) {
        dot(Palette.profit)
        Text(L10n.Trades.cleanLegend)
      }
      HStack(spacing: Tokens.Space.xs) {
        dot(Palette.warning)
        Text(L10n.Trades.needsLook)
      }
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func dot(_ color: Color) -> some View {
    Circle().fill(color).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
  }

  private func header(_ shown: DayCalendar.Month, months: [DayCalendar.Month]) -> some View {
    // Months run newest first: the previous one is later in the list.
    let index = months.firstIndex(of: shown)
    let previous = index.flatMap { months.indices.contains($0 + 1) ? months[$0 + 1] : nil }
    let next = index.flatMap { $0 > 0 ? months[$0 - 1] : nil }
    return HStack(spacing: Tokens.Space.s) {
      Button { month = previous } label: { Image(systemName: "chevron.backward") }
        .disabled(previous == nil)
        .help(Text(L10n.Trades.previousMonth))
        .accessibilityLabel(Text(L10n.Trades.previousMonth))
      Spacer(minLength: 0)
      if let first = shown.firstDay {
        Text(first, format: .dateTime.month(.wide).year())
          .font(Tokens.Typography.calloutMono.bold())
          .contentTransition(.opacity)
      }
      Spacer(minLength: 0)
      Button { month = next } label: { Image(systemName: "chevron.forward") }
        .disabled(next == nil)
        .help(Text(L10n.Trades.nextMonth))
        .accessibilityLabel(Text(L10n.Trades.nextMonth))
    }
    .buttonStyle(.borderless)
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

/// One weekday: its number and, when the bot recorded it, its gross result.
private struct CalendarDay: View {
  /// Height of a day's cell, in points.
  static let height: CGFloat = 36

  let cell: DayCalendar.Cell
  let isToday: Bool
  let selected: Bool
  let action: () -> Void

  var body: some View {
    let result = cell.summary?.resultGrossUsd.value
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small)
    Button(action: action) {
      VStack(spacing: 0) {
        Text(cell.day.day, format: .number)
          .font(Tokens.Typography.annotationBold)
        if let result {
          Text(verbatim: Money.signed(result, fractionDigits: 0))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.result(result))
            .lineLimit(1)
            .minimumScaleFactor(Tokens.Shrink.tight)
        }
      }
      .frame(maxWidth: .infinity, minHeight: Self.height)
      .foregroundStyle(result == nil && !isToday ? Palette.textQuaternary : Palette.textPrimary)
      .background {
        if let result { shape.fill(Palette.result(result).opacity(Tokens.Opacity.wash)) }
      }
      .overlay {
        if selected {
          shape.strokeBorder(isToday ? Palette.accent : Palette.info, lineWidth: Tokens.Stroke.regular)
        } else if isToday {
          shape.strokeBorder(Palette.accent.opacity(Tokens.Opacity.faint), lineWidth: Tokens.Stroke.thin)
        }
      }
      .overlay(alignment: .topTrailing) {
        if let clean = cell.summary?.clean, clean.verdict != .unknown {
          Circle()
            .fill(clean.verdict == .clean ? Palette.profit : Palette.warning)
            .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
            .padding(Tokens.Space.xxs)
        }
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .disabled(result == nil && !isToday)
    .help(Text(verbatim: cell.summary.map { Format.dayLabel(cell.day) + Format.lineSeparator + CleanMark.text($0.clean) }
      ?? Format.dayLabel(cell.day)))
    .accessibilityLabel(Text(verbatim: Format.dayLabel(cell.day)))
    .accessibilityValue(result.map { Text(verbatim: Money.signedUSD($0)) } ?? Text(L10n.Trades.noRecords))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
