import SwiftUI
import TickrDesign
import TickrKit

/// Model lab, as the design's board (MacLab, mockup v159): the version that trades and its day,
/// the versions the bot knows, one symbol's decision explained, the replay that compares two
/// versions and the entries the safety rules blocked. Three equal columns of stacked cards (two in
/// a narrow window), as tall as the tallest column (never stretched to the window, which left
/// cards half empty). The board's version chart, next version and profit by confidence need an
/// API the bot does not have yet.
struct LabView: View {
  /// Entrance order of the cards.
  private enum Order: Int {
    case active = 0, versions, explain, replay, refusals
  }

  /// Positions of the cards in the screen's `CardGrid`.
  private enum Slot: Int { case active = 0, versions, replay, refusals, explain }

  /// The grid: the board's three columns, two below the width three need.
  static let arrangements: [CardArrangement] = [
    CardArrangement(minWidth: CardArrangement.columnsMinWidth(CardArrangement.wideColumns), rows: [
      columns([[.active, .versions], [.explain], [.replay, .refusals]]),
    ]),
    CardArrangement(minWidth: 0, rows: [
      columns([[.active, .versions, .explain], [.replay, .refusals]]),
    ]),
  ]

  private static func columns(_ stacks: [[Slot]]) -> CardRow {
    CardRow(columns: stacks.map { CardColumn(width: .share(1), cards: $0.map(\.rawValue)) })
  }

  var body: some View {
    ScrollView {
      CardGrid(arrangements: Self.arrangements, spacing: Tokens.Space.l) {
        active
        versions
        replay
        refusals
        explain
      }
      .filling()
      .padding(Tokens.Space.l)
    }
    .scrollEdgeHints()
    // Session times for the chart's axis, and the reconcile clock other screens read.
    .task(id: model.endpoint) { await model.followJobs() }
  }

  @Environment(AppModel.self) private var model

  private var active: some View { ActiveVersionCard().gridColumn().rise(step: Order.active.rawValue) }
  private var versions: some View { VersionsCard().gridColumn().rise(step: Order.versions.rawValue) }
  private var replay: some View { ReplayCard().gridColumn().rise(step: Order.replay.rawValue) }
  private var refusals: some View { RefusalsCard().gridColumn().rise(step: Order.refusals.rawValue) }
  private var explain: some View { ExplainCard().gridColumn().rise(step: Order.explain.rawValue) }
}

/// Every model version the bot knows, as the board's rows: the active one that trades and the
/// candidates the replay can run, each with its role's `Badge`. The "i" says how versions swap.
private struct VersionsCard: View {
  @Environment(AppModel.self) private var model

  private var activeName: String { model.status?.strategy.name ?? model.settings?.activeStrategy ?? Format.missing }

  /// Candidate versions the bot offers for replay, which do not trade.
  private var candidates: [LabVersionV1] {
    model.labReplay?.versions.filter { $0.role == .candidate } ?? []
  }

  var body: some View {
    Card(L10n.Lab.versions, trailing: {
      LabInfoButton(label: L10n.Lab.versionsAbout, texts: [L10n.Lab.swapNote])
    }, content: {
      VStack(alignment: .leading, spacing: 0) {
        row(name: activeName, version: model.status?.strategy.version, tag: Badge(L10n.Lab.tagActive, tone: .accent))
        // The candidates: the first few (more in a tall window), then "Show all N ›" on the
        // card's bottom edge; the active version above is always shown.
        CappedList(candidates, id: \.folder, title: L10n.Lab.versions, limit: Tokens.Lists.comparedRows,
          spacing: 0) { _, candidate in
          row(name: candidate.strategy ?? candidate.folder, version: candidate.version,
            tag: Badge(L10n.Lab.tagCandidate, tone: .warning))
        }
      }
      .animation(Tokens.Motion.standard, value: candidates)
    })
  }

  /// One version's row under a hairline, its role's `Badge` at the end.
  private func row(name: String, version: String?, tag: Badge) -> some View {
    HStack(spacing: Tokens.Space.s) {
      HStack(spacing: 0) {
        Text(verbatim: name)
        if let version {
          Text(L10n.Lab.versionSuffix(version))
        }
      }
      .font(Tokens.Typography.calloutMono.bold())
      .foregroundStyle(Palette.textPrimary)
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      tag
    }
    .padding(.vertical, Tokens.Space.s)
    .overlay(alignment: .top) { Divider() }
    .accessibilityElement(children: .combine)
  }
}

