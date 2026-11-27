import SwiftUI
import TickrDesign
import TickrKit

/// Home's funnel as on the IOS2Home board (mockup v155): the card's label with "Risk ›", then one
/// row that is a single button: the nine stages as rings on one line (`FunnelRings`, the Mac's
/// colours and glyphs), and under them how many symbols were found and bought and whether every
/// stop is at the broker. A tap opens "Today's funnel" (IOS2Funnel): the same summary, each stage
/// as a bar with its count and what it dropped (a tap on a stage opens its symbols, or the broker
/// check's detail), and "Symbols at each stage ›". While Home's ornaments move, ticker dots fall
/// through the bars (`FunnelDrops`, IOSFunnel board, mockup v159). A status that is stale, failed or from an
/// earlier session shows faint rings and says so; a recorded day shows that day's flow.
struct FunnelCard: View {
  let status: StatusV1
  /// The shown day's flow: stage counts and the day's stops; nil until read.
  let flow: FlowV1?
  /// The first /flow read has not answered yet: the figures stand as skeleton.
  let flowPending: Bool
  /// The status is fresh and describes today's session.
  let current: Bool
  /// A recorded past day: every value comes from that day's flow and symbols, nothing is live.
  let recorded: Bool
  /// What the broker check's detail is built from (`StageDetail`).
  let sources: StageSources
  /// The shown day's symbols by the stage they got to: the Priced and Liquid counts; nil until read.
  let symbols: SymbolsV1?
  /// Home's ornaments move (`OrnamentGate`): the lights along the rail run.
  let moving: Bool
  /// Pushes the Symbols screen on a tab, once the sheet has closed.
  let openSymbols: (SymbolsTab) -> Void

