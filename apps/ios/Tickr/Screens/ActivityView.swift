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
        let day = DayText.day(status.writtenAt.date)
        DayCard(label: String(localized: isToday ? L10n.Common.today(day) : L10n.Activity.lastSession(day)),
          live: isToday && model.response?.stale == false, figures: DayFigures(status))
          .rise(step: Order.day.rawValue)
        panes(status: status)
      }
    }
    // Another pane or day replaces the one shown at once: a crossfade laid one pane's words over
    // the other's. The calendar still slides; a loaded day takes its skeleton's place at once,
    // without fading or rising (design-system "Loading").
    .animation(Tokens.Motion.standard, value: showsCalendar)
    .loadsInPlace(activity.selectedDay == nil || activity.day != nil)
    .jumps(on: section)
    .jumps(on: activity.selectedDay)
    .task(id: model.connection.url) {
      guard let url = model.connection.url else { return }
      await activity.loadDays(url)
    }
    // The app's one shown day: another tab's pick (Home's arrows, the Chart's day menu) shows here.
    .task(id: ShownDayKey(url: model.connection.url, day: model.selectedDay)) {
      guard let url = model.connection.url else { return }
      await activity.follow(from: url)
    }
    .task(id: skippedKey) {
      guard let url = model.connection.url, let day = skippedKey.day else { return }
      // Today's refusals keep coming without a trade closing: read them again while today shows.
      repeat {
        async let skippedRead: Void = activity.loadSkipped(url, day: day)
        async let journalRead: Void = activity.loadJournal(url, day: day)
        _ = await (skippedRead, journalRead)
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
      if let day = skippedKey.day {
        await activity.loadSkipped(url, day: day)
        await activity.loadJournal(url, day: day)
      }
    }
  }

  /// Changes when the status's session or its closed trades change, reloading the session's
  /// record (for each trade's MAE and MFE, which the status does not carry).
  private var sessionKey: SessionKey {
    SessionKey(url: model.connection.url, day: model.status.map(activity.sessionDay(of:)),
      trades: model.status?.tradesToday.count ?? 0)
  }

  private struct ShownDayKey: Hashable {
    let url: URL?
    let day: WireDate?
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
    let label = String(localized: L10n.Activity.pastDay(DayText.day(selected.noonInNewYork)))
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
        VStack(spacing: Tokens.Space.m) {
          UnavailableState(L10n.Activity.dayUnavailable(DayText.day(selected)),
            message: L10n.Activity.dayUnavailableDetail, cause: cause)
          Button {
            guard let url = model.connection.url else { return }
            Task { await activity.show(selected, from: url) }
          } label: {
            Text(L10n.Activity.retry)
          }
          .buttonStyle(.action(.secondary, size: .compact))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.dayUnavailable)
        .rise()
      default:
        Skeleton(L10n.Activity.loadingDay) {
          VStack(alignment: .leading, spacing: Tokens.Space.l) {
            SkeletonTiles(Tokens.Loading.tiles)
            SkeletonRows(Tokens.Loading.manyRows, badge: true)
          }
        }
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
            empty: (L10n.Activity.noTradesOn(DayText.day(activity.selectedDay ?? activity.today)),
              L10n.Activity.noTradesThatDayBody))
        }
      case .skipped:
        NotTaken(groups: activity.skipped, failure: activity.skippedFailure)
      case .journal:
        if let lines = activity.journalDay == skippedKey.day ? activity.journal : nil {
          Journal(events: lines)
        } else if let status {
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
      SegmentSwitch(options: Pane.allCases.map { ($0, Text($0.title)) }, selection: $section,
        identifier: AccessibilityID.activitySection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.Activity.show))
    }
  }
}

