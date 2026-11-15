import Foundation

/// The live flow as symbols on a board: where each symbol the screeners listed today stands,
/// built only from what the bot reported (GET /flow and GET /skipped). The apps draw one dot per
/// mark and move a dot only when a new read moves its mark, so every motion is a real event.
public struct FlowMark: Identifiable, Hashable, Sendable {
  /// How a mark is drawn beyond its stage's colour.
  public enum Tone: Hashable, Sendable {
    /// At its stage, nothing to flag.
    case normal
    /// Filled, its broker stop not confirmed yet.
    case pending
    /// Its broker stop never confirmed, or its state is unknown.
    case alarm
  }

  /// The symbol.
  public let id: String
  /// The furthest stage it reached today; for a refused symbol, the stage that refused it.
  public let stage: FlowStage
  /// Left out by the universe filter, or refused by risk: drawn in that stage's tray.
  public let refused: Bool
  /// Why it is where it is: the exclusion or refusal, or nil.
  public let note: String?
  public let tone: Tone

  public init(id: String, stage: FlowStage, refused: Bool = false, note: String? = nil, tone: Tone = .normal) {
    self.id = id
    self.stage = stage
    self.refused = refused
    self.note = note
    self.tone = tone
  }
}

public enum FlowBoard {
  /// The marks of a day: every symbol in the flow's chips and stages once, at its furthest
  /// stage. A chip the universe left out sits in the universe tray; a symbol whose ENTER risk
  /// refused (and that never passed risk later) sits in the risk tray. Sorted by symbol, so the
  /// board is stable between reads. `positions`, the status's open positions, are newer than
  /// the flow's stops: an open position's own stop state colours its mark.
  public static func marks(flow: FlowV1?, skipped: SkippedV1?, positions: [Position] = []) -> [FlowMark] {
    guard let flow else { return [] }
    var furthest: [String: FlowStage] = [:]
    for chip in flow.chips { furthest[chip.symbol] = .screeners }
    for stage in FlowStage.allCases {
      guard let reached = flow.stages.first(where: { $0.stage == stage }) else { continue }
      for symbol in reached.symbols { furthest[symbol] = stage }
    }
    let excluded = Dictionary(flow.chips.compactMap { chip in chip.excludedCause.map { (chip.symbol, $0) } },
      uniquingKeysWith: { first, _ in first })
    var refusedByRisk: [String: String] = [:]
    for signal in skipped?.signals ?? [] where signal.admission == .refused {
      refusedByRisk[signal.symbol] = note(signal)
    }
    let stops = Dictionary(flow.stops.map { ($0.symbol, $0.state) }, uniquingKeysWith: { _, last in last })
    let open = Dictionary(positions.map { ($0.symbol, $0.stop.state) }, uniquingKeysWith: { first, _ in first })
    return furthest.keys.sorted().map { symbol in
      let stage = furthest[symbol] ?? .screeners
      if stage == .screeners, let cause = excluded[symbol] {
        return FlowMark(id: symbol, stage: .universe, refused: true, note: cause)
      }
      if stage == .strategy, let cause = refusedByRisk[symbol] {
        return FlowMark(id: symbol, stage: .risk, refused: true, note: cause)
      }
      if let open = open[symbol] { return FlowMark(id: symbol, stage: stage, tone: tone(open)) }
      return FlowMark(id: symbol, stage: stage, tone: tone(stops[symbol]))
    }
  }

  /// Why the platform refused `signal`, as the apps word it: the refusal in the reader's
  /// language (`ApiText.refusal`), else the recorded "CAUSE: detail"; nil when neither was recorded.
  public static func note(_ signal: SkippedSignalV1) -> String? {
    signal.refusal.map(ApiText.refusal) ?? signal.refusalCause
  }

  /// How an open position's stop colours its mark: verified, waiting, or missing or unknown.
  private static func tone(_ stop: StopState) -> FlowMark.Tone {
    switch stop {
    case .verified: .normal
    case .pending: .pending
    case .missing, .unknown: .alarm
    }
  }

  /// How a symbol's broker stop colours its mark: waiting, never confirmed or unknown.
  private static func tone(_ stop: FlowStopState?) -> FlowMark.Tone {
    switch stop {
    case .pending?: .pending
    case .neverVerified?, .unknown?: .alarm
    case .verified?, nil: .normal
    }
  }
}
