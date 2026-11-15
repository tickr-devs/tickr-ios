import SwiftUI
import TickrDesign
import TickrKit

/// Strategy lab: the active strategy with its shown-day results, and the planned tools for
/// comparing strategies (observers, replays, the advisor), shown disabled until they are built.
struct LabView: View {
  /// Entrance order of the cards.
  private enum Order: Int {
    case active = 0, observers, refusals, replay, advisor
  }

  var body: some View {
    ScrollView {
      VStack(spacing: Tokens.Space.l) {
        ActiveStrategyCard().rise(step: Order.active.rawValue)
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          ObserversCard().rise(step: Order.observers.rawValue)
          RefusalsCard().rise(step: Order.refusals.rawValue)
        }
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          ReplayCard().rise(step: Order.replay.rawValue)
          AdvisorCard().rise(step: Order.advisor.rawValue)
        }
      }
      .padding(Tokens.Space.xl)
      .frame(maxWidth: Tokens.Size.contentMaxWidth)
    }
  }
}

/// The strategy the bot trades with, and how it did on the shown day.
private struct ActiveStrategyCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.activeStrategy, tint: Palette.accent) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: model.status?.strategy.name ?? model.settings?.activeStrategy ?? Format.missing)
            .font(Tokens.Typography.title)
            .foregroundStyle(Palette.textPrimary)
          if let version = model.status?.strategy.version {
            Badge(verbatim: version, color: Palette.accentText)
          }
        }
        HStack(spacing: Tokens.Space.xl) {
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            CardLabel(L10n.Lab.shownDayTrades)
            Text(L10n.Lab.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses))
              .font(Tokens.Typography.metric)
              .foregroundStyle(Palette.textPrimary)
          }
          .fixedSize()
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            CardLabel(L10n.Lab.shownDayResult)
            MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.metric)
          }
          .fixedSize()
          // The figures keep their one line; the curve takes the room left, so it neither squeezes
          // them in a narrow window nor leaves a gap before it in a wide one.
          DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Size.sparkline)
        }
        Footnote(L10n.Lab.swapNote)
      }
    }
  }
}

/// Observer strategies: shadow versions that see the same data and never trade, with what they
/// decided on the shown day.
private struct ObserversCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.observers) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if let observers = model.observers?.observers {
          if observers.isEmpty {
            Footnote(L10n.Lab.observersEmpty)
          }
          let lines = lines(observers)
          if realDayMatches, let span = span(observers) {
            DayCurvesChart(lines: lines, start: span.start, end: span.end, live: model.isLive)
            Footnote(L10n.Lab.curvesNote)
            if let active = lines.first(where: \.active) {
              HStack(spacing: Tokens.Space.s) {
                CurveSwatch(color: active.color, curve: active.curve)
                Text(L10n.Lab.activeLine(active.name)).font(Tokens.Typography.calloutMono)
                Spacer()
                MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.calloutMono)
              }
            }
          }
          ForEach(Array(observers.enumerated()), id: \.element.id) { index, observer in
            ObserverRow(observer: observer, live: model.isLive, traded: traded,
              color: DayCurveLine.color(observerIndex: index))
              .transition(.opacity)
          }
        } else if model.observersError != nil {
          Footnote(L10n.Lab.observersUnavailable, color: Palette.warningText)
        }
        Footnote(L10n.Lab.observersNote)
      }
      .animation(Tokens.Motion.standard, value: model.observers)
    }
  }

  /// The active strategy's real trades, then each observer's simulated ones, in the rows' order.
  private func lines(_ observers: [ObserverV1]) -> [DayCurveLine] {
    let name = model.status?.strategy.name ?? model.settings?.activeStrategy ?? Format.missing
    let active = DayCurveLine(name: name, color: Palette.accent,
      curve: DayCurve.trades(model.shownTrades, reported: model.shownResult), active: true)
    return [active] + observers.enumerated().map { index, observer in
      DayCurveLine(name: observer.name + Format.itemSeparator + observer.version,
        color: DayCurveLine.color(observerIndex: index), curve: DayCurve.observer(observer), active: false)
    }
  }

  /// From the day's first recorded event to the latest status (live) or its last event; nil
  /// when nothing was recorded, so no axis is drawn around nothing.
  private func span(_ observers: [ObserverV1]) -> (start: Date, end: Date)? {
    var times = observers.flatMap { observer in
      observer.decisions.map(\.at.date) + (observer.trades ?? []).flatMap { [$0.at.date] + [$0.closedAt?.date].compactMap { $0 } }
    }
    times += model.shownTrades.flatMap { [$0.openedAt.date, $0.closedAt.date] }
    guard let first = times.min(), let last = times.max() else { return nil }
    let end = model.isLive ? max(model.status?.writtenAt.date ?? last, last) : last
    return (first, end)
  }

  /// True when the real trades and result the app shows are of the observers' day, so the
  /// chart never draws one day's observers against another day's real line while days switch.
  private var realDayMatches: Bool {
    guard let day = model.observers?.day else { return false }
    if model.isLive { return day == model.today && model.status != nil && model.todayDocument?.day == day }
    return model.dayDocument?.day == day
  }

  /// Symbols the bot traded or holds on the observers' day, to compare each observer's entries
  /// with; nil while that day's trades are not read, so no row claims the bot traded none.
  private var traded: Set<String>? {
    guard let day = model.observers?.day else { return nil }
    if model.isLive {
      guard let status = model.status, day == model.today else { return nil }
      return Set(status.tradesToday.map(\.symbol) + status.positions.map(\.symbol))
    }
    guard let document = model.dayDocument, document.day == day else { return nil }
    return Set(document.trades.map(\.symbol))
  }
}

