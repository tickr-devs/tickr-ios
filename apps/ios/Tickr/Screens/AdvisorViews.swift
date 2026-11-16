import SwiftUI
import TickrDesign
import TickrKit

/// What the iOS advisor screens share: symbols, tones and the rows they build from a run.
enum AdvisorLook {
  /// The advisor's mark: a star, as on the design.
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
  /// Arrows between a changed value's old and new value.
  static let upSymbol = "arrow.up"
  static let downSymbol = "arrow.down"
  static let changedSymbol = "arrow.right"
  /// Decimals of a mean R and its bounds, and of a profit factor; a win rate is whole percents.
  static let rDigits = 2
  static let factorDigits = 2
  static let percentDigits = 0
  /// The fitting period: results there are no evidence.
  static let fittingSymbol = "eye.slash"
  /// Most changes the Lab card lists before the page.
  static let cardChanges = 3

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

  /// The base and the candidate on one axis around 0 R.
  static func intervals(_ judge: AdvisorJudgeV1) -> [IntervalRow] {
    let scale = HoldoutScale(judge)
    return [(judge.base, judge.baseHoldout, Palette.accent), (judge.candidate, judge.holdout, Palette.highlight)]
      .map { name, stats, color in
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

/// The Lab's advisor card: the leading run (the newest awaiting review) with its path and changes,
/// then every listed run as a row that opens its page.
struct AdvisorCard: View {
  let advisor: AdvisorModel
  let url: URL?

  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack {
        Label { Text(AdvisorWords.title) } icon: { Image(systemName: AdvisorLook.symbol) }
          .font(Tokens.Typography.label)
          .foregroundStyle(Palette.highlightText)
        Spacer()
        if let count = advisor.runs?.awaitingReview, count > 0 {
          StatusPill(AdvisorWords.awaiting(count), tone: .highlight)
        }
      }
      content
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(tint: Palette.highlight)
    .task(id: url) {
      guard let url else { return }
      await advisor.load(url)
    }
  }

  @ViewBuilder private var content: some View {
    if let runs = advisor.runs {
      if let lead = runs.lead {
        StepPath(AdvisorLook.steps(lead, settings: model.settings))
        ForEach(lead.changes.prefix(AdvisorLook.cardChanges), id: \.path) { change in
          ChangeLine(change: change)
        }
        ForEach(runs.runs) { run in
          NavigationLink {
            AdvisorProposalView(advisor: advisor, runID: run.id, url: url)
          } label: {
            AdvisorRunRow(run: run)
          }
        }
      } else {
        InfoCaption(verbatim: runs.cause ?? String(localized: AdvisorWords.noRuns))
      }
      if !runs.unreadable.isEmpty {
        InfoCaption(AdvisorWords.unreadable(runs.unreadable.count), systemImage: LabView.warningSymbol, tone: .warning)
      }
    } else if let failure = advisor.failure {
      ReadFailureNote(AdvisorWords.failed, detail: failure)
    } else if url != nil {
      ProgressView().frame(maxWidth: .infinity)
    }
  }
}

/// One run in a list: its name, where it stands and when it ran.
struct AdvisorRunRow: View {
  let run: AdvisorRunV1

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: run.idea != nil && run.changes.isEmpty ? AdvisorLook.ideaSymbol : AdvisorLook.symbol)
        .foregroundStyle(AdvisorLook.tone(run).text)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: run.title)
          .font(Tokens.Typography.calloutMono.weight(.semibold))
          .foregroundStyle(Palette.textPrimary)
          .lineLimit(1)
        Text(verbatim: Format.day(run.at.date) + Format.separator + Format.time(run.at.date))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
      Spacer(minLength: Tokens.Space.s)
      StatusPill(run.stateWords, tone: AdvisorLook.tone(run))
      Chevron()
    }
    .padding(.vertical, Tokens.Space.xs)
    .contentShape(Rectangle())
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
        .accessibilityLabel(Text(change.direction.words))
      Text(verbatim: change.proposed)
        .font(Tokens.Typography.captionMono.weight(.bold))
        .foregroundStyle(Palette.profitText)
    }
  }
}

/// One advisor run: its path, what changes and why, the hold-out check, and Accept or Reject.
/// Accept asks for Face ID; either only records the owner's decision, nothing starts or trades.
struct AdvisorProposalView: View {
  /// Order in which the blocks rise in (`rise(step:)`), as on the design.
  private enum Order: Int { case header = 1, path, changes, idea, texts, holdout, notes }

