import SwiftUI
import TickrDesign
import TickrKit

/// What the macOS advisor views share: symbols, tones and the rows they build from a run.
enum AdvisorLook {
  /// The advisor's mark, as on the design.
  static let symbol = "sparkles"
  /// An idea: text for a developer.
  static let ideaSymbol = "lightbulb"
  /// Path step symbols: proposed, judged, decided (a cross once rejected), observer, active.
  static let proposedSymbol = "checkmark"
  static let judgedSymbol = "scalemass"
  static let decidedSymbol = "checkmark"
  static let rejectedSymbol = "xmark"
  static let observerSymbol = "eye"
  static let activeSymbol = "lock"
  /// Back from the page to the Lab's cards.
  static let backSymbol = "chevron.left"
  /// The fitting period: results there are no evidence.
  static let fittingSymbol = "eye.slash"
  /// Arrows between a changed value's old and new value.
  static let upSymbol = "arrow.up"
  static let downSymbol = "arrow.down"
  static let changedSymbol = "arrow.right"
  /// Decimals of a mean R and its bounds, and of a profit factor; a win rate is whole percents.
  static let rDigits = 2
  static let factorDigits = 2
  static let percentDigits = 0
  /// Most changes the Lab card lists before the page.
  static let cardChanges = 3
  /// Between a figure's base and candidate value.
  static let arrow = " → "
  /// Narrowest a hold-out figure gets before the figures wrap, in points.
  static let figureMinWidth: CGFloat = 120

  /// Violet while it waits for the owner, teal once accepted, red once rejected or refused.
  static func tone(_ run: AdvisorRunV1) -> Tone {
    if let decision = run.decision { return decision.verdict == .accepted ? .accent : .loss }
    return switch run.status {
    case .proposed, .idea: .highlight
    case .noChange: .neutral
    case .refused: .loss
    }
  }

  static func steps(_ run: AdvisorRunV1, settings: SettingsV1?) -> [PathStep] {
    AdvisorStep.allCases.map { step in
      let rejected = step == .decided && run.decision?.verdict == .rejected
      let symbol = switch step {
      case .proposed: proposedSymbol
      case .judged: judgedSymbol
      case .decided: rejected ? rejectedSymbol : decidedSymbol
      case .observer: observerSymbol
      case .active: activeSymbol
      }
      let state: PathStep.State = rejected ? .refused : run.reached(step, settings: settings) ? .done : .pending
      let value = switch state {
      case .done: AdvisorWords.stepDone
      case .refused: AdvisorWords.stepRefused
      case .pending: AdvisorWords.stepPending
      }
      return PathStep(id: step.rawValue, title: Text(step.words), systemImage: symbol, state: state, value: Text(value))
    }
  }

  static func symbol(_ direction: ChangeDirection) -> String {
    switch direction {
    case .up: upSymbol
    case .down: downSymbol
    case .changed: changedSymbol
    }
  }

  static func r(_ value: Decimal) -> String {
    Risk.text(value, fractionDigits: rDigits)
  }

  /// "Nov 15 · 07:42" in New York time.
  static func when(_ run: AdvisorRunV1) -> String {
    Format.chartMonthDay(run.at.date) + Format.itemSeparator + Format.marketMinute(run.at.date)
  }

  /// The base and the candidate on one axis around 0 R.
  static func intervals(_ judge: AdvisorJudgeV1) -> [IntervalRow] {
    let scale = HoldoutScale(judge)
    let rows: [(String, AdvisorStatsV1?, Color)] = [(judge.base, judge.baseHoldout, Palette.accent),
      (judge.candidate, judge.holdout, Palette.highlight)]
    return rows.map { name, stats, color in
      let mean = stats?.meanR?.value
      let detail = stats?.trades.map { String(localized: AdvisorWords.tradesMean($0, mean.map(r) ?? Format.missing)) }
        ?? Format.missing
      return IntervalRow(id: name, name: name, detail: detail, color: color,
        low: stats?.meanRIntervalLow.map { scale.fraction($0.value) },
        mean: mean.map(scale.fraction),
        high: stats?.meanRIntervalHigh.map { scale.fraction($0.value) },
        value: String(localized: AdvisorWords.interval(
          stats?.meanRIntervalLow.map { r($0.value) } ?? Format.missing,
          stats?.meanRIntervalHigh.map { r($0.value) } ?? Format.missing)))
    }
  }
}