/// The calendar of recorded days: one month of Monday-to-Friday weeks, each day tinted by its net
/// result. Tapping a recorded day shows it; tapping today goes back to the live view.
private struct DayPicker: View {
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
    // The month arrows always, so earlier months stay reachable; the one that leads nowhere is
    // dimmed.
    HStack(spacing: Tokens.Space.s) {
      Button {
        if let month = activity.previousMonth { activity.month = month }
      } label: {
        monthArrow(Symbols.previous)
      }
      .disabled(activity.previousMonth == nil)
      .accessibilityLabel(Text(L10n.Activity.previousMonth))
      Spacer(minLength: 0)
      if let first = activity.month.firstDay {
        VStack(spacing: Tokens.Space.xxs) {
          Text(first, format: .dateTime.month(.wide).year())
            .font(Tokens.Typography.calloutMono.bold())
            .foregroundStyle(Palette.textPrimary)
          // The month's total result under its name, as the Mac shows it beside the month.
          if let total = DayCalendar.total(of: activity.month, days: activity.days) {
            Text(L10n.Activity.monthTotal(Money.signedUSD(total)))
              .font(Tokens.Typography.label)
              .foregroundStyle(Palette.result(total))
          }
        }
        // The month and year wrap ("Ноябрь 2026 г." at large text sizes), never shrink or get cut.
        .multilineTextAlignment(.center)
        .contentTransition(.opacity)
      }
      // At accessibility sizes the button takes its own row under the month.
      if activity.selectedDay != nil && !dynamicTypeSize.isAccessibilitySize {
        backToToday
      }
      Spacer(minLength: 0)
      Button {
        if let month = activity.nextMonth { activity.month = month }
      } label: {
        monthArrow(Symbols.next)
      }
      .disabled(activity.nextMonth == nil)
      .accessibilityLabel(Text(L10n.Activity.nextMonth))
    }
    .buttonStyle(.glyph)
  }

  /// A month arrow: the bare glyph in the link colour, dimmed while it leads nowhere.
  private func monthArrow(_ symbol: String) -> some View {
    HeaderIcon(symbol: symbol, glass: false).foregroundStyle(Palette.infoText).dimmedWhenDisabled()
  }

  private var backToToday: some View {
    TodayButton(L10n.Activity.backToToday) { activity.showToday() }
      .transition(.scale.combined(with: .opacity))
  }

  /// Short weekday names, Monday to Friday, in the phone's language.
  private var weekdays: [String] {
    let names = Calendar.current.shortStandaloneWeekdaySymbols
    return Array(names[(DayCalendar.monday - 1)...(DayCalendar.friday - 1)])
  }
}