/// "Blocked by safety rules": how many entries the active version wanted on the shown day that the
/// platform's limits refused, big, then one compact row per cause, the most frequent first, each
/// cause in its own colour (GET /skipped, counted by `RefusalCount`). The "i" says what it counts.
private struct RefusalsCard: View {
  @Environment(AppModel.self) private var model

  /// Width of a cause's label and of its count, in points, as the design's three columns.
  static let labelWidth: CGFloat = 170
  static let countWidth: CGFloat = 30
  /// One colour per cause, in the rows' order.
  static let colors = [Palette.warning, Palette.info, Palette.highlight, Palette.loss, Palette.accent, Palette.profit]

  var body: some View {
    Card(L10n.Lab.refusals, trailing: {
      LabInfoButton(label: L10n.Lab.refusalsAbout, texts: [L10n.Lab.refusalsInfo])
    }, content: {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        if let signals = model.skipped?.signals {
          let counts = RefusalCount.make(signals)
          total(counts.reduce(0) { $0 + $1.count })
          if counts.isEmpty {
            Footnote(L10n.Lab.noRefusals)
          }
          let most = Double(counts.first?.count ?? 1)
          // The most frequent causes (more in a tall window), then "Show all N ›".
          CappedList(counts, id: \.id, title: L10n.Lab.refusals) { index, count in
            row(count, share: Double(count.count) / most, color: Self.colors[index % Self.colors.count], step: index)
          }
        } else if let error = model.skippedError {
          ReadFailureNote(L10n.Trades.notTakenUnavailable, detail: error)
        } else {
          Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.rows) }
        }
      }
      .animation(Tokens.Motion.standard, value: model.skipped)
    })
  }

  /// The day's total, big, with its day ("today", or the recorded day).
  private func total(_ count: Int) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(verbatim: String(count))
        .font(Tokens.Typography.metric)
        .foregroundStyle(Palette.textPrimary)
        .contentTransition(.numericText())
      Group {
        if model.isLive {
          Text(L10n.Lab.refusalsToday)
        } else {
          Text(verbatim: DayText.day(model.shownDay))
        }
      }
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textTertiary)
    }
    .accessibilityElement(children: .combine)
  }

  private func row(_ count: RefusalCount, share: Double, color: Color, step: Int) -> some View {
    HStack(spacing: Tokens.Space.s) {
      title(count.cause)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .frame(width: Self.labelWidth, alignment: .leading)
      Capsule()
        .fill(Palette.surfaceSunken)
        .overlay(alignment: .leading) {
          GeometryReader { proxy in
            // The bars grow in one after another, then move only when a count changes.
            Capsule().fill(color).frame(width: proxy.size.width * share).grows(with: share, step: step)
          }
        }
        .frame(height: Tokens.Size.bar)
        .accessibilityHidden(true)
      Text(verbatim: String(count.count))
        // One bump each time the bot skips another signal for this cause.
        .bumps(on: count.count)
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textPrimary)
        .frame(width: Self.countWidth, alignment: .trailing)
    }
    .tip(help(count.cause))
    .accessibilityElement(children: .combine)
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

/// "Compare two versions", the Lab's replay: a strategy version SIMULATED over the last sessions
/// of data fetched on the Mac, or over one of its days, optionally against a second version over
/// the same days (GET/POST /lab/replay), started here and read while the Lab is open; the "i" says
/// how it runs. The result is each version's net with the bot's limits, win rate and trades, a
/// line saying which earned more, and "All figures ›" with every figure and the difference of the
/// two versions in a popover. While the regular
/// session refuses a start (`LabReplayV1.availableAt`), the button rests with the time it opens
/// and a countdown; any other refusal (a run going, no data) reads as a calm reason in words.
private struct ReplayCard: View {
  @Environment(AppModel.self) private var model
  /// The chosen folders and day; nil means the API's default (the active version, no comparison,
  /// the last sessions).
  @State private var version: String?
  @State private var compare: String?
  @State private var day: WireDate?
  @State private var oneDay = false

