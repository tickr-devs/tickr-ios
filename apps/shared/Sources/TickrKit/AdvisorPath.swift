import Foundation

// What the apps derive from an advisor run (advisor-runs-v1) for the Lab's advisor screens: the
// proposal path, the direction of each change and the scale of the hold-out intervals. Nothing
// here talks to the bot or changes a strategy.

/// One step of a proposal's path. Proposed, judged and decided come from the run; observer and
/// active from the bot's settings, since running a version is a config edit by the owner.
public enum AdvisorStep: Int, CaseIterable, Sendable {
  case proposed, judged, decided, observer, active
}

/// How a changed value moves, for the arrow between its old and new value.
public enum ChangeDirection: Sendable {
  /// Both values are numbers and the new one is larger, or smaller.
  case up, down
  /// Not two numbers (a switch, a word): it only changes.
  case changed
}

extension AdvisorChangeV1 {
  /// Up or down when both values read as numbers, else changed.
  public var direction: ChangeDirection {
    guard let old = Self.number(now), let new = Self.number(proposed) else { return .changed }
    return new > old ? .up : new < old ? .down : .changed
  }

  /// "lookback_bars" under its section, as the strategy file names it.
  public var path: String { "\(section).\(key)" }

  static func number(_ text: String) -> Decimal? {
    guard Wire.matches(Wire.decimalPattern, text) else { return nil }
    return Decimal(string: text, locale: Locale(identifier: Wire.posixLocale))
  }
}

extension AdvisorRunV1 {
  /// The strategy folder name advisor.run gives a proposed version ("price-action-v1-v2" for
  /// "price-action-v1 v2"), the name `[strategy] observers` and `active` use.
  public var proposedFolder: String? {
    guard let proposed, let space = proposed.lastIndex(of: Self.identitySeparator) else { return nil }
    return String(proposed[..<space]) + Self.folderSeparator + String(proposed[proposed.index(after: space)...])
  }

  /// The judge result of the proposed version; for an idea (nothing proposed), its module's first.
  /// A proposal judged only under another name has none: its verdict is not this version's.
  public var judge: AdvisorJudgeV1? {
    guard let proposed else { return judges.first }
    return judges.first { $0.candidate == proposed }
  }

  /// Whether the path has reached `step`. Observer and active need the bot's settings: nil
  /// settings read as not reached.
  public func reached(_ step: AdvisorStep, settings: SettingsV1?) -> Bool {
    switch step {
    case .proposed: status == .proposed || status == .idea
    case .judged: proposed == nil ? !judges.isEmpty : judge != nil
    case .decided: decision != nil
    case .observer: proposedFolder.map { settings?.observers.contains($0) ?? false } ?? false
    case .active: proposedFolder != nil && proposedFolder == settings?.activeStrategy
    }
  }

  /// "price-action-v1 v2": strategy name and version.
  static let identitySeparator: Character = " "
  /// "price-action-v1-v2": the folder joins them with a dash.
  static let folderSeparator = "-"
}

extension AdvisorRunsV1 {
  /// The run the Overview and the Lab card lead with: the newest awaiting review, else the newest.
  public var lead: AdvisorRunV1? {
    runs.first(where: \.awaitingReview) ?? runs.first
  }
}

/// A symmetric scale around 0 R for the hold-out intervals of one judge result, so the base and
/// the candidate share one axis.
public struct HoldoutScale: Equatable, Sendable {
  /// The axis runs from -bound to +bound, in R.
  public let bound: Decimal

  /// Smallest bound, in R, so a tiny interval is not drawn across the whole width.
  public static let minimumBound: Decimal = 0.1
  /// 0 R sits in the middle of the axis.
  static let middle: Decimal = 0.5

  public init(_ judge: AdvisorJudgeV1) {
    let ends = [judge.holdout, judge.baseHoldout].compactMap { $0 }
      .flatMap { [$0.meanR, $0.meanRIntervalLow, $0.meanRIntervalHigh] }
      .compactMap { $0?.value }
    bound = ends.map { abs($0) }.reduce(Self.minimumBound, max)
  }

  /// Where `r` sits from the left edge, 0 to 1 (0.5 is 0 R).
  public func fraction(_ r: Decimal) -> Double {
    let clamped = min(max(r, -bound), bound)
    return NSDecimalNumber(decimal: Self.middle + clamped / bound * Self.middle).doubleValue
  }
}

// MARK: words

extension AdvisorRunV1 {
  /// The run's name in a list: the proposed version, the idea, or the base it started from.
  public var title: String {
    if let proposed { return proposed }
    if let idea { return String(localized: AdvisorWords.ideaName(idea.name)) }
    return base
  }

  /// Where the run stands: the owner's decision once noted, else what the advisor produced.
  public var stateWords: LocalizedStringResource {
    if let decision {
      return decision.verdict == .accepted ? AdvisorWords.stateAccepted : AdvisorWords.stateRejected
    }
    return switch status {
    case .proposed, .idea: AdvisorWords.stateAwaiting
    case .noChange: AdvisorWords.stateNoChange
    case .refused: AdvisorWords.stateRefused
    }
  }

  public var modeWords: LocalizedStringResource {
    mode == .live ? AdvisorWords.modeLive : AdvisorWords.modeBacktest
  }
}

extension AdvisorStep {
  public var words: LocalizedStringResource {
    switch self {
    case .proposed: AdvisorWords.stepProposed
    case .judged: AdvisorWords.stepJudged
    case .decided: AdvisorWords.stepDecided
    case .observer: AdvisorWords.stepObserver
    case .active: AdvisorWords.stepActive
    }
  }
}

extension ChangeDirection {
  /// For the arrow's hint and accessibility label.
  public var words: LocalizedStringResource {
    switch self {
    case .up: AdvisorWords.raised
    case .down: AdvisorWords.lowered
    case .changed: AdvisorWords.changed
    }
  }
}

extension HoldoutVerdict {
  /// What the hold-out says of the version `name`.
  public func words(_ name: String) -> LocalizedStringResource {
    switch self {
    case .edge: AdvisorWords.verdictEdge(name)
    case .negativeEdge: AdvisorWords.verdictNegative(name)
    case .noEvidence: AdvisorWords.verdictNoEvidence(name)
    case .tooFew: AdvisorWords.verdictTooFew(name)
    }
  }
}