/// One weekday of the calendar: its number and, when the bot recorded it, its net result with its
/// wins and losses.
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
    let result = cell.summary?.resultUsd.value
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.small)
    Button(action: action) {
      VStack(spacing: Tokens.Space.xxs) {
        Text(verbatim: String(cell.day.day))
          .font(Tokens.Typography.calloutMono.bold())
          // Inset from the cell's edges, so neighbouring day numbers never touch.
          .padding(.horizontal, Tokens.Space.xxs)
        if let result {
          // figure: a calendar cell's day result in whole dollars without "$" (the IOSActivity
          // board's compact cell), coloured by the figure as shown.
          Text(verbatim: Money.signed(result, fractionDigits: 0))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Tone.result(result, fractionDigits: 0).text)
          if let summary = cell.summary {
            // Wins and losses side by side when they fit the cell, else one under the other.
            ViewThatFits(in: .horizontal) {
              HStack(spacing: Tokens.Space.xxs) { winsLosses(summary) }
              VStack(spacing: 0) { winsLosses(summary) }
            }
            .font(Tokens.Typography.annotation)
          }
        } else if isToday {
          PulseDot(Palette.accent, size: Tokens.Size.dotSmall, event: todayEvent)
        }
      }
      // A margin above and below, so a day's last line (its wins and losses) never sits on the edge.
      .padding(.vertical, Tokens.Space.xxs)
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
    .accessibilityLabel(Text(verbatim: DayText.day(cell.day.noonInNewYork)))
    .accessibilityValue(cell.summary.map {
      Text(verbatim: Money.signedUSD($0.resultUsd.value) + Format.separator
        + String(localized: L10n.Activity.chipWins($0.wins)) + Format.separator
        + String(localized: L10n.Activity.chipLosses($0.losses)))
    } ?? Text(L10n.Activity.noRecords))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  /// The day's wins ("2W") and losses ("1L"), green and pink when there are any.
  @ViewBuilder
  private func winsLosses(_ summary: DaySummary) -> some View {
    Text(L10n.Activity.calendarWins(summary.wins))
      .foregroundStyle(Tone.result(Decimal(summary.wins)).text)
      .fixedSize()
    Text(L10n.Activity.calendarLosses(summary.losses))
      .foregroundStyle(Tone.loss(Decimal(summary.losses)).text)
      .fixedSize()
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
    result = stats.resultUsd
    counts = L10n.Activity.counts(stats.trades, stats.wins, stats.losses, status.positions.count)
    tally = Tally(closed: stats.trades, wins: stats.wins, losses: stats.losses, open: status.positions.count)
    curve = Self.curve(status.tradesToday.map { ($0.closedAt.date, $0.resultGrossUsd.value) })
  }

  /// A recorded day with its trades.
  init(_ day: DayV1) {
    let results = day.trades.map(\.resultUsd.value)
    result = day.resultUsd.value
    counts = L10n.Activity.pastCounts(results.count, results.filter { $0 > 0 }.count, results.filter { $0 < 0 }.count)
    tally = Tally(closed: results.count, wins: results.filter { $0 > 0 }.count, losses: results.filter { $0 < 0 }.count)
    curve = Self.curve(day.trades.map { ($0.closedAt.date, $0.resultUsd.value) })
  }

  /// A recorded day from the calendar's summary, while its trades load.
  init(_ summary: DaySummary) {
    result = summary.resultUsd.value
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
            value: String(localized: L10n.Activity.chipLosses(figures.tally.losses)), tone: .series,
            color: Tone.series.text, compact: true)
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
        // The day's result colour, as its figure (IOSActivity: green, red, muted at zero).
        DrawnSparkline(values: figures.curve, color: Palette.result(figures.result))
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
  DayCard(label: String(localized: L10n.Activity.pastDay(DayText.day(.now))), live: false, figures: .sample)
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
    result = trade.resultUsd.value
    let planned = trade.plannedLossUsd.value
    resultR = planned == 0 ? nil : trade.resultUsd.value / planned
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
    result = trade.resultUsd.value
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
      parts.append(String(localized: L10n.Activity.excursion(Money.signedUSD(mae), Money.signedUSD(mfe))))
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
  /// A stop the broker confirmed (its time to confirmation).
  static let stopSymbol = StopState.verifiedSymbol
  static let maeSymbol = "arrow.down"
  static let mfeSymbol = "arrow.up"
  static let codeSymbol = "chevron.left.forwardslash.chevron.right"
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
        // As on the design (IOSActivity v99): no time beside the symbol (the fill time is a chip
        // below); the OPEN tag, then the stop's own state beside it (VERIFIED green, PENDING amber…).
        row(symbol: position.symbol, time: nil,
          tag: String(localized: L10n.Activity.openTag),
          tone: Tone.openPosition,
          result: String(localized: L10n.Common.quantityAt(position.quantity.text, Money.price(position.entryPrice.value))),
          figures: openFigures(position), stopState: state, open: true)
          .rise(step: ActivityView.Order.list.rawValue)
      }
      ForEach(Array(sorted.enumerated()), id: \.offset) { index, trade in
        row(symbol: trade.symbol,
          time: Format.time(trade.openedAt) + Format.timeRange + Format.time(trade.closedAt),
          tag: Board.exitReasonTitle(trade.exitReason).uppercased(),
          // The reason's own tone (v99: strategy exit teal, stopped out pink, other closes grey),
          // as the Mac's Trades; the result keeps its sign's.
          tagTone: Tone.exit(trade.exitReason),
          tone: Tone.result(trade.result),
          result: Money.signedUSD(trade.result),
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
    .buttonStyle(.glyph)
    // The row is one VoiceOver element and offers this as its named action instead.
    .accessibilityHidden(true)
  }

  /// An open position as on the design: last price and R while current, entry sends, stop, time
  /// of the fill and quantity.
  private func openFigures(_ position: Position) -> [Figure] {
    let state = position.stop.state
    var list: [Figure] = []
    if let marks = marks[position.symbol] {
      list.append(Figure(symbol: Self.lastSymbol, label: marks.isLive ? L10n.Activity.hintBid : L10n.Activity.hintLast,
        value: Money.price(marks.last)))
      if let r = marks.resultR {
        list.append(Figure(symbol: r < 0 ? Self.resultDownSymbol : Self.resultUpSymbol, label: L10n.Activity.hintResultR,
          value: Risk.text(r), tone: Tone.result(marks.unrealized)))
      }
    }
    if let sends = position.entry.sends {
      list.append(Figure(symbol: Self.sendsSymbol, label: L10n.Activity.hintSends,
        value: String(localized: L10n.Activity.sends(sends)), tone: sends == 1 ? nil : .loss))
    }
    list.append(Figure(symbol: StopState.levelSymbol, label: L10n.Activity.hintStop,
      value: position.stop.price.map { Money.price($0.value) } ?? Format.missing, tone: state.tone))
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
      // Coloured by the value shown, so "↓ $0.00" is not pink.
      list.append(Figure(symbol: Self.maeSymbol, label: L10n.Activity.hintMae, value: Money.signedUSD(mae),
        tone: Tone.result(mae)))
      list.append(Figure(symbol: Self.mfeSymbol, label: L10n.Activity.hintMfe, value: Money.signedUSD(mfe),
        tone: Tone.result(mfe)))
    }
    if let code = trade.codeVersion {
      list.append(Figure(symbol: Self.codeSymbol, label: L10n.Activity.hintCodeVersion, value: code))
    }
    return list
  }

  private func headerText(_ symbol: String) -> some View {
    SymbolText(symbol)
      .font(Tokens.Typography.calloutMono.bold())
  }

  private func timeText(_ time: String) -> some View {
    Text(verbatim: time)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
  }

  private func resultText(_ result: String, tone: Tone) -> some View {
    Text(verbatim: result)
      .font(Tokens.Typography.calloutMono.bold())
      .foregroundStyle(tone.text)
  }

  /// A row's tag, and for an open position its stop's state as a tag of its own beside it (the
  /// board's OPEN, then VERIFIED): two meanings, two tags, never one "OPEN · VERIFIED".
  @ViewBuilder
  private func tags(_ tag: String, tone: Tone, stopState: StopState?) -> some View {
    Badge(verbatim: tag, tone: tone)
    if let stopState {
      Badge(verbatim: Board.stopStateTitle(stopState), tone: stopState.tone)
        .hint(L10n.Activity.hintStop)
    }
  }

  private func row(
    symbol: String, time: String?, tag: String, tagTone: Tone? = nil, tone: Tone, result: String,
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
          tags(tag, tone: tagTone ?? tone, stopState: stopState)
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
            tags(tag, tone: tagTone ?? tone, stopState: stopState)
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
            tags(tag, tone: tagTone ?? tone, stopState: stopState)
          }
        }
      }
      ChipFlow {
        chipViews(figures)
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
    // One view, so the rows remember that a skeleton stood there (`loadsInPlace`).
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      list
    }
    .loadsInPlace(groups != nil || failure != nil)
  }

  @ViewBuilder
  private var list: some View {
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
      Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.rows, badge: true) }
    }
  }
}