/// The Lab's advisor card: the leading run (the newest awaiting review) with its path and first
/// changes, and Review, which opens the advisor page.
struct AdvisorCard: View {
  @Environment(AppModel.self) private var model
  @Environment(AdvisorModel.self) private var advisor
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Card(AdvisorWords.title, tint: Palette.highlight, tone: .highlight) {
      if let count = advisor.runs?.awaitingReview, count > 0 {
        StatusPill(AdvisorWords.awaiting(count), tone: .highlight)
      }
    } content: {
      if let runs = advisor.runs {
        if let lead = runs.lead {
          HStack(spacing: Tokens.Space.s) {
            Text(verbatim: lead.title)
              .font(Tokens.Typography.calloutMono.weight(.bold))
              .lineLimit(1)
            StatusPill(lead.stateWords, tone: AdvisorLook.tone(lead))
            Spacer(minLength: Tokens.Space.s)
          }
          StepPath(AdvisorLook.steps(lead, settings: model.settings))
          ForEach(lead.changes.prefix(AdvisorLook.cardChanges), id: \.path) { change in
            ChangeLine(change: change)
          }
          Button { advisor.open() } label: {
            Label { Text(AdvisorWords.review) } icon: { Image(systemName: AdvisorLook.symbol) }
          }
          .buttonStyle(.action(.secondary))
        } else {
          // The sentence in the person's language; the bot's own cause (English) on hover.
          Footnote(AdvisorWords.noRuns)
            .help(Text(verbatim: runs.cause ?? String(localized: AdvisorWords.noRuns)))
        }
      } else if let failure = advisor.failure {
        ReadFailureNote(AdvisorWords.failed, detail: failure)
      }
      Footnote(AdvisorWords.note)
    }
    // The design's shine across the title: ornament, moving only while the bot is at work.
    .environment(\.titleShines, model.ornamentsMove(reduceMotion: reduceMotion))
  }
}

/// "key  old → new": the old value struck through, the arrow saying up or down.
struct ChangeLine: View {
  let change: AdvisorChangeV1

  var body: some View {
    // On one line while it fits; else the values go under the key, so neither is squeezed.
    ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.s) {
        key
        Spacer(minLength: Tokens.Space.xs)
        values
      }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        key
        values
      }
    }
  }

  private var key: some View {
    Text(verbatim: change.path)
      .font(Tokens.Typography.captionMono.weight(.semibold))
      .lineLimit(1)
      .truncationMode(.middle)
  }

  private var values: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(verbatim: change.now)
        .font(Tokens.Typography.captionMono)
        .strikethrough()
        .foregroundStyle(Palette.lossText)
      Image(systemName: AdvisorLook.symbol(change.direction))
        .font(Tokens.Typography.chevron)
        .foregroundStyle(Palette.profitText)
        .hint(Text(change.direction.words))
        .accessibilityLabel(Text(change.direction.words))
      Text(verbatim: change.proposed)
        .font(Tokens.Typography.captionMono.weight(.bold))
        .foregroundStyle(Palette.profitText)
    }
  }
}

/// Strategy lab › Advisor proposal: every run in a side list, the chosen one with its path, what
/// changes and why, the hold-out check, and Accept or Reject. Either only records the owner's
/// decision: nothing is copied, started or traded.
struct AdvisorPage: View {
  /// Order in which a run's rows rise.
  private enum Rows: Int {
    case path = 0, cards, decision
  }

