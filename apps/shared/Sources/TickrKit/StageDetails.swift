import Foundation

/// A stage of the live flow as the Overview draws it: the six flow stages, then the
/// reconciliation with the broker (macOS only).
public enum PipelineStage: String, Hashable, Sendable, CaseIterable, Identifiable {
  case screeners, universe, strategy, risk, order, stop, reconcile

  public var id: String { rawValue }

  /// The flow stage whose symbols sit under this one; nil for reconcile.
  public var flowStage: FlowStage? { FlowStage(rawValue: rawValue) }
}

/// What the bot reported that a stage's detail card is built from: the shown day's flow and
/// skipped signals, its watching rows, the settings, and the status only while the day is live.
public struct StageSources: Sendable {
  public let flow: FlowV1?
  public let skipped: SkippedV1?
  public let watching: WatchingV1?
  /// The live status; nil on a recorded day or when the status is not current, the same rule the
  /// stages' own values follow.
  public let status: StatusV1?
  public let settings: SettingsV1?

  public init(flow: FlowV1?, skipped: SkippedV1?, watching: WatchingV1?, status: StatusV1?, settings: SettingsV1?) {
    self.flow = flow
    // Another day's signals or watching rows never describe the shown day.
    self.skipped = skipped.flatMap { skipped in (flow.map { $0.day == skipped.day } ?? true) ? skipped : nil }
    self.watching = watching.flatMap { watching in (flow.map { $0.day == watching.day } ?? true) ? watching : nil }
    self.status = status
    self.settings = settings
  }
}

/// The card a stage of the live flow opens (a click on the Mac, a tap on the iPhone): a few facts,
/// then groups of symbol rows. Built only from what the bot reported, by one pure function both
/// apps render, so the two apps never disagree.
public struct StageDetail: Hashable, Sendable {
  /// The colour of a fact or a row, as the events' tones.
  public typealias Tone = Board.Event.Tone

  /// "Gainers · 12": one figure of the stage.
  public struct Fact: Hashable, Sendable, Identifiable {
    public let label: String
    public let value: String
    public let tone: Tone
    public var id: String { label }
  }

  /// One symbol with what the stage did with it; `symbol` is nil for a row about no one symbol
  /// (a fence the app cannot tie to a position).
  public struct Row: Hashable, Sendable, Identifiable {
    public let id: String
    public let symbol: String?
    public let text: String?
    public let tone: Tone
  }

  /// A titled list of rows; past the stage's cap the rest are only counted in `more`.
  public struct Group: Hashable, Sendable, Identifiable {
    public let title: String
    public let rows: [Row]
    public let more: Int
    public var id: String { title }
  }

  public let stage: PipelineStage
  public let facts: [Fact]
  public let groups: [Group]

  /// The one short line an empty stage shows instead of an empty card; nil when it has content.
  public var empty: String? {
    facts.isEmpty && groups.isEmpty ? String(localized: L10n.stageNothing) : nil
  }
}

extension StageDetail {
  /// Strongest movers listed each way (top gainers, top losers).
  public static let moversCap = 5
  /// Watched symbols listed as closest to entering.
  public static let closestCap = 5
  /// Rows a group lists before it counts the rest.
  public static let rowCap = 12
  /// Percent in a closeness of 1.
  static let percentPerUnit: Decimal = 100
  /// Placeholder for a value the bot did not record.
  static let missing = "—"
  /// Between the parts of one row ("11:26 · Refused by risk").
  static let separator = " · "
  /// Between the parts of a check ("Spread 0.0031 <= 0.002").
  static let space = " "

  /// The detail of `stage` from what the bot reported.
  public static func make(_ stage: PipelineStage, from sources: StageSources) -> StageDetail {
    let (facts, groups): ([Fact], [Group]) = switch stage {
    case .screeners: screeners(sources)
    case .universe: universe(sources)
    case .strategy: strategy(sources)
    case .risk: risk(sources)
    case .order: order(sources)
    case .stop: stop(sources)
    case .reconcile: reconcile(sources)
    }
    return StageDetail(stage: stage, facts: facts, groups: groups.filter { !$0.rows.isEmpty })
  }

  /// How many symbols reached `stage` on the shown day; nil without a flow.
  static func count(_ stage: FlowStage, _ flow: FlowV1?) -> Int? {
    flow?.stages.first { $0.stage == stage }?.count
  }

