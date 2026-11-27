import SwiftUI
import TickrDesign
import TickrKit

/// "Compare two versions" (IOS2Lab): a strategy version SIMULATED over the last sessions of data
/// fetched on the Mac, or over one of its days, optionally compared with a second version over the
/// same days (GET/POST /lab/replay), started here and read while the Lab is open. A run's result is
/// each version's net with the bot's limits and its trades side by side, a line saying which earned
/// more, and "Win rate and more ›" with every figure in a sheet; the "i" says how it runs. While
/// the regular session refuses a start (`LabReplayV1.availableAt`), the button rests with the time
/// it opens and a countdown; any other refusal (a run going, no data) reads as a calm reason in words that clears
/// once the replay moves on or after `LabModel.replaySeconds`; the bot never reads the replay.
struct LabReplayCard: View {
  @Environment(AppModel.self) private var model

  /// Symbols of a refusal, of the wait for the session to close and of a picker's menu.
  static let refusalSymbol = "info.circle"
  static let waitSymbol = "clock"
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
  @State private var showsInfo = false

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
      HStack(spacing: 0) {
        CardLabel(L10n.Lab.compare)
        InfoToggle(shown: $showsInfo, label: L10n.Lab.compareAbout)
        Spacer(minLength: 0)
      }
      if showsInfo {
        InfoCaption(L10n.Lab.replayNote)
          .transition(.opacity)
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
        // The design's full-width button: the title alone; while starting, the spinner and what
        // is in flight (mockup v102).
        HStack(spacing: Tokens.Space.s) {
          if lab.replayStarting { Spinner() }
          Text(lab.replayStarting ? InFlightText.replayStarting
            : replay?.state == .done ? L10n.Lab.replayRunAgain
            : second == nil ? L10n.Lab.replayStart : L10n.Lab.replayStartCompare)
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
        || (oneDay && chosenDay == nil) || waitsUntil != nil)
      if let waitsUntil, !running {
        availability(waitsUntil)
      }
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

  /// When a start is allowed again while the regular session refuses one, from the bot's own
  /// document (never found out by a refused start).
  private var waitsUntil: Date? { replay?.waitsUntil(now: model.botNow) }

  /// Why the button rests: "Available after 16:00 ET · in 1:12:03", counting down; the parts
  /// wrap whole at large text sizes.
  private func availability(_ until: Date) -> some View {
    Label {
      ChipFlow {
        Text(L10n.Lab.replayAvailableAfter(Format.time(until)))
        HStack(spacing: Tokens.Space.xs) {
          Text(L10n.Lab.replayAvailableIn)
          Text(timerInterval: Date.now...Date.now.addingTimeInterval(until.timeIntervalSince(model.botNow)))
            .monospacedDigit()
        }
      }
    } icon: {
      Image(systemName: Self.waitSymbol)
    }
    .font(Tokens.Typography.caption)
    .foregroundStyle(Palette.textSecondary)
    .accessibilityElement(children: .combine)
  }

  /// Which version, which second version and which days the next run replays.
  @ViewBuilder private var choices: some View {
    if runnable.isEmpty, let cause = replay?.versions.first?.causeText {
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
            ?? String(localized: L10n.Lab.replayCompareNone), tone: second == nil ? nil : .highlight)
        }
        .accessibilityLabel(Text(L10n.Lab.replayCompare))
      }
      // Segments while both labels fit; at large text sizes a menu, which wraps nothing away.
      ViewThatFits(in: .horizontal) {
        SegmentSwitch(options: [(false, Text(L10n.Lab.replayLastSessions(replay?.sessions ?? .zero))),
          (true, Text(L10n.Lab.replayOneDay))], selection: $oneDay)
          .fixedSize(horizontal: false, vertical: true)
        daysPicker.pickerStyle(.menu)
      }
      if oneDay, let days = replay?.days, !days.isEmpty {
        Menu {
          Picker(selection: Binding(get: { chosenDay ?? days[0] }, set: { day = $0 })) {
            ForEach(days, id: \.self) { item in
              Text(verbatim: DayText.day(item.noonInNewYork)).tag(item)
            }
          } label: {
            Text(L10n.Lab.replayDay)
          }
        } label: {
          menuLabel(DayText.day((chosenDay ?? days[0]).noonInNewYork), tone: .accent)
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

  /// A picker's current choice as the apps' chip (`chipFace`) with a menu mark: chosen in the
  /// version's tone, plain while nothing is chosen ("No comparison"). It answers taps over the
  /// whole touch target, as every chip does.
  private func menuLabel(_ title: String, tone: Tone?) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      Text(verbatim: title)
      Image(systemName: Self.menuSymbol)
        .imageScale(.small)
    }
    .chipFace(selected: tone != nil, tone: tone ?? .info)
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

  @ViewBuilder private var status: some View {
    if let replay {
      switch replay.state {
      case .running:
        HStack(spacing: Tokens.Space.s) {
          Spinner()
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
        if let summary = replay.summary {
          outcome(replay, summary)
        }
        if let cause = replay.causeText {
          InfoCaption(verbatim: cause)
        }
        if let day = replay.day {
          InfoCaption(L10n.Lab.replayOneDayNote(DayText.day(day.noonInNewYork)))
        }
      case .failed:
        InfoCaption(verbatim: replay.causeText ?? Format.missing, systemImage: LabView.warningSymbol, tone: .loss)
      case .idle:
        // The apps' empty state, sized to its content: no run yet is a calm state, not a gap.
        ContentUnavailableView {
          Label { Text(L10n.Lab.replayIdle) } icon: { Image(systemName: EmptyState.nothingSymbol) }
        }
      }
    } else if let failure = lab.replayFailure {
      ReadFailureNote(L10n.Lab.replayFailed, detail: failure)
    } else if url != nil {
      Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.lines) }
    }
  }