  @Environment(AppModel.self) private var model
  @Environment(AdvisorModel.self) private var advisor
  /// The run whose Accept is being confirmed, taken when Accept was clicked, so a read that
  /// arrives while the dialog is open can never point the decision at another run.
  @State private var accepting: AdvisorRunV1?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      // The run list beside the run while the window has room for both, else the run alone.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 0) {
          list
            .frame(width: Tokens.Size.sideColumn)
          Divider()
          // An ideal width of one grid column: the run's long texts must not make the pair look
          // too wide to fit.
          shown
            .frame(minWidth: Tokens.Size.gridColumnMin, idealWidth: Tokens.Size.gridColumnMin, maxWidth: .infinity)
        }
        shown
      }
    }
    .confirmationDialog(Text(AdvisorWords.confirmTitle(accepting?.title ?? Format.missing)),
      isPresented: Binding { accepting != nil } set: { if !$0 { accepting = nil } }, presenting: accepting) { run in
      Button { decide(run.id, .accepted) } label: { Text(AdvisorWords.accept) }
      Button(role: .cancel) {} label: { Text(AdvisorWords.cancel) }
    } message: { _ in
      Text(AdvisorWords.confirmText)
    }
  }

  @ViewBuilder private var shown: some View {
    if let run = advisor.shown {
      detail(run)
    } else {
      // The sentence in the person's language; the bot's own cause (English) on hover.
      Footnote(AdvisorWords.noRuns)
        .help(Text(verbatim: advisor.runs?.cause ?? String(localized: AdvisorWords.noRuns)))
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private var header: some View {
    HStack(spacing: Tokens.Space.s) {
      Button { advisor.pageOpen = false } label: {
        Label { Text(AdvisorWords.back) } icon: { Image(systemName: AdvisorLook.backSymbol) }
      }
      .buttonStyle(.action(.ghost, size: .compact))
      Image(systemName: AdvisorLook.symbol).foregroundStyle(Palette.highlightText)
      Text(AdvisorWords.page).font(Tokens.Typography.button)
      Spacer()
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.s)
  }

  private var list: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        ForEach(advisor.runs?.runs ?? []) { run in
          Button { advisor.selected = run.id } label: {
            RunRow(run: run, selected: run.id == advisor.shown?.id)
          }
          .buttonStyle(.plain)
        }
        if let unreadable = advisor.runs?.unreadable, !unreadable.isEmpty {
          Footnote(AdvisorWords.unreadable(unreadable.count), color: Palette.warningText)
            .hint(Text(verbatim: unreadable.map { $0.id + Format.itemSeparator + $0.cause }
              .joined(separator: Format.lineSeparator)))
        }
        if let failure = advisor.failure {
          ReadFailureNote(AdvisorWords.failed, detail: failure)
        }
        InfoCaption(AdvisorWords.note)
          .padding(.top, Tokens.Space.m)
      }
      .padding(Tokens.Space.m)
    }
  }

  private func detail(_ run: AdvisorRunV1) -> some View {
    ScrollView {
      // The run's cards rise one after another as it is shown, as the design's page; another run
      // rises afresh.
      VStack(alignment: .leading, spacing: Tokens.Space.l) {
        Card(AdvisorWords.path, tint: Palette.highlight, tone: .highlight) {
          HStack(spacing: Tokens.Space.s) {
            StatusPill(run.modeWords, tone: .info)
            Text(verbatim: AdvisorLook.when(run))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textQuaternary)
          }
        } content: {
          Text(verbatim: run.proposed.map { run.base + Format.itemSeparator + $0 } ?? run.title)
            .font(Tokens.Typography.subtitle)
            .lineLimit(1)
            .truncationMode(.middle)
          StepPath(AdvisorLook.steps(run, settings: model.settings))
        }
        .rise(step: Rows.path.rawValue)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Tokens.Size.gridColumnMin), spacing: Tokens.Space.l,
          alignment: .top)], alignment: .leading, spacing: Tokens.Space.l) {
          VStack(alignment: .leading, spacing: Tokens.Space.l) {
            if !run.changes.isEmpty { ChangesCard(run: run) }
            if let idea = run.idea { IdeaCard(idea: idea) }
            TextsCard(run: run)
          }
          if run.status == .proposed || run.status == .idea { HoldoutCard(run: run) }
        }
        .rise(step: Rows.cards.rawValue)
        decisionBar(run).rise(step: Rows.decision.rawValue)
      }
      .id(run.id)
      .padding(Tokens.Space.xl)
      .frame(maxWidth: Tokens.Size.contentMaxWidth, alignment: .leading)
    }
  }

  /// The run's state with what happened to the decision on its own line, then the buttons, so
  /// neither squeezes the other in a narrow window.
  private func decisionBar(_ run: AdvisorRunV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      Group {
        if let decision = run.decision {
          Text(decision.verdict == .accepted ? AdvisorWords.acceptedNext : AdvisorWords.rejectedRecorded)
        } else if let failure = advisor.decisionFailures[run.id] {
          ReadFailureNote(AdvisorWords.decisionFailed, detail: failure, defersToConnection: false)
        }
      }
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: Tokens.Space.m) {
        StatusPill(run.stateWords, tone: AdvisorLook.tone(run), event: run.decision?.at)
        Spacer(minLength: Tokens.Space.s)
        if run.status == .proposed || run.status == .idea {
          Button { decide(run.id, .rejected) } label: {
            Label { Text(AdvisorWords.reject) } icon: { Image(systemName: AdvisorLook.rejectedSymbol) }
          }
          .buttonStyle(.action(.destructive))
          Button { accepting = run } label: {
            Label { Text(AdvisorWords.accept) } icon: { Image(systemName: AdvisorLook.decidedSymbol) }
          }
          .buttonStyle(.action(.primary))
        }
      }
    }
    .disabled(advisor.deciding != nil)
    .padding(Tokens.Space.m)
    .tickrCard(radius: Tokens.Radius.large)
  }

  private func decide(_ run: String, _ verdict: OwnerVerdict) {
    let url = model.baseURL
    Task { await advisor.decide(url, run: run, verdict: verdict) }
  }
}