private struct SkippedRow: View {
  /// Symbol of the time.
  static let whenSymbol = "clock"

  let group: SkippedGroup
  /// Whether the row just arrived with a new read: it tints once.
  var arrived = false

  private var refused: Bool { group.latest.admission == .refused }

  /// "16:27" or, for repeats, "16:27–16:29 · ×3"; repeats within one minute (or on one bar)
  /// read "16:27 · ×3", never "16:27–16:27".
  private var when: String {
    let first = Format.time(group.first.at.date)
    guard group.count > 1 else { return first }
    let last = Format.time(group.latest.at.date)
    let span = last == first ? first : first + Format.timeRange + last
    return span + Format.separator + String(localized: L10n.Activity.repeats(group.count))
  }

  private func symbolText(_ symbol: String) -> some View {
    SymbolText(symbol)
      .font(Tokens.Typography.bodyMono.bold())
      .foregroundStyle(Palette.textPrimary)
  }

  private var tagPill: some View {
    // The reason tag, as every reason tag on both apps: a `Badge` (REFUSED amber, too late grey).
    Badge(refused ? L10n.Activity.refusedTag : L10n.Activity.tooLateTag,
      tone: refused ? Tone.refused : Tone.notEvaluated)
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
        IconMetric(StopState.levelSymbol, label: L10n.Activity.hintWhatIfStop,
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
      var value = AttributedString(change.map { Money.priceChange($0, at: point.price?.value) } ?? Format.missing)
      value.swiftUI.foregroundColor = change.map(Palette.result) ?? Palette.textQuaternary
      text += label + value
    }
    return text
  }

  var body: some View {
    if !prices.isEmpty {
      // Small, as on the design; it wraps when the line is too narrow, never cut.
      Text(line)
        .font(Tokens.Typography.annotation)
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
  let events: [Board.Event]

  var body: some View {
    Group {
      if events.isEmpty {
        Text(L10n.Activity.nothingYet)
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        JournalLines(events)
      }
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .tickrCard(radius: Tokens.Radius.card)
    .rise(step: ActivityView.Order.list.rawValue)
  }
}
