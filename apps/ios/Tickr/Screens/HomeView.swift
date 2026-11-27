import SwiftUI
import TickrDesign
import TickrKit

/// The first screen (IOS2Home board, mockup v155): the shown day's button, the one line that says
/// what the bot is doing, the day's result, the day's events as a ticker, open positions, the
/// funnel on one line and the fast movers. The power button opens bot control; a sideways swipe
/// changes the day. In landscape (IOS2Landscape) the same in two columns.
struct HomeView: View {
  /// Order in which the blocks rise in (`rise(step:)`); open positions follow one step apart.
  private enum Order: Int { case day = 1, summary, ticker, positions, flow = 6, movers }

  @Environment(AppModel.self) private var model
  @State private var showControl = false
  @State private var prices = Container.shared.positionsModel()
  @State private var dayModel = Container.shared.homeDayModel()
  /// The Symbols tab the funnel sheet picked, pushed on Home.
  @State private var symbolsTab: SymbolsTab?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.verticalSizeClass) private var verticalSizeClass

  /// Whether Home's looping ornaments (the brand mark's halo, the ticker's scroll) move: they read
  /// as "the bot is at work", so only on the live day with a fresh status while the bot runs.
  private var ornamentMoves: Bool {
    guard model.isLive else { return false }
    return OrnamentGate.moves(reduceMotion: reduceMotion, current: model.showsLiveStatus,
      botState: model.status?.botState)
  }

  var body: some View {
    Screen(L10n.App.name, tab: .home) {
      // The mark the opening animation flies into (LaunchHandoff); it pulses while data is current.
      // Muted while the link is down: the mark says nothing about a bot it cannot hear.
      BrandMark(size: Tokens.Size.glyph, live: ornamentMoves && model.fetchError == nil,
        tone: model.fetchError == nil ? .brand : .muted)
        .onGeometryChange(for: CGPoint.self) { proxy in
          let frame = proxy.frame(in: .global)
          return CGPoint(x: frame.midX, y: frame.midY)
        } action: { centre in
          model.homeMarkCentre = centre
        }
    } actions: {
      if let environment = model.status?.environment {
        EnvironmentBadge(ApiText.environment(environment), raw: environment,
          accessibilityLabel: ApiText.environmentLabel(environment))
      }
      Button {
        showControl = true
      } label: {
        HeaderIcon(.power)
          .foregroundStyle(model.canCommand && model.isLive ? powerTint : Palette.textQuaternary)
      }
      .disabled(!model.canCommand || !model.isLive)
      .accessibilityLabel(Text(L10n.Control.title))
      .accessibilityIdentifier(AccessibilityID.botControl)
      NavigationLink {
        SettingsView()
      } label: {
        HeaderIcon(.settings)
          .foregroundStyle(Palette.textPrimary)
      }
      .accessibilityLabel(Text(L10n.Home.settings))
      .accessibilityIdentifier(AccessibilityID.settings)
      // In landscape the day's button moves into the title row (IOS2Landscape board).
      if compactHeight { daySwitch }
    } content: {
      if model.connection.demo {
        // Every command from here goes to the demo day: said at the top, as loud as a warning.
        WarningBanner(L10n.Home.demoTitle, detail: L10n.Home.demoDetail, systemImage: SettingsView.demoSymbol)
      }
      if compactHeight {
        // An iPhone in landscape (IOS2Landscape board): two columns, the day on the left (what
        // the bot does, its result without the ring, its events, the fast movers), the
        // positions and the funnel on the right.
        HStack(alignment: .top, spacing: Tokens.Space.m) {
          VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Summary(past: dayModel.shown, showsRing: false).rise(step: Order.summary.rawValue)
            switch phase {
            case .unread, .offline: EmptyView()
            case .past: pastNote
            case .live(let status):
              ticker(status)
              movers(of: model.today)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .leading, spacing: Tokens.Space.m) {
            switch phase {
            case .unread: EmptyView()
            case .offline: offlineCards
            case .past(let status):
              pastFunnel(status)
              movers(of: model.shownDay)
            case .live(let status):
              positions(status)
              liveFunnel(status)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        daySwitch.rise(step: Order.day.rawValue)
        Summary(past: dayModel.shown).rise(step: Order.summary.rawValue)
        switch phase {
        case .unread: EmptyView()
        case .offline: offlineCards
        case .past(let status):
          // A recorded day: its result above, then what it recorded (the flow, its fast movers);
          // nothing live (no positions, quotes or fences of today).
          pastNote
          pastFunnel(status)
          movers(of: model.shownDay)
        case .live(let status):
          ticker(status)
          positions(status)
          liveFunnel(status)
          movers(of: model.today)
        }
      }
    }
    .botControl(isPresented: $showControl)
    .navigationDestination(item: $symbolsTab) { SymbolsView(tab: $0) }
    .daySwipe(dayModel.arrows, back: { dayModel.back() }, forward: { dayModel.forward() })
    // Another day lands at once: no crossfade of one day's figures over the other's.
    .jumps(on: model.shownDay)
    .refreshable {
      await model.refreshAll()
      if let url = model.connection.url { await dayModel.load(url) }
    }
    // A new address or a new day (the bot's clock, known once its status arrives) reads at once.
    .task(id: DaysKey(url: model.connection.url, today: model.today)) { await model.followFlow() }
    .task(id: DaysKey(url: model.connection.url, today: model.today)) {
      guard let url = model.connection.url else { return }
      await dayModel.load(url)
    }
    .task(id: followKey) {
      guard let url = model.connection.url, let status = model.status, !status.positions.isEmpty else { return }
      await prices.follow(url, status: status)
    }
  }
}

extension HomeView {
  /// The shown day as the board's "Today ▾": a recorded day, today, or the last session (a weekend,
  /// a day off), which is never shown as live.
  fileprivate var daySwitch: some View {
    let written = model.status?.writtenAt.date ?? model.botNow
    let isToday = WireDate(newYorkDateOf: written) == model.today
    let past = dayModel.shown.map { DayText.day($0.day.noonInNewYork) }
    let day = past ?? String(localized: isToday ? L10n.Common.today(DayText.day(written))
      : L10n.Activity.lastSession(DayText.day(written)))
    return DaySwitch(caption: past ?? (isToday ? nil : DayText.day(written)), day: day, away: past != nil,
      steps: dayModel.arrows, today: { dayModel.showToday() }, back: { dayModel.back() },
      forward: { dayModel.forward() })
      .accessibilityIdentifier(AccessibilityID.daySwitch)
  }

  /// An iPhone in landscape: Home lays out in two columns, the day's button in the title row.
  fileprivate var compactHeight: Bool { verticalSizeClass == .compact }

  /// What Home shows under the summary.
  fileprivate enum Phase {
    /// No status yet, with the link not known to be down.
    case unread
    /// Nothing was ever read and the link is down.
    case offline
    /// A recorded day, with the bot's status.
    case past(StatusV1)
    /// Today, with the bot's status.
    case live(StatusV1)
  }

  fileprivate var phase: Phase {
    if model.status == nil && model.connectionState.isNeverConnected { return .offline }
    guard let status = model.status else { return .unread }
    return model.isLive ? .live(status) : .past(status)
  }

  /// Nothing was ever read: the cards keep their titles over a quiet outline, never a
  /// "no position" or zero we do not know (mockup "no connection" v2).
  @ViewBuilder
  fileprivate var offlineCards: some View {
    OfflineCard(L10n.App.positions).rise(step: Order.positions.rawValue)
    OfflineCard(L10n.Watching.title).rise(step: Order.flow.rawValue)
  }

  /// A recorded day says so in a card where today's positions stand.
  fileprivate var pastNote: some View {
    Text(L10n.Home.pastDayNote(DayText.day(model.shownDay.noonInNewYork)))
      .font(Tokens.Typography.subheadline)
      .foregroundStyle(Palette.textTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(Tokens.Space.l)
      .tickrCard()
      .rise(step: Order.positions.rawValue)
  }

  /// The recorded day's funnel, from what that day recorded.
  fileprivate func pastFunnel(_ status: StatusV1) -> some View {
    let dayFlow = model.flow?.day == model.shownDay ? model.flow : nil
    return FunnelCard(status: status, flow: dayFlow, flowPending: model.flowPending,
      current: false, recorded: true,
      sources: StageSources(flow: dayFlow, skipped: model.skipped?.day == model.shownDay ? model.skipped : nil,
        watching: nil, status: nil, settings: model.settings),
      symbols: model.symbols?.day == model.shownDay ? model.symbols : nil, moving: false) { symbolsTab = $0 }
      .rise(step: Order.flow.rawValue)
  }

  /// The fast movers of `day`, when they were read for it.
  fileprivate func movers(of day: WireDate) -> some View {
    FastMoversCard(movers: model.movers?.day == day ? model.movers : nil, failure: model.moversError)
      .rise(step: Order.movers.rawValue)
  }

  /// Today's events as the ticker strip, when there are any.
  @ViewBuilder
  fileprivate func ticker(_ status: StatusV1) -> some View {
    if let strip = EventStrip.make(status: status,
      skipped: model.skipped?.day == model.today ? model.skipped : nil) {
      strip.moving(ornamentMoves).rise(step: Order.ticker.rawValue)
    }
  }

  /// The open positions, or a card saying there are none.
  @ViewBuilder
  fileprivate func positions(_ status: StatusV1) -> some View {
    if let stopped = model.stoppedPositions {
      // Bot stopped with positions open (board IOSHome): the stopped bot's last knowledge
      // of them in place of the live rows, with Start bot.
      StoppedPositionsPanel(stopped) { HomeStartButton() }
        .rise(step: Order.positions.rawValue)
    } else {
      ForEach(Array(Board.positions(status).enumerated()), id: \.element.symbol) { index, position in
        PositionRow(position: position, marks: prices.marks[position.symbol])
          .rise(step: Order.positions.rawValue + index)
      }
    }
    // Own entry orders working with nothing filled, and those just cancelled: one alone with
    // nothing open as a full card (mockup v160), else a compact row each (mockup v162).
    let entries = model.entryRows
    let compact = !status.positions.isEmpty || entries.count > 1
    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
      EntryCard(row: entry, compact: compact).rise(step: Order.positions.rawValue + status.positions.count + index)
    }
    if status.positions.isEmpty && entries.isEmpty {
      Text(L10n.Home.noPosition)
        .font(Tokens.Typography.subheadline)
        .foregroundStyle(Palette.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.l)
        .tickrCard()
        .rise(step: Order.positions.rawValue)
    }
  }

  /// Today's funnel, with the status's own values while it is current.
  fileprivate func liveFunnel(_ status: StatusV1) -> some View {
    let todayFlow = model.flow?.day == model.today ? model.flow : nil
    let todaySkipped = model.skipped?.day == model.today ? model.skipped : nil
    let current = model.isFresh && WireDate(newYorkDateOf: status.writtenAt.date) == model.today
    return FunnelCard(status: status, flow: todayFlow, flowPending: model.flowPending,
      current: current, recorded: false,
      // The status only while it is current, as the stages' own values.
      sources: StageSources(flow: todayFlow, skipped: todaySkipped, watching: nil,
        status: current ? status : nil, settings: model.settings),
      symbols: model.symbols?.day == model.today ? model.symbols : nil, moving: ornamentMoves) { symbolsTab = $0 }
      .rise(step: Order.flow.rawValue)
  }

  /// What VoiceOver says for the day's ring: the result and counts once the day is read, else
  /// that there is no data yet.
  static func dayResultLabel(stats: Board.DayStats?, result: Decimal) -> LocalizedStringResource {
    guard let stats else { return L10n.Home.dayResultUnavailable }
    return L10n.Home.dayResult(Money.signedUSD(result), stats.wins, stats.losses)
  }

  /// The power glyph in the bot's state, as on the design: green running, amber with entries paused
  /// or while it starts or stops, red stopped.
  fileprivate var powerTint: Color {
    guard let status = model.status else { return Palette.textQuaternary }
    switch status.botState {
    case .running: return status.entryStop ? Palette.warningText : Palette.profitText
    case .starting, .stopping: return Palette.warningText
    case .stopped: return Palette.lossText
    }
  }

  /// Changes when the address, the session or the open positions change, restarting the reads.
  fileprivate var followKey: FollowKey {
    FollowKey(url: model.connection.url, day: model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date) },
      positions: model.status?.positions ?? [])
  }

  /// The recorded days are listed again for another bot and when a new day begins.
  fileprivate struct DaysKey: Hashable {
    let url: URL?
    let today: WireDate
  }

  fileprivate struct FollowKey: Hashable {
    let url: URL?
    let day: WireDate?
    let positions: [Position]
  }
}