/// One run in the page's side list.
private struct RunRow: View {
  let run: AdvisorRunV1
  let selected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Image(systemName: run.idea != nil && run.changes.isEmpty ? AdvisorLook.ideaSymbol : AdvisorLook.symbol)
          .foregroundStyle(AdvisorLook.tone(run).text)
        Text(verbatim: run.title)
          .font(Tokens.Typography.captionMono.weight(.bold))
          .lineLimit(1)
          .truncationMode(.middle)
      }
      HStack(spacing: Tokens.Space.s) {
        StatusPill(run.stateWords, tone: AdvisorLook.tone(run))
        Text(verbatim: AdvisorLook.when(run))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .padding(Tokens.Space.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(selected ? Palette.surfaceSunken : .clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium)
      .strokeBorder(selected ? Palette.separatorStrong : .clear, lineWidth: Tokens.Stroke.thin))
    .contentShape(Rectangle())
  }
}

/// What changes: key, old and new value, and the advisor's reason and evidence.
private struct ChangesCard: View {
  let run: AdvisorRunV1

  var body: some View {
    Card(AdvisorWords.diff) {
      if let folder = run.proposedFolder {
        Text(verbatim: folder).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
      }
    } content: {
      ForEach(run.changes, id: \.path) { change in
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          Divider()
          ChangeLine(change: change)
          Text(verbatim: change.reason)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textTertiary)
          Text(verbatim: change.evidence)
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
    }
    .opacity(run.decision?.verdict == .rejected ? Tokens.Opacity.medium : 1)
  }
}

/// The advisor's own words: summary, expected effect, risks, why no change or why refused.
private struct TextsCard: View {
  let run: AdvisorRunV1