  /// Symbol of a refusal.
  static let refusalSymbol = "info.circle"
  /// Symbol of the wait for the session to close.
  static let waitSymbol = "clock"
  /// Symbol of a chip's menu.
  static let menuSymbol = "chevron.down"

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
    Card(L10n.Lab.replay, trailing: {
      LabInfoButton(label: L10n.Lab.compareAbout, texts: [L10n.Lab.replayNote, L10n.Lab.replayPriority])
    }, content: {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        choices
        status
        // As the board: the button under the result.
        Button {
          Task { await model.startLabReplay(version: first, compare: second, day: chosenDay) }
        } label: {
          Text(runTitle).frame(maxWidth: .infinity)
        }
        .buttonStyle(.action(.secondary))
        .disabled(running || model.labReplayStarting || replay == nil || (first == nil && !listsNone)
          || (oneDay && chosenDay == nil) || waitsUntil != nil)
        .inFlight(model.labReplayStarting ? Text(InFlightText.replayStarting)
          : running ? Text(InFlightText.replayRunning) : nil)
        if let waitsUntil, !running {
          availability(waitsUntil)
        }
      }
    })
    .task(id: model.endpoint) { await model.followLabReplay() }
  }

  /// When a start is allowed again while the regular session refuses one, from the bot's own
  /// document (never found out by a refused start).
  private var waitsUntil: Date? { replay?.waitsUntil(now: model.botNow) }

  /// Why the button rests: "Available after 16:00 ET · in 1:12:03", counting down; the parts
  /// wrap whole in a narrow card.
  private func availability(_ until: Date) -> some View {
    Label {
      ChipFlow {
        Text(L10n.Lab.replayAvailableAfter(Format.marketMinute(until)))
        HStack(spacing: Tokens.Space.xs) {
          Text(verbatim: Format.itemSeparator)
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

  /// "Run again" once a replay has a result, else what the next run does.
  private var runTitle: LocalizedStringResource {
    if replay?.state == .done { return L10n.Lab.replayRunAgain }
    return second == nil ? L10n.Lab.replayRun : L10n.Lab.replayRunCompare
  }

  /// Which version, which second version and which days the next run replays, as the design's
  /// chips and two-part switch.
  @ViewBuilder private var choices: some View {
    if runnable.isEmpty, let cause = replay?.versions.first?.causeText {
      // Every version the bot lists is refused: say why rather than leave the start dead.
      Text(verbatim: cause)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
    }
    if !runnable.isEmpty {
      // As the design's board: the two pickers side by side with "vs" between, on a new row only
      // when the card is too narrow for both.
      ChipFlow(spacing: Tokens.Space.s) {
        Menu {
          Picker(selection: Binding(get: { first ?? "" }, set: { version = $0 })) {
            ForEach(runnable, id: \.folder) { item in
              Text(name(item)).tag(item.folder)
            }
          } label: {
            Text(L10n.Lab.replayVersion)
          }
          .pickerStyle(.inline)
        } label: {
          chip(first.flatMap(item).map(name) ?? Format.missing, tone: .accent)
        }
        .buttonMenuStyle()
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(L10n.Lab.replayVersion))
        Text(L10n.Lab.replayVersus)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
        Menu {
          Picker(selection: Binding(get: { second }, set: { compare = $0 })) {
            Text(L10n.Lab.replayCompareNone).tag(String?.none)
            ForEach(runnable.filter { $0.folder != first }, id: \.folder) { item in
              Text(name(item)).tag(String?.some(item.folder))
            }
          } label: {
            Text(L10n.Lab.replayCompare)
          }
          .pickerStyle(.inline)
        } label: {
          if let second, let item = item(second) {
            chip(name(item), tone: .highlight)
          } else {
            chip(String(localized: L10n.Lab.replayCompareNone), tone: nil)
          }
        }
        .buttonMenuStyle()
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(L10n.Lab.replayCompare))
      }
      .onChange(of: first) { _, now in
        if compare == now { compare = nil }
      }
      SegmentSwitch(options: [(false, Text(L10n.Lab.replayLastSessions(replay?.sessions ?? .zero))),
        (true, Text(L10n.Lab.replayOneDay))], selection: $oneDay)
        .accessibilityLabel(Text(L10n.Lab.replayDays))
      if oneDay, let days = replay?.days, !days.isEmpty {
        Menu {
          ForEach(days, id: \.self) { item in
            Button {
              day = item
            } label: {
              Text(verbatim: DayText.day(item))
            }
          }
        } label: {
          chip(DayText.day(chosenDay ?? days[0]), tone: .accent)
        }
        .buttonMenuStyle()
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(L10n.Lab.replayDay))
      } else if oneDay {
        // Never a bare switch with the start greyed out: say why there is no day to pick.
        Text(L10n.Lab.replayNoDays)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// A picker's current choice as the apps' chip (`chipFace`) with a menu mark: chosen in the
  /// version's tone, plain while nothing is chosen ("No comparison").
  private func chip(_ title: String, tone: Tone?) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      Text(verbatim: title)
      Image(systemName: Self.menuSymbol)
    }
    .chipFace(selected: tone != nil, tone: tone ?? .info)
  }

  private func item(_ folder: String) -> LabVersionV1? {
    runnable.first { $0.folder == folder }
  }

  /// "price-action-v2 v2 · observer": a version as the chips and the comparison name it.
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
        if let started = replay.startedAt {
          Footnote(L10n.Lab.replayRunningSince(Format.marketTime(started.date)))
        }
        if let second = replay.compare {
          Footnote(L10n.Lab.replayThen(String(localized: L10n.Lab.versionName(second.strategy, second.version))))
        }
      case .done:
        if let summary = replay.summary {
          glance(replay, summary)
          FooterDetail(L10n.Lab.replayAllFigures, endsCard: false) { table(replay, summary) }
        }
        if let cause = replay.causeText { Footnote(verbatim: cause) }
        if let day = replay.day { Footnote(L10n.Lab.replayOneDayNote(DayText.day(day))) }
      case .failed:
        Text(verbatim: replay.causeText ?? Format.missing)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.warningText)
      case .idle:
        // The apps' empty state, centred in the card: no run yet is a calm state, not a gap.
        EmptyState(L10n.Lab.replayIdle)
      }
    } else if let error = model.labReplayError {
      ReadFailureNote(L10n.ReadFailed.replay, detail: error)
    }
  }

  /// The board's compare table: each version's net with the bot's limits, win rate and trades in a
  /// column per version, then which one earned more.
  @ViewBuilder private func glance(_ replay: LabReplayV1, _ summary: LabReplaySummaryV1) -> some View {
    let other = replay.compare?.summary
    Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.xs) {
      header(replay, compared: other != nil, difference: false)
      compareRow(L10n.Lab.replayWithBotLimits, summary.botTotalUsd.value, other?.botTotalUsd.value,
        compared: other != nil, difference: false, format: { Money.signedUSD($0) }, delta: { Money.signedUSD($0) })
      compareRow(L10n.Lab.replayWinRate, summary.winRatePercent?.value, other?.winRatePercent?.value,
        compared: other != nil, colored: false, difference: false, format: { Percent.plain(points: $0) },
        delta: { Percent.plain(points: $0) })
      compareRow(L10n.Lab.replayTrades, Decimal(summary.trades), other.map { Decimal($0.trades) },
        compared: other != nil, colored: false, difference: false,
        format: { Money.plain($0, fractionDigits: .zero) }, delta: { Money.signed($0, fractionDigits: .zero) })
    }
    if let second = replay.compare, let verdict = LabFigures.verdict(replay) {
      Text(verdictText(String(localized: L10n.Lab.versionName(second.strategy, second.version)), verdict))
        .font(Tokens.Typography.callout.weight(.semibold))
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    if let second = replay.compare, second.summary == nil {
      Text(L10n.Lab.replayCompareFailed(String(localized: L10n.Lab.versionName(second.strategy, second.version)),
        second.causeText ?? Format.missing))
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
    }
  }

  /// "v2 earned +$69.00 more · not proven yet", "v2 earned $3.10 less", or that both earned the same.
  private func verdictText(_ name: String, _ verdict: LabFigures.Verdict) -> LocalizedStringResource {
    switch verdict {
    case .more(let difference): L10n.Lab.verdictMore(name, Money.signedUSD(difference))
    case .less(let difference): L10n.Lab.verdictLess(name, Money.usd(difference))
    case .same: L10n.Lab.verdictSame
    }
  }

  /// The tables' first row: the versions' names in their chips' colours, and "difference".
  private func header(_ replay: LabReplayV1, compared: Bool, difference: Bool) -> some View {
    GridRow {
      Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
      // A version's name wider than its column wraps onto a second line, never cut.
      Text(verbatim: String(localized: L10n.Lab.versionName(replay.strategy ?? Format.missing,
        replay.version ?? Format.missing))).foregroundStyle(Palette.accentText)
        .fixedSize(horizontal: false, vertical: true)
      if let second = replay.compare, compared {
        Text(verbatim: String(localized: L10n.Lab.versionName(second.strategy, second.version)))
          .foregroundStyle(Palette.highlightText)
          .fixedSize(horizontal: false, vertical: true)
        if difference {
          Text(L10n.Lab.replayDifference).foregroundStyle(Palette.textQuaternary)
        }
      }
    }
    .font(Tokens.Typography.annotation)
  }

  /// The design's compare table: a column for the replayed version, one for the second version
  /// and their difference when there is one, a row per figure, then where the data came from.
  @ViewBuilder private func table(_ replay: LabReplayV1, _ summary: LabReplaySummaryV1) -> some View {
    let other = replay.compare?.summary
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.xs) {
        header(replay, compared: other != nil, difference: true)
        compareRow(L10n.Lab.replayTrades, Decimal(summary.trades), other.map { Decimal($0.trades) },
          compared: other != nil, colored: false,
          format: { Money.plain($0, fractionDigits: .zero) },
          delta: { Money.signed($0, fractionDigits: .zero) })
        compareRow(L10n.Lab.replayWinRate, summary.winRatePercent?.value, other?.winRatePercent?.value, compared: other != nil,
          format: { Percent.plain(points: $0) },
          delta: { String(localized: L10n.Lab.replayPoints(Money.signed($0, fractionDigits: StatDigits.percent))) })
        compareRow(L10n.Lab.replayMeanR, summary.meanR?.value, other?.meanR?.value, compared: other != nil,
          format: { Risk.text($0, fractionDigits: StatDigits.r) },
          delta: { Risk.text($0, fractionDigits: StatDigits.r) })
        compareRow(L10n.Lab.replayProfitFactor, summary.profitFactor?.value, other?.profitFactor?.value, compared: other != nil,
          format: { Money.plain($0, fractionDigits: StatDigits.factor) },
          delta: { Money.signed($0, fractionDigits: StatDigits.factor) })
        compareRow(L10n.Lab.replayMaxDrawdown, summary.maxDrawdownR.map { -$0.value },
          other?.maxDrawdownR.map { -$0.value }, compared: other != nil,
          format: { Risk.text($0, fractionDigits: StatDigits.r) },
          delta: { Risk.text($0, fractionDigits: StatDigits.r) })
        compareRow(L10n.Lab.replayWithBotLimits, summary.botTotalUsd.value, other?.botTotalUsd.value, compared: other != nil,
          format: { Money.signedUSD($0) }, delta: { Money.signedUSD($0) })
      }
      Text(L10n.Lab.replayData(DayText.day(summary.firstDay), DayText.day(summary.lastDay), summary.sessions))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
      if let interval = interval(summary) {
        Text(verbatim: interval)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  /// One figure of the version, and of the second version with their difference when compared;
  /// a missing number reads as a dash.
  private func compareRow(
    _ title: LocalizedStringResource, _ first: Decimal?, _ second: Decimal?, compared: Bool = false,
    colored: Bool = true, difference: Bool = true, format: (Decimal) -> String, delta: (Decimal) -> String
  ) -> some View {
    GridRow {
      // A name longer than its column ("% de acierto" in a narrow column) wraps onto a second line, never cut.
      Text(title)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
        .gridColumnAlignment(.leading)
      cell(first, format, colored: colored)
      if compared {
        cell(second, format, colored: colored)
        if difference, let first, let second {
          let change = second - first
          Text(verbatim: delta(change))
            .foregroundStyle(colored ? Palette.result(change) : Palette.textSecondary)
        } else if difference {
          Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        }
      }
    }
    .font(Tokens.Typography.calloutMono.bold())
  }

  private func cell(_ value: Decimal?, _ format: (Decimal) -> String, colored: Bool) -> some View {
    Text(verbatim: value.map(format) ?? Format.missing)
      .foregroundStyle(value == nil ? Palette.textQuaternary : Palette.textPrimary)
  }

  /// "mean R · 95%: −0.21 … +0.57", or nil without an interval.
  private func interval(_ summary: LabReplaySummaryV1) -> String? {
    guard let low = summary.meanRIntervalLow?.value, let high = summary.meanRIntervalHigh?.value else { return nil }
    return String(localized: L10n.Lab.replayMeanRInterval(
      Money.plain(summary.confidencePercent.value, fractionDigits: StatDigits.percent),
      Risk.text(low, fractionDigits: StatDigits.r), Risk.text(high, fractionDigits: StatDigits.r)))
  }
}