/// The status's age under Home's summary with the quote stream ("updated 3 s ago · quotes fresh"),
/// after the connection's own health dot: green while fresh statuses arrive, amber when the status
/// is stale, red with no status or a failed read. Only a fresh status of today pulses, and only when the health changes.
private struct AgeLine: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let written = model.status?.writtenAt.date ?? model.botNow
    let isToday = WireDate(newYorkDateOf: written) == model.today
    let fresh = model.response?.stale == false && model.fetchError == nil
    let freshness = ConnectionFreshness.color(response: model.response, fetchError: model.fetchError)
    HStack(spacing: Tokens.Space.xs) {
      PulseDot(freshness, size: Tokens.Size.dotSmall, pulsing: isToday && fresh, event: freshness)
      Text(line(isToday: isToday))
        .contentTransition(.numericText())
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
  }

  /// "updated 3 s ago · quotes fresh": the quote stream only for a status of today (an old one
  /// says nothing about the stream now); off is the bot's normal state while flat, said so.
  private func line(isToday: Bool) -> LocalizedStringResource {
    let age = Format.age(model.response)
    guard isToday, let stream = model.status?.freshness.stream else { return age }
    let quotes = L10n.Flow.quotes(String(localized: stream == .off ? L10n.Settings.streamNoPosition : stream.title))
    return L10n.Home.ageQuotes(String(localized: age), String(localized: quotes))
  }
}