/// Why the active strategy's signals were refused on the shown day: one bar per cause, the most
/// frequent first (GET /skipped, counted by `RefusalCount`).
private struct RefusalsCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.refusals) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if let signals = model.skipped?.signals {
          let counts = RefusalCount.make(signals)
          if counts.isEmpty {
            Footnote(L10n.Lab.noRefusals)
          }
          let most = Double(counts.first?.count ?? 1)
          ForEach(counts) { count in
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              HStack(alignment: .firstTextBaseline) {
                title(count.cause)
                  .font(Tokens.Typography.callout)
                  .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(verbatim: String(count.count))
                  .font(Tokens.Typography.calloutMono.bold())
                  .foregroundStyle(Palette.textPrimary)
              }
              ProgressView(value: Double(count.count), total: most)
                .tint(Palette.warning)
                .accessibilityHidden(true)
            }
            .help(help(count.cause))
            .accessibilityElement(children: .combine)
          }
        } else if let error = model.skippedError {
          Footnote(L10n.Trades.notTakenUnavailable(error), color: Palette.warningText)
        } else {
          ProgressView().controlSize(.small)
        }
      }
      .animation(Tokens.Motion.standard, value: model.skipped)
    }
  }

  private func title(_ cause: RefusalCause?) -> Text {
    if let code = cause?.known { return Text(L10n.Cause.title(code)) }
    if let cause { return cause.hasCode ? Text(L10n.Cause.other) : Text(verbatim: cause.code) }
    return Text(L10n.Lab.noCause)
  }

  /// The tooltip: the bot's detail of the first refusal with this cause, else the title.
  private func help(_ cause: RefusalCause?) -> Text {
    guard let cause, cause.hasCode, !cause.detail.isEmpty else { return title(cause) }
    return Text(verbatim: cause.readable(time: Format.marketMinute))
  }
}