  @State private var sheetOpen = false
  /// The tab a pick in the sheet opens once the sheet is gone.
  @State private var picked: SymbolsTab?
  /// The broker check's detail, open in a popover over its bar.
  @State private var checkOpen = false

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      RowStack {
        ChipFlow(spacing: Tokens.Space.s) {
          CardLabel(L10n.Flow.funnel)
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
      Button { sheetOpen = true } label: {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          FunnelRings(stages, moving: moving && current)
          HStack(spacing: Tokens.Space.s) {
            summary.frame(maxWidth: .infinity, alignment: .leading)
            FooterChevronChip()
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.washPress(Palette.info))
      .accessibilityElement(children: .combine)
      .accessibilityHint(Text(L10n.Flow.funnelHint))
      .accessibilityIdentifier(AccessibilityID.funnel)
      ForEach(liveFences, id: \.kind) { fence in
        Label { Text(verbatim: Board.fenceText(fence, status: status)) } icon: {
          Image(systemName: Symbols.failure)
        }
        .font(.caption)
        .foregroundStyle(Palette.warningText)
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .tickrCard()
    .sheet(isPresented: $sheetOpen, onDismiss: openPicked) {
      let shown = $sheetOpen
      CardSheet(title: recorded ? L10n.Flow.titleRecorded : L10n.Flow.title, subtitle: nil,
        close: { shown.wrappedValue = false }, rows: { sheet })
    }
  }

  /// "412 found → 4 bought", and under it whether the stops are at the broker.
  private var summary: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      Text(L10n.Flow.foundBought(figure(count(.screeners)), figure(bought)))
        .font(.subheadline)
        .foregroundStyle(Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .skeleton((current || recorded) && flowPending)
      if let protection {
        Label { Text(protection.text) } icon: { Image(systemName: protection.symbol) }
          .font(.footnote.weight(.semibold))
          .foregroundStyle(protection.tone.text)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// The sheet: the summary, a bar per stage, and the way to every symbol by stage.
  private var sheet: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      summary
      let all = stages
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        ForEach(all) { stage in
          bar(stage, in: all)
        }
      }
      // decorative: owner-approved funnel sheet dots (mockup v159, 2026-11-26)
      .overlay { FunnelDrops(moving: moving && current) }
      CardFooterLink(L10n.Flow.symbolsAtEachStage) { pick(.stage(.screeners)) }
    }
  }

  /// A stage's bar as a button: its symbols on the Symbols screen, or the broker check's detail.
  @ViewBuilder
  private func bar(_ stage: FunnelStage, in stages: [FunnelStage]) -> some View {
    let row = FunnelBarRow(stage, in: stages).contentShape(Rectangle())
    if let tab = SymbolsTab(stage.stage) {
      Button { pick(tab) } label: { row }
        .buttonStyle(.washPress(stage.color))
        .accessibilityHint(Text(L10n.FlowStages.symbolsHint))
        .accessibilityIdentifier(AccessibilityID.funnelStage)
    } else {
      Button { checkOpen = true } label: { row }
        .buttonStyle(.washPress(stage.color))
        .accessibilityHint(Text(L10n.Flow.stageDetailsHint))
        .accessibilityIdentifier(AccessibilityID.funnelStage)
        .popover(isPresented: $checkOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
          StageDetailView(name: stage.stage.title, color: stage.color, stage: stage.stage, sources: sources)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Palette.surface)
        }
    }
  }

  /// Once the sheet has closed, pushes the tab picked in it.
  private func openPicked() {
    guard let tab = picked else { return }
    picked = nil
    openSymbols(tab)
  }

  private func pick(_ tab: SymbolsTab) {
    picked = tab
    sheetOpen = false
  }
}

extension FunnelCard {
  /// The nine stages as the rings and bars draw them. Nothing live while the status is not
  /// current: no counts, no colours.
  fileprivate var stages: [FunnelStage] {
    guard current || recorded else {
      return PipelineStage.allCases.map {
        FunnelStage(stage: $0, color: Palette.textQuaternary, text: Palette.textQuaternary, count: nil, value: nil)
      }
    }
    let positions = recorded ? [] : status.positions
    let verified = positions.filter { $0.stop.state.isProtected }.count
    let dayStops = flow?.stops ?? []
    let dayVerified = dayStops.filter { $0.state == .verified }.count
    // An open position waiting for its stop shows first; then the day's stops from the flow.
    let openFirst = verified < positions.count || dayStops.isEmpty
    let stops: String? = openFirst
      ? (positions.isEmpty ? nil : Self.stops(verified, of: positions.count))
      : Self.stops(dayVerified, of: dayStops.count)
    let stopTone = StopState.stageTone(open: positions.map(\.stop.state), day: dayStops.map(\.state))
    // With a flow every count comes from it; the status's stand in only when /flow failed, and
    // never for a recorded day.
    let fromStatus = flow == nil && !recorded
    let allowed = recorded || status.entriesAllowed
    let blocked = !recorded && !status.entriesAllowed && !status.entriesCalm
    let riskTone: Tone? = allowed ? nil : blocked ? .loss : .neutral
    return [
      plain(.screeners, count(.screeners)),
      plain(.universe, count(.universe)),
      plain(.quote, reached(.quote)),
      plain(.bars, reached(.bars)),
      plain(.strategy, count(.strategy), value: fromStatus ? status.strategy.version : nil),
      plain(.risk, count(.risk), tone: riskTone,
        value: fromStatus && status.entriesAllowed ? RiskFormat.amount(status.dailyRoomUsd?.value) : nil),
      plain(.order, bought),
      FunnelStage(stage: .stop, color: stopTone.fill, text: stopTone.text,
        count: openFirst ? (positions.isEmpty ? nil : verified) : dayVerified, value: stops ?? Format.missing),
      checkStage,
    ]
  }

  /// A stage in its own colour (or `tone`'s), drawn to `count`; `value` stands in for a missing count.
  private func plain(_ stage: PipelineStage, _ count: Int?, tone: Tone? = nil, value: String? = nil) -> FunnelStage {
    FunnelStage(stage: stage, color: tone?.fill ?? stage.fill, text: tone?.text ?? stage.text, count: count,
      value: count.map { $0.formatted() } ?? value, dropped: dropped(stage))
  }