/// A Home card while nothing was ever read and the link is down: its title over the still grey
/// outline (`OfflineOutline`), as the Mac's outlined cards.
private struct OfflineCard: View {
  let title: LocalizedStringResource

  init(_ title: LocalizedStringResource) {
    self.title = title
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(title)
      OfflineOutline()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Tokens.Space.l)
    .tickrCard()
  }
}

/// The colour of Home's connection dot.
enum ConnectionFreshness {
  /// Grey after a failed read (no connection is not danger; the banner says why), red with no
  /// status, amber while the status is stale, green while it is current.
  static func color(response: StatusResponseV1?, fetchError: String?) -> Color {
    guard fetchError == nil else { return Palette.textQuaternary }
    guard let response else { return Palette.loss }
    return response.stale ? Palette.warning : Palette.profit
  }
}

/// The Home glyph for whether new entries can open.
enum EntriesGlyph {
  /// Symbols of the entries glyph: allowed, calm "not now", blocked (paused by the owner draws
  /// `Symbols.pause`).
  static let entriesAllowedSymbol = "lock.open.fill"
  /// The full stop the "No entries now: …." and "Entries blocked: …." sentences end with: a
  /// cause that is a sentence of its own already ends with one, which then is not doubled.
  static let fullStop = "."
  static let entriesNotNowSymbol = "moon.fill"
  static let entriesBlockedSymbol = "hand.raised.fill"