  var body: some View {
    let parts: [(LocalizedStringResource, String)] = [
      (AdvisorWords.summary, run.summary), (AdvisorWords.expectedEffect, run.expectedEffect),
      (AdvisorWords.risks, run.risks.joined(separator: Format.itemSeparator)),
      (AdvisorWords.whyNoChange, run.noChangeReason), (AdvisorWords.whyRefused, run.cause),
    ].filter { !$0.1.isEmpty }
    Card(AdvisorWords.summary) {
      ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          CardLabel(part.0)
          Text(verbatim: part.1)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textSecondary)
            .textSelection(.enabled)
        }
      }
      Footnote(AdvisorWords.tunedOn(run.tunedOn))
      Footnote(AdvisorWords.judgeOn(run.judgeOn))
    }
  }
}

/// A new strategy idea: text for a developer, never code.
private struct IdeaCard: View {
  let idea: AdvisorIdeaV1

  var body: some View {
    let parts: [(LocalizedStringResource, String)] = [
      (AdvisorWords.hypothesis, idea.hypothesis), (AdvisorWords.entry, idea.entryRule),
      (AdvisorWords.exit, idea.exitRule), (AdvisorWords.filters, idea.filters),
      (AdvisorWords.evidence, idea.evidence), (AdvisorWords.testPlan, idea.testPlan),
    ].filter { !$0.1.isEmpty }
    Card(AdvisorWords.idea, tone: .warning) {
      StatusPill(AdvisorWords.textOnly, tone: .warning)
    } content: {
      Text(verbatim: idea.name).font(Tokens.Typography.calloutMono.weight(.bold))
      ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          CardLabel(part.0)
          Text(verbatim: part.1)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textSecondary)
            .textSelection(.enabled)
        }
      }
    }
  }
}

/// The hold-out check: base and candidate mean R with their intervals on one axis, the figures
/// "base → candidate", what each interval says, and the fitting period marked as no evidence.
private struct HoldoutCard: View {
  let run: AdvisorRunV1

  var body: some View {
    Card(AdvisorWords.holdout, tone: .warning) {
      HStack(spacing: Tokens.Space.s) {
        StatusPill(AdvisorWords.simulated, tone: .warning)
        if let judge = run.judge {
          Text(AdvisorWords.holdoutFrom(Format.dayLabel(judge.holdoutStarts)))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
    } content: {
      if let judge = run.judge {
        IntervalBars(AdvisorLook.intervals(judge), axis: AdvisorLook.r(0))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: AdvisorLook.figureMinWidth), spacing: Tokens.Space.s,
          alignment: .topLeading)], alignment: .leading, spacing: Tokens.Space.s) {
          MetricChip(AdvisorWords.totalR, value: pair(judge, \.totalR) { AdvisorLook.r($0) })
          MetricChip(AdvisorWords.winRate, value: pair(judge, \.winRatePercent) {
            String(localized: L10n.Trades.percent(Money.plain($0, fractionDigits: AdvisorLook.percentDigits)))
          })
          MetricChip(AdvisorWords.profitFactor, value: pair(judge, \.profitFactor) {
            Money.plain($0, fractionDigits: AdvisorLook.factorDigits)
          })
        }
        InfoCaption(judge.verdict.words(judge.candidate), tone: .warning)
        InfoCaption(judge.baseVerdict.words(judge.base))
        if let fitting = judge.fitting?.meanR {
          InfoCaption(AdvisorWords.fitting(AdvisorLook.r(fitting.value)), systemImage: AdvisorLook.fittingSymbol)
            .hint(Text(AdvisorWords.fittingHint))
        }
      } else {
        InfoCaption(AdvisorWords.notJudged)
      }
    }
  }

  /// "base → candidate" of one figure.
  private func pair(
    _ judge: AdvisorJudgeV1, _ figure: KeyPath<AdvisorStatsV1, DecimalString?>, _ text: (Decimal) -> String
  ) -> String {
    let base = judge.baseHoldout?[keyPath: figure].map { text($0.value) } ?? Format.missing
    let candidate = judge.holdout?[keyPath: figure].map { text($0.value) } ?? Format.missing
    return base + AdvisorLook.arrow + candidate
  }
}