/// "Why did the bot decide that?": what the active strategy last decided on a symbol on the
/// shown day, the decision big, then check by check, from the decisions the bot recorded
/// (GET /decisions). Opens on the day's latest traded symbol.
private struct ExplainCard: View {
  @Environment(AppModel.self) private var model
  @State private var symbol = ""
  @State private var explain = ExplainModel()

  /// Checks shown before the card's height is measured (the first layout pass).
  static let fallbackLines = 4
  /// Width of the symbol field, in points.
  static let fieldWidth: CGFloat = 110
  /// Size of a check's mark, in points.
  static let markSize: CGFloat = 14
  /// Symbols of a passed, a failed and a not-reached check.
  static let passedSymbol = "checkmark"
  static let failedSymbol = "xmark"
  static let unreachedSymbol = "minus"

  /// The answer for the typed symbol on the shown day; nil for any other.
  private var decisions: DecisionsV1? { current ? explain.decisions : nil }

  /// Why the read for the typed symbol on the shown day failed; nil for any other.
  private var error: String? { current ? explain.error : nil }

  /// True when the model's last read is for the typed symbol on the shown day.
  private var current: Bool { explain.request == ExplainModel.Request(symbol: wanted, day: model.shownDay) }

  /// The typed symbol as the bot names it.
  private var wanted: String { symbol.trimmingCharacters(in: .whitespaces).uppercased() }

