import SwiftUI
import TickrDesign
import TickrKit

/// The first screen: the day's result, the one line that says what the bot is doing, live events,
/// open positions and the live flow. The power button opens bot control.
struct HomeView: View {
  /// Order in which the blocks rise in (`rise(step:)`); open positions follow one step apart.
  private enum Order: Int { case day = 1, summary, ticker, positions, flow = 6 }

  @Environment(AppModel.self) private var model
  @State private var showControl = false
  @State private var prices = Container.shared.positionsModel()
  @State private var dayModel = Container.shared.homeDayModel()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Whether Home's looping ornaments (the brand mark's halo, the ticker's scroll) move: they read
  /// as "the bot is at work", so only on the live day with a fresh status while the bot runs.
  private var ornamentMoves: Bool {
    guard dayModel.shown == nil else { return false }
    return OrnamentGate.moves(reduceMotion: reduceMotion, current: model.showsLiveStatus,
      botState: model.status?.botState)
  }

  var body: some View {
    Screen(L10n.App.name, tab: .home) {
      // The mark the opening animation flies into (LaunchHandoff); it pulses while data is current.
      BrandMark(size: Tokens.Size.glyph, live: ornamentMoves)
        .onGeometryChange(for: CGPoint.self) { proxy in
          let frame = proxy.frame(in: .global)
          return CGPoint(x: frame.midX, y: frame.midY)
        } action: { centre in
          model.homeMarkCentre = centre
        }
    } actions: {
      if let environment = model.status?.environment {
        EnvironmentBadge(environment: environment)
      }
      Button {
        showControl = true
      } label: {
        HeaderIcon(.power)
          .foregroundStyle(model.canCommand && dayModel.shown == nil ? powerTint : Palette.textQuaternary)
      }
      .disabled(!model.canCommand || dayModel.shown != nil)
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
      if let past = dayModel.shown {
        // A recorded day: its result above, nothing live below.
        Text(L10n.Home.pastDayNote(Format.day(past.day.noonInNewYork)))
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(Tokens.Space.l)
          .tickrCard()
          .rise(step: Order.positions.rawValue)
      } else if let status = model.status {
        if let strip = EventStrip.make(status: status,
          skipped: model.skipped?.day == model.today ? model.skipped : nil) {
          strip.moving(ornamentMoves).rise(step: Order.ticker.rawValue)
        }
        ForEach(Array(Board.positions(status).enumerated()), id: \.element.symbol) { index, position in
          PositionRow(position: position, marks: prices.marks[position.symbol])
            .rise(step: Order.positions.rawValue + index)
        }
        if status.positions.isEmpty {
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
          slotLimit: model.settings?.risk.maxOpenPositions,
          marks: FlowBoard.marks(flow: todayFlow, skipped: todaySkipped, positions: status.positions),
          current: current,
          // The status only while it is current, as the stages' own values.
          sources: StageSources(flow: todayFlow, skipped: todaySkipped, watching: nil,
            status: current ? status : nil, settings: model.settings))
          .rise(step: Order.flow.rawValue)
      }
    }
    .botControl(isPresented: $showControl)
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
  /// Symbols of the arrows to the previous and next day.
  static let previousSymbol = "chevron.left"
  static let nextSymbol = "chevron.right"

  @Environment(AppModel.self) private var model
  let days: HomeDayModel

  /// Accessibility id of the DEMO chip, for the UI tests.
  static let demoChipID = "home-demo"

  var body: some View {
    VStack(spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        if days.locked {
          // The demo day is the only day: no arrows. An invisible twin of the DEMO chip on the
          // left keeps the day centred.
          demoChip
            .hidden()
            .accessibilityHidden(true)
          dayText
          demoChip
            .accessibilityIdentifier(Self.demoChipID)
        } else if arrows.visible {
          // The arrow that leads nowhere is dimmed and refuses taps ("dimmed" to VoiceOver).
          Button { days.back() } label: { arrow(Self.previousSymbol) }
            .disabled(!arrows.canGoBack)
            .accessibilityLabel(Text(L10n.Home.previousDay))
          dayText
          Button { days.forward() } label: { arrow(Self.nextSymbol) }
            .disabled(!arrows.canGoForward)
            .accessibilityLabel(Text(L10n.Home.nextDay))
        } else {
          // No other recorded day to step to: no arrows that would do nothing.
          dayText
        }
      }
      if days.shown != nil {
        Button { days.showToday() } label: { Text(L10n.Home.backToToday) }
          .foregroundStyle(Palette.infoText)
      }
    }
    .font(Tokens.Typography.captionMono)
    .foregroundStyle(Palette.textPrimary)
    .buttonStyle(.borderless)
    .animation(Tokens.Motion.standard, value: days.shown)
  }

