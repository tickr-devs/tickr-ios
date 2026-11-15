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
        // "Today" only when the status is of today's New York session; over a weekend or after a
        // day off it is the last session, and nothing about it is live.
        let isToday = activity.sessionDay(of: status) == activity.today
        let day = Format.day(status.writtenAt.date)
        DayCard(label: String(localized: isToday ? L10n.Common.today(day) : L10n.Activity.lastSession(day)),
          live: isToday && model.response?.stale == false, figures: DayFigures(status))
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
    .task(id: skippedKey) {
      guard let url = model.connection.url, let day = skippedKey.day else { return }
      // Today's refusals keep coming without a trade closing: read them again while today shows.
      repeat {
        await activity.loadSkipped(url, day: day)
        guard activity.selectedDay == nil, day == activity.today else { return }
        try? await Task.sleep(for: .seconds(ChartModel.liveReloadSeconds))
      } while !Task.isCancelled
    }
    .task(id: sessionKey) {
      guard let url = model.connection.url, let status = model.status else { return }
      await activity.loadSession(url, of: status)
    }
    .refreshable {
      await model.refresh()
      guard let url = model.connection.url else { return }
      await activity.loadDays(url)
      if let selected = activity.selectedDay { await activity.show(selected, from: url) }
      if let day = skippedKey.day { await activity.loadSkipped(url, day: day) }
    }
  }

  /// Changes when the status's session or its closed trades change, reloading the session's
  /// record (for each trade's MAE and MFE, which the status does not carry).
  private var sessionKey: SessionKey {
    SessionKey(url: model.connection.url, day: model.status.map(activity.sessionDay(of:)),
      trades: model.status?.tradesToday.count ?? 0)
  }

  /// The day the Not taken pane lists (the chosen past day, else the status's session), with the
  /// address and the shown trade count, so a refusal recorded meanwhile is read on the next trade.
  private var skippedKey: SkippedKey {
    SkippedKey(url: model.connection.url,
      day: activity.selectedDay ?? model.status.map(activity.sessionDay(of:)),
      trades: model.status?.tradesToday.count ?? 0)
  }

  private struct SkippedKey: Hashable {
    let url: URL?
    let day: WireDate?
    let trades: Int
  }

  private struct SessionKey: Hashable {
    let url: URL?
    let day: WireDate?
    let trades: Int
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
          TradesList(positions: status.positions,
            trades: status.tradesToday.map { TradeLine($0, recorded: activity.session?.trades ?? []) },
            empty: (L10n.Activity.noTrades, L10n.Activity.noTradesBody))
        } else {
          TradesList(positions: [], trades: activity.day?.trades.map(TradeLine.init) ?? [],
            empty: (L10n.Activity.noTradesThatDay, L10n.Activity.noTradesThatDayBody))
        }
      case .skipped:
        NotTaken(groups: activity.skipped, failure: activity.skippedFailure)
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
    counts = L10n.Activity.counts(stats.trades, stats.wins, stats.losses, status.positions.count)
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

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// The result as shown: counts up from zero to the day's result when the card appears.
  @State private var shown = Decimal(0)
  let label: String
  let live: Bool
  let figures: DayFigures

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    // At accessibility text sizes the curve goes under the figures, so the result keeps the width.
    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Space.m))
      : AnyLayout(HStackLayout(spacing: Tokens.Space.m))
    layout {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(spacing: Tokens.Space.s) {
          if live { PulseDot(Palette.profit, size: Tokens.Size.dotSmall) }
          Text(verbatim: label)
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        Text(verbatim: Money.signedUSD(shown))
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.result(figures.result))
          .lineLimit(1)
          .minimumScaleFactor(StatTile.minimumScale)
          .contentTransition(.numericText(value: NSDecimalNumber(decimal: shown).doubleValue))
          .accessibilityLabel(Text(verbatim: Money.signedUSD(figures.result)))
        Text(figures.counts)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      Spacer(minLength: 0)
      // A day without closed trades has no curve; one point would draw as a lone ring.
      if figures.curve.count > 1 {
        DrawnSparkline(values: figures.curve, color: Palette.result(figures.result))
          .frame(width: Self.curveSize.width, height: Self.curveSize.height)
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard()
    .onAppear { count(to: figures.result) }
    .onChange(of: figures.result) { _, result in count(to: result) }
  }

  /// Rolls the shown result to `result`; at once when the owner asked for less motion.
  private func count(to result: Decimal) {
    if reduceMotion {
      shown = result
    } else {
      withAnimation(Tokens.Motion.fill) { shown = result }
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
  /// Result in R; nil when the planned loss is zero.
  let resultR: Decimal?
  /// Seconds from the entry fill to the broker confirming the stop, when recorded.
  let stopAfter: Decimal?
  /// Worst and best open result in USD, a lower bound (only prices proven while the shares were
  /// held), when the bars were captured.
  let mae: Decimal?
  let mfe: Decimal?

  /// A trade of today's status. MAE and MFE come from the session's record when it holds the same
  /// trade (symbol, opening and closing time); the status does not carry them.
  init(_ trade: Trade, recorded: [DayTrade]) {
    symbol = trade.symbol
    openedAt = trade.openedAt.date
    closedAt = trade.closedAt.date
    exitReason = trade.exitReason
    quantity = trade.quantity.text
    entryPrice = trade.entryPrice.text
    exitPrice = trade.exitPrice.text
    result = trade.resultGrossUsd.value
    let planned = trade.plannedLossUsd.value
    resultR = planned == 0 ? nil : trade.resultGrossUsd.value / planned
    stopAfter = trade.stopConfirmedAfterSeconds?.value
    let same = recorded.first {
      $0.symbol == trade.symbol && $0.openedAt == trade.openedAt && $0.closedAt == trade.closedAt
    }
    mae = same?.maeUsd?.value
    mfe = same?.mfeUsd?.value
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
    stopAfter = trade.stopConfirmedAfterSeconds?.value
    mae = trade.maeUsd?.value
    mfe = trade.mfeUsd?.value
  }

  /// "stop confirmed in 1.4 s · MAE −12.00 · MFE +30.00 (at least)", or nil with neither: what
  /// VoiceOver reads for the row's metric chips.
  var metrics: String? {
    var parts: [String] = []
    if let stopAfter {
      parts.append(String(localized: L10n.Activity.stopAfter(Money.plain(stopAfter, fractionDigits: 1))))
    }
    if let mae, let mfe {
      parts.append(String(localized: L10n.Activity.excursion(Money.signed(mae), Money.signed(mfe))))
    }
    return parts.isEmpty ? nil : parts.joined(separator: Format.separator)
  }
}

private struct TradesList: View {
  /// Symbols of a trade's figures.
  static let quantitySymbol = "number"
  static let entrySymbol = "arrow.right.to.line"
  static let entryExitSymbol = "arrow.right"
  static let resultRSymbol = "scalemass"
  static let stopSymbol = "checkmark.shield"
  static let maeSymbol = "arrow.down"
  static let mfeSymbol = "arrow.up"
  static let openSymbol = "circle.fill"

  /// One figure of a row: a symbol, the figure and its hint.
  struct Figure: Identifiable {
    let symbol: String
    let label: LocalizedStringResource
    let value: String
    var tone: Tone?
    var id: String { symbol }
  }

  let positions: [Position]
  let trades: [TradeLine]
  /// Title and text shown when there is nothing to list.
  let empty: (title: LocalizedStringResource, body: LocalizedStringResource)

  var body: some View {
    let sorted = trades.sorted { $0.closedAt > $1.closedAt }
    VStack(spacing: Tokens.Space.s) {
      ForEach(positions, id: \.symbol) { position in
        let state = position.stop.state
        row(symbol: position.symbol, time: String(localized: L10n.Activity.openSince(Format.time(position.openedAt.date))),
          tag: String(localized: L10n.Activity.openTag), tagSymbol: Self.openSymbol, tone: .accent,
          result: String(localized: L10n.Common.quantityAt(position.quantity.text, position.entryPrice.text)),
          figures: [
            Figure(symbol: StopGlyph.stateSymbol(state), label: L10n.Activity.hintStop,
              value: position.stop.price?.text ?? Format.missing, tone: StopGlyph.stateTone(state)),
          ],
          stopState: state)
          .rise(step: ActivityView.Order.list.rawValue)
      }
      ForEach(Array(sorted.enumerated()), id: \.offset) { index, trade in
        row(symbol: trade.symbol,
          time: Format.time(trade.openedAt) + Format.timeRange + Format.time(trade.closedAt),
          tag: Board.exitReasonTitle(trade.exitReason).uppercased(),
          tagSymbol: Board.exitReasonSymbol(trade.exitReason),
          tone: Tone.result(trade.result),
          result: Money.signed(trade.result),
          figures: figures(trade), metrics: metrics(trade), metricsText: trade.metrics)
          .rise(step: ActivityView.Order.list.rawValue + index)
      }
      if trades.isEmpty && positions.isEmpty {
        ContentUnavailableView {
          Label { Text(empty.title) } icon: { BrandMark.empty() }
        } description: {
          Text(empty.body)
        }
      }
    }
  }

  /// Quantity, entry to exit, and the result in R.
  private func figures(_ trade: TradeLine) -> [Figure] {
    var list = [
      Figure(symbol: Self.quantitySymbol, label: L10n.Activity.hintQuantity, value: trade.quantity),
      Figure(symbol: Self.entryExitSymbol, label: L10n.Activity.hintEntryExit,
        value: trade.entryPrice + Format.arrow + trade.exitPrice),
    ]
    if let r = trade.resultR {
      list.append(Figure(symbol: Self.resultRSymbol, label: L10n.Activity.hintResultR, value: Risk.text(r),
        tone: Tone.result(trade.result)))
    }
    return list
  }

  /// Seconds to the confirmed stop, MAE and MFE, when recorded.
  private func metrics(_ trade: TradeLine) -> [Figure] {
    var list: [Figure] = []
    if let after = trade.stopAfter {
      list.append(Figure(symbol: Self.stopSymbol, label: L10n.Activity.hintStopAfter,
        value: String(localized: L10n.Risk.seconds(Money.plain(after, fractionDigits: 1))), tone: .profit))
    }
    if let mae = trade.mae, let mfe = trade.mfe {
      list.append(Figure(symbol: Self.maeSymbol, label: L10n.Activity.hintMae, value: Money.signed(mae), tone: .loss))
      list.append(Figure(symbol: Self.mfeSymbol, label: L10n.Activity.hintMfe, value: Money.signed(mfe), tone: .profit))
    }
    return list
  }

  private func headerText(_ symbol: String) -> some View {
    Text(verbatim: symbol)
      .font(Tokens.Typography.calloutMono.bold())
      .lineLimit(1)
      .minimumScaleFactor(StatTile.minimumScale)
  }

  private func timeText(_ time: String) -> some View {
    Text(verbatim: time)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .lineLimit(1)
      .minimumScaleFactor(StatTile.minimumScale)
  }

  private func resultText(_ result: String, tone: Tone) -> some View {
    Text(verbatim: result)
      .font(Tokens.Typography.calloutMono.bold())
      .foregroundStyle(tone.text)
      .lineLimit(1)
      .minimumScaleFactor(StatTile.minimumScale)
  }

  private func row(symbol: String, time: String, tag: String, tagSymbol: String, tone: Tone, result: String,
    figures: [Figure], metrics: [Figure] = [], metricsText: String? = nil, stopState: StopState? = nil) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // One line while it fits; at large text sizes the symbol and result keep a line of their own
      // and the time and tag wrap below, so no figure breaks in the middle or falls into letters.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.s) {
          headerText(symbol)
          timeText(time)
          Spacer(minLength: Tokens.Space.s)
          StatusPill(verbatim: tag, systemImage: tagSymbol, tone: tone)
          resultText(result, tone: tone)
        }
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack(spacing: Tokens.Space.s) {
            headerText(symbol)
            Spacer(minLength: Tokens.Space.s)
            resultText(result, tone: tone)
          }
          ChipFlow {
            timeText(time)
            StatusPill(verbatim: tag, systemImage: tagSymbol, tone: tone)
          }
        }
      }
      ChipFlow {
        chipViews(figures)
        // An open position's stop state in words, so pending, missing and unknown never look alike.
        if let stopState {
          StatusPill(verbatim: Board.stopStateTitle(stopState), systemImage: StopGlyph.stateSymbol(stopState),
            tone: StopGlyph.stateTone(stopState))
            .hint(L10n.Activity.hintStop)
        }
      }
      if !metrics.isEmpty {
        // VoiceOver reads the sentence ("stop confirmed in 1.4 s · MAE … (at least)").
        chips(metrics)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Text(verbatim: metricsText ?? ""))
      }
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard(radius: Tokens.Radius.card)
    .accessibilityElement(children: .combine)
  }

  /// A row of figure chips that wraps on a narrow screen.
  private func chips(_ figures: [Figure]) -> some View {
    ChipFlow { chipViews(figures) }
  }

  private func chipViews(_ figures: [Figure]) -> some View {
    ForEach(figures) { figure in
      IconMetric(figure.symbol, label: figure.label, value: figure.value, tone: figure.tone,
        color: figure.tone?.text, compact: true)
    }
  }
}