  /// Live fences first (the status is newer than any reconciliation), then the latest
  /// reconciliation's match or mismatch; without one, no value (never read as fine). No bar: the
  /// check has no count of its own.
  private var checkStage: FunnelStage {
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
    let tone: Tone? = value == nil ? .neutral : agrees ? nil : .loss
    return FunnelStage(stage: .reconcile, color: tone?.fill ?? PipelineStage.reconcile.fill,
      text: tone?.text ?? PipelineStage.reconcile.text, count: nil, value: value.map { String(localized: $0) })
  }

  /// Whether the stops are at the broker, under the found and bought line: a position waiting for
  /// its stop first, else how many of the day's stops the broker confirmed; nothing before a buy.
  fileprivate var protection: (text: LocalizedStringResource, symbol: String, tone: Tone)? {
    guard current || recorded else { return nil }
    let open = recorded ? [] : status.positions.map(\.stop.state)
    let day = (flow?.stops ?? []).map(\.state)
    let states = day.isEmpty ? open : day.map(StopState.init)
    guard !states.isEmpty else { return nil }
    let tone = StopState.stageTone(open: open, day: day)
    let symbol = StopState.combinedSymbol(open + day.map(StopState.init))
    if let words = Self.unprotectedWords(open) {
      return (words, symbol, tone)
    }
    let verified = states.filter(\.isProtected).count
    return (verified == states.count ? L10n.Flow.allProtected : L10n.Flow.protectedOf(verified, states.count),
      symbol, tone)
  }

  /// The words for open positions whose stop is not confirmed, the worst state winning: a stop
  /// missing or unknown at the broker ("1 stop missing") before one still pending ("2 stops
  /// pending"); nil when every open stop is verified.
  static func unprotectedWords(_ open: [StopState]) -> LocalizedStringResource? {
    let missing = open.filter { $0 == .missing || $0 == .unknown }.count
    if missing > 0 { return missing == 1 ? L10n.Flow.stopMissing : L10n.Flow.stopsMissing(missing) }
    let pending = open.filter { $0 == .pending }.count
    if pending > 0 { return pending == 1 ? L10n.Flow.stopPending : L10n.Flow.stopsPending(pending) }
    return nil
  }

  /// The order stage's count: the flow's, else (only when /flow failed) the status's trades today.
  fileprivate var bought: Int? {
    count(.order) ?? (flow == nil && !recorded ? status.tradesToday.count : nil)
  }

  /// Today's fences from the status; none on a recorded day.
  fileprivate var liveFences: [Fence] { recorded ? [] : status.fences }

  /// "2/2 ✓" only when every stop is verified; otherwise the bare count, never a check mark.
  private static func stops(_ verified: Int, of total: Int) -> String {
    String(localized: verified == total ? L10n.Flow.stopsVerified(verified, total) : L10n.Flow.stopsCount(verified, total))
  }

  /// A count as the summary shows it; a dash until known.
  fileprivate func figure(_ count: Int?) -> String {
    count.map { $0.formatted() } ?? Format.missing
  }

  /// How many symbols reached `stage` (GET /flow); nil until the flow is read.
  fileprivate func count(_ stage: FlowStage) -> Int? {
    flow?.stages.first { $0.stage == stage }?.count
  }

  /// How many symbols got to `stage` (GET /symbols); nil until the symbols are read.
  private func reached(_ stage: SymbolStage) -> Int? {
    symbols?.stages.first { $0.stage == stage }?.count
  }

  /// How many symbols `stage` dropped (the Symbols screen's "dropped here" rows); nil when none.
  private func dropped(_ stage: PipelineStage) -> Int? {
    guard let symbols, let here = SymbolStage(rawValue: stage.rawValue) else { return nil }
    let count = symbols.rows.filter { $0.stage == here && $0.state == .dropped }.count
    return count > 0 ? count : nil
  }
}
