import Foundation

/// Every text of the AI advisor screens, shared by both apps, in English with its Russian
/// translation in Resources/Localizable.xcstrings (docs/design-system.md, rule 2).
public enum AdvisorWords {
  public static var title: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.title", defaultValue: "AI advisor", bundle: L10n.bundle)
  }
  public static var page: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.page", defaultValue: "Advisor proposal", bundle: L10n.bundle)
  }
  public static func awaiting(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.awaiting", defaultValue: "\(count) awaiting review", bundle: L10n.bundle)
  }
  public static var noRuns: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.noRuns",
      defaultValue: "No advisor run yet: runs come from python -m tickr.advisor on the Mac.",
      bundle: L10n.bundle)
  }
  public static var failed: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.failed",
      defaultValue: "Couldn't read the advisor's runs",
      bundle: L10n.bundle)
  }
  public static func unreadable(_ count: Int) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.unreadable", defaultValue: "Unreadable runs: \(count)", bundle: L10n.bundle)
  }
  public static var runGone: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.runGone",
      defaultValue: "This run is no longer among the newest runs the bot lists.",
      bundle: L10n.bundle)
  }
  public static var stateAwaiting: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.state.awaiting", defaultValue: "awaiting review", bundle: L10n.bundle)
  }
  public static var stateAccepted: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.state.accepted", defaultValue: "accepted", bundle: L10n.bundle)
  }
  public static var stateRejected: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.state.rejected", defaultValue: "rejected", bundle: L10n.bundle)
  }
  public static var stateNoChange: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.state.noChange", defaultValue: "no change", bundle: L10n.bundle)
  }
  public static var stateRefused: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.state.refused", defaultValue: "answer refused", bundle: L10n.bundle)
  }
  public static var modeLive: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.mode.live", defaultValue: "live days", bundle: L10n.bundle)
  }
  public static var modeBacktest: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.mode.backtest", defaultValue: "backtest", bundle: L10n.bundle)
  }
  public static func ideaName(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.ideaName", defaultValue: "idea · \(name)", bundle: L10n.bundle)
  }
  public static var stepProposed: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.proposed", defaultValue: "Proposed", bundle: L10n.bundle)
  }
  public static var stepJudged: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.judged", defaultValue: "Judged", bundle: L10n.bundle)
  }
  public static var stepDecided: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.decided", defaultValue: "Your decision", bundle: L10n.bundle)
  }
  public static var stepObserver: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.observer", defaultValue: "Observer · config", bundle: L10n.bundle)
  }
  public static var stepActive: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.active", defaultValue: "Active · config", bundle: L10n.bundle)
  }
  public static var stepDone: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.done", defaultValue: "reached", bundle: L10n.bundle)
  }
  public static var stepRefused: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.refused", defaultValue: "rejected here", bundle: L10n.bundle)
  }
  public static var stepPending: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.step.pending", defaultValue: "not reached", bundle: L10n.bundle)
  }
  public static func interval(_ low: String, _ high: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.interval", defaultValue: "interval \(low) to \(high)", bundle: L10n.bundle)
  }
  public static var path: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.path", defaultValue: "Proposal path", bundle: L10n.bundle)
  }
  public static var diff: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.diff", defaultValue: "What changes", bundle: L10n.bundle)
  }
  public static var idea: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.idea", defaultValue: "New strategy idea", bundle: L10n.bundle)
  }
  public static var textOnly: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.textOnly", defaultValue: "text only", bundle: L10n.bundle)
  }
  public static var summary: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.summary", defaultValue: "Summary", bundle: L10n.bundle)
  }
  public static var expectedEffect: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.expectedEffect", defaultValue: "Expected effect", bundle: L10n.bundle)
  }
  public static var risks: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.risks", defaultValue: "Risks", bundle: L10n.bundle)
  }
  public static var whyNoChange: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.whyNoChange", defaultValue: "Why no change", bundle: L10n.bundle)
  }
  public static var whyRefused: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.whyRefused", defaultValue: "Why the answer was refused", bundle: L10n.bundle)
  }
  public static var hypothesis: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.hypothesis", defaultValue: "Hypothesis", bundle: L10n.bundle)
  }
  public static var entry: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.entry", defaultValue: "Entry", bundle: L10n.bundle)
  }
  public static var exit: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.exit", defaultValue: "Exit", bundle: L10n.bundle)
  }
  public static var filters: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.filters", defaultValue: "Filters", bundle: L10n.bundle)
  }
  public static var evidence: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.evidence", defaultValue: "Evidence", bundle: L10n.bundle)
  }
  public static var testPlan: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.testPlan", defaultValue: "How to test", bundle: L10n.bundle)
  }
  public static var holdout: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.holdout", defaultValue: "Hold-out check", bundle: L10n.bundle)
  }
  public static var simulated: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.simulated", defaultValue: "simulated", bundle: L10n.bundle)
  }
  public static func holdoutFrom(_ day: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.holdoutFrom", defaultValue: "hold-out from \(day)", bundle: L10n.bundle)
  }
  public static var notJudged: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.notJudged",
      defaultValue: "Not judged yet: run python -m tickr.advisor.judge on the Mac.",
      bundle: L10n.bundle)
  }
  public static func tradesMean(_ trades: Int, _ mean: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.tradesMean", defaultValue: "\(trades) tr · \(mean)", bundle: L10n.bundle)
  }
  public static func verdictEdge(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.verdict.edge",
      defaultValue: "\(name): the interval is above 0, evidence of an edge.",
      bundle: L10n.bundle)
  }
  public static func verdictNegative(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.verdict.negative",
      defaultValue: "\(name): the interval is below 0, evidence of a negative edge.",
      bundle: L10n.bundle)
  }
  public static func verdictNoEvidence(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.verdict.noEvidence",
      defaultValue: "\(name): the interval includes 0, no edge proven.",
      bundle: L10n.bundle)
  }
  public static func verdictTooFew(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.verdict.tooFew",
      defaultValue: "\(name): too few trades for an interval, no evidence either way.",
      bundle: L10n.bundle)
  }
  public static var totalR: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.totalR", defaultValue: "Total R", bundle: L10n.bundle)
  }
  public static var winRate: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.winRate", defaultValue: "Win rate", bundle: L10n.bundle)
  }
  public static var profitFactor: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.profitFactor", defaultValue: "Profit factor", bundle: L10n.bundle)
  }
  public static func fitting(_ mean: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.fitting", defaultValue: "Fitting period \(mean) · no evidence", bundle: L10n.bundle)
  }
  public static var fittingHint: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.fittingHint",
      defaultValue: "The advisor learned on these days, so their result proves nothing.",
      bundle: L10n.bundle)
  }
  public static func tunedOn(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.tunedOn", defaultValue: "Tuned on \(text)", bundle: L10n.bundle)
  }
  public static func judgeOn(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.judgeOn", defaultValue: "Judge on \(text)", bundle: L10n.bundle)
  }
  public static var note: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.note",
      // swiftlint:disable:next line_length
      defaultValue: "The advisor never applies anything. Accept records your decision; running a version as an observer or active is a config edit on the Mac.",
      bundle: L10n.bundle)
  }
  public static var reject: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.reject", defaultValue: "Reject", bundle: L10n.bundle)
  }
  public static var accept: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.accept", defaultValue: "Accept", bundle: L10n.bundle)
  }
  public static var cancel: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.cancel", defaultValue: "Cancel", bundle: L10n.bundle)
  }
  public static var review: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.review", defaultValue: "Review", bundle: L10n.bundle)
  }
  public static func confirmTitle(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.confirmTitle", defaultValue: "Accept \(name)?", bundle: L10n.bundle)
  }
  public static var confirmText: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.confirmText",
      defaultValue: "Only your decision is recorded. Nothing is copied, started or traded.",
      bundle: L10n.bundle)
  }
  public static func confirmReason(_ name: String) -> LocalizedStringResource {
    LocalizedStringResource("kit.advisor.confirmReason",
      defaultValue: "Record your decision on \(name)",
      bundle: L10n.bundle)
  }
  public static var acceptedNext: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.acceptedNext",
      defaultValue: "Accepted · next: a config edit on the Mac",
      bundle: L10n.bundle)
  }
  public static var rejectedRecorded: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.rejectedRecorded", defaultValue: "Rejected · recorded", bundle: L10n.bundle)
  }
  public static var decisionFailed: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.decisionFailed",
      defaultValue: "Couldn't record the decision",
      bundle: L10n.bundle)
  }
  public static var raised: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.raised", defaultValue: "raised", bundle: L10n.bundle)
  }
  public static var lowered: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.lowered", defaultValue: "lowered", bundle: L10n.bundle)
  }
  public static var changed: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.changed", defaultValue: "changed", bundle: L10n.bundle)
  }
  public static var back: LocalizedStringResource {
    LocalizedStringResource("kit.advisor.back", defaultValue: "Strategy lab", bundle: L10n.bundle)
  }
}
