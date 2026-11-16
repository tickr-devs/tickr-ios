import SwiftUI
import TickrDesign
import TickrKit

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
  /// The open positions' marks (last price, R), as on Positions.
  @State private var prices = Container.shared.positionsModel()
  @State private var section: Pane = .trades
  @State private var showsCalendar = false
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Screen(L10n.App.activity, tab: .activity) {
      Button {
        showsCalendar.toggle()
      } label: {
        // Open, the calendar's button sits on a wash, as a selected chip.
        HeaderIcon(.calendar, selected: showsCalendar)
          .foregroundStyle(Palette.textPrimary)
      }
      .accessibilityLabel(Text(L10n.Activity.calendar))
      .accessibilityIdentifier(AccessibilityID.calendar)
    } content: {
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
    .task(id: followKey) {
      guard let url = model.connection.url, let status = model.status, !status.positions.isEmpty else { return }
      await prices.follow(url, status: status)
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

  /// Changes when the address, the session or the open positions change, restarting the reads.
  private var followKey: FollowKey {
    FollowKey(url: model.connection.url, day: model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date) },
      positions: model.status?.positions ?? [])
  }

  private struct FollowKey: Hashable {
    let url: URL?
    let day: WireDate?
    let positions: [Position]
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
    paneControl
      .rise(step: Order.picker.rawValue)
    Group {
      switch section {
      case .trades:
        if let status {
          TradesList(activity: activity, url: model.connection.url, positions: status.positions,
            marks: prices.marks.filter { model.isCurrent($0.value) },
            trades: status.tradesToday.map { TradeLine($0, recorded: activity.session?.trades ?? []) },
            empty: (L10n.Activity.noTrades, L10n.Activity.noTradesBody))
        } else {
          TradesList(activity: activity, url: model.connection.url, positions: [],
            trades: activity.day?.trades.map(TradeLine.init) ?? [],
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

extension ActivityView {
  /// The pane control as on the design: three segments on a card, the chosen one raised; at
  /// accessibility sizes a menu of the panes, whose button grows with the text.
  @ViewBuilder fileprivate var paneControl: some View {
    if dynamicTypeSize.isAccessibilitySize {
      Picker(selection: $section) {
        ForEach(Pane.allCases) { Text($0.title).tag($0) }
      } label: {
        Text(L10n.Activity.show)
      }
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      SegmentChips(options: Pane.allCases.map { ($0, Text($0.title)) }, selection: $section, style: .raised,
        identifier: AccessibilityID.activitySection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.Activity.show))
    }
  }
}

/// The calendar of recorded days: one month of Monday-to-Friday weeks, each day tinted by its net
/// result. Tapping a recorded day shows it; tapping today goes back to the live view.
private struct DayPicker: View {
  /// Lines the month and year may take in the header ("Ноябрь 2026 г." at large text sizes).
  static let monthLines = 2

  let activity: ActivityModel
  let url: URL

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(AppModel.self) private var model

  /// Today's live dot pulses once when today's trading changes: a trade closed, a position opened
  /// or closed (the status's counts); still in between.
  private var todayEvent: AnyHashable? {
    guard let status = model.status else { return nil }
    return AnyHashable([status.tradesToday.count, status.positions.count])
  }

  var body: some View {
    VStack(spacing: Tokens.Space.s) {
      header
      if activity.selectedDay != nil && dynamicTypeSize.isAccessibilitySize {
        backToToday
      }
      HStack(spacing: dynamicTypeSize.isAccessibilitySize ? Tokens.Space.s : Tokens.Space.xs) {
        ForEach(weekdays, id: \.self) { name in
          Text(verbatim: name)
            .font(Tokens.Typography.label)
            .foregroundStyle(Palette.textQuaternary)
            .lineLimit(1)
            .minimumScaleFactor(Tokens.Shrink.most)
            .frame(maxWidth: .infinity)
        }
      }
      .accessibilityHidden(true)
      // A new month assembles cell by cell (the board's per-cell fade-up, `Motion.cellStagger` apart).
      VStack(spacing: Tokens.Space.s) {
        ForEach(Array(activity.weeks.enumerated()), id: \.offset) { row, week in
          // Wider gaps at accessibility sizes, where the day numbers fill their cells.
          HStack(spacing: dynamicTypeSize.isAccessibilitySize ? Tokens.Space.s : Tokens.Space.xs) {
            ForEach(week.indices, id: \.self) { column in
              if let cell = week[column] {
                DayCell(cell: cell, isToday: cell.day == activity.today,
                  selected: cell.day == (activity.selectedDay ?? activity.today), todayEvent: todayEvent) {
                  Task { await activity.show(cell.day, from: url) }
                }
                .rise(Double(row * week.count + column) * Tokens.Motion.cellStagger)
              } else {
                Color.clear.frame(maxWidth: .infinity, minHeight: DayCell.height)
              }
            }
          }
        }
      }
      .id(activity.month)
      if let failure = activity.daysFailure {
        ReadFailureNote(L10n.Activity.daysFailed, detail: failure)
      }
    }
    .padding(Tokens.Space.l)
    .tickrCard()
    .animation(Tokens.Motion.standard, value: activity.month)
    .sensoryFeedback(.selection, trigger: activity.selectedDay)
  }

  private var header: some View {
    // The month arrows only with another month to step to; the one that leads nowhere is dimmed.
    let steps = activity.previousMonth != nil || activity.nextMonth != nil
    return HStack(spacing: Tokens.Space.s) {
      if steps {
        Button {
          if let month = activity.previousMonth { activity.month = month }
        } label: {
          HeaderIcon(symbol: "chevron.backward", glass: false)
        }
        .disabled(activity.previousMonth == nil)
        .accessibilityLabel(Text(L10n.Activity.previousMonth))
      }
      Spacer(minLength: 0)
      if let first = activity.month.firstDay {
        Text(first, format: .dateTime.month(.wide).year())
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(Palette.textPrimary)
          // The month and year wrap to a second line before they shrink or get cut.
          .lineLimit(Self.monthLines)
          .multilineTextAlignment(.center)
          .minimumScaleFactor(Tokens.Shrink.standard)
          .contentTransition(.opacity)
      }
      // At accessibility sizes the button takes its own row under the month.
      if activity.selectedDay != nil && !dynamicTypeSize.isAccessibilitySize {
        backToToday
      }
      Spacer(minLength: 0)
      if steps {
        Button {
          if let month = activity.nextMonth { activity.month = month }
        } label: {
          HeaderIcon(symbol: "chevron.forward", glass: false)
        }
        .disabled(activity.nextMonth == nil)
        .accessibilityLabel(Text(L10n.Activity.nextMonth))
      }
    }
    .buttonStyle(.borderless)
  }

  private var backToToday: some View {
    Button { activity.showToday() } label: { Text(L10n.Activity.backToToday) }
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
      .font(Tokens.Typography.captionMono)
      .transition(.scale.combined(with: .opacity))
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

  let cell: DayCalendar.Cell
  let isToday: Bool
  let selected: Bool
  /// Today's real change (see `DayPicker.todayEvent`): one pulse of today's dot per change.
  let todayEvent: AnyHashable?
  let action: () -> Void

  var body: some View {
    let result = cell.summary?.resultGrossUsd.value
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small)
    Button(action: action) {
      VStack(spacing: Tokens.Space.xxs) {
        Text(cell.day.day, format: .number)
          .font(Tokens.Typography.calloutMono.bold())
          .lineLimit(1)
          .minimumScaleFactor(Tokens.Shrink.most)
          // Inset from the cell's edges, so neighbouring day numbers never touch.
          .padding(.horizontal, Tokens.Space.xxs)
        if let result {
          Text(verbatim: Money.signed(result, fractionDigits: 0))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.result(result))
            .lineLimit(1)
            .minimumScaleFactor(Tokens.Shrink.tight)
        } else if isToday {
          PulseDot(Palette.accent, size: Tokens.Size.dotSmall, event: todayEvent)
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
  /// The day's trades counted for the chips under the result; `open` only for today.
  struct Tally: Hashable {
    let closed: Int
    let wins: Int
    let losses: Int
    var open: Int?
  }

  let result: Decimal
  let counts: LocalizedStringResource
  let tally: Tally
  let curve: [Double]

  init(result: Decimal, counts: LocalizedStringResource, tally: Tally, curve: [Double]) {
    self.result = result
    self.counts = counts
    self.tally = tally
    self.curve = curve
  }

  /// Today, live from the status.
  init(_ status: StatusV1) {
    let stats = Board.dayStats(status)
    result = stats.resultGrossUsd
    counts = L10n.Activity.counts(stats.trades, stats.wins, stats.losses, status.positions.count)
    tally = Tally(closed: stats.trades, wins: stats.wins, losses: stats.losses, open: status.positions.count)
    curve = Self.curve(status.tradesToday.map { ($0.closedAt.date, $0.resultGrossUsd.value) })
  }

  /// A recorded day with its trades.
  init(_ day: DayV1) {
    let results = day.trades.map(\.resultGrossUsd.value)
    result = day.resultGrossUsd.value
    counts = L10n.Activity.pastCounts(results.count, results.filter { $0 > 0 }.count, results.filter { $0 < 0 }.count)
    tally = Tally(closed: results.count, wins: results.filter { $0 > 0 }.count, losses: results.filter { $0 < 0 }.count)
    curve = Self.curve(day.trades.map { ($0.closedAt.date, $0.resultGrossUsd.value) })
  }

  /// A recorded day from the calendar's summary, while its trades load.
  init(_ summary: DaySummary) {
    result = summary.resultGrossUsd.value
    counts = L10n.Activity.pastCounts(summary.trades, summary.wins, summary.losses)
    tally = Tally(closed: summary.trades, wins: summary.wins, losses: summary.losses)
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
    a.result == b.result && a.curve == b.curve && a.tally == b.tally
  }
}

private struct DayCard: View {
  /// Size of the day's result curve, in points.
  static let curveSize = CGSize(width: 120, height: 50)
  /// Symbols of the day's chips: closed trades, wins, losses, open positions.
  static let closedSymbol = "checkmark"
  static let winsSymbol = "arrow.up"
  static let lossesSymbol = "arrow.down"
  static let openSymbol = "circle"

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
          // One pulse per real change of the day's tally (a trade closed, a position opened).
          if live { PulseDot(Palette.profit, size: Tokens.Size.dotSmall, event: figures.tally) }
          Text(verbatim: label)
        }
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
        Text(verbatim: Money.signedUSD(shown))
          .font(.title.monospaced().bold())
          .foregroundStyle(Palette.result(figures.result))
          .lineLimit(1)
          .minimumScaleFactor(Tokens.Shrink.standard)
          .contentTransition(.numericText(value: NSDecimalNumber(decimal: shown).doubleValue))
          .accessibilityLabel(Text(verbatim: Money.signedUSD(figures.result)))
        // As on the design: the day's counts as chips; VoiceOver reads the sentence.
        ChipFlow {
          IconMetric(Self.closedSymbol, label: L10n.Activity.hintClosed, value: String(figures.tally.closed),
            compact: true)
          IconMetric(Self.winsSymbol, label: L10n.Activity.hintWins,
            value: String(localized: L10n.Activity.chipWins(figures.tally.wins)), tone: .profit,
            color: Tone.profit.text, compact: true)
          IconMetric(Self.lossesSymbol, label: L10n.Activity.hintLosses,
            value: String(localized: L10n.Activity.chipLosses(figures.tally.losses)), tone: .loss,
            color: Tone.loss.text, compact: true)
          if let open = figures.tally.open, open > 0 {
            IconMetric(Self.openSymbol, label: L10n.Activity.hintOpen,
              value: String(localized: L10n.Activity.chipOpen(open)), tone: .accent, color: Tone.accent.text,
              compact: true)
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(figures.counts))
      }
      Spacer(minLength: 0)
      // A day without closed trades has no curve; one point would draw as a lone ring.
      if figures.curve.count > 1 {
        DrawnSparkline(values: figures.curve, color: figures.result < 0 ? Palette.loss : Palette.accent)
          .frame(width: Self.curveSize.width, height: Self.curveSize.height)
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .tickrCard()
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
  static let sampleTally = Tally(closed: 3, wins: 2, losses: 1)
  static let sampleCurve: [Double] = [0, 12, -4, 42.5]
  static let sample = DayFigures(result: 42.5, counts: L10n.Activity.pastCounts(3, 2, 1), tally: sampleTally,
    curve: sampleCurve)
}

#Preview {
  DayCard(label: String(localized: L10n.Activity.pastDay(Format.day(.now))), live: false, figures: .sample)
    .padding()
    .background(TickrBackground())
}
#endif

/// A closed trade as a row shows it, from today's status or from a recorded day.
private struct TradeLine: Identifiable {
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
  /// Prices at set minutes after the exit, when the bot computed them.
  let pricesAfter: [PriceAfterV1]
  /// The bot code version (short git commit) of the run that opened the trade, when recorded.
  let codeVersion: String?

  /// A trade of today's status. MAE and MFE come from the session's record when it holds the same
  /// trade (symbol, opening and closing time); the status does not carry them.
  init(_ trade: Trade, recorded: [DayTrade]) {
    symbol = trade.symbol
    openedAt = trade.openedAt.date
    closedAt = trade.closedAt.date
    exitReason = trade.exitReason
    quantity = trade.quantity.text
    entryPrice = Money.price(trade.entryPrice.value)
    exitPrice = Money.price(trade.exitPrice.value)
    result = trade.resultGrossUsd.value
    let planned = trade.plannedLossUsd.value
    resultR = planned == 0 ? nil : trade.resultGrossUsd.value / planned
    stopAfter = trade.stopConfirmedAfterSeconds?.value
    let same = recorded.first {
      $0.symbol == trade.symbol && $0.openedAt == trade.openedAt && $0.closedAt == trade.closedAt
    }
    mae = same?.maeUsd?.value
    mfe = same?.mfeUsd?.value
    pricesAfter = same?.pricesAfter ?? []
    codeVersion = trade.codeVersion.map(CodeVersion.short)
  }

  init(_ trade: DayTrade) {
    symbol = trade.symbol
    openedAt = trade.openedAt.date
    closedAt = trade.closedAt.date
    exitReason = trade.exitReason
    quantity = trade.quantity.text
    entryPrice = Money.price(trade.entryPrice.value)
    exitPrice = Money.price(trade.exitPrice.value)
    result = trade.resultGrossUsd.value
    resultR = trade.resultR
    stopAfter = trade.stopConfirmedAfterSeconds?.value
    mae = trade.maeUsd?.value
    mfe = trade.mfeUsd?.value
    pricesAfter = trade.pricesAfter
    codeVersion = trade.codeVersion.map(CodeVersion.short)
  }

  /// One trade per symbol and opening time.
  var id: String { symbol + Format.separator + openedAt.formatted(.iso8601) }
  /// The New York day the trade opened, which the what-if replays.
  var day: WireDate { WireDate(newYorkDateOf: openedAt) }

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
    if let codeVersion {
      parts.append(String(localized: L10n.Activity.codeVersion(codeVersion)))
    }
    return parts.isEmpty ? nil : parts.joined(separator: Format.separator)
  }
}

private struct TradesList: View {
  /// Symbols of a trade's figures.
  static let quantitySymbol = "number"
  static let entrySymbol = "arrow.right.to.line"
  static let entryExitSymbol = "arrow.right"
  static let resultUpSymbol = "chart.line.uptrend.xyaxis"
  static let resultDownSymbol = "chart.line.downtrend.xyaxis"
  static let lastSymbol = "chart.bar"
  static let sendsSymbol = "paperplane"
  static let timeSymbol = "clock"
  static let stopSymbol = "checkmark.shield"
  static let maeSymbol = "arrow.down"
  static let mfeSymbol = "arrow.up"
  static let codeSymbol = "chevron.left.forwardslash.chevron.right"
  static let openSymbol = "circle"
  /// Symbol of a closed trade's "Another strategy" button.
  static let anotherSymbol = "arrow.triangle.branch"

  /// One figure of a row: a symbol, the figure and its hint.
  struct Figure: Identifiable {
    let symbol: String
    let label: LocalizedStringResource
    let value: String
    var tone: Tone?
    var id: String { symbol }
  }

  let activity: ActivityModel
  let url: URL?
  let positions: [Position]
  /// Current marks of the open positions, by symbol.
  var marks: [String: PositionMarks] = [:]
  let trades: [TradeLine]
  /// Title and text shown when there is nothing to list.
  let empty: (title: LocalizedStringResource, body: LocalizedStringResource)

  /// The closed trade whose "Another strategy" sheet is open.
  @State private var another: TradeLine?

  var body: some View {
    let sorted = trades.sorted { $0.closedAt > $1.closedAt }
    VStack(spacing: Tokens.Space.s) {
      ForEach(positions, id: \.symbol) { position in
        let state = position.stop.state
        // As on the design: no time beside the symbol (the fill time is a chip below), and a verified
        // stop said in the tag.
        row(symbol: position.symbol, time: nil,
          tag: String(localized: state == .verified ? L10n.Activity.openVerifiedTag : L10n.Activity.openTag),
          tagSymbol: Self.openSymbol, tone: .accent,
          result: String(localized: L10n.Common.quantityAt(position.quantity.text, Money.price(position.entryPrice.value))),
          figures: openFigures(position), stopState: state.isProtected ? nil : state, open: true)
          .rise(step: ActivityView.Order.list.rawValue)
      }
      ForEach(Array(sorted.enumerated()), id: \.offset) { index, trade in
        row(symbol: trade.symbol,
          time: Format.time(trade.openedAt) + Format.timeRange + Format.time(trade.closedAt),
          tag: Board.exitReasonTitle(trade.exitReason).uppercased(),
          tagSymbol: Board.exitReasonSymbol(trade.exitReason),
          tone: Tone.result(trade.result),
          result: Money.signed(trade.result),
          figures: figures(trade), metrics: metrics(trade), metricsText: trade.metrics, after: trade.pricesAfter,
          another: url == nil ? nil : trade)
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
    .sheet(item: $another) { trade in
      if let url {
        AnotherStrategySheet(activity: activity, url: url, symbol: trade.symbol, day: trade.day,
          botR: trade.resultR, botUsd: trade.result)
      }
    }
  }

  /// The button that opens "Another strategy" on a closed trade.
  private func anotherButton(_ trade: TradeLine) -> some View {
    Button {
      another = trade
    } label: {
      Image(systemName: Self.anotherSymbol)
        .foregroundStyle(Tone.highlight.text)
    }
    .buttonStyle(.borderless)
    // The row is one VoiceOver element and offers this as its named action instead.
    .accessibilityHidden(true)
  }

  /// An open position as on the design: last price and R while current, entry sends, stop, time
  /// of the fill and quantity.
  private func openFigures(_ position: Position) -> [Figure] {
    let state = position.stop.state
    var list: [Figure] = []
    if let marks = marks[position.symbol] {
      list.append(Figure(symbol: Self.lastSymbol, label: L10n.Activity.hintLast, value: Money.price(marks.last)))
      if let r = marks.resultR {
        list.append(Figure(symbol: r < 0 ? Self.resultDownSymbol : Self.resultUpSymbol, label: L10n.Activity.hintResultR,
          value: Risk.text(r), tone: Tone.result(marks.unrealized)))
      }
    }
    if let sends = position.entry.sends {
      list.append(Figure(symbol: Self.sendsSymbol, label: L10n.Activity.hintSends,
        value: String(localized: L10n.Activity.sends(sends)), tone: sends == 1 ? nil : .loss))
    }
    list.append(Figure(symbol: StopGlyph.stateSymbol(state), label: L10n.Activity.hintStop,
      value: position.stop.price.map { Money.price($0.value) } ?? Format.missing, tone: StopGlyph.stateTone(state)))
    list.append(Figure(symbol: Self.timeSymbol, label: L10n.Activity.hintOpened,
      value: Format.time((position.entry.filledAt ?? position.openedAt).date)))
    list.append(Figure(symbol: Self.quantitySymbol, label: L10n.Activity.hintQuantity, value: position.quantity.text))
    return list
  }

  /// Quantity, entry to exit, and the result in R.
  private func figures(_ trade: TradeLine) -> [Figure] {
    var list = [
      Figure(symbol: Self.quantitySymbol, label: L10n.Activity.hintQuantity, value: trade.quantity),
      Figure(symbol: Self.entryExitSymbol, label: L10n.Activity.hintEntryExit,
        value: trade.entryPrice + Format.arrow + trade.exitPrice),
    ]
    if let r = trade.resultR {
      list.append(Figure(symbol: r < 0 ? Self.resultDownSymbol : Self.resultUpSymbol, label: L10n.Activity.hintResultR,
        value: Risk.text(r),
        tone: Tone.result(trade.result)))
    }
    return list
  }

  /// Seconds to the confirmed stop, MAE and MFE, and the code version, when recorded.
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
    if let code = trade.codeVersion {
      list.append(Figure(symbol: Self.codeSymbol, label: L10n.Activity.hintCodeVersion, value: code))
    }
    return list
  }

  private func headerText(_ symbol: String) -> some View {
    Text(verbatim: symbol)
      .font(Tokens.Typography.calloutMono.bold())
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  private func timeText(_ time: String) -> some View {
    Text(verbatim: time)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  private func resultText(_ result: String, tone: Tone) -> some View {
    Text(verbatim: result)
      .font(Tokens.Typography.calloutMono.bold())
      .foregroundStyle(tone.text)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  private func row(
    symbol: String, time: String?, tag: String, tagSymbol: String, tone: Tone, result: String,
    figures: [Figure], metrics: [Figure] = [], metricsText: String? = nil, stopState: StopState? = nil,
    open: Bool = false, after: [PriceAfterV1] = [], another: TradeLine? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      // One line while it fits; at large text sizes the symbol and result keep a line of their own
      // and the time and tag wrap below, so no figure breaks in the middle or falls into letters.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.s) {
          headerText(symbol)
          if let time { timeText(time) }
          Spacer(minLength: Tokens.Space.s)
          StatusPill(verbatim: tag, systemImage: tagSymbol, tone: tone)
          resultText(result, tone: tone)
          if let another { anotherButton(another) }
        }
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack(spacing: Tokens.Space.s) {
            headerText(symbol)
            Spacer(minLength: Tokens.Space.s)
            resultText(result, tone: tone)
            if let another { anotherButton(another) }
          }
          ChipFlow {
            if let time { timeText(time) }
            StatusPill(verbatim: tag, systemImage: tagSymbol, tone: tone)
          }
        }
        // The largest sizes: the result ("53 @ 24.69") gets a line of its own too.
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack(spacing: Tokens.Space.s) {
            headerText(symbol)
            Spacer(minLength: Tokens.Space.s)
            if let another { anotherButton(another) }
          }
          resultText(result, tone: tone)
          ChipFlow {
            if let time { timeText(time) }
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
      // Where the price went after the exit, per share.
      AfterLine(prices: after)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.m)
    // An open position's card is washed in `info`, as on the design.
    .background {
      if open {
        RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
          .fill(Palette.info.opacity(Tokens.Opacity.wash))
      }
    }
    .tickrCard(radius: Tokens.Radius.card, tint: open ? Palette.info : nil)
    .accessibilityElement(children: .combine)
    .accessibilityActions {
      if let another {
        Button {
          self.another = another
        } label: {
          Text(L10n.Activity.anotherHelp)
        }
      }
    }
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
  /// Rows a new read brought while the list was on screen: each flashes once.
  @State private var arrived: Set<String> = []

  var body: some View {
    if let groups {
      // A failed refresh after a good read: the rows stay, marked as the last read.
      if let failure {
        ReadFailureNote(L10n.Activity.notTakenStale, detail: failure)
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
          // A genuinely new refusal tints its row once (the board flashes the newest row).
          SkippedRow(group: group, arrived: arrived.contains(group.id))
            .rise(step: ActivityView.Order.list.rawValue + index)
        }
      }
      .onArrival(of: groups.map(\.id)) { arrived = $0 }
    } else if let failure {
      ReadFailureNote(L10n.Activity.notTakenFailed, detail: failure)
        .frame(maxWidth: .infinity, alignment: .leading)
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
  /// Whether the row just arrived with a new read: it tints once.
  var arrived = false

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
      .minimumScaleFactor(Tokens.Shrink.standard)
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
      // It may wrap (between words) rather than lose the repeat count at its end.
      .fixedSize(horizontal: false, vertical: true)
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
    // Inside the card, inset from its rounded edge.
    .arrivalFlash(arrived, color: Palette.info, outset: EdgeInsets(top: -Tokens.Space.xs,
      leading: -Tokens.Space.xs, bottom: -Tokens.Space.xs, trailing: -Tokens.Space.xs))
    .tickrCard()
    .accessibilityElement(children: .combine)
  }
}

/// Where the price went after a signal or an exit, per share: "after 1m +0.12 · 5m −0.30 ·
/// 15m —". Each change in its direction's colour; a minute with no captured bar shows a dash.
/// Nothing when the bot sent no prices.
struct AfterLine: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let prices: [PriceAfterV1]

  private var line: AttributedString { Self.line(prices) }

  /// "after 1m +0.12 · 5m −0.30", each change coloured by its sign; a missing price reads "—".
  static func line(_ prices: [PriceAfterV1]) -> AttributedString {
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
      // Small and on one line, as on the design; it wraps only at large text sizes.
      Text(line)
        .font(Tokens.Typography.annotation)
        .lineLimit(typeSize.stacksRows ? nil : 1)
        .minimumScaleFactor(typeSize.stacksRows ? 1 : Tokens.Shrink.standard)
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
    } else if let cause = ApiText.prose(whatIf.causeCodes, text: whatIf.cause) {
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
      Group {
        if let code = cause.known {
          Text(L10n.Cause.title(code))
        } else if cause.hasCode {
          // A code this app has no words for is never shown; its detail follows.
          Text(L10n.Cause.other)
        }
      }
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textSecondary)
      Group {
        if let cooldown = cause.cooldown {
          Text(L10n.Cause.cooldownDetail(Format.time(cooldown.loss), Format.time(cooldown.until)))
        } else if cause.known == nil, !cause.hasCode {
          // Prose the bot wrote without a code: as written, times made readable.
          Text(verbatim: cause.detail.isEmpty ? cause.code
            : cause.code + RefusalCause.separator + cause.readable(time: Format.time))
        } else if cause.known == nil {
          if !cause.detail.isEmpty {
            Text(verbatim: cause.readable(time: Format.time))
          }
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

  @Environment(\.dynamicTypeSize) private var typeSize
  /// Events a new read brought while the journal was on screen: each flashes once.
  @State private var arrived: Set<String> = []
  let events: [Board.Event]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
        Group {
          if typeSize.isAccessibilitySize {
            // The time column would leave the text a few letters per line: time and tag go on
            // top, wrapping as chips, and the text takes the whole width below.
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              ChipFlow(spacing: Tokens.Space.s) {
                HStack(spacing: Tokens.Space.s) {
                  dot(event)
                  time(event)
                }
                tag(event)
              }
              text(event)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
              time(event)
              dot(event)
              VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                tag(event)
                text(event)
              }
              Spacer(minLength: 0)
            }
          }
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        // A genuinely new event washes its row once (the board's `flashA/B`), never a rotation.
        .arrivalFlash(arrived.contains(event.id), color: Palette.info)
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
    .tickrCard(radius: Tokens.Radius.card)
    .onArrival(of: events.map(\.id)) { arrived = $0 }
  }

  private func time(_ event: Board.Event) -> some View {
    Text(verbatim: Format.clock(event.time))
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  private func dot(_ event: Board.Event) -> some View {
    Circle().fill(event.tone.color).frame(width: Self.dotSide, height: Self.dotSide)
  }

  private func tag(_ event: Board.Event) -> some View {
    Text(verbatim: event.tag)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(event.tone.color)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  private func text(_ event: Board.Event) -> some View {
    Text(verbatim: event.text).font(.footnote).foregroundStyle(Palette.textSecondary)
  }
}