  private var arrows: DayArrows { days.arrows }

  private func arrow(_ symbol: String) -> some View {
    HeaderIcon(symbol: symbol).foregroundStyle(Palette.textPrimary).dimmedWhenDisabled()
  }

  /// The day, centred in the room between the arrows (or the DEMO chips).
  private var dayText: some View {
    day
      .frame(maxWidth: .infinity)
      .multilineTextAlignment(.center)
      // Wraps as far as it needs ("Пт 13 нояб. · сегодня" at large sizes), never cut.
      .fixedSize(horizontal: false, vertical: true)
  }

  private var demoChip: some View {
    Badge(L10n.Home.demoChip, tone: .warning)
  }

  /// The shown day: a recorded one, today or the last session.
  @ViewBuilder
  private var day: some View {
    let written = model.status?.writtenAt.date ?? model.botNow
    let isToday = WireDate(newYorkDateOf: written) == model.today
    if let past = days.shown {
      Text(verbatim: Format.day(past.day.noonInNewYork))
        .foregroundStyle(Palette.highlightText)
    } else {
      Text(isToday ? L10n.Common.today(Format.day(written)) : L10n.Activity.lastSession(Format.day(written)))
    }
  }
}

/// The status's age under Home's summary ("updated 3 s ago"), after the connection's own health
/// dot: green while fresh statuses arrive, amber when the status is stale, red with no status or a
/// failed read. Only a fresh status of today pulses, and only when the health changes.
private struct AgeLine: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    let written = model.status?.writtenAt.date ?? model.botNow
    let isToday = WireDate(newYorkDateOf: written) == model.today
    let fresh = model.response?.stale == false && model.fetchError == nil
    let freshness = ConnectionFreshness.color(response: model.response, fetchError: model.fetchError)
    HStack(spacing: Tokens.Space.xs) {
      PulseDot(freshness, size: Tokens.Size.dotSmall, pulsing: isToday && fresh, event: freshness)
      Text(Format.age(model.response))
        .contentTransition(.numericText())
        .fixedSize(horizontal: false, vertical: true)
    }
    .font(Tokens.Typography.annotation)
    .foregroundStyle(Palette.textQuaternary)
  }
}

/// The colour of Home's connection dot.
enum ConnectionFreshness {
  /// Red without an answer or after a failed read, amber while the status is stale, green while it
  /// is current.
  static func color(response: StatusResponseV1?, fetchError: String?) -> Color {
    guard let response, fetchError == nil else { return Palette.loss }
    return response.stale ? Palette.warning : Palette.profit
  }
}

/// The Home glyph for whether new entries can open.
enum EntriesGlyph {
  /// Symbols of the entries glyph: allowed, paused by the owner, calm "not now", blocked.
  static let entriesAllowedSymbol = "lock.open.fill"
  static let entriesPausedSymbol = "pause.fill"
  static let entriesNotNowSymbol = "moon.fill"
  static let entriesBlockedSymbol = "hand.raised.fill"

  /// Whether new entries can open, as on the board: allowed, paused by the owner, a calm
  /// "not now" (outside the session) or blocked; the gate, when closed, has its own glyph. The
  /// bot's own entry block decides, in its precedence: a stopped bot outranks the owner's pause.
  static func make(_ status: StatusV1) -> (symbol: String, tone: Tone, label: LocalizedStringResource) {
    guard let block = status.entryBlock else { return (entriesAllowedSymbol, .profit, L10n.Home.entriesAllowed) }
    if BlockCode(rawValue: block.cause) == .entryStop { return (entriesPausedSymbol, .warning, L10n.Home.entriesPaused) }
    if status.entriesCalm { return (entriesNotNowSymbol, .neutral, L10n.Home.entriesNotNow(ApiText.entryBlock(block))) }
    return (entriesBlockedSymbol, .warning, L10n.Home.entriesBlocked(ApiText.entryBlock(block)))
  }
}