  /// Whether new entries can open, as on the board: allowed, paused by the owner, a calm
  /// "not now" (outside the session) or blocked; the gate, when closed, has its own glyph. The
  /// bot's own entry block decides, in its precedence: a stopped bot outranks the owner's pause.
  static func make(_ status: StatusV1) -> (symbol: String, tone: Tone, label: LocalizedStringResource) {
    guard let block = status.entryBlock else { return (entriesAllowedSymbol, .profit, L10n.Home.entriesAllowed) }
    if BlockCode(rawValue: block.cause) == .entryStop { return (Symbols.pause, .warning, L10n.Home.entriesPaused) }
    let cause = clause(ApiText.entryBlock(block))
    if status.entriesCalm { return (entriesNotNowSymbol, .neutral, L10n.Home.entriesNotNow(cause)) }
    return (entriesBlockedSymbol, .warning, L10n.Home.entriesBlocked(cause))
  }

  /// The cause as a clause inside the sentence: without its own final full stop ("…: cause."
  /// read "cause.." when the cause was a sentence).
  static func clause(_ cause: String) -> String {
    cause.hasSuffix(fullStop) ? String(cause.dropLast(fullStop.count)) : cause
  }
}

/// The headline on its own row, and under it the ring with the day's result; in landscape, where
/// the board has no room for the ring, the result as a figure over the facts.
private struct Summary: View {
  /// Side of the result ring and the width of its track and arc, in points.
  static let ringSide: CGFloat = 136
  static let ringLine: CGFloat = 10
  /// Width of the ring's figures as a share of its side: the square inside the circle.
  static let innerShare: CGFloat = 0.7

  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  /// The ring grows with the text inside it.
  @ScaledMetric(relativeTo: .title) private var ringSide = Summary.ringSide
  /// A recorded past day to summarize instead of today's status.
  let past: DaySummary?
  /// Whether the result stands in its ring (false: a figure on the facts' first line).
  var showsRing = true

