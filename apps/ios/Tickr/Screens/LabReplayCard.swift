import SwiftUI
import TickrDesign
import TickrKit

/// The Lab's replay: a strategy version SIMULATED over the last sessions of data fetched on the
/// Mac, or over one of its days, optionally compared with a second version over the same days
/// (GET/POST /lab/replay), started here and read while the Lab is open. A refusal (the session is
/// open, a run is going, no data) reads as a calm reason that clears once the replay moves on or
/// after `LabModel.replaySeconds`; the bot never reads the replay.
struct LabReplayCard: View {
  /// Symbols of a refusal and a picker's menu.
  static let refusalSymbol = "info.circle"
  static let menuSymbol = "chevron.down"
  /// Narrowest a figure gets before the figures wrap to another row, in points at the default text
  /// size (scaled with Dynamic Type).
  static let figureMinWidth: CGFloat = 96

  let lab: LabModel
  let url: URL?

  /// The chosen folders and day; nil means the bot's default (the active version, no comparison,
  /// the last sessions).
  @State private var version: String?
  @State private var compare: String?
  @State private var day: WireDate?
  @State private var oneDay = false

  @ScaledMetric(relativeTo: .body) private var figureWidth = LabReplayCard.figureMinWidth

  private var replay: LabReplayV1? { lab.replay }
  private var running: Bool { replay?.state == .running }
  /// Versions a run may name: their folder can be replayed.
  private var runnable: [LabVersionV1] { replay?.versions.filter { $0.cause == nil } ?? [] }
  /// The version to replay: the one picked while the bot still offers it, else the active one,
  /// else the first it offers.
  private var first: String? {
    if let version, runnable.contains(where: { $0.folder == version }) { return version }
    return (runnable.first { $0.role == .active } ?? runnable.first)?.folder
  }
  /// The second version: the one picked while the bot still offers it and it is not the first.
  private var second: String? {
    guard let compare, compare != first, runnable.contains(where: { $0.folder == compare }) else { return nil }
    return compare
  }
  /// The bot lists no version (an older API): a start replays its default, the active one.
  private var listsNone: Bool { replay?.versions.isEmpty ?? true }
  /// The day to replay: the one picked while it is still a pool day, else the newest.
  private var chosenDay: WireDate? {
    guard oneDay, let days = replay?.days else { return nil }
    if let day, days.contains(day) { return day }
    return days.first
  }

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
      choices
      status
      if let refusal = lab.replayRefusal, !running {
        InfoCaption(verbatim: refusal, systemImage: Self.refusalSymbol)
      }
      Button {
        guard let url else { return }
        Task { await lab.startReplay(url, version: first, compare: second, day: chosenDay) }
      } label: {
        // The design's full-width button: the title alone, a spinner beside it while starting.
        HStack(spacing: Tokens.Space.s) {
          if lab.replayStarting { ProgressView() }
          Text(second == nil ? L10n.Lab.replayStart : L10n.Lab.replayStartCompare)
        }
        .font(Tokens.Typography.button)
        .foregroundStyle(Palette.infoText)
        .frame(maxWidth: .infinity, minHeight: Tokens.Size.touchTarget)
        .background(Palette.info.opacity(Tokens.Opacity.wash),
          in: RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
          .strokeBorder(Palette.info, lineWidth: Tokens.Stroke.thin))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(url == nil || replay == nil || (first == nil && !listsNone) || running || lab.replayStarting
        || (oneDay && chosenDay == nil))
      InfoCaption(L10n.Lab.replayNote)
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
    .task(id: url) {
      guard let url else { return }
      await lab.followReplay(url)
    }
    .onChange(of: first) { _, now in
      if compare == now { compare = nil }
    }
  }

  /// Which version, which second version and which days the next run replays.
  @ViewBuilder private var choices: some View {
    if runnable.isEmpty, let cause = replay?.versions.first?.cause {
      // Every version the bot lists is refused: say why rather than leave the start dead.
      InfoCaption(verbatim: cause, systemImage: LabView.warningSymbol, tone: .warning)
    }
    if !runnable.isEmpty {
      ChipFlow {
        Menu {
          Picker(selection: Binding(get: { first ?? "" }, set: { version = $0 })) {
            ForEach(runnable, id: \.folder) { item in
              Text(verbatim: name(item)).tag(item.folder)
            }
          } label: {
            Text(L10n.Lab.replayVersion)
          }
        } label: {
          menuLabel(runnable.first { $0.folder == first }.map(name) ?? Format.missing, tone: .accent)
        }
        .accessibilityLabel(Text(L10n.Lab.replayVersion))
        Text(L10n.Lab.replayVersus)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
        Menu {
          Picker(selection: Binding(get: { second }, set: { compare = $0 })) {
            Text(L10n.Lab.replayCompareNone).tag(String?.none)
            ForEach(runnable.filter { $0.folder != first }, id: \.folder) { item in
              Text(verbatim: name(item)).tag(String?.some(item.folder))
            }
          } label: {
            Text(L10n.Lab.replayCompare)
          }
        } label: {
          menuLabel(runnable.first { $0.folder == second }.map(name)
            ?? String(localized: L10n.Lab.replayCompareNone), tone: second == nil ? .neutral : .highlight)
        }
        .accessibilityLabel(Text(L10n.Lab.replayCompare))
      }
      // Segments while both labels fit; at large text sizes a menu, which wraps nothing away.
      ViewThatFits(in: .horizontal) {
        SegmentChips(options: [(false, Text(L10n.Lab.replayLastSessions(replay?.sessions ?? .zero))),
          (true, Text(L10n.Lab.replayOneDay))], selection: $oneDay, style: .filled)
          .fixedSize(horizontal: false, vertical: true)
        daysPicker.pickerStyle(.menu)
      }
      if oneDay, let days = replay?.days, !days.isEmpty {
        Menu {
          Picker(selection: Binding(get: { chosenDay ?? days[0] }, set: { day = $0 })) {
            ForEach(days, id: \.self) { item in
              Text(verbatim: Format.day(item.noonInNewYork)).tag(item)
            }
          } label: {
            Text(L10n.Lab.replayDay)
          }
        } label: {
          menuLabel(Format.day((chosenDay ?? days[0]).noonInNewYork), tone: .accent)
        }
        .accessibilityLabel(Text(L10n.Lab.replayDay))
      }
    }
  }