/// One observer: name and version, how many decisions it made, the latest one and its result.
struct ObserverRow: View {
  let observer: ObserverV1
  let live: Bool
  /// Symbols the bot traded that day; when given, the row says how many of the observer's entries
  /// the bot also took.
  var traded: Set<String>?
  /// Its line's colour on the Lab chart; when given, a swatch of the line leads the row.
  var color: Color?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(spacing: Tokens.Space.s) {
        if let color {
          CurveSwatch(color: color, curve: DayCurve.observer(observer))
        } else {
          PulseDot(Palette.highlight, size: Tokens.Size.dotSmall, pulsing: live)
        }
        Text(verbatim: observer.name).font(Tokens.Typography.calloutMono)
        Badge(verbatim: observer.version, color: Palette.accentText)
        Spacer()
        if let result = observer.resultGrossUSD {
          MoneyText(value: result.value, usd: true, font: Tokens.Typography.calloutMono)
        } else {
          // The bot says why it has no result (no captured bars, no decisions...).
          Text(verbatim: Format.missing)
            .foregroundStyle(Palette.textQuaternary)
            .help(observer.resultCause.map { Text(verbatim: $0) } ?? Text(L10n.Lab.resultPending))
        }
      }
      HStack(spacing: Tokens.Space.s) {
        Text(L10n.Lab.decisionCount(observer.decisions.count))
        if let last = observer.decisions.last {
          Text(L10n.Lab.lastDecision(String(localized: last.action.title), last.symbol,
            Format.marketMinute(last.at.date)))
        }
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textTertiary)
      if observer.resultGrossUSD == nil,
        let cause = ApiText.prose(observer.resultCauseCodes, text: observer.resultCause) {
        Text(verbatim: cause)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
      if color != nil {
        curveNote
      }
      if let traded {
        agreement(ObserverSummary(observer, traded: traded))
      }
    }
  }

  /// Why the row has no line, or why its line is dashed.
  @ViewBuilder private var curveNote: some View {
    if observer.trades == nil, let cause = ApiText.prose(observer.tradesCauseCodes, text: observer.tradesCause) {
      Text(verbatim: cause)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textQuaternary)
    } else if observer.tradesTruncated {
      Text(L10n.Lab.tradesIncomplete(String(localized: L10n.Lab.tradesTruncated)))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  /// How many of the symbols the observer would have entered the bot also traded, as a bar.
  @ViewBuilder private func agreement(_ summary: ObserverSummary) -> some View {
    if let share = summary.agreement {
      ProgressView(value: share)
        .tint(Palette.highlight)
        .accessibilityHidden(true)
      Text(L10n.Lab.agreement(summary.shared.count, summary.entered.count,
        summary.entered.joined(separator: Format.listSeparator)))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
    } else {
      Text(L10n.Lab.noEntries)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
    }
  }
}

extension Verdict {
  /// The decision as the app names it.
  var title: LocalizedStringResource {
    switch self {
    case .ignore: L10n.Lab.verdictIgnore
    case .watch: L10n.Lab.verdictWatch
    case .enter: L10n.Lab.verdictEnter
    case .hold: L10n.Lab.verdictHold
    case .exit: L10n.Lab.verdictExit
    }
  }
}

/// The Lab's replay: a strategy version SIMULATED over the last sessions of data fetched on the
/// Mac, or over one of its days, optionally compared with a second version over the same days
/// (GET/POST /lab/replay), started here and read while the Lab is open. A refusal (the session is
/// open, a run is going, no data) reads as a calm reason.
private struct ReplayCard: View {
  @Environment(AppModel.self) private var model
  /// The chosen folders and day; nil means the API's default (the active version, no comparison,
  /// the last sessions).
  @State private var version: String?
  @State private var compare: String?
  @State private var day: WireDate?
  @State private var oneDay = false

  /// Symbols of the start button and a refusal.
  static let startSymbol = "play.circle"
  static let refusalSymbol = "info.circle"
  /// Narrowest a figure gets before the figures wrap to another row, in points.
  static let figureMinWidth: CGFloat = 96