  var body: some View {
    let stats = past.map(Board.dayStats) ?? model.status.map(Board.dayStats)
    let result = stats?.resultUsd ?? 0
    let headline = model.headline
    // A recorded day says so, in the highlight colour and without a pulse; the live headline is about today.
    // While the link is down the banner above speaks; no headline about a bot we cannot hear.
    let linkDown = past == nil && model.fetchError != nil
    let text = past != nil ? String(localized: L10n.Home.recordedDay) : headline.text
    let detail = past != nil ? String(localized: L10n.Home.recordedNote) : headline.detail
    let tone = past == nil ? headline.tone : Tone.highlight
    // A stale status's text counts its age; read again it is no new event.
    let pulse: Headline.Pulse = past == nil ? headline.pulse : .text(text)
    VStack(alignment: .leading, spacing: Tokens.Space.l) {
      // As IOSHome draws it (mockup v108): the shared headline on its own row above the ring, the
      // title over its detail, with the session countdown and the gate badge on the live day.
      if !linkDown {
        HeadlineBanner(text, detail: detail, tone: tone, alarm: past == nil && headline.severity == .alarm,
          pulse: past == nil && (headline.severity != .ok || model.response?.stale == false) ? AnyHashable(pulse) : nil,
          arrangement: .stacked, facts: past == nil ? facts : nil)
      }
      RowStack(spacing: Tokens.Space.l) {
        if showsRing { ring(stats: stats, result: result) }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          if !showsRing { resultLine(stats: stats, result: result) }
          if stats?.beforeFees == true {
            // The ring's result does not count the broker's fees yet; wraps rather than cuts.
            Text(L10n.Home.beforeFees)
              .font(Tokens.Typography.footnote)
              .foregroundStyle(Palette.warningText)
              .fixedSize(horizontal: false, vertical: true)
          }
          // As on the board: wins and losses, then the free slots, why entries are closed (only
          // while they are), the version and the status's age, little text beside the big result.
          Group {
            if let stats {
              Text(L10n.Common.winsLosses(stats.wins, stats.losses))
            } else {
              Text(verbatim: Format.missing)
            }
          }
          .font(Tokens.Typography.headline)
          .foregroundStyle(Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          if let past {
            CleanLine(clean: past.clean)
          } else if let status = model.status {
            if let limit = model.settings?.risk.maxOpenPositions {
              // A working entry holds a slot as the engine counts it (mockup v162: "· 1 pending").
              Text(verbatim: Slots.withPending(String(localized: L10n.Home.slotsFree(Slots.free(status, limit: limit), limit)),
                status))
                .font(Tokens.Typography.subheadline)
                .foregroundStyle(Palette.textTertiary)
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)
            }
            // Why entries are closed, only while they are: the gate closed in config, else the
            // bot's own block (red when it needs the operator, grey for a calm "not now").
            if !status.tradingGate.open {
              entryLine(L10n.Home.gateClosed(ApiText.gate(status.tradingGate)), tone: EntryGate.closed.tone)
            } else if status.entryBlock != nil {
              let entries = EntriesGlyph.make(status)
              entryLine(entries.label, tone: entries.tone)
            }
            Text(status.codeVersion.map { L10n.Home.versionCode(status.strategy.version, CodeVersion.short($0)) }
              ?? L10n.Common.version(status.strategy.version))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.highlightText)
            AgeLine()
          }
        }
      }
    }
    .animation(Tokens.Motion.standard, value: pulse)
  }

  private func entryLine(_ text: LocalizedStringResource, tone: Tone) -> some View {
    Text(text)
      .font(Tokens.Typography.footnote)
      .foregroundStyle(tone.text)
      .fixedSize(horizontal: false, vertical: true)
  }

  /// The headline's facts on the live day: the status's gate, and the countdown to the regular
  /// close or the next open from /jobs, on the bot's clock.
  private var facts: HeadlineBanner.Facts {
    let session = model.jobs?.session
    let next = model.jobs?.nextSession
    let offset = model.botClockOffset
    return HeadlineBanner.Facts(gate: EntryGate.make(model.status, headline: model.headline)) { local in
      SessionCountdown.make(session: session, next: next, now: local.addingTimeInterval(offset))
    }
  }

  /// The day's result as a figure: a dash before the day is read, never a $0.00 we do not know;
  /// else it counts up from zero as it appears and on to each new result (the board's count).
  @ViewBuilder
  private func figure(stats: Board.DayStats?, result: Decimal) -> some View {
    if stats == nil {
      Text(verbatim: Format.missing)
        .font(Tokens.Typography.metric)
        .foregroundStyle(Palette.textQuaternary)
    } else {
      CountingText(NSDecimalNumber(decimal: result).doubleValue, period: model.shownDay) { Money.signedUSD(Decimal($0)) }
        .font(Tokens.Typography.metric)
        .foregroundStyle(Palette.result(result))
        // One line at its full size; the ring (or the column) grows around it.
        .fixedSize()
    }
  }

  /// The day's result without its ring: the label and the figure on one line.
  private func resultLine(stats: Board.DayStats?, result: Decimal) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      CardLabel(past == nil ? L10n.Home.today : L10n.Home.day)
      figure(stats: stats, result: result)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(HomeView.dayResultLabel(stats: stats, result: result)))
  }

  /// The day's result in its ring.
  private func ring(stats: Board.DayStats?, result: Decimal) -> some View {
    // Wins in the accent, then losses in the money-loss pink: a day of losses only is a pink
    // ring, not an empty one.
    ResultRing(fraction: stats?.winShare ?? 0, color: Palette.accent,
      trailing: stats?.lossShare ?? 0, trailingColor: Palette.seriesATR,
      halo: result < 0 ? Palette.seriesATR : Palette.accent, lineWidth: Self.ringLine) {
      VStack(spacing: Tokens.Space.xxs) {
        CardLabel(past == nil ? L10n.Home.today : L10n.Home.day)
        figure(stats: stats, result: result)
      }
      // Inside the ring's opening at every text size.
      .frame(minWidth: 0, maxWidth: ringSide * Self.innerShare)
      .padding(Tokens.Space.l)
    }
    // Beside the facts the ring keeps its scaled side, growing only when its figures need more;
    // stacked above them at large text sizes, it stops growing at the screen's width, so it is
    // never cut and never widens the page.
    .frame(minWidth: typeSize.stacksRows ? nil : ringSide, minHeight: typeSize.stacksRows ? nil : ringSide)
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: ringSide)
    .accessibilityElement(children: .ignore)
    // Before the day is read the ring shows dashes; VoiceOver says so, never "$0.00, 0 wins".
    .accessibilityLabel(Text(HomeView.dayResultLabel(stats: stats, result: result)))
  }
}