  /// A run's result on the card (IOS2Lab): each version's net with the bot's limits and its trades,
  /// side by side while they fit, which one earned more, then "Win rate and more ›"
  /// with every figure in a sheet.
  @ViewBuilder private func outcome(_ replay: LabReplayV1, _ summary: LabReplaySummaryV1) -> some View {
    let firstName = L10n.Lab.versionName(replay.strategy ?? Format.missing, replay.version ?? Format.missing)
    let second = replay.compare
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: Tokens.Space.s) { netColumns(firstName, summary, second) }
      VStack(alignment: .leading, spacing: Tokens.Space.s) { netColumns(firstName, summary, second) }
    }
    if let second {
      if let other = second.summary {
        Text(verdict(L10n.Lab.versionName(second.strategy, second.version), summary, other, oneDay: replay.day != nil))
          .font(Tokens.Typography.callout)
          .foregroundStyle(Palette.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        InfoCaption(L10n.Lab.replayCompareFailed(String(localized: L10n.Lab.versionName(second.strategy,
          second.version)), second.causeText ?? Format.missing), systemImage: LabView.warningSymbol, tone: .warning)
      }
    }
    FooterDetail(L10n.Lab.replayDetails, endsCard: false) {
      if let second {
        comparison(replay, summary, second)
      } else {
        result(summary)
      }
    }
  }

  /// The first version's column, then the second's when there is one.
  @ViewBuilder private func netColumns(
    _ firstName: LocalizedStringResource, _ summary: LabReplaySummaryV1, _ second: LabReplayLegV1?
  ) -> some View {
    netColumn(firstName, summary, tone: .accent)
    if let second {
      netColumn(L10n.Lab.versionName(second.strategy, second.version), second.summary, tone: .highlight)
    }
  }

  /// One version: its name in its chip's colour, its net with the bot's limits big, its trades.
  private func netColumn(_ name: LocalizedStringResource, _ summary: LabReplaySummaryV1?, tone: Tone) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      Text(name)
        .font(Tokens.Typography.captionMono.weight(.semibold))
        .foregroundStyle(tone.text)
        .fixedSize(horizontal: false, vertical: true)
      Text(verbatim: summary.map { Money.signedUSD($0.botTotalUsd.value) } ?? Format.missing)
        .font(Tokens.Typography.metric)
        .foregroundStyle(summary.map { Palette.result($0.botTotalUsd.value) } ?? Palette.textQuaternary)
        .fixedSize()
      if let summary {
        Text(L10n.Lab.replayTradesCount(summary.botTrades))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
      }
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  /// Which version earned more with the bot's limits: "v2 earned +$69.00 more · not proven yet",
  /// "v2 earned $3.10 less", or that one day is only an example.
  private func verdict(
    _ name: LocalizedStringResource, _ first: LabReplaySummaryV1, _ other: LabReplaySummaryV1, oneDay: Bool
  ) -> LocalizedStringResource {
    if oneDay { return L10n.Lab.verdictOneDay }
    let difference = other.botTotalUsd.value - first.botTotalUsd.value
    let title = String(localized: name)
    if difference > 0 { return L10n.Lab.verdictMore(title, Money.signedUSD(difference)) }
    if difference < 0 { return L10n.Lab.verdictLess(title, Money.usd(-difference)) }
    return L10n.Lab.verdictSame
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
      InfoCaption(L10n.Lab.replayData(DayText.day(summary.firstDay.noonInNewYork),
        DayText.day(summary.lastDay.noonInNewYork), summary.sessions))
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
        InfoCaption(L10n.Lab.replayData(DayText.day(summary.firstDay.noonInNewYork),
          DayText.day(summary.lastDay.noonInNewYork), summary.sessions))
      }
    } else {
      result(summary)
      InfoCaption(L10n.Lab.replayCompareFailed(String(localized: secondName), second.causeText ?? Format.missing),
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
    value.map { Percent.plain(points: $0.value) } ?? Format.missing
  }

  private func factor(_ value: DecimalString?) -> String {
    value.map { Money.plain($0.value, fractionDigits: StatDigits.factor) } ?? Format.missing
  }

  private func tone(_ value: DecimalString?) -> Tone? {
    value.flatMap { tone($0.value) }
  }

  /// The rail of a result: green above zero, red below (`Tone.result`), none at zero.
  private func tone(_ value: Decimal) -> Tone? {
    value == 0 ? nil : Tone.result(value)
  }

  private func color(_ value: DecimalString?) -> Color? {
    value.map { Palette.result($0.value) }
  }
}