/// The active strategy's entries the bot did not take that day (GET /skipped): refused at
/// admission, with the single recorded cause, or made too late to act on; each with the what-if
/// entry and stop the strategy recorded. Repeats on one symbol for one reason are one row.
private struct NotTaken: View {
  let groups: [SkippedGroup]?
  let failure: String?

  var body: some View {
    if let groups {
      // A failed refresh after a good read: the rows stay, marked as the last read.
      if let failure {
        Text(L10n.Activity.notTakenStale(failure))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.warningText)
      }
      if groups.isEmpty {
        ContentUnavailableView {
          Label { Text(L10n.Activity.notTakenTitle) } icon: { Image(systemName: "hand.raised") }
        } description: {
          Text(L10n.Activity.notTakenNone)
        }
      }
      VStack(spacing: Tokens.Space.s) {
        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
          SkippedRow(group: group)
            .rise(step: ActivityView.Order.list.rawValue + index)
        }
      }
    } else if let failure {
      ContentUnavailableView {
        Label { Text(L10n.Activity.notTakenFailed) } icon: { Image(systemName: "exclamationmark.triangle") }
      } description: {
        Text(verbatim: failure)
      }
    } else {
      ProgressView().frame(maxWidth: .infinity).padding(.top, Tokens.Space.xl)
    }
  }
}

