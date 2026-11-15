import ApertureDesign
import ApertureKit
import SwiftUI

/// What happened on a day: the day's result curve, closed trades, signals not taken, and the
/// journal. Today is live from the status; the calendar button picks a recorded past day, which
/// shows read-only from the bot's history.
struct ActivityView: View {
  enum Pane: String, CaseIterable, Identifiable {
    case trades, skipped, journal
    var id: String { rawValue }

    var title: LocalizedStringResource {
      switch self {
      case .trades: return L10n.Activity.trades
      case .skipped: return L10n.Activity.notTaken
      case .journal: return L10n.Activity.journal
      }
    }
  }

  /// Order in which the blocks rise in (`rise(step:)`); list rows follow one step apart.
  enum Order: Int { case day = 1, picker, list }

  @Environment(AppModel.self) private var model
  @State private var activity = Container.shared.activityModel()
  @State private var section: Pane = .trades
  @State private var showsCalendar = false

  var body: some View {
    Screen(L10n.App.activity) {
      ConnectionPrompt()
      if showsCalendar, let url = model.connection.url {
        DayPicker(activity: activity, url: url)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
      if let selected = activity.selectedDay {
        pastDay(selected)
      } else if let status = model.status {
        DayCard(label: String(localized: L10n.Common.today(Format.day(status.writtenAt.date))),
          live: model.response?.stale == false, figures: DayFigures(status))
          .rise(step: Order.day.rawValue)
        panes(status: status)
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showsCalendar.toggle()
        } label: {
          Image(systemName: "calendar")
            .symbolVariant(showsCalendar ? SymbolVariants.fill.circle : .none)
        }
        .accessibilityLabel(Text(L10n.Activity.calendar))
      }
    }
    .animation(Tokens.Motion.standard, value: section)
    .animation(Tokens.Motion.standard, value: showsCalendar)
    .animation(Tokens.Motion.standard, value: activity.selectedDay)
    .animation(Tokens.Motion.standard, value: activity.phase)
    .task(id: model.connection.url) {
      guard let url = model.connection.url else { return }
      await activity.loadDays(url)
    }
    .refreshable {
      await model.refresh()
      guard let url = model.connection.url else { return }
      await activity.loadDays(url)
      if let selected = activity.selectedDay { await activity.show(selected, from: url) }
    }
  }

  @ViewBuilder
  private func pastDay(_ selected: WireDate) -> some View {
    let label = String(localized: L10n.Activity.pastDay(Format.day(selected.noonInNewYork)))
    if let day = activity.day {
      DayCard(label: label, live: false, figures: DayFigures(day))
        .id(selected)
        .rise(step: Order.day.rawValue)
      panes(status: nil)
    } else {
      if let summary = activity.summary {
        DayCard(label: label, live: false, figures: DayFigures(summary))
          .id(selected)
          .rise(step: Order.day.rawValue)
      }
      switch activity.phase {
      case .failed(let cause):
        ContentUnavailableView {
          Label { Text(L10n.Activity.dayFailed) } icon: { Image(systemName: "exclamationmark.triangle") }
        } description: {
          Text(verbatim: cause)
        } actions: {
          Button {
            guard let url = model.connection.url else { return }
            Task { await activity.show(selected, from: url) }
          } label: {
            Text(L10n.Activity.retry)
          }
          .buttonStyle(.borderedProminent)
        }
        .rise()
      default:
        ProgressView { Text(L10n.Activity.loadingDay) }
          .frame(maxWidth: .infinity)
          .padding(.top, Tokens.Space.xl)
      }
    }
  }

  /// The pane picker and the chosen pane: today's when `status` is given, else the past day's.
  @ViewBuilder
  private func panes(status: StatusV1?) -> some View {
    Picker(selection: $section) {
      ForEach(Pane.allCases) { Text($0.title).tag($0) }
    } label: {
      Text(L10n.Activity.show)
    }
    .pickerStyle(.segmented)
    .rise(step: Order.picker.rawValue)
    Group {
      switch section {
      case .trades:
        if let status {
          TradesList(position: status.position, trades: status.tradesToday.map(TradeLine.init),
            empty: (L10n.Activity.noTrades, L10n.Activity.noTradesBody))
        } else {
          TradesList(position: nil, trades: activity.day?.trades.map(TradeLine.init) ?? [],
            empty: (L10n.Activity.noTradesThatDay, L10n.Activity.noTradesThatDayBody))
        }
      case .skipped:
        NotTaken()
      case .journal:
        if let status {
          Journal(events: Board.events(status))
        } else {
          ContentUnavailableView {
            Label { Text(L10n.Activity.pastJournalTitle) } icon: { Image(systemName: "list.bullet.rectangle") }
          } description: {
            Text(L10n.Activity.pastJournalBody)
          }
        }
      }
    }
    .transition(.opacity.combined(with: .move(edge: .bottom)))
    .id(section)
  }
}