  static func fact(_ label: LocalizedStringResource, _ value: String, _ tone: Tone = .muted) -> Fact {
    Fact(label: String(localized: label), value: value, tone: tone)
  }

  static func group(_ title: LocalizedStringResource, _ rows: [Row]) -> Group {
    Group(title: String(localized: title), rows: Array(rows.prefix(rowCap)), more: max(rows.count - rowCap, 0))
  }

  // MARK: stages

  /// Each screener's count, the total, and the strongest movers each way.
  static func screeners(_ sources: StageSources) -> ([Fact], [Group]) {
    guard let chips = sources.flow?.chips, !chips.isEmpty else { return ([], []) }
    let listed: [(LocalizedStringResource, ScreenerSource, Tone)] = [
      (L10n.stageGainers, .gainers, .green), (L10n.stageLosers, .losers, .red), (L10n.stageActives, .topActives, .blue),
    ]
    let facts = listed.map { label, source, tone in
      fact(label, String(chips.filter { $0.sources.contains(source) }.count), tone)
    } + [fact(L10n.stageListed, String(chips.count))]
    let changed = chips.compactMap { chip in chip.changePct.map { (chip, $0) } }
    func row(_ pair: (FlowChipV1, DecimalString), _ tone: Tone) -> Row {
      Row(id: pair.0.symbol, symbol: pair.0.symbol, text: String(localized: L10n.stageChange(Board.signed(pair.1))),
        tone: tone)
    }
    let gainers = changed.filter { $0.1.value > 0 }.sorted { $0.1.value > $1.1.value }.prefix(moversCap)
    let losers = changed.filter { $0.1.value < 0 }.sorted { $0.1.value < $1.1.value }.prefix(moversCap)
    return (facts, [
      group(L10n.stageTopGainers, gainers.map { row($0, .green) }),
      group(L10n.stageTopLosers, losers.map { row($0, .red) }),
    ])
  }

  /// Admitted of listed, then the left-out symbols grouped by why, in the order first seen.
  static func universe(_ sources: StageSources) -> ([Fact], [Group]) {
    guard let flow = sources.flow else { return ([], []) }
    var facts: [Fact] = []
    if let admitted = count(.universe, flow) {
      let listed = count(.screeners, flow) ?? flow.chips.count
      facts.append(fact(L10n.stageAdmitted, String(localized: L10n.stageCountOf(admitted, listed)), .violet))
    }
    var causes: [String] = []
    var symbols: [String: [String]] = [:]
    for chip in flow.chips {
      guard let cause = chip.excludedCause else { continue }
      let text = FlowBoard.exclusion(cause)
      if symbols[text] == nil { causes.append(text) }
      symbols[text, default: []].append(chip.symbol)
    }
    let groups = causes.map { cause in
      let rows = (symbols[cause] ?? []).map { Row(id: $0, symbol: $0, text: nil, tone: .muted) }
      return Group(title: cause, rows: Array(rows.prefix(rowCap)), more: max(rows.count - rowCap, 0))
    }
    return (facts, groups)
  }

  /// The active strategy, how many symbols it decided on, and the watched symbols closest to
  /// entering with their deciding check and closeness.
  static func strategy(_ sources: StageSources) -> ([Fact], [Group]) {
    var facts: [Fact] = []
    if let strategy = sources.status?.strategy {
      facts.append(fact(L10n.stageActiveStrategy, String(localized: L10n.stageStrategy(strategy.name, strategy.version)),
        .violet))
    }
    if let decided = count(.strategy, sources.flow) { facts.append(fact(L10n.stageDecided, String(decided))) }
    let closest = (sources.watching?.rows ?? []).prefix(closestCap).map { row in
      let check = row.decisiveCheck.map { [ApiText.rule($0.rule), $0.valueText].joined(separator: space) }
      let closeness = row.closeness.map { closeness in
        String(localized: L10n.stageCloseness(whole(closeness.value * percentPerUnit)))
      }
      let text = [check, closeness].compactMap { $0 }.joined(separator: separator)
      return Row(id: row.symbol, symbol: row.symbol, text: text.isEmpty ? nil : text, tone: .violet)
    }
    return (facts, [group(L10n.stageClosest, Array(closest))])
  }