private struct SkippedRow: View {
  /// Symbols of a refusal, a signal made too late, and the time.
  static let refusedSymbol = "hand.raised.fill"
  static let tooLateSymbol = "hourglass"
  static let whenSymbol = "clock"

  let group: SkippedGroup

  private var refused: Bool { group.latest.admission == .refused }

  /// "16:27" or, for repeats, "16:27–16:29 · ×3".
  private var when: String {
    let first = Format.time(group.first.at.date)
    guard group.count > 1 else { return first }
    return first + Format.timeRange + Format.time(group.latest.at.date) + Format.separator
      + String(localized: L10n.Activity.repeats(group.count))
  }

  private func symbolText(_ symbol: String) -> some View {
    Text(verbatim: symbol)
      .font(Tokens.Typography.bodyMono.bold())
      .foregroundStyle(Palette.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(StatTile.minimumScale)
  }

  private var tagPill: some View {
    StatusPill(refused ? L10n.Activity.refusedTag : L10n.Activity.tooLateTag,
      systemImage: refused ? Self.refusedSymbol : Self.tooLateSymbol, tone: refused ? .warning : .neutral)
  }

  private var whenLabel: some View {
    Label { Text(verbatim: when) } icon: { Image(systemName: Self.whenSymbol) }
      .labelStyle(ControlLabelStyle())
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textTertiary)
      .lineLimit(1)
      .minimumScaleFactor(StatTile.minimumScale)
      .hint(L10n.Activity.hintWhen)
  }

