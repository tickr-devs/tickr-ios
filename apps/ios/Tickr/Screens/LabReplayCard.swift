import SwiftUI
import TickrDesign
import TickrKit

/// The Lab's replay: the active strategy SIMULATED over the last sessions of data fetched on the
/// Mac (GET/POST /lab/replay), started here and read while the Lab is open. A refusal (the session
/// is open, a run is going, no data) reads as a calm reason that clears once the replay moves on or
/// after `LabModel.replaySeconds`; the bot never reads the replay.
struct LabReplayCard: View {
  /// Symbols of the start button and of a refusal.
  static let startSymbol = "play.fill"
  static let refusalSymbol = "info.circle"
  /// Narrowest a figure gets before the figures wrap to another row, in points at the default text
  /// size (scaled with Dynamic Type).
  static let figureMinWidth: CGFloat = 96

  let lab: LabModel
  let url: URL?

  @ScaledMetric(relativeTo: .body) private var figureWidth = LabReplayCard.figureMinWidth

  private var replay: LabReplayV1? { lab.replay }
  private var running: Bool { replay?.state == .running }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(alignment: .firstTextBaseline) {
        if let sessions = replay?.sessions {
          CardLabel(L10n.Lab.replayLast(sessions))
        } else {
          CardLabel(L10n.Lab.replayRecent)
        }
        Spacer()
        if let replay { pill(replay) }
      }
      status
      if let refusal = lab.replayRefusal, !running {
        InfoCaption(verbatim: refusal, systemImage: Self.refusalSymbol)
      }
      Button {
        guard let url else { return }
        Task { await lab.startReplay(url) }
      } label: {
        Label {
          Text(L10n.Lab.replayStart)
        } icon: {
          if lab.replayStarting { ProgressView() } else { Image(systemName: Self.startSymbol) }
        }
      }
      .buttonStyle(.action(.secondary))
      .disabled(url == nil || replay == nil || running || lab.replayStarting)
      InfoCaption(L10n.Lab.replayNote)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
    .task(id: url) {
      guard let url else { return }
      await lab.followReplay(url)
    }
  }

  private func pill(_ replay: LabReplayV1) -> some View {
    switch replay.state {
    case .idle: StatusPill(L10n.Lab.replayStateIdle, tone: .neutral)
    case .running: StatusPill(L10n.Lab.replayStateRunning, tone: .accent, live: true, event: replay.runId)
    case .done: StatusPill(L10n.Lab.replayStateDone, tone: .profit)
    case .failed: StatusPill(L10n.Lab.replayStateFailed, tone: .loss)
    }
  }

  @ViewBuilder private var status: some View {
    if let replay {
      switch replay.state {
      case .running:
        HStack(spacing: Tokens.Space.s) {
          ProgressView()
          if let started = replay.startedAt {
            Text(L10n.Lab.replayRunningSince(Format.time(started.date)))
              .font(Tokens.Typography.caption)
              .foregroundStyle(Palette.textSecondary)
          }
        }
      case .done:
        if let summary = replay.summary {
          result(summary)
        }
        if let cause = replay.cause {
          InfoCaption(verbatim: cause)
        }
      case .failed:
        InfoCaption(verbatim: replay.cause ?? Format.missing, systemImage: LabView.warningSymbol, tone: .loss)
      case .idle:
        InfoCaption(L10n.Lab.replayIdle)
      }
    } else if let failure = lab.replayFailure {
      InfoCaption(L10n.Lab.replayFailed(failure), systemImage: LabView.warningSymbol, tone: .warning)
    } else if url != nil {
      ProgressView().frame(maxWidth: .infinity)
    }
  }

  private func result(_ summary: LabReplaySummaryV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: figureWidth), spacing: Tokens.Space.s, alignment: .topLeading)],
        alignment: .leading, spacing: Tokens.Space.s) {
        MetricChip(L10n.Lab.replayTrades, value: String(summary.trades))
        MetricChip(L10n.Lab.replayWinRate, value: percent(summary.winRatePercent))
        MetricChip(L10n.Lab.replayMeanR, value: r(summary.meanR), tone: tone(summary.meanR),
          color: color(summary.meanR))
        MetricChip(L10n.Lab.replayProfitFactor, value: factor(summary.profitFactor))
        MetricChip(L10n.Lab.replayMaxDrawdown, value: summary.maxDrawdownR.map { r(-$0.value) } ?? Format.missing)
        MetricChip(L10n.Lab.replayWithLimits, value: Money.signedUSD(summary.botTotalUsd.value),
          tone: tone(summary.botTotalUsd.value), color: Palette.result(summary.botTotalUsd.value))
      }
      if let low = summary.meanRIntervalLow?.value, let high = summary.meanRIntervalHigh?.value {
        InfoCaption(L10n.Lab.replayInterval(Money.plain(summary.confidencePercent.value, fractionDigits: StatDigits.percent),
          r(low), r(high)))
      }
      InfoCaption(L10n.Lab.replayBotTrades(summary.botTrades))
      InfoCaption(L10n.Lab.replayData(Format.day(summary.firstDay.noonInNewYork),
        Format.day(summary.lastDay.noonInNewYork), summary.sessions))
    }
  }

  private func r(_ value: DecimalString?) -> String {
    value.map { r($0.value) } ?? Format.missing
  }

  /// "+0.18 R": two decimals, as a mean or a bound would hide its difference at one.
  private func r(_ value: Decimal) -> String {
    String(localized: L10n.Lab.replayR(Money.signed(value, fractionDigits: StatDigits.r)))
  }

  private func percent(_ value: DecimalString?) -> String {
    value.map { Money.plain($0.value, fractionDigits: StatDigits.percent) + Format.percentSign } ?? Format.missing
  }

  private func factor(_ value: DecimalString?) -> String {
    value.map { Money.plain($0.value, fractionDigits: StatDigits.factor) } ?? Format.missing
  }

  private func tone(_ value: DecimalString?) -> Tone? {
    value.flatMap { tone($0.value) }
  }

  /// The rail of a result: green above zero, red below, plain at zero.
  private func tone(_ value: Decimal) -> Tone? {
    value > 0 ? .profit : value < 0 ? .loss : nil
  }

  private func color(_ value: DecimalString?) -> Color? {
    value.map { Palette.result($0.value) }
  }
}