  /// What risk passed and refused, the entry block now, the limits, the room left and the
  /// latest size; then each refusal with its New York time and why.
  static func risk(_ sources: StageSources) -> ([Fact], [Group]) {
    let signals = sources.skipped?.signals ?? []
    let refused = signals.filter { $0.admission == .refused }
    var facts: [Fact] = []
    if let passed = count(.risk, sources.flow) { facts.append(fact(L10n.stagePassed, String(passed), .amber)) }
    if sources.skipped != nil {
      facts.append(fact(L10n.stageRefused, String(refused.count), refused.isEmpty ? .muted : .red))
      facts.append(fact(L10n.stageNotEvaluated, String(signals.filter { $0.admission == .notEvaluated }.count)))
    }
    if let status = sources.status {
      let block = status.entryBlock
      facts.append(fact(L10n.stageEntries, block.map(ApiText.entryBlock) ?? String(localized: L10n.stageEntriesAllowed),
        block == nil ? .green : block?.attention == true ? .red : .amber))
    }
    if let risk = sources.settings?.risk {
      facts.append(fact(L10n.stagePlannedLoss, String(localized: L10n.stageUSD(risk.plannedLossUsd.text))))
      facts.append(fact(L10n.stageMaxDailyLoss, String(localized: L10n.stageUSD(risk.maxDailyLossUsd.text))))
      facts.append(fact(L10n.stageMaxPositions, String(risk.maxOpenPositions)))
    }
    if let status = sources.status {
      if let room = status.dailyRoomUsd {
        facts.append(fact(L10n.stageRoomLeft, String(localized: L10n.stageUSD(room.text)), .teal))
      }
      let used = sources.settings.map { String(localized: L10n.stageCountOf(status.positions.count,
        $0.risk.maxOpenPositions)) } ?? String(status.positions.count)
      facts.append(fact(L10n.stagePositionsUsed, used))
    }
    if let size = sources.watching?.latestSize {
      facts.append(fact(L10n.stageLatestSize, String(localized: L10n.stageSize(size.symbol, size.quantity.text)), .amber))
    }
    let rows = refused.sorted { $0.at.date < $1.at.date }.map { signal in
      Row(id: "\(signal.symbol) \(signal.at.text)", symbol: signal.symbol,
        text: [FlowBoard.newYorkMinute(signal.at.date), FlowBoard.note(signal)].compactMap { $0 }
          .joined(separator: separator),
        tone: .amber)
    }
    return (facts, [group(L10n.stageRefusedSignals, rows)])
  }

  /// The day's fills: closed trades with their result, then the open positions.
  static func order(_ sources: StageSources) -> ([Fact], [Group]) {
    var facts: [Fact] = []
    if let filled = count(.order, sources.flow) { facts.append(fact(L10n.stageFilled, String(filled), .blue)) }
    guard let status = sources.status else { return (facts, []) }
    facts.append(fact(L10n.stageClosed, String(status.tradesToday.count)))
    facts.append(fact(L10n.stageOpen, String(status.positions.count)))
    let closed = status.tradesToday.enumerated().map { index, trade in
      Row(id: "\(trade.symbol) \(index)", symbol: trade.symbol,
        text: String(localized: L10n.stageTrade(trade.quantity.text, trade.entryPrice.text, trade.exitPrice.text,
          Board.signed(trade.resultGrossUsd))),
        tone: Board.exitTone(trade.exitReason, result: trade.resultGrossUsd.value))
    }
    let open = status.positions.map { position in
      Row(id: position.symbol, symbol: position.symbol,
        text: String(localized: L10n.stagePosition(position.quantity.text, position.entryPrice.text)), tone: .teal)
    }
    return (facts, [group(L10n.stageClosedTrades, closed), group(L10n.stageOpenPositions, open)])
  }