/// The calendar of recorded days: one month of Monday-to-Friday weeks, each day tinted by its net
/// result. Tapping a recorded day shows it; tapping today goes back to the live view.
private struct DayPicker: View {
  let activity: ActivityModel
  let url: URL

  var body: some View {
    VStack(spacing: Tokens.Space.s) {
      header
      HStack(spacing: Tokens.Space.xs) {
        ForEach(weekdays, id: \.self) { name in
          Text(verbatim: name)
            .font(Tokens.Typography.label)
            .foregroundStyle(Palette.textQuaternary)
            .frame(maxWidth: .infinity)
        }
      }
      .accessibilityHidden(true)
      ForEach(Array(activity.weeks.enumerated()), id: \.offset) { _, week in
        HStack(spacing: Tokens.Space.xs) {
          ForEach(week.indices, id: \.self) { column in
            if let cell = week[column] {
              DayCell(cell: cell, isToday: cell.day == activity.today,
                selected: cell.day == (activity.selectedDay ?? activity.today)) {
                Task { await activity.show(cell.day, from: url) }
              }
            } else {
              Color.clear.frame(maxWidth: .infinity, minHeight: DayCell.height)
            }
          }
        }
      }
      if let failure = activity.daysFailure {
        VStack(spacing: Tokens.Space.xxs) {
          Text(L10n.Activity.daysFailed).font(Tokens.Typography.callout)
          Text(verbatim: failure).font(Tokens.Typography.annotation)
        }
        .foregroundStyle(Palette.lossText)
      }
    }
    .padding(Tokens.Space.l)
    .apertureCard()
    .animation(Tokens.Motion.standard, value: activity.month)
    .sensoryFeedback(.selection, trigger: activity.selectedDay)
  }

  private var header: some View {
    HStack(spacing: Tokens.Space.s) {
      Button {
        if let month = activity.previousMonth { activity.month = month }
      } label: {
        Image(systemName: "chevron.backward")
      }
      .disabled(activity.previousMonth == nil)
      .accessibilityLabel(Text(L10n.Activity.previousMonth))
      Spacer(minLength: 0)
      if let first = activity.month.firstDay {
        Text(first, format: .dateTime.month(.wide).year())
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(Palette.textPrimary)
          .contentTransition(.opacity)
      }
      if activity.selectedDay != nil {
        Button { activity.showToday() } label: { Text(L10n.Activity.backToToday) }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .font(Tokens.Typography.captionMono)
          .transition(.scale.combined(with: .opacity))
      }
      Spacer(minLength: 0)
      Button {
        if let month = activity.nextMonth { activity.month = month }
      } label: {
        Image(systemName: "chevron.forward")
      }
      .disabled(activity.nextMonth == nil)
      .accessibilityLabel(Text(L10n.Activity.nextMonth))
    }
    .buttonStyle(.borderless)
  }

  /// Short weekday names, Monday to Friday, in the phone's language.
  private var weekdays: [String] {
    let names = Calendar.current.shortStandaloneWeekdaySymbols
    return Array(names[(DayCalendar.monday - 1)...(DayCalendar.friday - 1)])
  }
}

/// One weekday of the calendar: its number and, when the bot recorded it, its net result.
private struct DayCell: View {
  /// Height of a day's cell, in points: a comfortable touch target.
  static let height: CGFloat = 46
  /// Smallest scale the result may shrink to before it truncates.
  static let minimumScale = 0.6

  let cell: DayCalendar.Cell
  let isToday: Bool
  let selected: Bool
  let action: () -> Void