  let advisor: AdvisorModel
  let runID: String
  let url: URL?

  @Environment(AppModel.self) private var model
  @State private var confirming = false
  /// Why Face ID could not confirm the owner (no passcode on the phone).
  @State private var ownerFailure: String?

  var body: some View {
    Screen(AdvisorWords.page, back: L10n.App.lab) {
      if let run = advisor.run(runID) {
        header(run)
          .rise(step: Order.header.rawValue)
        StepPath(AdvisorLook.steps(run, settings: model.settings))
          .padding(Tokens.Space.l)
          .tickrCard()
          .rise(step: Order.path.rawValue)
        if !run.changes.isEmpty { changes(run).rise(step: Order.changes.rawValue) }
        if let idea = run.idea { IdeaCard(idea: idea).rise(step: Order.idea.rawValue) }
        texts(run)
          .rise(step: Order.texts.rawValue)
        holdout(run)
          .rise(step: Order.holdout.rawValue)
        Group {
          InfoCaption(AdvisorWords.note)
          InfoCaption(AdvisorWords.tunedOn(run.tunedOn))
          InfoCaption(AdvisorWords.judgeOn(run.judgeOn))
        }
        .rise(step: Order.notes.rawValue)
      } else if advisor.runs != nil {
        InfoCaption(AdvisorWords.runGone)
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let run = advisor.run(runID) { decisionBar(run) }
    }
    .confirmationDialog(Text(AdvisorWords.confirmTitle(advisor.run(runID)?.title ?? runID)),
      isPresented: $confirming, titleVisibility: .visible) {
      Button { accept() } label: { Text(AdvisorWords.accept) }
      Button(role: .cancel) {} label: { Text(AdvisorWords.cancel) }
    } message: {
      Text(AdvisorWords.confirmText)
    }
  }

  private func header(_ run: AdvisorRunV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      Text(verbatim: run.title)
        .font(Tokens.Typography.title.monospaced())
        .foregroundStyle(Palette.textPrimary)
      ChipFlow {
        StatusPill(run.stateWords, tone: AdvisorLook.tone(run))
        StatusPill(run.modeWords, tone: .info)
        Text(verbatim: Format.day(run.at.date) + Format.separator + Format.time(run.at.date))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  private func changes(_ run: AdvisorRunV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(AdvisorWords.diff)
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
    .padding(Tokens.Space.l)
    .tickrCard()
    .opacity(run.decision?.verdict == .rejected ? Tokens.Opacity.medium : 1)
  }

  @ViewBuilder private func texts(_ run: AdvisorRunV1) -> some View {
    let parts: [(LocalizedStringResource, String)] = [
      (AdvisorWords.summary, run.summary), (AdvisorWords.expectedEffect, run.expectedEffect),
      (AdvisorWords.risks, run.risks.joined(separator: Format.separator)),
      (AdvisorWords.whyNoChange, run.noChangeReason), (AdvisorWords.whyRefused, run.cause),
    ].filter { !$0.1.isEmpty }
    if !parts.isEmpty {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            CardLabel(part.0)
            Text(verbatim: part.1)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textSecondary)
          }
        }
      }
      .padding(Tokens.Space.l)
      .frame(maxWidth: .infinity, alignment: .leading)
      .tickrCard()
    }
  }

  @ViewBuilder private func holdout(_ run: AdvisorRunV1) -> some View {
    if run.status == .proposed || run.status == .idea {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack {
          CardLabel(AdvisorWords.holdout)
          StatusPill(AdvisorWords.simulated, tone: .warning)
          Spacer()
          if let judge = run.judge {
            Text(AdvisorWords.holdoutFrom(Format.day(judge.holdoutStarts.noonInNewYork)))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        if let judge = run.judge {
          IntervalBars(AdvisorLook.intervals(judge), axis: AdvisorLook.r(0))
          JudgeFigures(judge: judge)
          InfoCaption(judge.verdict.words(judge.candidate), tone: .warning)
          InfoCaption(judge.baseVerdict.words(judge.base))
          if let fitting = judge.fitting?.meanR {
            InfoCaption(AdvisorWords.fitting(AdvisorLook.r(fitting.value)), systemImage: AdvisorLook.fittingSymbol)
          }
        } else {
          InfoCaption(AdvisorWords.notJudged)
        }
      }
      .padding(Tokens.Space.l)
      .tickrCard()
    }
  }

  @ViewBuilder private func decisionBar(_ run: AdvisorRunV1) -> some View {
    if run.status == .proposed || run.status == .idea {
      VStack(spacing: Tokens.Space.s) {
        if let failure = ownerFailure ?? advisor.decisionFailures[run.id] {
          ReadFailureNote(AdvisorWords.decisionFailed, detail: failure, defersToConnection: false)
        }
        if let decision = run.decision {
          StatusPill(decision.verdict == .accepted ? AdvisorWords.acceptedNext : AdvisorWords.rejectedRecorded,
            tone: AdvisorLook.tone(run), event: decision.at)
            .frame(maxWidth: .infinity)
        }
        HStack(spacing: Tokens.Space.s) {
          Button { decide(.rejected) } label: {
            Label { Text(AdvisorWords.reject) } icon: { Image(systemName: AdvisorLook.rejectedSymbol) }
          }
          .buttonStyle(.action(.destructive))
          Button { confirming = true } label: {
            Label { Text(AdvisorWords.accept) } icon: { Image(systemName: AdvisorLook.decidedSymbol) }
          }
          .buttonStyle(.action(.primary))
        }
        .disabled(url == nil || advisor.deciding != nil)
      }
      .padding(Tokens.Space.l)
      .background(.bar)
    }
  }

  private func accept() {
    let name = advisor.run(runID)?.title ?? runID
    Task {
      switch await Biometrics.confirm(String(localized: AdvisorWords.confirmReason(name))) {
      case .confirmed:
        ownerFailure = nil
        await send(.accepted)
      case .declined:
        return
      case .unavailable(let cause):
        ownerFailure = cause
      }
    }
  }

  private func decide(_ verdict: OwnerVerdict) {
    Task { await send(verdict) }
  }

  private func send(_ verdict: OwnerVerdict) async {
    guard let url else { return }
    ownerFailure = nil
    await advisor.decide(url, run: runID, verdict: verdict)
  }
}