  private var replay: LabReplayV1? { model.labReplay }
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
    Card(L10n.Lab.replay) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        Footnote(L10n.Lab.replayNote)
        choices
        HStack(spacing: Tokens.Space.s) {
          Button {
            Task { await model.startLabReplay(version: first, compare: second, day: chosenDay) }
          } label: {
            Label {
              Text(second == nil ? L10n.Lab.replayRun : L10n.Lab.replayRunCompare)
            } icon: {
              Image(systemName: Self.startSymbol)
            }
          }
          .disabled(running || model.labReplayStarting || replay == nil || (first == nil && !listsNone)
            || (oneDay && chosenDay == nil))
          if running || model.labReplayStarting {
            ProgressView().controlSize(.small)
          }
        }
        status
      }
    }
    .task(id: model.baseURL) { await model.followLabReplay() }
  }

  /// Which version, which second version and which days the next run replays.
  @ViewBuilder private var choices: some View {
    if runnable.isEmpty, let cause = replay?.versions.first?.cause {
      // Every version the bot lists is refused: say why rather than leave the start dead.
      Text(verbatim: cause)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
    }
    if !runnable.isEmpty {
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Tokens.Space.s, verticalSpacing: Tokens.Space.s) {
        GridRow {
          Text(L10n.Lab.replayVersion).foregroundStyle(Palette.textSecondary)
          Picker(selection: Binding(get: { first ?? "" }, set: { version = $0 })) {
            ForEach(runnable, id: \.folder) { item in
              Text(name(item)).tag(item.folder)
            }
          } label: {
            Text(L10n.Lab.replayVersion)
          }
          .labelsHidden()
          .fixedSize()
        }
        GridRow {
          Text(L10n.Lab.replayCompare).foregroundStyle(Palette.textSecondary)
          Picker(selection: Binding(get: { second }, set: { compare = $0 })) {
            Text(L10n.Lab.replayCompareNone).tag(String?.none)
            ForEach(runnable.filter { $0.folder != first }, id: \.folder) { item in
              Text(name(item)).tag(String?.some(item.folder))
            }
          } label: {
            Text(L10n.Lab.replayCompare)
          }
          .labelsHidden()
          .fixedSize()
        }
        GridRow {
          Text(L10n.Lab.replayDays).foregroundStyle(Palette.textSecondary)
          HStack(spacing: Tokens.Space.s) {
            Picker(selection: $oneDay) {
              Text(L10n.Lab.replayLastSessions(replay?.sessions ?? .zero)).tag(false)
              Text(L10n.Lab.replayOneDay).tag(true)
            } label: {
              Text(L10n.Lab.replayDays)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            if oneDay, let days = replay?.days, !days.isEmpty {
              Picker(selection: Binding(get: { chosenDay ?? days[0] }, set: { day = $0 })) {
                ForEach(days, id: \.self) { item in
                  Text(verbatim: Format.dayLabel(item)).tag(item)
                }
              } label: {
                Text(L10n.Lab.replayDay)
              }
              .labelsHidden()
              .fixedSize()
            }
          }
        }
      }
      .font(Tokens.Typography.callout)
      .onChange(of: first) { _, now in
        if compare == now { compare = nil }
      }
    }
  }

  /// "price-action-v2 v2 · observer": a version as the pickers and the comparison name it.
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
    if let refusal = model.labReplayRefusal, !running {
      Label {
        Text(verbatim: refusal)
      } icon: {
        Image(systemName: Self.refusalSymbol)
      }
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textSecondary)
    }
    if let replay {
      switch replay.state {
      case .running:
        ProgressView().progressViewStyle(.linear)
        if let started = replay.startedAt {
          Footnote(L10n.Lab.replayRunningSince(Format.marketTime(started.date)))
        }
        if let second = replay.compare {
          Footnote(L10n.Lab.replayThen(String(localized: L10n.Lab.versionName(second.strategy, second.version))))
        }
      case .done:
        if let second = replay.compare, let summary = replay.summary {
          comparison(replay, summary, second)
        } else if let summary = replay.summary {
          result(summary)
        }
        if let cause = replay.cause { Footnote(verbatim: cause) }
        if let day = replay.day { Footnote(L10n.Lab.replayOneDayNote(Format.dayLabel(day))) }
      case .failed:
        Text(verbatim: replay.cause ?? Format.missing)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.warningText)
      case .idle:
        Footnote(L10n.Lab.replayIdle)
      }
    } else if let error = model.labReplayError {
      Text(verbatim: error)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
    }
  }

  private func result(_ summary: LabReplaySummaryV1) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.figureMinWidth), spacing: Tokens.Space.m, alignment: .topLeading)],
        alignment: .leading, spacing: Tokens.Space.m) {
        figure(L10n.Lab.replayTrades, Text(verbatim: String(summary.trades)))
        figure(L10n.Lab.replayWinRate, number(summary.winRatePercent) {
          String(localized: L10n.Trades.percent(Money.plain($0, fractionDigits: StatDigits.percent)))
        })
        figure(intervalTitle(summary), number(summary.meanR, colored: true) {
          Risk.text($0, fractionDigits: StatDigits.r)
        })
        figure(L10n.Lab.replayProfitFactor, number(summary.profitFactor) {
          Money.plain($0, fractionDigits: StatDigits.factor)
        })
        figure(L10n.Lab.replayMaxDrawdown, number(summary.maxDrawdownR) {
          Risk.text(-$0, fractionDigits: StatDigits.r)
        })
        figure(L10n.Lab.replayWithLimits(summary.botTrades), MoneyText(value: summary.botTotalUsd.value, usd: true,
          font: Tokens.Typography.metric))
      }
      Footnote(L10n.Lab.replayData(Format.dayLabel(summary.firstDay), Format.dayLabel(summary.lastDay),
        summary.sessions))
    }
  }

  /// Both versions side by side over the same days, with the second minus the first.
  @ViewBuilder private func comparison(
    _ replay: LabReplayV1, _ summary: LabReplaySummaryV1, _ second: LabReplayLegV1
  ) -> some View {
    let firstName = String(localized: L10n.Lab.versionName(replay.strategy ?? Format.missing,
      replay.version ?? Format.missing))
    let secondName = String(localized: L10n.Lab.versionName(second.strategy, second.version))
    if let other = second.summary {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.s) {
          GridRow {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            Text(verbatim: firstName).foregroundStyle(Palette.textSecondary)
            Text(verbatim: secondName).foregroundStyle(Palette.textSecondary)
            Text(L10n.Lab.replayDifference).foregroundStyle(Palette.textTertiary)
          }
          .font(Tokens.Typography.caption)
          compareRow(L10n.Lab.replayTrades, Decimal(summary.trades), Decimal(other.trades), colored: false,
            format: { Money.plain($0, fractionDigits: .zero) },
            delta: { Money.signed($0, fractionDigits: .zero) })
          compareRow(L10n.Lab.replayWinRate, summary.winRatePercent?.value, other.winRatePercent?.value,
            format: { String(localized: L10n.Trades.percent(Money.plain($0, fractionDigits: StatDigits.percent))) },
            delta: { String(localized: L10n.Lab.replayPoints(Money.signed($0, fractionDigits: StatDigits.percent))) })
          compareRow(L10n.Lab.replayMeanR, summary.meanR?.value, other.meanR?.value,
            format: { Risk.text($0, fractionDigits: StatDigits.r) },
            delta: { Risk.text($0, fractionDigits: StatDigits.r) })
          compareRow(L10n.Lab.replayProfitFactor, summary.profitFactor?.value, other.profitFactor?.value,
            format: { Money.plain($0, fractionDigits: StatDigits.factor) },
            delta: { Money.signed($0, fractionDigits: StatDigits.factor) })
          compareRow(L10n.Lab.replayMaxDrawdown, summary.maxDrawdownR.map { -$0.value },
            other.maxDrawdownR.map { -$0.value },
            format: { Risk.text($0, fractionDigits: StatDigits.r) },
            delta: { Risk.text($0, fractionDigits: StatDigits.r) })
          compareRow(L10n.Lab.replayWithBotLimits, summary.botTotalUsd.value, other.botTotalUsd.value,
            format: { Money.signedUSD($0) }, delta: { Money.signedUSD($0) })
        }
        Footnote(L10n.Lab.replayData(Format.dayLabel(summary.firstDay), Format.dayLabel(summary.lastDay),
          summary.sessions))
      }
    } else {
      result(summary)
      Text(L10n.Lab.replayCompareFailed(secondName, second.cause ?? Format.missing))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
    }
  }

  /// One metric of both versions and their difference; a missing number reads as a dash.
  private func compareRow(
    _ title: LocalizedStringResource, _ first: Decimal?, _ second: Decimal?,
    colored: Bool = true, format: (Decimal) -> String, delta: (Decimal) -> String
  ) -> some View {
    GridRow {
      Text(title)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .gridColumnAlignment(.leading)
      cell(first, format)
      cell(second, format)
      if let first, let second {
        let difference = second - first
        Text(verbatim: delta(difference))
          .foregroundStyle(colored ? Palette.result(difference) : Palette.textSecondary)
      } else {
        Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
      }
    }
    .font(Tokens.Typography.calloutMono)
  }

  private func cell(_ value: Decimal?, _ format: (Decimal) -> String) -> some View {
    Text(verbatim: value.map(format) ?? Format.missing)
      .foregroundStyle(value == nil ? Palette.textQuaternary : Palette.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  /// "mean R · 95%: −0.21 … +0.57", or plain "mean R" without an interval.
  private func intervalTitle(_ summary: LabReplaySummaryV1) -> LocalizedStringResource {
    guard let low = summary.meanRIntervalLow?.value, let high = summary.meanRIntervalHigh?.value else {
      return L10n.Lab.replayMeanR
    }
    return L10n.Lab.replayMeanRInterval(Money.plain(summary.confidencePercent.value, fractionDigits: StatDigits.percent),
      Risk.text(low, fractionDigits: StatDigits.r), Risk.text(high, fractionDigits: StatDigits.r))
  }

  private func number(_ value: DecimalString?, colored: Bool = false, format: (Decimal) -> String) -> some View {
    Group {
      if let value = value?.value {
        Text(verbatim: format(value)).foregroundStyle(colored ? Palette.result(value) : Palette.textPrimary)
      } else {
        Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
      }
    }
    .font(Tokens.Typography.metric)
  }

  private func figure(_ title: LocalizedStringResource, _ value: some View) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      value
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Shrink.standard)
      Text(title)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
    }
  }
}