  var body: some View {
    let result = cell.summary?.resultGrossUsd.value
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small)
    Button(action: action) {
      VStack(spacing: Tokens.Space.xxs) {
        Text(cell.day.day, format: .number)
          .font(Tokens.Typography.calloutMono.bold())
        if let result {
          Text(verbatim: Money.signed(result, fractionDigits: 0))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.result(result))
            .lineLimit(1)
            .minimumScaleFactor(Self.minimumScale)
        } else if isToday {
          PulseDot(Palette.accent, size: Tokens.Size.dotSmall)
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
        }
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .disabled(result == nil && !isToday)
    .accessibilityLabel(Text(verbatim: Format.day(cell.day.noonInNewYork)))
    .accessibilityValue(result.map { Text(verbatim: Money.signedUSD($0)) } ?? Text(L10n.Activity.noRecords))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// What a day card shows: the net result, the counts and the running total of closed trades.
private struct DayFigures: Equatable {
  let result: Decimal
  let counts: LocalizedStringResource
  let curve: [Double]

  init(result: Decimal, counts: LocalizedStringResource, curve: [Double]) {
    self.result = result
    self.counts = counts
    self.curve = curve
  }

  /// Today, live from the status.
  init(_ status: StatusV1) {
    let stats = Board.dayStats(status)
    result = stats.resultGrossUsd
    counts = L10n.Activity.counts(stats.trades, stats.wins, stats.losses, status.position == nil ? 0 : 1)
    curve = Self.curve(status.tradesToday.map { ($0.closedAt.date, $0.resultGrossUsd.value) })
  }

  /// A recorded day with its trades.
  init(_ day: DayV1) {
    let results = day.trades.map(\.resultGrossUsd.value)
    result = day.resultGrossUsd.value
    counts = L10n.Activity.pastCounts(results.count, results.filter { $0 > 0 }.count, results.filter { $0 < 0 }.count)
    curve = Self.curve(day.trades.map { ($0.closedAt.date, $0.resultGrossUsd.value) })
  }

  /// A recorded day from the calendar's summary, while its trades load.
  init(_ summary: DaySummary) {
    result = summary.resultGrossUsd.value
    counts = L10n.Activity.pastCounts(summary.trades, summary.wins, summary.losses)
    curve = Self.curve([])
  }

  /// Running total of closed trades in the order they closed, starting at zero.
  static func curve(_ closes: [(Date, Decimal)]) -> [Double] {
    var total = Decimal(0)
    var points: [Double] = [0]
    for (_, result) in closes.sorted(by: { $0.0 < $1.0 }) {
      total += result
      points.append(NSDecimalNumber(decimal: total).doubleValue)
    }
    return points
  }

  static func == (a: DayFigures, b: DayFigures) -> Bool {
    a.result == b.result && a.curve == b.curve
  }
}

private struct DayCard: View {
  /// Size of the day's result curve, in points.
  static let curveSize = CGSize(width: 120, height: 50)

  @State private var drawn = false
  let label: String
  let live: Bool
  let figures: DayFigures

  var body: some View {
    HStack(spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(spacing: Tokens.Space.s) {
          if live { PulseDot(Palette.profit, size: Tokens.Size.dotSmall) }
          Text(verbatim: label)
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        Text(verbatim: Money.signedUSD(figures.result))
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.result(figures.result))
          .contentTransition(.numericText(value: NSDecimalNumber(decimal: figures.result).doubleValue))
        Text(figures.counts)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      Spacer()
      Sparkline(figures.curve)
        .trim(from: 0, to: drawn ? 1 : 0)
        .stroke(Palette.result(figures.result),
          style: StrokeStyle(lineWidth: Tokens.Stroke.bold, lineCap: .round, lineJoin: .round))
        .frame(width: Self.curveSize.width, height: Self.curveSize.height)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard()
    .animation(Tokens.Motion.standard, value: figures)
    .onAppear { withAnimation(Tokens.Motion.draw) { drawn = true } }
    .onChange(of: figures.curve.count) { _, _ in
      // A day whose trades just arrived draws its curve again.
      drawn = false
      withAnimation(Tokens.Motion.draw) { drawn = true }
    }
  }
}

#if DEBUG
extension DayFigures {
  /// A sample past day for previews: three closed trades, two wins and a loss, net +42.50 USD.
  static let sample = DayFigures(result: 42.5, counts: L10n.Activity.pastCounts(3, 2, 1), curve: [0, 12, -4, 42.5])
}

#Preview {
  DayCard(label: String(localized: L10n.Activity.pastDay(Format.day(.now))), live: false, figures: .sample)
    .padding()
    .background(ApertureBackground())
}
#endif

/// A closed trade as a row shows it, from today's status or from a recorded day.
private struct TradeLine {
  let symbol: String
  let openedAt: Date
  let closedAt: Date
  let exitReason: String
  let quantity: String
  let entryPrice: String
  let exitPrice: String
  let result: Decimal
  /// Result in R, when the day's record carries the planned loss.
  let resultR: Decimal?

  init(_ trade: Trade) {
    symbol = trade.symbol
    openedAt = trade.openedAt.date
    closedAt = trade.closedAt.date
    exitReason = trade.exitReason
    quantity = trade.quantity.text
    entryPrice = trade.entryPrice.text
    exitPrice = trade.exitPrice.text
    result = trade.resultGrossUsd.value
    resultR = nil
  }

  init(_ trade: DayTrade) {
    symbol = trade.symbol
    openedAt = trade.openedAt.date
    closedAt = trade.closedAt.date
    exitReason = trade.exitReason
    quantity = trade.quantity.text
    entryPrice = trade.entryPrice.text
    exitPrice = trade.exitPrice.text
    result = trade.resultGrossUsd.value
    resultR = trade.resultR
  }
}

private struct TradesList: View {
  let position: Position?
  let trades: [TradeLine]
  /// Title and text shown when there is nothing to list.
  let empty: (title: LocalizedStringResource, body: LocalizedStringResource)

  var body: some View {
    let sorted = trades.sorted { $0.closedAt > $1.closedAt }
    VStack(spacing: Tokens.Space.s) {
      if let position {
        row(symbol: position.symbol, time: String(localized: L10n.Activity.openSince(Format.time(position.openedAt.date))),
          tag: String(localized: L10n.Activity.openTag),
          color: Palette.accentText,
          result: String(localized: L10n.Common.quantityAt(position.quantity.text, position.entryPrice.text)),
          detail: String(localized: L10n.Activity.stopDetail(position.stop.price?.text ?? Format.missing,
            Board.stopStateTitle(position.stop.state))))
          .rise(step: ActivityView.Order.list.rawValue)
      }
      ForEach(Array(sorted.enumerated()), id: \.offset) { index, trade in
        let detail = String(localized: L10n.Common.quantityAt(trade.quantity, trade.entryPrice))
          + Format.arrow + trade.exitPrice
        row(symbol: trade.symbol,
          time: Format.time(trade.openedAt) + Format.timeRange + Format.time(trade.closedAt),
          tag: Board.exitReasonTitle(trade.exitReason).uppercased(),
          color: Palette.result(trade.result),
          result: Money.signed(trade.result),
          detail: trade.resultR.map { detail + Format.separator + Risk.text($0) } ?? detail)
          .rise(step: ActivityView.Order.list.rawValue + index)
      }
      if trades.isEmpty && position == nil {
        ContentUnavailableView {
          Label { Text(empty.title) } icon: { Image(systemName: "clock") }
        } description: {
          Text(empty.body)
        }
      }
    }
  }

  private func row(symbol: String, time: String, tag: String, color: Color, result: String, detail: String)
    -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: symbol).font(Tokens.Typography.calloutMono.bold())
        Text(verbatim: time).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
        Spacer()
        Text(verbatim: tag)
          .font(Tokens.Typography.annotation)
          .padding(.horizontal, Tokens.Space.s)
          .padding(.vertical, Tokens.Space.xxs)
          .foregroundStyle(color)
          .background(color.opacity(Tokens.Opacity.glow), in: Capsule())
        Text(verbatim: result)
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(color)
      }
      Text(verbatim: detail)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard(radius: Tokens.Radius.card)
    .accessibilityElement(children: .combine)
  }
}

private struct NotTaken: View {
  var body: some View {
    ContentUnavailableView {
      Label { Text(L10n.Activity.notTakenTitle) } icon: { Image(systemName: "hand.raised") }
    } description: {
      Text(L10n.Activity.notTakenBody)
    }
  }
}

private struct Journal: View {
  /// Rows after this many rise in together, so a long journal does not keep animating.
  static let staggeredRows = 10
  /// Side of an event's dot, in points.
  static let dotSide: CGFloat = 7

  let events: [Board.Event]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: Format.clock(event.time))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
          Circle().fill(event.tone.color).frame(width: Self.dotSide, height: Self.dotSide)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(verbatim: event.tag).font(Tokens.Typography.annotationBold).foregroundStyle(event.tone.color)
            Text(verbatim: event.text).font(.footnote).foregroundStyle(Palette.textSecondary)
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .rise(step: ActivityView.Order.list.rawValue + min(index, Self.staggeredRows))
      }
      if events.isEmpty {
        Text(L10n.Activity.nothingYet)
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .padding(Tokens.Space.l)
      }
    }
    .padding(.vertical, Tokens.Space.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard(radius: Tokens.Radius.card)
  }
}