  /// The last sessions or one day.
  private var daysPicker: some View {
    Picker(selection: $oneDay) {
      Text(L10n.Lab.replayLastSessions(replay?.sessions ?? .zero)).tag(false)
      Text(L10n.Lab.replayOneDay).tag(true)
    } label: {
      Text(L10n.Lab.replayDays)
    }
  }

  /// A picker's current choice as a pill with a menu chevron.
  private func menuLabel(_ title: String, tone: Tone) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      Text(verbatim: title)
        .lineLimit(1)
      Image(systemName: Self.menuSymbol)
        .imageScale(.small)
    }
    .font(Tokens.Typography.captionMono.weight(.semibold))
    .foregroundStyle(tone.text)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(tone.fill.opacity(Tokens.Opacity.wash), in: Capsule())
    .overlay(Capsule().strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
  }

  /// "price-action-v2 v2 · observer": a version as the pickers name it.
  private func name(_ item: LabVersionV1) -> String {
    let title = String(localized: L10n.Lab.versionName(item.strategy ?? item.folder, item.version ?? Format.missing))
    return String(localized: L10n.Lab.versionWithRole(title, String(localized: role(item.role))))
  }

  private func role(_ role: LabVersionRole) -> LocalizedStringResource {
    switch role {
    case .active: L10n.Lab.roleActive
    case .observer: L10n.Lab.roleObserver
    case .candidate: L10n.Lab.roleCandidate
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
        if let second = replay.compare {
          Text(L10n.Lab.replayThen(String(localized: L10n.Lab.versionName(second.strategy, second.version))))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textTertiary)
        }
      case .done:
        if let second = replay.compare, let summary = replay.summary {
          comparison(replay, summary, second)
        } else if let summary = replay.summary {
          result(summary)
        }
        if let cause = replay.cause {
          InfoCaption(verbatim: cause)
        }
        if let day = replay.day {
          InfoCaption(L10n.Lab.replayOneDayNote(Format.day(day.noonInNewYork)))
        }
      case .failed:
        InfoCaption(verbatim: replay.cause ?? Format.missing, systemImage: LabView.warningSymbol, tone: .loss)
      case .idle:
        InfoCaption(L10n.Lab.replayIdle)
      }
    } else if let failure = lab.replayFailure {
      ReadFailureNote(L10n.Lab.replayFailed, detail: failure)
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

  /// Both versions side by side over the same days, as mean R with trades and the bot-limited
  /// result under it, then the second minus the first.
  @ViewBuilder private func comparison(
    _ replay: LabReplayV1, _ summary: LabReplaySummaryV1, _ second: LabReplayLegV1
  ) -> some View {
    let firstName = L10n.Lab.versionName(replay.strategy ?? Format.missing, replay.version ?? Format.missing)
    let secondName = L10n.Lab.versionName(second.strategy, second.version)
    if let other = second.summary {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        // The full names, wrapping, in the chips' colours: a chip's label may cut a long one short.
        ChipFlow {
          Text(firstName).foregroundStyle(Tone.accent.text)
          Text(L10n.Lab.replayVersus).foregroundStyle(Palette.textTertiary)
          Text(secondName).foregroundStyle(Tone.highlight.text)
        }
        .font(Tokens.Typography.captionMono.weight(.semibold))
        LazyVGrid(columns: [GridItem(.adaptive(minimum: figureWidth), spacing: Tokens.Space.s, alignment: .topLeading)],
          alignment: .leading, spacing: Tokens.Space.s) {
          versionChip(firstName, summary, tone: .accent)
          versionChip(secondName, other, tone: .highlight)
          if let low = summary.meanR?.value, let high = other.meanR?.value {
            let difference = high - low
            MetricChip(L10n.Lab.replayDifference, tone: tone(difference)) {
              VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(verbatim: r(difference)).foregroundStyle(Palette.result(difference))
                caption(String(localized: L10n.Lab.replayMeanRPerTrade))
              }
            }
          } else {
            MetricChip(L10n.Lab.replayDifference, value: Format.missing)
          }
        }
        InfoCaption(L10n.Lab.replayData(Format.day(summary.firstDay.noonInNewYork),
          Format.day(summary.lastDay.noonInNewYork), summary.sessions))
      }
    } else {
      result(summary)
      InfoCaption(L10n.Lab.replayCompareFailed(String(localized: secondName), second.cause ?? Format.missing),
        systemImage: LabView.warningSymbol, tone: .warning)
    }
  }

  /// One version of a comparison: its mean R, then its trades and its result with the bot's limits.
  private func versionChip(_ title: LocalizedStringResource, _ summary: LabReplaySummaryV1, tone: Tone) -> some View {
    MetricChip(title, tone: tone) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: r(summary.meanR)).foregroundStyle(color(summary.meanR) ?? Palette.textPrimary)
        caption(String(localized: L10n.Lab.replayTradesAndUsd(summary.trades,
          Money.signedUSD(summary.botTotalUsd.value))))
      }
    }
  }

  private func caption(_ text: String) -> some View {
    Text(verbatim: text)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
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