/// The advisor: proposes new strategy versions from recorded days, for the owner to accept.
private struct AdvisorCard: View {
  var body: some View {
    Card(L10n.Lab.advisor, trailing: { PlannedTag(.backlog) }, content: {
      HStack(alignment: .top, spacing: Tokens.Space.m) {
        Image(systemName: "sparkles")
          .font(Tokens.Typography.symbol)
          .foregroundStyle(Palette.highlight)
        Footnote(L10n.Lab.advisorNote)
      }
    })
  }
}

#if DEBUG
#Preview {
  LabView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif

/// A short sample of a version's line on the Lab chart, as its legend: solid, dashed when the
/// trade list is incomplete, dotted grey when there is no line.
struct CurveSwatch: View {
  let color: Color
  let curve: DayCurve?

  /// Width of the swatch, in points.
  static let width: CGFloat = 14

  var body: some View {
    Canvas { context, size in
      var path = Path()
      path.move(to: CGPoint(x: 0, y: size.height / 2))
      path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
      let dash = curve == nil ? Tokens.Stroke.dashFine : curve?.complete == false ? Tokens.Stroke.dash : []
      context.stroke(path, with: .color(curve == nil ? Palette.textQuaternary : color),
        style: StrokeStyle(lineWidth: DayCurvesChart.observerWidth, dash: dash))
    }
    .frame(width: Self.width, height: Tokens.Size.dotSmall)
    .accessibilityHidden(true)
  }
}