  /// Each trade's broker stop as the flow knows it, with how fast the broker confirmed it when
  /// the status says; then each open position's stop now.
  static func stop(_ sources: StageSources) -> ([Fact], [Group]) {
    var facts: [Fact] = []
    if let verified = count(.stop, sources.flow) { facts.append(fact(L10n.stageVerified, String(verified), .green)) }
    let stops = sources.flow?.stops ?? []
    if sources.flow != nil { facts.append(fact(L10n.stageTrades, String(stops.count))) }
    let trades = sources.status?.tradesToday ?? []
    let rows = stops.map { stop in
      // A trade is matched by its symbol only when the day has one trade and one stop for it:
      // the status does not carry the flow's trade id, so a guess is never made.
      let alone = stops.filter { $0.symbol == stop.symbol }.count == 1
      let match = trades.filter { $0.symbol == stop.symbol }
      let seconds = alone && match.count == 1 ? match[0].stopConfirmedAfterSeconds : nil
      let after = seconds.map { String(localized: L10n.stageConfirmedAfter($0.text)) }
      return Row(id: stop.tradeId, symbol: stop.symbol,
        text: [title(stop.state), after].compactMap { $0 }.joined(separator: separator), tone: tone(stop.state))
    }
    let open = (sources.status?.positions ?? []).map { position in
      Row(id: position.symbol, symbol: position.symbol,
        text: [Board.stopStateTitle(position.stop.state), position.stop.price.map { $0.text }].compactMap { $0 }
          .joined(separator: separator),
        tone: tone(position.stop.state))
    }
    return (facts, [group(L10n.stageTradeStops, rows), group(L10n.stageOpenPositions, open)])
  }

  /// The latest reconciliation: agreement, when it read the broker, the mismatch, and the fences
  /// (live from the status, else the flow's), each missing part with the bot's cause.
  static func reconcile(_ sources: StageSources) -> ([Fact], [Group]) {
    guard let latest = sources.flow?.reconcile else {
      guard let status = sources.status, !status.fences.isEmpty else { return ([], []) }
      return ([fact(L10n.stageFences, String(status.fences.count), .amber)], [fences(status.fences, status: status)])
    }
    var facts: [Fact] = []
    switch latest.agreement {
    case .match?: facts.append(fact(L10n.stageRecords, String(localized: L10n.stageMatch), .green))
    case .mismatch?: facts.append(fact(L10n.stageRecords, String(localized: L10n.stageMismatch), .red))
    case nil: facts.append(fact(L10n.stageRecords, latest.agreementCause ?? missing))
    }
    if let read = latest.readAt { facts.append(fact(L10n.stageReadAt, FlowBoard.newYorkMinute(read.date))) }
    if let mismatch = latest.mismatch { facts.append(fact(L10n.stageMismatchDetail, mismatch, .red)) }
    let fences = sources.status?.fences ?? latest.fences
    if let fences {
      facts.append(fact(L10n.stageFences, String(fences.count), fences.isEmpty ? .green : .amber))
    } else {
      facts.append(fact(L10n.stageFences, latest.fencesCause ?? missing))
    }
    return (facts, [Self.fences(fences ?? [], status: sources.status)])
  }

  /// Fences as rows: the symbol a fence is about when the live status ties it to one.
  static func fences(_ fences: [Fence], status: StatusV1?) -> Group {
    group(L10n.stageFenceList, fences.map { fence in
      let symbol = status.flatMap { Board.fenceSymbol(fence, status: $0) }
      return Row(id: fence.kind, symbol: symbol, text: ApiText.fenceWithDetail(fence), tone: .amber)
    })
  }

  /// "100" for 99.83: a share in whole percents.
  static func whole(_ value: Decimal) -> String {
    var input = value
    var output = Decimal()
    NSDecimalRound(&output, &input, 0, .plain)
    return NSDecimalNumber(decimal: output).stringValue
  }

  /// A trade's broker stop in words.
  static func title(_ state: FlowStopState) -> String {
    switch state {
    case .verified: String(localized: L10n.stateVerified)
    case .pending: String(localized: L10n.statePending)
    case .neverVerified: String(localized: L10n.stageNeverVerified)
    case .unknown: String(localized: L10n.stateUnknown)
    }
  }

  static func tone(_ state: FlowStopState) -> Tone {
    switch state {
    case .verified: .green
    case .pending: .amber
    case .neverVerified, .unknown: .red
    }
  }

  static func tone(_ state: StopState) -> Tone {
    switch state {
    case .verified: .green
    case .pending: .amber
    case .missing, .unknown: .red
    }
  }
}

extension CheckV1 {
  /// "measured operator threshold": what the check measured against what it needs, as the bot
  /// recorded them; a side it did not record is a dash.
  public var valueText: String {
    [measured?.text ?? StageDetail.missing, `operator`, threshold?.text ?? StageDetail.missing]
      .joined(separator: StageDetail.space)
  }
}