  /// The decision to explain: the active strategy's latest (a shadow strategy's are left out).
  private var decision: DecisionV1? {
    decisions?.decisions.last { !$0.observer }
  }

  var body: some View {
    Card(L10n.Lab.explain) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        HStack(spacing: Tokens.Space.s) {
          TextField(text: $symbol, prompt: Text(L10n.Lab.explainPrompt)) {
            Text(L10n.Lab.explainSymbol)
          }
          .textFieldStyle(.roundedBorder)
          .font(Tokens.Typography.calloutMono.bold())
          .frame(width: Self.fieldWidth)
          .onSubmit { load() }
          Button {
            load()
          } label: {
            Text(L10n.Lab.explainRun)
          }
          .buttonStyle(.action(.secondary, size: .compact))
          .disabled(wanted.isEmpty || explain.loading)
          .inFlight(explain.loading ? Text(L10n.Lab.explainReading) : nil)
        }
        content
      }
    }
    // The checks take the skeleton's place without rising (design-system "Loading").
    .loadsInPlace(!explain.loading)
    // A new day reads the typed symbol again; the read for the old day is cancelled.
    .task(id: model.shownDay) {
      if symbol.isEmpty, let latest = model.shownTrades.last?.symbol {
        symbol = latest
      }
      if wanted.isEmpty { explain.cancel() } else { load() }
    }
    // Typing another symbol stops the read for the old one; Explain starts the new read.
    .onChange(of: wanted) { _, now in
      if explain.request?.symbol != now { explain.cancel() }
    }
  }

  @ViewBuilder private var content: some View {
    if let error {
      ReadFailureNote(L10n.ReadFailed.explain, detail: error)
    } else if let decision {
      headline(decision)
      // As many checks as fill the card's cell (a long list never stretches the row's other
      // cards), then the footer on its bottom edge. The checks rise one after another as a
      // decision is shown; another decision rises afresh.
      let lines = Self.lines(decision)
      FittingRows(lines, id: \.self, spacing: Tokens.Space.xs, fallback: Self.fallbackLines) { index, line in
        lineRow(line, of: decision).rise(step: index)
      } footer: { shown in
        footer(decision, total: lines.count, shown: shown)
      }
      .id(decision)
    } else {
      if explain.loading {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.manyLines, leadingValue: true) }
      } else if decisions != nil {
        Footnote(L10n.Lab.explainNone)
      } else if symbol.isEmpty {
        Footnote(L10n.Lab.explainHint)
      }
    }
  }

  /// The decision's lines, why it was decided first (`DecisionV1.explainLines`).
  private static func lines(_ decision: DecisionV1) -> [Int] { decision.explainLines }

  @ViewBuilder
  private func lineRow(_ line: Int, of decision: DecisionV1) -> some View {
    if decision.checks.indices.contains(line) {
      checkRow(decision.checks[line])
    } else {
      admissionRow(decision.admission)
    }
  }

  /// Which version decided, then "All checks N ›" when the card shows only some of the checks;
  /// the link opens every check in a popover.
  @ViewBuilder
  private func footer(_ decision: DecisionV1, total: Int, shown: Int) -> some View {
    Footnote(L10n.Lab.decidedBy(String(localized: L10n.Lab.versionName(decision.strategy.name,
      decision.strategy.version))))
    if shown < total {
      FooterDetail(L10n.Lab.explainShowAll, count: total) {
        ForEach(Self.lines(decision), id: \.self) { line in lineRow(line, of: decision) }
      }
    }
  }

  /// As the board: "KLMN · 10:43" with the decision big at the end ("IGNORE"), then its cause
  /// ("Cause: round trip / ATR 0.31 > 0.25") when it has one.
  @ViewBuilder private func headline(_ decision: DecisionV1) -> some View {
    let head = [decisions?.symbol ?? symbol, Format.marketMinute(decision.at.date)].joined(separator: Format.itemSeparator)
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(L10n.Lab.explainHead(head))
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Tokens.Space.s)
      Text(decision.action.title)
        .textCase(.uppercase)
        .font(Tokens.Typography.metric)
        .foregroundStyle(Palette.textPrimary)
        .fixedSize()
    }
    .accessibilityElement(children: .combine)
    if let cause = Self.cause(decision) {
      Text(L10n.Lab.explainCause(cause))
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// Why it was decided: the platform's refusal, else the first failed check; nil when neither.
  private static func cause(_ decision: DecisionV1) -> String? {
    if let reason = RefusalText.text(decision.refusal, cause: decision.refusalCause) { return reason }
    return decision.checks.first { !$0.passed }?.comparisonText
  }

  private func checkRow(_ check: CheckV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      mark(check.passed ? Self.passedSymbol : Self.failedSymbol, color: check.passed ? Palette.accent : Palette.loss)
      Text(verbatim: ApiText.rule(check.rule))
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: check.valueText)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .tip(check.note.isEmpty ? Text(verbatim: ApiText.rule(check.rule)) : Text(verbatim: check.note))
    .accessibilityElement(children: .combine)
    .accessibilityValue(Text(check.passed ? L10n.Chart.checkPassed : L10n.Chart.checkFailed))
  }

  private func admissionRow(_ admission: Admission) -> some View {
    let state: (symbol: String, color: Color, text: LocalizedStringResource) = switch admission {
    case .taken: (Self.passedSymbol, Palette.accent, L10n.Lab.admissionTaken)
    case .refused: (Self.failedSymbol, Palette.loss, L10n.Lab.admissionRefused)
    case .notEvaluated: (Self.unreachedSymbol, Palette.separatorStrong, L10n.Lab.admissionNotEvaluated)
    case .notApplicable: (Self.unreachedSymbol, Palette.separatorStrong, L10n.Lab.admissionNotReached)
    }
    return HStack(spacing: Tokens.Space.s) {
      mark(state.symbol, color: state.color)
      Text(L10n.Lab.admission)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
      Spacer(minLength: Tokens.Space.s)
      Text(state.text)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .accessibilityElement(children: .combine)
  }

  private func mark(_ symbol: String, color: Color) -> some View {
    Image(systemName: symbol)
      .font(Tokens.Typography.badge)
      .foregroundStyle(Palette.onAccent)
      .frame(width: Self.markSize, height: Self.markSize)
      .background(Circle().fill(color))
      .accessibilityHidden(true)
  }

  /// Reads the decisions on the typed symbol on the shown day.
  private func load() {
    guard !wanted.isEmpty else { return }
    symbol = wanted
    explain.load(symbol: wanted, day: model.shownDay, endpoint: model.endpoint)
  }
}

#if DEBUG
#Preview {
  LabView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