  var body: some View {
    let signal = group.latest
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      // One line while it fits, else the symbol, tag and time wrap as chips.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          symbolText(signal.symbol)
          tagPill
          Spacer(minLength: Tokens.Space.s)
          whenLabel
        }
        ChipFlow {
          symbolText(signal.symbol)
          tagPill
          whenLabel
        }
      }
      if let cause = group.cause {
        CauseText(cause: cause)
      }
      ChipFlow {
        Badge(L10n.Activity.whatIfTag, tone: .highlight)
        IconMetric(TradesList.entrySymbol, label: L10n.Activity.hintWhatIfEntry,
          value: signal.entryPrice.map { Money.price($0.value) } ?? Format.missing, compact: true)
        IconMetric(TradesList.stopSymbol, label: L10n.Activity.hintWhatIfStop,
          value: signal.stopPrice.map { Money.price($0.value) } ?? Format.missing, compact: true)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Activity.whatIf(signal.entryPrice.map { Money.price($0.value) } ?? Format.missing,
        signal.stopPrice.map { Money.price($0.value) } ?? Format.missing)))
      ReplayLine(whatIf: signal.whatIf)
      AfterLine(prices: signal.pricesAfter)
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
    .accessibilityElement(children: .combine)
  }
}

/// Where the price went after a signal, per share: "after 1m +0.12 · 5m −0.30 · 15m —". Each
/// change in its direction's colour; a minute with no captured bar shows a dash. Nothing when the
/// bot sent no prices.
private struct AfterLine: View {
  let prices: [PriceAfterV1]