/// Total R, win rate and profit factor of the candidate's hold-out, each with the base's beside it.
struct JudgeFigures: View {
  let judge: AdvisorJudgeV1

  @ScaledMetric(relativeTo: .body) private var figureWidth = LabReplayCard.figureMinWidth

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: figureWidth), spacing: Tokens.Space.s, alignment: .topLeading)],
      alignment: .leading, spacing: Tokens.Space.s) {
      MetricChip(AdvisorWords.totalR, value: pair(\.totalR) { AdvisorLook.r($0) })
      MetricChip(AdvisorWords.winRate, value: pair(\.winRatePercent) {
        Money.plain($0, fractionDigits: AdvisorLook.percentDigits) + Format.percentSign
      })
      MetricChip(AdvisorWords.profitFactor, value: pair(\.profitFactor) {
        Money.plain($0, fractionDigits: AdvisorLook.factorDigits)
      })
    }
  }

  /// "base → candidate" of one figure.
  private func pair(_ figure: KeyPath<AdvisorStatsV1, DecimalString?>, _ text: (Decimal) -> String) -> String {
    let base = judge.baseHoldout?[keyPath: figure].map { text($0.value) } ?? Format.missing
    let candidate = judge.holdout?[keyPath: figure].map { text($0.value) } ?? Format.missing
    return base + Format.arrow + candidate
  }
}

/// A new strategy idea: text for a developer, never code.
struct IdeaCard: View {
  let idea: AdvisorIdeaV1

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack {
        Label { Text(AdvisorWords.idea) } icon: { Image(systemName: AdvisorLook.ideaSymbol) }
          .font(Tokens.Typography.label)
          .foregroundStyle(Palette.warningText)
        Spacer()
        StatusPill(AdvisorWords.textOnly, tone: .warning)
      }
      Text(verbatim: idea.name)
        .font(Tokens.Typography.calloutMono.weight(.bold))
      let parts: [(LocalizedStringResource, String)] = [
        (AdvisorWords.hypothesis, idea.hypothesis), (AdvisorWords.entry, idea.entryRule),
        (AdvisorWords.exit, idea.exitRule), (AdvisorWords.filters, idea.filters),
        (AdvisorWords.evidence, idea.evidence), (AdvisorWords.testPlan, idea.testPlan),
      ].filter { !$0.1.isEmpty }
      ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          CardLabel(part.0)
          Text(verbatim: part.1)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textSecondary)
        }
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }
}