/// One open position on Home as on the design: its stop glyph, symbol and stop level on the left,
/// the price since the fill as a sparkline, and the open result with the last price on the right,
/// while they are current; tapping it opens it on the Positions tab.
private struct PositionRow: View {
  /// Width of the price sparkline, in points (its height is `Size.sparkline`), as on the design:
  /// with the symbol column it leaves the figures room on a 402-point iPhone.
  static let sparkWidth: CGFloat = 80
  static var sparkHeight: CGFloat { Tokens.Size.sparkline }
  /// Width of the symbol column, in points: a five-letter symbol after its stop glyph.
  static let symbolColumn: CGFloat = 84

  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  let position: Position
  let marks: PositionMarks?

  var body: some View {
    Button {
      model.selectedSymbol = position.symbol
      model.selectedTab = .positions
    } label: {
      // At large text sizes the figures go under the symbol instead of squeezing it.
      RowStack(spacing: Tokens.Space.m) {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack(spacing: Tokens.Space.s) {
            StopGlyph(state: position.stop.state, symbol: position.symbol, price: position.stop.price)
            SymbolText(position.symbol)
              .font(Tokens.Typography.headlineMono)
              .foregroundStyle(Palette.textPrimary)
              .fixedSize()
          }
          Label {
            Text(verbatim: position.stop.price.map { Money.price($0.value) } ?? Format.missing)
          } icon: {
            Image(systemName: StopState.levelSymbol)
          }
          .labelStyle(ControlLabelStyle())
          .font(Tokens.Typography.annotation)
          .foregroundStyle(position.stop.state.isProtected ? Palette.textQuaternary : Palette.lossText)
          .fixedSize()
          .accessibilityLabel(Text(stopLine))
          // Long press names the stop, as on the shield beside the symbol, instead of opening the row.
          .hint(stopLine)
        }
        .frame(minWidth: typeSize.stacksRows ? nil : Self.symbolColumn, alignment: .leading)
        // An old last bar (capture stopped, a quiet minute past the limit) shows muted with its
        // time, as on Positions, never as a live result.
        let current = marks.map(model.isCurrent) ?? false
        if let marks, marks.closes.count > 1 {
          // The day's closes with the last price under them, as on the design.
          ViewThatFits(in: .horizontal) {
            VStack(spacing: Tokens.Space.xxs) {
              // Drawn in once; each new price glides the line's end and its dot, which rings
              // while the price is current (mockup v116).
              LiveSparkline(values: marks.closes.map { NSDecimalNumber(decimal: $0).doubleValue }, live: current,
                scale: .small)
                .frame(width: Self.sparkWidth, height: Self.sparkHeight)
              if current {
                Text(marks.priceText)
                  .font(Tokens.Typography.annotation)
                  .foregroundStyle(Palette.textQuaternary)
              }
            }
            Color.clear.frame(width: 0, height: 0)
          }
        }
        Spacer(minLength: 0)
        VStack(alignment: typeSize.stacksRows ? .leading : .trailing, spacing: Tokens.Space.xxs) {
          if let marks {
            if current {
              DeltaTag(marks.unrealized, text: Money.signedUSD(marks.unrealized))
            } else {
              Text(verbatim: Money.signedUSD(marks.unrealized))
                .font(Tokens.Typography.calloutMono.weight(.semibold))
                .foregroundStyle(Palette.textQuaternary)
                .contentTransition(.numericText())
              Text(L10n.Positions.asOf(Format.clock(marks.lastAt.addingTimeInterval(PositionMarks.barSeconds))))
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.warningText)
            }
          }
          // Size, entry and fill time, as on the design: "10 sh @ 12.34", "since 10:42".
          Group {
            Text(L10n.Home.sharesAt(position.quantity.text, Money.price(position.entryPrice.value)))
            Text(L10n.Home.since(Format.time(position.openedAt.date)))
          }
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
        }
        // Each value on one line; the sparkline gives way first when the row is narrow. Stacked
        // at large text sizes, a value wraps instead of widening the card past the screen.
        .fixedSize(horizontal: !typeSize.stacksRows, vertical: typeSize.stacksRows)
        .layoutPriority(1)
        if !typeSize.stacksRows {
          // The row opens the position.
          Image(systemName: Symbols.next)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(Palette.textQuaternary)
            .accessibilityHidden(true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.m)
      .tickrCard(tint: position.stop.state.isProtected ? nil : Palette.loss)
    }
    .buttonStyle(.plain)
  }