  private var line: AttributedString {
    var text = AttributedString(String(localized: L10n.Activity.after))
    text.swiftUI.foregroundColor = Palette.textQuaternary
    for (index, point) in prices.enumerated() {
      let lead = (index == 0 ? ChartFormat.space : Format.separator)
        + String(localized: L10n.Activity.minutesAfter(point.minutes)) + ChartFormat.space
      var label = AttributedString(lead)
      label.swiftUI.foregroundColor = Palette.textQuaternary
      let change = point.changeUsd?.value
      var value = AttributedString(change.map { Money.signed($0) } ?? Format.missing)
      value.swiftUI.foregroundColor = change.map(Palette.result) ?? Palette.textQuaternary
      text += label + value
    }
    return text
  }

  var body: some View {
    if !prices.isEmpty {
      Text(line)
        .font(Tokens.Typography.captionMono)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// What the bot's replay says a skipped signal would have made, with R and how the replay ended;
/// or why it could not replay. Figures are shown as the bot sent them.
private struct ReplayLine: View {
  let whatIf: WhatIfV1

  private var ending: LocalizedStringResource? {
    switch whatIf.exitReason {
    case .stop: L10n.Activity.replayStop
    case .strategyExit: L10n.Activity.replayStrategyExit
    case .flatten: L10n.Activity.replayFlatten
    case .endOfData: L10n.Activity.replayEndOfData
    case nil: nil
    }
  }

  /// "would have made +$12.30" in the result's colour (neutral at zero), then R and the ending.
  private func line(_ result: Decimal) -> AttributedString {
    var text = AttributedString(localized: L10n.Activity.wouldHaveMade(Money.signedUSD(result)))
    text.swiftUI.foregroundColor = Palette.result(result)
    var rest = whatIf.resultR.map { Format.separator + Risk.text($0.value) } ?? ""
    if let ending { rest += Format.separator + String(localized: ending) }
    var tail = AttributedString(rest)
    tail.swiftUI.foregroundColor = Palette.textTertiary
    return text + tail
  }

  var body: some View {
    if let result = whatIf.resultGrossUsd?.value {
      // One text, so it wraps as a whole at large Dynamic Type instead of clipping a row of parts.
      Text(line(result))
        .font(Tokens.Typography.captionMono)
        .fixedSize(horizontal: false, vertical: true)
    } else if let cause = whatIf.cause {
      Text(L10n.Activity.noReplay(cause))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textQuaternary)
    }
  }
}

/// A refusal in words: what the rule is, then the bot's detail with its times in New York.
private struct CauseText: View {
  let cause: RefusalCause

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      if let code = cause.known {
        Text(L10n.Cause.title(code))
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
      }
      Group {
        if let cooldown = cause.cooldown {
          Text(L10n.Cause.cooldownDetail(Format.time(cooldown.loss), Format.time(cooldown.until)))
        } else if cause.known == nil {
          // A cause this app has no words for: the bot's own text, times made readable.
          Text(verbatim: cause.detail.isEmpty ? cause.code
            : cause.code + RefusalCause.separator + cause.readable(time: Format.time))
        } else if let phrase = cause.phrase {
          // The detail in the person's language, from the refusal's code and values.
          Text(verbatim: phrase)
        } else if !cause.detail.isEmpty {
          Text(verbatim: cause.readable(time: Format.time))
        }
        // A refusal that ends at a known time (sent structured) says when entries may resume.
        if cause.cooldown == nil, let until = cause.until {
          Text(L10n.Cause.until(Format.time(until)))
        }
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .fixedSize(horizontal: false, vertical: true)
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
