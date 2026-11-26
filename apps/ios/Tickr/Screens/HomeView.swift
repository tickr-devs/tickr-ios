import SwiftUI
import TickrDesign
import TickrKit

/// The first screen (IOSHome board): the one line that says what the bot is doing, the day's
/// result, the day's events as a ticker, open positions, today's funnel and the fast movers. The
/// power button opens bot control.
struct HomeView: View {
  /// Order in which the blocks rise in (`rise(step:)`); open positions follow one step apart.
  private enum Order: Int { case day = 1, summary, ticker, positions, flow = 6, movers }

  @Environment(AppModel.self) private var model
  @State private var showControl = false
  @State private var prices = Container.shared.positionsModel()
  @State private var dayModel = Container.shared.homeDayModel()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    } content: {
      if model.connection.demo {
        // Every command from here goes to the demo day: said at the top, as loud as a warning.
        WarningBanner(L10n.Home.demoTitle, detail: L10n.Home.demoDetail, systemImage: SettingsView.demoSymbol)
      }
      DayLine(days: dayModel).rise(step: Order.day.rawValue)
      Summary(past: dayModel.shown).rise(step: Order.summary.rawValue)
      if model.status == nil && model.connectionState.isNeverConnected {
        // Nothing was ever read: the cards keep their titles over a quiet outline, never a
        // "no position" or zero we do not know (mockup "no connection" v2).
        OfflineCard(L10n.App.positions).rise(step: Order.positions.rawValue)
        OfflineCard(L10n.Watching.title).rise(step: Order.flow.rawValue)
      } else if !model.isLive, let status = model.status {
        // A recorded day: its result above, then what it recorded (the flow, its fast movers);
        // nothing live (no positions, quotes or fences of today).
        Text(L10n.Home.pastDayNote(DayText.day(model.shownDay.noonInNewYork)))
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Tokens.Space.l)
          .tickrCard()
          .rise(step: Order.positions.rawValue)
        let dayFlow = model.flow?.day == model.shownDay ? model.flow : nil
        LiveFlowCard(status: status, flow: dayFlow, flowPending: model.flowPending,
          current: false, recorded: true,
          sources: StageSources(flow: dayFlow, skipped: model.skipped?.day == model.shownDay ? model.skipped : nil,
            watching: nil, status: nil, settings: model.settings),
          symbols: model.symbols?.day == model.shownDay ? model.symbols : nil)
          .rise(step: Order.flow.rawValue)
        FastMoversCard(movers: model.movers?.day == model.shownDay ? model.movers : nil, failure: model.moversError)
          .rise(step: Order.movers.rawValue)
      } else if let status = model.status {
        if let strip = EventStrip.make(status: status,
          skipped: model.skipped?.day == model.today ? model.skipped : nil) {
          strip.moving(ornamentMoves).rise(step: Order.ticker.rawValue)
        }
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
        // Own entry orders working with nothing filled, and those just cancelled (mockup v160).
        let entries = model.entryRows
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
          EntryCard(row: entry).rise(step: Order.positions.rawValue + status.positions.count + index)
        }
        if status.positions.isEmpty && entries.isEmpty {
          Text(L10n.Home.noPosition)
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Space.l)
            .tickrCard()
            .rise(step: Order.positions.rawValue)
        }
        let todayFlow = model.flow?.day == model.today ? model.flow : nil
        let todaySkipped = model.skipped?.day == model.today ? model.skipped : nil
        let current = model.isFresh && WireDate(newYorkDateOf: status.writtenAt.date) == model.today
        LiveFlowCard(status: status, flow: todayFlow, flowPending: model.flowPending,
          current: current, recorded: false,
          // The status only while it is current, as the stages' own values.
          sources: StageSources(flow: todayFlow, skipped: todaySkipped, watching: nil,
            status: current ? status : nil, settings: model.settings),
          symbols: model.symbols?.day == model.today ? model.symbols : nil)
          .rise(step: Order.flow.rawValue)
        FastMoversCard(movers: model.movers?.day == model.today ? model.movers : nil, failure: model.moversError)
          .rise(step: Order.movers.rawValue)
      }
    }
    .botControl(isPresented: $showControl)
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