  private var stopLine: LocalizedStringResource {
    switch position.stop.state {
    case .verified: return L10n.Home.stopVerified(position.stop.price.map { Money.price($0.value) } ?? Format.missing)
    case .pending: return L10n.Home.stopPending
    case .missing: return L10n.Home.noStop
    case .unknown: return L10n.Home.stopUnknown
    }
  }
}

/// The day's events as the design's ticker strip: each event's tag in its tone and what happened,
/// newest first (a risk refusal counts as an event), on a sunken strip faded at both ends. As on
/// the board it scrolls, the whole row once every `Motion.tickerLoopSeconds`: the scroll is
/// ornament (docs/design-system.md, rule 5); its items change only on real events. It scrolls only
/// while `OrnamentGate` allows; otherwise, and under Reduce Motion, it holds still and a finger
/// scrolls it.
private struct EventStrip: View {
  /// Most events the strip carries.
  static let maxEvents = 12
  /// Corner radius of the strip, in points.
  static var radius: CGFloat { Tokens.Radius.large }

  let items: [TickerItem]
  /// Whether the strip scrolls (`OrnamentGate`); still otherwise, and a finger scrolls it.
  var scrolls = false

  /// The same strip, scrolling when `on`.
  func moving(_ on: Bool) -> EventStrip {
    var strip = self
    strip.scrolls = on
    return strip
  }