/// The ring with the day's result next to the headline.
private struct Summary: View {
  /// Side of the result ring and the width of its track and arc, in points.
  static let ringSide: CGFloat = 136
  static let ringLine: CGFloat = 10
  /// Width of the ring's figures as a share of its side: the square inside the circle.
  static let innerShare: CGFloat = 0.7
  /// Symbol of a closed trading gate.
  static let gateClosedSymbol = "lock.fill"

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
    // Without any status the connection card above shows the failure; the headline does not repeat it.
    let unreachable = model.status == nil && model.fetchError != nil
    let text = past != nil ? String(localized: L10n.Home.recordedDay)
      : unreachable ? String(localized: L10n.Home.statusUnknown) : headline.text
    let tint = past == nil ? headline.severity.tint : Palette.highlightText
    // A stale status's text counts its age; read again it is no new event.
    let pulse: Headline.Pulse = past == nil ? headline.pulse : .text(text)
    RowStack(spacing: Tokens.Space.l) {
      ResultRing(fraction: stats?.winShare ?? 0, color: result < 0 ? Palette.seriesATR : Palette.accent,
        lineWidth: Self.ringLine) {
        VStack(spacing: Tokens.Space.xxs) {
          CardLabel(L10n.Home.day)
          // Counts up from zero as the ring appears and on to each new result (the board's count).
          CountingText(NSDecimalNumber(decimal: result).doubleValue) { Money.signed(Decimal($0)) }
            .font(Tokens.Typography.metric)
            .foregroundStyle(result < 0 ? Palette.seriesATRText : Palette.profitText)
            // One line at its full size; the ring grows around it.
            .fixedSize()
          Group {
            if let stats {
              Text(L10n.Common.winsLosses(stats.wins, stats.losses))
            } else {
              Text(verbatim: Format.missing)
            }
          }
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .multilineTextAlignment(.center)
          // "1 в плюс · 5 в минусе" wraps in Russian, never cut.
          .fixedSize(horizontal: false, vertical: true)
        }
        // Inside the ring's opening at every text size ("4 W · 7 L" ran past it).
        .frame(minWidth: 0, maxWidth: ringSide * Self.innerShare)
        .padding(Tokens.Space.l)
      }
      // Beside the headline the ring keeps its scaled side, growing only when its figures need
      // more; stacked above it at large text sizes, it stops growing at the screen's width, so it
      // is never cut and never widens the page.
      .frame(minWidth: typeSize.stacksRows ? nil : ringSide, minHeight: typeSize.stacksRows ? nil : ringSide)
      .aspectRatio(1, contentMode: .fit)
      .frame(maxWidth: ringSide)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(Text(L10n.Home.dayResult(Money.signedUSD(result), stats?.wins ?? 0, stats?.losses ?? 0)))

      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          PulseDot(tint, pulsing: past == nil && (headline.severity != .ok || model.response?.stale == false),
            event: pulse)
          Text(verbatim: text)
            .font(.subheadline.bold())
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
        }
        if stats?.beforeFees == true {
          // The ring's result does not count the broker's fees yet; wraps rather than cuts.
          Text(L10n.Home.beforeFees)
            .font(.footnote)
            .foregroundStyle(Palette.warningText)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let past {
          Text(L10n.Home.recordedNote)
            .font(.footnote)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
          CleanLine(clean: past.clean)
        } else if let status = model.status {
          // Each position's protection and the gate as glyphs; the words are in their hints.
          HStack(spacing: Tokens.Space.xs) {
            ForEach(status.positions, id: \.symbol) { position in
              StopGlyph(state: position.stop.state, symbol: position.symbol, price: position.stop.price)
            }
            if !status.tradingGate.open {
              StateGlyph(Self.gateClosedSymbol, tone: .warning,
                label: L10n.Home.gateClosed(ApiText.gate(status.tradingGate)), style: .compact)
            } else {
              let entries = EntriesGlyph.make(status)
              StateGlyph(entries.symbol, tone: entries.tone, label: entries.label, style: .compact)
            }
            Badge(keepingCase: status.codeVersion.map { L10n.Home.versionCode(status.strategy.version, CodeVersion.short($0)) }
              ?? L10n.Common.version(status.strategy.version), tone: .highlight)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(Text(verbatim: subline(status)))
          AgeLine()
        }
      }
      .animation(Tokens.Motion.standard, value: pulse)
    }
  }

  private func subline(_ status: StatusV1) -> String {
    var parts: [LocalizedStringResource] = []
    for position in status.positions {
      parts.append(position.stop.state.isProtected
        ? L10n.Home.protected(position.symbol)
        : L10n.Home.stopIs(position.symbol, Board.stopStateTitle(position.stop.state)))
    }
    parts.append(L10n.Home.strategy(status.strategy.name, status.strategy.version))
    if let code = status.codeVersion {
      parts.append(L10n.Home.codeVersion(CodeVersion.short(code)))
    }
    parts.append(status.tradingGate.open
      ? EntriesGlyph.make(status).label : L10n.Home.gateClosed(ApiText.gate(status.tradingGate)))
    return parts.map { String(localized: $0) }.joined(separator: " ")
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
            Text(verbatim: position.symbol)
              .font(.headline.monospaced())
              .foregroundStyle(Palette.textPrimary)
              .fixedSize()
          }
          Label {
            Text(verbatim: position.stop.price.map { Money.price($0.value) } ?? Format.missing)
          } icon: {
            Image(systemName: StopGlyph.levelSymbol)
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
              DrawnSparkline(values: marks.closes.map { NSDecimalNumber(decimal: $0).doubleValue },
                color: current ? Palette.accent : Palette.textQuaternary)
                .frame(width: Self.sparkWidth, height: Self.sparkHeight)
                .accessibilityHidden(true)
              if current {
                Text(L10n.Positions.last(Money.price(marks.last)))
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
              DeltaTag(marks.unrealized, text: Money.signed(marks.unrealized))
            } else {
              Text(verbatim: Money.signed(marks.unrealized))
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
          Image(systemName: DayLine.nextSymbol)
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

/// The live flow as on the design: the stages a setup passes, each a dot in its colour with what
/// the bot reports for it, today's symbols as small dots under the stage they reached (a dot moves
/// on only when a new read moves it), and the bot's inputs (quote stream, last broker read) below.
/// A status that is stale, failed or from an earlier session shows still, faint dots and says so.
/// Tapping it opens Risk (the room and why entries are blocked).
private struct LiveFlowCard: View {
  let status: StatusV1
  /// Today's flow: stage counts and the day's stops; nil until read.
  let flow: FlowV1?
  /// The first /flow read has not answered yet: the stages show a placeholder, not the status's
  /// numbers they would jump from.
  let flowPending: Bool
  /// The configured position slots; nil until the settings are read.
  let slotLimit: Int?
  /// Today's symbols, each at the furthest stage it reached; empty until the flow is read.
  let marks: [FlowMark]
  /// The status is fresh and describes today's session.
  let current: Bool
  /// What the stages' details are built from (`StageDetail`); the detail reads the watching rows.
  let sources: StageSources

  /// The stages, in the order a setup passes them.
  private enum StageID: Int {
    case screen = 0, stocks, strategy, risk, order, stop

    /// The flow stage whose symbols sit under this one.
    var flowStage: FlowStage {
      switch self {
      case .screen: .screeners
      case .stocks: .universe
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      }
    }

    /// The stage of the detail a tap opens.
    var pipeline: PipelineStage {
      switch self {
      case .screen: .screeners
      case .stocks: .universe
      case .strategy: .strategy
      case .risk: .risk
      case .order: .order
      case .stop: .stop
      }
    }
  }

  @Namespace private var board
  /// The stage whose detail is open in a popover (a tap on the stage, its dots or its tray).
  @State private var openStage: StageID?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize

  /// Symbol dots per row under a stage, and the most shown before "+N".
  static let poolColumns = 3
  static let poolCap = 9

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
    let positions = status.positions
    let verified = positions.filter { $0.stop.state.isProtected }.count
    // Green only while every open position's stop, and every stop of the day's trades the flow
    // knows, is verified at the broker.
    let flowVerified = flow?.stops.filter { $0.state == .verified }.count
    let allProtected = verified == positions.count && flowVerified == flow?.stops.count
    guard current else {
      // Nothing here is live: no counts, no green, nothing breathing.
      return [StageID.screen, .stocks, .strategy, .risk, .order, .stop].map { id in
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
    let blocked = !status.entriesAllowed && !status.entriesCalm
    let riskCount = count(.risk)
    // With a flow, every count comes from it; the status's numbers only stand in when /flow failed.
    let fromStatus = flow == nil
    return [
      Stage(id: .screen, name: L10n.Flow.screen, value: count(.screeners), color: Palette.accent),
      Stage(id: .stocks, name: L10n.Flow.stocks, value: count(.universe), color: Palette.seriesUniverse),
      Stage(id: .strategy, name: L10n.Flow.strategy,
        value: count(.strategy) ?? (fromStatus ? status.strategy.version : nil), color: Palette.highlight),
      Stage(id: .risk, name: L10n.Flow.risk,
        value: riskCount ?? (status.entriesAllowed ? RiskFormat.amount(status.dailyRoomUsd?.value) : nil),
        color: blocked ? Palette.loss : status.entriesAllowed ? Palette.warning : Palette.textQuaternary,
        urgent: blocked,
        flag: status.entriesAllowed ? nil : blocked ? L10n.Flow.blocked : L10n.Risk.notNow,
        flagColor: blocked ? Palette.lossText : Palette.textQuaternary),
      Stage(id: .order, name: L10n.Flow.order,
        value: count(.order) ?? (fromStatus ? String(status.tradesToday.count) : nil), color: Palette.info),
      Stage(id: .stop, name: L10n.Flow.stop, value: stops ?? Format.missing,
        color: allProtected ? Palette.profit : Palette.loss, urgent: verified < positions.count),
    ]
  }

  /// "2/2 ✓" only when every stop is verified; otherwise the bare count, never a check mark.
  private static func stops(_ verified: Int, of total: Int) -> String {
    String(localized: verified == total ? L10n.Flow.stopsVerified(verified, total) : L10n.Flow.stopsCount(verified, total))
  }

  /// How many symbols reached `stage` today; nil until the flow is read.
  private func count(_ stage: FlowStage) -> String? {
    flow?.stages.first { $0.stage == stage }.map { String($0.count) }
  }

  var body: some View {
    // Only the header opens Risk: a whole-card link would swallow the stages' taps and host their
    // popovers inside its label.
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      NavigationLink {
        RiskView()
      } label: {
        // As on the design: the label, then the bot's inputs (the quote stream and how long ago
        // the broker was read); the whole row is the link to Risk. At large text sizes the inputs
        // take the line under the label.
        RowStack {
          HStack(spacing: Tokens.Space.s) {
            CardLabel(L10n.Flow.title)
            // The slots in use, the visible end of the link to Risk, as on the design.
            if current, let slotLimit {
              HStack(spacing: Tokens.Space.xxs) {
                Text(L10n.Flow.slots(status.positions.count, slotLimit))
                Image(systemName: DayLine.nextSymbol)
              }
              .font(Tokens.Typography.annotationBold)
              .foregroundStyle(Palette.infoText)
              .fixedSize()
            }
          }
          Spacer(minLength: 0)
          HStack(alignment: .center, spacing: Tokens.Space.s) {
            if !current {
              Text(L10n.Flow.notCurrent)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.warningText)
                .fixedSize(horizontal: false, vertical: true)
            }
            StateGlyph(Self.streamSymbol, tone: streamTone,
              label: L10n.Flow.quotes(String(localized: status.freshness.stream.title)),
              live: current && status.freshness.stream == .fresh, event: status.freshness.stream, style: .compact)
            BrokerReadAge(readAt: status.freshness.lastBrokerReadAt, alarm: current)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(AccessibilityID.risk)
      // Six equal columns, as in the design (a long value never widens its stage); at large text
      // sizes one row per stage, so the names stay whole.
      Group {
        if typeSize.stacksRows {
          VStack(alignment: .leading, spacing: Tokens.Space.s) {
            ForEach(stages) { stage in opens(stage) { row(stage) } }
          }
        } else {
          HStack(alignment: .top) {
            ForEach(stages) { stage in
              opens(stage) { column(stage).frame(maxWidth: .infinity, alignment: .top) }
            }
          }
        }
      }
      // Until the first /flow read answers, a placeholder instead of numbers that would jump.
      .redacted(reason: current && flowPending ? .placeholder : [])
      // A symbol's dot flies to its next stage only when a new read moves it.
      .animation(reduceMotion ? nil : Tokens.Motion.standard, value: marks)
      // The quote stream in words and the trays' legend, under a hairline, as on the design.
      if current {
        VStack(spacing: Tokens.Space.s) {
          Divider().overlay(Palette.separator)
          HStack(spacing: Tokens.Space.s) {
            Text(L10n.Flow.quotes(String(localized: status.freshness.stream.title)))
            Spacer(minLength: Tokens.Space.s)
            Label {
              Text(L10n.Flow.refusedToday)
            } icon: {
              Rectangle()
                .strokeBorder(Palette.loss,
                  style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
                .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
            }
            .labelStyle(ControlLabelStyle())
          }
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
        }
      }
      ForEach(status.fences, id: \.kind) { fence in
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

  /// Stage names, in `StageID` order.
  private static let names = [L10n.Flow.screen, L10n.Flow.stocks, L10n.Flow.strategy, L10n.Flow.risk, L10n.Flow.order,
    L10n.Flow.stop]

  /// Symbol of the quote stream.
  static let streamSymbol = "waveform.path.ecg"

  /// The quote stream's state as a tone: a lost stream is an alarm.
  private var streamTone: Tone {
    // An old status says nothing about the stream now.
    guard current else { return .neutral }
    switch status.freshness.stream {
    case .fresh: return .profit
    case .quiet: return .warning
    case .lost: return .loss
    case .off: return .neutral
    }
  }

  /// A stage as a button: a tap anywhere on it (its dot, name, value, dots or tray) opens what it
  /// did today in a popover that stays until dismissed (HIG), the stage's colour washing behind it
  /// while the finger is down.
  private func opens(_ stage: Stage, @ViewBuilder label: () -> some View) -> some View {
    Button {
      openStage = stage.id
    } label: {
      label().contentShape(Rectangle())
    }
    .buttonStyle(StagePressStyle(color: stage.color))
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

  private func column(_ stage: Stage) -> some View {
    VStack(spacing: Tokens.Space.xs) {
      FlowDot(color: stage.color, lit: stage.value != nil || stage.flag != nil, event: stage.value)
      Text(stage.name)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textTertiary)
      Group {
        if stage.value != nil || stage.flag == nil {
          Text(verbatim: stage.value ?? Format.missing)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(stage.value == nil ? Palette.textQuaternary : Palette.textPrimary)
            .contentTransition(.numericText())
        }
        if let flag = stage.flag {
          Text(flag)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(stage.flagColor)
        }
      }
      pool(stage)
    }
    .unredacted(when: stage.urgent)
  }

  /// A stage as one row: its dot and name, then its value and today's symbols at the end; a flag
  /// ("not now", "blocked") goes under the name and wraps whole instead of being cut ("Не сей…").
  private func row(_ stage: Stage) -> some View {
    HStack(spacing: Tokens.Space.s) {
      FlowDot(color: stage.color, lit: stage.value != nil || stage.flag != nil, event: stage.value)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(stage.name).font(Tokens.Typography.annotation).foregroundStyle(Palette.textTertiary)
        if let flag = stage.flag {
          Text(flag)
            .font(Tokens.Typography.annotationBold)
            .foregroundStyle(stage.flagColor)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .layoutPriority(1)
      Spacer(minLength: Tokens.Space.s)
      if stage.value != nil || stage.flag == nil {
        Text(verbatim: stage.value ?? Format.missing)
          .font(Tokens.Typography.annotationBold)
          .foregroundStyle(stage.value == nil ? Palette.textQuaternary : Palette.textPrimary)
          .contentTransition(.numericText())
      }
      pool(stage)
    }
    .unredacted(when: stage.urgent)
  }

  /// Today's symbols at this stage as small dots, "+N" past the cap; under the stocks and risk
  /// stages the symbols they refused sit in a dashed tray as outlines, as in the design.
  @ViewBuilder
  private func pool(_ stage: Stage) -> some View {
    let here = current ? marks.filter { $0.stage == stage.id.flowStage } : []
    let passed = here.filter { !$0.refused }
    let refused = here.filter(\.refused)
    VStack(spacing: Tokens.Space.xs) {
      // A stop dot is green unless its own stop is waiting or unconfirmed: one unprotected
      // position reddens the stage, never the day's other stops.
      if !passed.isEmpty {
        dots(passed, color: stage.id == .stop ? Palette.profit : stage.color).accessibilityHidden(true)
      }
      if !refused.isEmpty {
        // No hover on a phone: the tray is part of its stage, whose tap lists who was refused
        // and why in the stage's detail.
        dots(refused, color: Palette.loss, hinted: false)
          .padding(Tokens.Space.xs)
          .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.small)
              .strokeBorder(Palette.separatorStrong,
                style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine))
          }
          .frame(maxWidth: .infinity, minHeight: Tokens.Size.touchTarget)
          .accessibilityLabel(Text(L10n.Flow.refusedCount(refused.count)))
      }
    }
  }

  /// `hinted`: each dot names itself on a long press; off inside the tray, whose stage's tap lists them all.
  private func dots(_ marks: [FlowMark], color: Color, hinted: Bool = true) -> some View {
    VStack(spacing: Tokens.Space.xxs) {
      LazyVGrid(columns: Array(repeating: GridItem(.fixed(Tokens.Size.dotSmall), spacing: Tokens.Space.xxs),
        count: Self.poolColumns), spacing: Tokens.Space.xxs) {
        ForEach(marks.prefix(Self.poolCap)) { mark in
          SymbolDot(mark: mark, color: color, hinted: hinted)
            .matchedGeometryEffect(id: mark.id, in: board)
            .transition(.scale.combined(with: .opacity))
        }
      }
      if marks.count > Self.poolCap {
        Text(L10n.Flow.more(marks.count - Self.poolCap))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }
}

/// How long ago the bot last read the broker, as on the design ("read 3 s"), counted on the
/// clock; red when there was no read at all, "—" without a time.
private struct BrokerReadAge: View {
  let readAt: WireTime?
  /// No read is an alarm only for a current status.
  let alarm: Bool

  @Environment(AppModel.self) private var model

  var body: some View {
    TimelineView(.periodic(from: .now, by: Tokens.Motion.clockTickSeconds)) { _ in
      Label {
        Text(text)
      } icon: {
        Image(systemName: LiveFlowCardSymbols.brokerSymbol)
      }
      .labelStyle(ControlLabelStyle())
      .font(Tokens.Typography.annotation)
      .foregroundStyle(alarm && readAt == nil ? Palette.lossText : Palette.textQuaternary)
      // Wraps at large text sizes rather than widening the card past the screen.
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityLabel(Text(L10n.Flow.brokerRead(Format.timeOrDash(readAt))))
    }
  }

  private var text: LocalizedStringResource {
    guard let readAt else { return L10n.Flow.readNever }
    let seconds = max(0, Int(model.botNow.timeIntervalSince(readAt.date)))
    let minute = Int(PositionMarks.barSeconds)
    return seconds < minute ? L10n.Flow.readSeconds(seconds) : L10n.Flow.readMinutes(seconds / minute)
  }
}

/// Symbols of the live flow's inputs, shared with `BrokerReadAge`.
private enum LiveFlowCardSymbols {
  /// The last broker read: a clock going round.
  static let brokerSymbol = "clock.arrow.circlepath"
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

/// One of today's symbols on the live flow: filled in its stage's colour, amber while its broker
/// stop waits, red when it was never confirmed; an outline when the universe left it out. A long
/// press names it and why.
private struct SymbolDot: View {
  let mark: FlowMark
  let color: Color
  /// Whether a long press names the dot; off in a tray, whose stage's tap lists the dots.
  var hinted = true

  /// Joins the symbol and its note in the hint.
  static let separator = "\n"

  @ViewBuilder var body: some View {
    if hinted {
      dot.hint(verbatim: [mark.id, mark.note].compactMap { $0 }.joined(separator: Self.separator))
    } else {
      dot
    }
  }

  private var dot: some View {
    let fill: Color = switch mark.tone {
    case .normal: color
    case .pending: Palette.warning
    case .alarm: Palette.loss
    }
    return Group {
      if mark.refused {
        Circle().strokeBorder(Palette.loss, lineWidth: Tokens.Stroke.regular)
      } else {
        Circle().fill(fill)
      }
    }
    .frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
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

/// A recorded day's clean-day verdict from the bot's journal and reconciliation: clean, not clean
/// with its first reason, or unknown with why.
private struct CleanLine: View {
  let clean: CleanDay

  var body: some View {
    Group {
      switch clean.verdict {
      case .clean:
        Text(L10n.Home.cleanDay)
          .foregroundStyle(Palette.profitText)
      case .notClean:
        Text(L10n.Home.notClean(clean.causes.first.map { ApiText.prose($0.textCodes, text: $0.text) } ?? Format.missing,
          clean.causes.count))
          .foregroundStyle(Palette.warningText)
      case .unknown:
        Text(L10n.Home.cleanUnknown(ApiText.prose(clean.causeCodes, text: clean.cause) ?? Format.missing))
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .font(Tokens.Typography.annotation)
    .fixedSize(horizontal: false, vertical: true)
  }
}