/// The session the status describes, centred between blue arrows as on the design: "today" only
/// when it is today's New York date on the bot's clock, else the last session (a weekend, a day off),
/// which is never shown as live. On a recorded day the way back to today sits under it.
private struct DayLine: View {
  @Environment(AppModel.self) private var model
  let days: HomeDayModel

  var body: some View {
    VStack(spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        if days.locked {
          // The demo day is the only day: no arrows; the header's environment badge says DEMO.
          dayText
        } else if arrows.visible {
          // The arrow that leads nowhere is dimmed and refuses taps ("dimmed" to VoiceOver).
          Button { days.back() } label: { arrow(Symbols.previous) }
            .disabled(!arrows.canGoBack)
            .accessibilityLabel(Text(L10n.Home.previousDay))
          dayText
          Button { days.forward() } label: { arrow(Symbols.next) }
            .disabled(!arrows.canGoForward)
            .accessibilityLabel(Text(L10n.Home.nextDay))
        } else {
          // No other recorded day to step to: no arrows that would do nothing.
          dayText
        }
      }
      if days.shown != nil {
        TodayButton(L10n.Home.backToToday) { days.showToday() }
      }
    }
    .font(Tokens.Typography.captionMono)
    .foregroundStyle(Palette.textPrimary)
    .buttonStyle(.glyph)
    .animation(Tokens.Motion.standard, value: days.shown)
  }

  private var arrows: DayArrows { days.arrows }

  private func arrow(_ symbol: String) -> some View {
    HeaderIcon(symbol: symbol).foregroundStyle(Palette.textPrimary).dimmedWhenDisabled()
  }

  /// The day, centred in the room between the arrows.
  private var dayText: some View {
    day
      .frame(maxWidth: .infinity)
      .multilineTextAlignment(.center)
      // Wraps as far as it needs ("vie 13 nov · hoy" at large sizes), never cut.
      .fixedSize(horizontal: false, vertical: true)
  }

  /// The shown day: a recorded one, today or the last session.
  @ViewBuilder
  private var day: some View {
    let written = model.status?.writtenAt.date ?? model.botNow
    let isToday = WireDate(newYorkDateOf: written) == model.today
    if let past = days.shown {
      Text(verbatim: DayText.day(past.day.noonInNewYork))
        .foregroundStyle(Palette.highlightText)
    } else {
      Text(isToday ? L10n.Common.today(DayText.day(written)) : L10n.Activity.lastSession(DayText.day(written)))
    }
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
  static let entriesNotNowSymbol = "moon.fill"
  static let entriesBlockedSymbol = "hand.raised.fill"

  /// Whether new entries can open, as on the board: allowed, paused by the owner, a calm
  /// "not now" (outside the session) or blocked; the gate, when closed, has its own glyph. The
  /// bot's own entry block decides, in its precedence: a stopped bot outranks the owner's pause.
  static func make(_ status: StatusV1) -> (symbol: String, tone: Tone, label: LocalizedStringResource) {
    guard let block = status.entryBlock else { return (entriesAllowedSymbol, .profit, L10n.Home.entriesAllowed) }
    if BlockCode(rawValue: block.cause) == .entryStop { return (Symbols.pause, .warning, L10n.Home.entriesPaused) }
    if status.entriesCalm { return (entriesNotNowSymbol, .neutral, L10n.Home.entriesNotNow(ApiText.entryBlock(block))) }
    return (entriesBlockedSymbol, .warning, L10n.Home.entriesBlocked(ApiText.entryBlock(block)))
  }
}