  /// Today's events from the status and the day's refusals, newest first; nil when there are none.
  static func make(status: StatusV1, skipped: SkippedV1?) -> EventStrip? {
    guard let latest = Board.latestEvent(status, skipped: skipped) else { return nil }
    let rest = Board.events(status).filter { $0.id != latest.id }
    let items = ([latest] + rest).prefix(maxEvents).map {
      TickerItem(id: $0.id, tag: $0.tag.uppercased(), text: $0.text, tone: $0.tone.ticker)
    }
    return EventStrip(items: Array(items))
  }

  var body: some View {
    Ticker(items, moving: scrolls, loopSeconds: Tokens.Motion.tickerLoopSeconds)
      // The first tag starts clear of the faded edge.
      .contentMargins(.horizontal, Tokens.Space.l, for: .scrollContent)
      .padding(.vertical, Tokens.Space.s)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: Self.radius, style: .continuous).strokeBorder(Palette.separator))
  }
}

/// When a looping ornament that reads as activity moves (Home's brand halo and ticker scroll): only
/// while the bot runs and the app shows the live day with a fresh status. Stopped, stale,
/// unreachable or on a recorded day it stands still, as with Reduce Motion (the macOS ornaments'
/// `OrnamentGate` rule).
enum OrnamentGate {
  static func moves(reduceMotion: Bool, current: Bool, botState: BotState?) -> Bool {
    !reduceMotion && current && botState == .running
  }
}

/// A recorded day's clean-day verdict from the bot's journal and reconciliation, as on the Mac: the
/// clean-day `Badge` (clean, or needs a look with its first reason under it), or a line saying
/// why the verdict is unknown.
private struct CleanLine: View {
  let clean: CleanDay

  var body: some View {
    switch clean.verdict {
    case .clean:
      // A short badge that never outgrows the column beside the ring, its reason under it
      // wrapping (the whole sentence in the badge pushed the page past the screen's edge).
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        Badge(L10n.Home.cleanBadge, color: Palette.profitText)
        caption(Text(L10n.Home.cleanNote))
      }
      .accessibilityElement(children: .combine)
    case .notClean:
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        Badge(L10n.Home.needsLookBadge, color: Palette.warningText)
        caption(Text(L10n.Home.notClean(
          clean.causes.first.map { ApiText.prose($0.textCodes, text: $0.text) } ?? Format.missing, clean.causes.count)))
      }
      .accessibilityElement(children: .combine)
    case .unknown:
      caption(Text(L10n.Home.cleanUnknown(ApiText.prose(clean.causeCodes, text: clean.cause) ?? Format.missing)))
    }
  }

  private func caption(_ text: Text) -> some View {
    text
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