/// The headline on its own row, and under it the ring with the day's result.
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
        ring(stats: stats, result: result)
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          if stats?.beforeFees == true {
            // The ring's result does not count the broker's fees yet; wraps rather than cuts.
            Text(L10n.Home.beforeFees)
              .font(.footnote)
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
          .font(.headline)
          .foregroundStyle(Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          if let past {
            CleanLine(clean: past.clean)
          } else if let status = model.status {
            if let limit = model.settings?.risk.maxOpenPositions {
              Text(L10n.Home.slotsFree(max(0, limit - status.positions.count), limit))
                .font(.subheadline)
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
      .font(.footnote)
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

  /// The day's result in its ring.
  private func ring(stats: Board.DayStats?, result: Decimal) -> some View {
    // Wins in the accent, then losses in the money-loss pink: a day of losses only is a pink
    // ring, not an empty one.
    ResultRing(fraction: stats?.winShare ?? 0, color: Palette.accent,
      trailing: stats?.lossShare ?? 0, trailingColor: Palette.seriesATR,
      halo: result < 0 ? Palette.seriesATR : Palette.accent, lineWidth: Self.ringLine) {
      VStack(spacing: Tokens.Space.xxs) {
        CardLabel(past == nil ? L10n.Home.today : L10n.Home.day)
        if stats == nil {
          // No day was read: a dash, never a $0.00 we do not know.
          Text(verbatim: Format.missing)
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textQuaternary)
        } else {
          // Counts up from zero as the ring appears and on to each new result (the board's count).
          CountingText(NSDecimalNumber(decimal: result).doubleValue, period: model.shownDay) { Money.signedUSD(Decimal($0)) }
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.result(result))
            // One line at its full size; the ring grows around it.
            .fixedSize()
        }
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
              .font(.headline.monospaced())
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

/// Today's funnel as on the board (IOSHome): the stages a setup passes as a 3×3 grid of tiles,
/// each with its glowing dot and name, what the bot reports for it, how many symbols it dropped
/// today ("−144") and a chevron to every symbol at the stage; "Risk ›" in the header.
/// A status that is stale, failed or from an earlier session shows still, faint dots and says so.
/// Its header link opens Risk (the room and why entries are blocked).
private struct LiveFlowCard: View {
  let status: StatusV1
  /// Today's flow: stage counts and the day's stops; nil until read.
  let flow: FlowV1?
  /// The first /flow read has not answered yet: the stages show a placeholder, not the status's
  /// numbers they would jump from.
  let flowPending: Bool
  /// The status is fresh and describes today's session.
  let current: Bool
  /// A recorded past day: every value comes from that day's flow and symbols, nothing from the
  /// status (today's), and nothing is live.
  let recorded: Bool
  /// What the reconcile stage's detail is built from (`StageDetail`).
  let sources: StageSources
  /// Today's symbols by the stage they got to: the Quote and Bars counts; nil until read.
  let symbols: SymbolsV1?

  /// The stages, in the order a setup passes them.
  private enum StageID: Int, CaseIterable {
    case screen = 0, stocks, quote, bars, strategy, risk, order, stop, reconcile

    /// The flow stage whose symbols sit under this one as dots; nil for a stage the flow does
    /// not place symbols at.
    var flowStage: FlowStage? {
      switch self {
      case .screen: .screeners
      case .stocks: .universe
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      case .quote, .bars, .reconcile: nil
      }
    }

    /// The stage of the detail a tap opens.
    var pipeline: PipelineStage {
      switch self {
      case .screen: .screeners
      case .stocks: .universe
      case .quote: .quote
      case .bars: .bars
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      case .reconcile: .reconcile
      }
    }

    /// The Symbols screen's tab a tap opens: every symbol at this stage today; nil for reconcile,
    /// whose detail opens in a popover.
    var tab: SymbolsTab? { SymbolsTab(pipeline) }

    /// The symbols' stage whose dropped rows this stage counts; nil for reconcile, which drops none.
    var symbolStage: SymbolStage? {
      switch self {
      case .screen: .screeners
      case .stocks: .universe
      case .quote: .quote
      case .bars: .bars
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      case .reconcile: nil
      }
    }
  }

  /// The stage whose detail is open in a popover (reconcile, which holds no symbol list).
  @State private var openStage: StageID?
  @Environment(\.dynamicTypeSize) private var typeSize

  /// Stages per row of the funnel's grid (the design's 3×3).
  static let gridColumns = 3
  /// Least height of a stage tile, in points (the board's `.stg2`, 52 px).
  static let tileHeight: CGFloat = 52

  private struct Stage: Identifiable {
    let id: StageID
    let name: LocalizedStringResource
    /// nil = the API does not report this stage yet.
    let value: String?
    let color: Color
    /// A blocked entry or an unprotected position from the status: shown at once, never under
    /// the placeholder that waits for the first /flow read.
    var urgent = false
    /// A state under the value that must stay visible next to the day's count ("blocked",
    /// "not now"), in `flagColor`.
    var flag: LocalizedStringResource?
    var flagColor = Palette.textQuaternary
  }

  private var stages: [Stage] {
    let positions = recorded ? [] : status.positions
    let verified = positions.filter { $0.stop.state.isProtected }.count
    let flowVerified = flow?.stops.filter { $0.state == .verified }.count
    // The one stage rule of both apps (`StopState.stageTone`): neutral with no position, else the
    // worst of the open and the day's stops.
    let stopTone = StopState.stageTone(open: positions.map(\.stop.state), day: (flow?.stops ?? []).map(\.state))
    guard current || recorded else {
      // Nothing here is live: no counts, no green, nothing breathing.
      return StageID.allCases.map { id in
        Stage(id: id, name: Self.names[id.rawValue], value: nil, color: Palette.textQuaternary)
      }
    }
    // An open position waiting for its stop shows first; then the day's stops from the flow.
    let stops: String? = if verified < positions.count || flow?.stops.isEmpty != false {
      positions.isEmpty ? nil : Self.stops(verified, of: positions.count)
    } else {
      flow.map { Self.stops(flowVerified ?? 0, of: $0.stops.count) }
    }
    // The day's count stays; an entry block shows under it, red when it needs the operator.
    let blocked = !recorded && !status.entriesAllowed && !status.entriesCalm
    let riskCount = count(.risk)
    // With a flow, every count comes from it; the status's numbers only stand in when /flow failed,
    // and never for a recorded day (they are today's).
    let fromStatus = flow == nil && !recorded
    let allowed = recorded || status.entriesAllowed
    return [
      Stage(id: .screen, name: L10n.Flow.screen, value: count(.screeners), color: Palette.accent),
      Stage(id: .stocks, name: L10n.Flow.stocks, value: count(.universe), color: Palette.seriesUniverse),
      Stage(id: .quote, name: L10n.FlowStages.quote, value: reached(.quote), color: Palette.accentText),
      Stage(id: .bars, name: L10n.FlowStages.bars, value: reached(.bars), color: Palette.info),
      Stage(id: .strategy, name: L10n.Flow.strategy,
        value: count(.strategy) ?? (fromStatus ? status.strategy.version : nil), color: Palette.highlight),
      Stage(id: .risk, name: L10n.Flow.risk,
        value: riskCount ?? (fromStatus && status.entriesAllowed ? RiskFormat.amount(status.dailyRoomUsd?.value) : nil),
        color: blocked ? Palette.loss : allowed ? Palette.warning : Palette.textQuaternary,
        urgent: blocked,
        flag: allowed ? nil : blocked ? L10n.Flow.blocked : L10n.Risk.notNow,
        flagColor: blocked ? Palette.lossText : Palette.textQuaternary),
      Stage(id: .order, name: L10n.Flow.order,
        value: count(.order) ?? (fromStatus ? String(status.tradesToday.count) : nil), color: Palette.info),
      Stage(id: .stop, name: L10n.Flow.stop, value: stops ?? Format.missing,
        color: stopTone.fill, urgent: verified < positions.count),
      reconcileStage,
    ]
  }

  /// Live fences first (the status is newer than any reconciliation), then the latest
  /// reconciliation's match or mismatch; without one, no value (never read as fine).
  private var reconcileStage: Stage {
    let fences = liveFences
    let agreement = flow?.reconcile.agreement
    let value: LocalizedStringResource? = if !fences.isEmpty {
      L10n.FlowStages.fences(fences.count)
    } else {
      switch agreement {
      case .match: L10n.FlowStages.match
      case .mismatch: L10n.FlowStages.mismatch
      case nil: nil
      }
    }
    let agrees = fences.isEmpty && agreement == .match
    return Stage(id: .reconcile, name: L10n.FlowStages.reconcile, value: value.map { String(localized: $0) },
      color: value == nil ? Palette.textQuaternary : agrees ? Palette.profit : Palette.loss,
      urgent: !fences.isEmpty || agreement == .mismatch)
  }

  /// "2/2 ✓" only when every stop is verified; otherwise the bare count, never a check mark.
  private static func stops(_ verified: Int, of total: Int) -> String {
    String(localized: verified == total ? L10n.Flow.stopsVerified(verified, total) : L10n.Flow.stopsCount(verified, total))
  }

  /// How many symbols got to `stage` today (GET /symbols); nil until the symbols are read.
  private func reached(_ stage: SymbolStage) -> String? {
    symbols?.stages.first { $0.stage == stage }.map { $0.count.formatted() }
  }

  /// How many symbols `stage` dropped today (the Symbols screen's "dropped here" rows); nil until
  /// the symbols are read, or for a stage that drops none.
  private func dropped(_ stage: StageID) -> Int? {
    guard current || recorded, let symbols, let here = stage.symbolStage else { return nil }
    let count = symbols.rows.filter { $0.stage == here && $0.state == .dropped }.count
    return count > 0 ? count : nil
  }

  /// How many symbols reached `stage` today; nil until the flow is read.
  private func count(_ stage: FlowStage) -> String? {
    flow?.stages.first { $0.stage == stage }.map { $0.count.formatted() }
  }

  var body: some View {
    // Only the header's link opens Risk: a whole-card link would swallow the stages' taps and host
    // their popovers inside its label.
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      // As on the board: the label with the key to the tiles' pink counts, and the link to Risk.
      // The quote stream is in the age line beside the ring; the broker read in the reconcile
      // stage's detail. At large text sizes the link takes the line under the label.
      RowStack {
        ChipFlow(spacing: Tokens.Space.s) {
          CardLabel(recorded ? L10n.Flow.titleRecorded : L10n.Flow.title)
          Text(L10n.Flow.droppedKey)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.droppedText)
          if !current && !recorded {
            Text(L10n.Flow.notCurrent)
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.warningText)
          }
        }
        Spacer(minLength: 0)
        NavigationLink {
          RiskView()
        } label: {
          HeaderLinkLabel(L10n.Home.riskLink)
        }
        .buttonStyle(.headerLink())
        .fixedSize()
        .accessibilityIdentifier(AccessibilityID.risk)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      // A 3×3 grid of equal tiles, as in the design (a long value wraps inside its tile, never
      // widening it); at large text sizes one tile per row, so the names stay whole.
      let columns = typeSize.stacksRows ? 1 : Self.gridColumns
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s, alignment: .top),
        count: columns), alignment: .leading, spacing: Tokens.Space.s) {
        ForEach(stages) { stage in
          opens(stage) { tile(stage) }
        }
      }
      // Until the first /flow read answers, a placeholder instead of numbers that would jump.
      .redacted(reason: (current || recorded) && flowPending ? .placeholder : [])
      ForEach(liveFences, id: \.kind) { fence in
        Label { Text(verbatim: Board.fenceText(fence, status: status)) } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
        }
          .font(.caption)
          .foregroundStyle(Palette.warningText)
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .tickrCard()
  }

  /// Today's fences from the status; none on a recorded day.
  private var liveFences: [Fence] { recorded ? [] : status.fences }

  /// Stage names, in `StageID` order.
  private static let names = [L10n.Flow.screen, L10n.Flow.stocks, L10n.FlowStages.quote, L10n.FlowStages.bars,
    L10n.Flow.strategy, L10n.Flow.risk, L10n.Flow.order, L10n.Flow.stop, L10n.FlowStages.reconcile]

  /// A stage as a button: a tap anywhere on it (its dot, name, value, dots or tray) pushes the
  /// Symbols screen on its tab, every symbol at the stage today; reconcile, which holds no symbol
  /// list, opens its detail in a popover that stays until dismissed (HIG). The stage's colour
  /// washes behind it while the finger is down.
  @ViewBuilder
  private func opens(_ stage: Stage, @ViewBuilder label: () -> some View) -> some View {
    if let tab = stage.id.tab {
      NavigationLink {
        SymbolsView(tab: tab)
      } label: {
        label().contentShape(Rectangle())
      }
      .buttonStyle(.washPress(stage.color))
      .accessibilityElement(children: .combine)
      .accessibilityHint(Text(L10n.FlowStages.symbolsHint))
    } else {
      popover(stage, label: label)
    }
  }

  private func popover(_ stage: Stage, @ViewBuilder label: () -> some View) -> some View {
    Button {
      openStage = stage.id
    } label: {
      label().contentShape(Rectangle())
    }
    .buttonStyle(.washPress(stage.color))
    .accessibilityElement(children: .combine)
    .accessibilityHint(Text(L10n.Flow.stageDetailsHint))
    // Above the stage (the card sits low on Home): the popover then has the screen's width and
    // never clips at the sides.
    .popover(isPresented: Binding(get: { openStage == stage.id }, set: { if !$0 { openStage = nil } }),
      attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
      StageDetailView(name: stage.name, color: stage.color, stage: stage.id.pipeline, sources: sources)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Palette.surface)
    }
  }

  /// A stage as the board's tile: its dot, name and the chevron of the screen it opens, then its
  /// value on a line of its own, then the symbols it dropped today ("−1,243", pink) and a flag
  /// ("blocked", "not now"). A number never wraps inside the narrow tile ("168/2"): each keeps
  /// its line, and the tile grows instead.
  /// A stage's name on the tile, kept whole.
  private func stageName(_ stage: Stage) -> some View {
    Text(stage.name)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize()
  }

  /// The chevron of the screen a tile opens.
  private var stageChevron: some View {
    Image(systemName: Symbols.next)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(Palette.textQuaternary)
      .accessibilityHidden(true)
  }

  private func tile(_ stage: Stage) -> some View {
    let lit = stage.value != nil || stage.flag != nil
    let dropped = dropped(stage.id)
    return VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      // The name never breaks inside a word ("recon-/cile"): when it does not fit beside the dot
      // and the chevron, it takes a line of its own under them.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.xs) {
          FlowDot(color: stage.color, lit: lit, event: stage.value)
          stageName(stage)
          Spacer(minLength: 0)
          stageChevron
        }
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack(spacing: Tokens.Space.xs) {
            FlowDot(color: stage.color, lit: lit, event: stage.value)
            Spacer(minLength: 0)
            stageChevron
          }
          stageName(stage)
        }
      }
      if stage.value != nil || stage.flag == nil {
        Text(verbatim: stage.value ?? Format.missing)
          .font(.subheadline.monospaced().bold())
          .foregroundStyle(stage.value == nil ? Palette.textQuaternary : Palette.textPrimary)
          .contentTransition(.numericText())
          .fixedSize()
      }
      if dropped != nil || stage.flag != nil {
        ChipFlow(spacing: Tokens.Space.xs) {
          if let dropped {
            Text(L10n.Flow.dropped(dropped))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.droppedText)
              .fixedSize()
              .accessibilityLabel(Text(L10n.Flow.droppedCount(dropped)))
          }
          if let flag = stage.flag {
            Badge(flag, color: stage.flagColor)
          }
        }
      }
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.s)
    .frame(maxWidth: .infinity, minHeight: Self.tileHeight, alignment: .topLeading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
        .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
    .unredacted(when: stage.urgent)
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

private extension View {
  /// Shows the view even under a placeholder redaction when `urgent`.
  @ViewBuilder func unredacted(when urgent: Bool) -> some View {
    if urgent { unredacted() } else { self }
  }
}

/// A live-flow stage: a glowing dot, faint for an unreported stage. It moves only on a real
/// event: one pulse each time the stage's value changes (a new count, a verified stop).
private struct FlowDot: View {
  let color: Color
  let lit: Bool
  /// The stage's value; a change plays one pulse.
  let event: String?

  /// Diameter of the dot and blur of its glow, in points.
  static let size: CGFloat = 11
  static let glow: CGFloat = 6

  var body: some View {
    PulseDot(color, size: Self.size, pulsing: lit, event: event)
      .shadow(color: lit ? color : .clear, radius: Self.glow)
      .opacity(lit ? 1 : Tokens.Opacity.faint)
      .accessibilityHidden(true)
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
