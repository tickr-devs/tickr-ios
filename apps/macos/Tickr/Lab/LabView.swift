import SwiftUI
import TickrDesign
import TickrKit

/// Strategy lab, as the design's board: the strategy versions, what each would have made on the
/// shown day, the replay that compares versions, the AI advisor, why signals were refused, and
/// one symbol's decision explained. Three equal columns in two rows that share the window; the
/// advisor's page takes the screen while it is open.
struct LabView: View {
  @Environment(AdvisorModel.self) private var advisor

  /// Entrance order of the cards.
  private enum Order: Int {
    case versions = 0, curves, replay, advisor, refusals, explain
  }

  /// Height of the scroll view, so the grid's two rows share the window as the design does.
  @State private var viewport: CGFloat = 0

  var body: some View {
    Group {
      if advisor.pageOpen {
        AdvisorPage()
      } else {
        cards
      }
    }
  }

  private var cards: some View {
    ScrollView {
      // The design's grid: three equal columns in two rows. A window too narrow for three
      // columns gets two.
      ViewThatFits(in: .horizontal) {
        Grid(horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.l) {
          GridRow {
            versions
            curves
            replay
          }
          GridRow {
            advisorCard
            refusals
            explain
          }
        }
        Grid(horizontalSpacing: Tokens.Space.l, verticalSpacing: Tokens.Space.l) {
          GridRow {
            versions
            curves
          }
          GridRow {
            replay
            refusals
          }
          GridRow {
            explain
            advisorCard
          }
        }
      }
      .filling()
      .padding(Tokens.Space.l)
      .frame(minHeight: viewport, alignment: .top)
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
    // Session times for the chart's axis, and the reconcile clock other screens read.
    .task(id: model.baseURL) { await model.followJobs() }
  }

  @Environment(AppModel.self) private var model

  private var versions: some View { VersionsCard().gridColumn().rise(step: Order.versions.rawValue) }
  private var curves: some View { CurvesCard().gridColumn().rise(step: Order.curves.rawValue) }
  private var replay: some View { ReplayCard().gridColumn().rise(step: Order.replay.rawValue) }
  private var advisorCard: some View { AdvisorCard().gridColumn().rise(step: Order.advisor.rawValue) }
  private var refusals: some View { RefusalsCard().gridColumn().rise(step: Order.refusals.rawValue) }
  private var explain: some View { ExplainCard().gridColumn().rise(step: Order.explain.rawValue) }
}

/// A version's role tag, as the design draws it: a dot and an outlined word in the role's colour.
private struct RoleTag: View {
  let title: LocalizedStringResource
  let color: Color

  var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      PulseDot(color, size: Tokens.Size.dotSmall, pulsing: false)
      Badge(title, color: color)
    }
  }
}

/// Every strategy version the bot knows: the active one that trades, the observers that decide
/// live without trading, and candidates the replay can run; each with its role.
private struct VersionsCard: View {
  @Environment(AppModel.self) private var model

  private var activeName: String { model.status?.strategy.name ?? model.settings?.activeStrategy ?? Format.missing }

  /// Candidate versions the bot offers for replay, which neither trade nor observe.
  private var candidates: [LabVersionV1] {
    model.labReplay?.versions.filter { $0.role == .candidate } ?? []
  }

  var body: some View {
    Card(L10n.Lab.versions) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        VStack(spacing: 0) {
          row(name: activeName, version: model.status?.strategy.version, tag: L10n.Lab.tagActive,
            color: Palette.accentText) {
            Text(L10n.Lab.activeRole)
          }
          activePanel
        }
        if let observers = model.observers?.observers {
          ForEach(observers) { observer in
            row(name: observer.name, version: observer.version, tag: L10n.Lab.tagObserver,
              color: Palette.highlightText) {
              Text(L10n.Lab.observerNote(observer.decisions.count))
            }
          }
        } else if let names = model.settings?.observers {
          ForEach(names, id: \.self) { name in
            row(name: name, version: nil, tag: L10n.Lab.tagObserver, color: Palette.highlightText) {
              Text(L10n.Lab.observerNoteUnread)
            }
          }
        }
        ForEach(candidates, id: \.folder) { item in
          row(name: item.strategy ?? item.folder, version: item.version, tag: L10n.Lab.tagCandidate,
            color: Palette.warningText) {
            Text(L10n.Lab.candidateNote)
          }
        }
        Spacer(minLength: 0)
        Text(L10n.Lab.swapNote)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .animation(Tokens.Motion.standard, value: model.observers)
    }
  }

  /// Height of the active version's curve, in points.
  static let sparkHeight: CGFloat = 24

  /// The active version's shown day under its row: trades, gross result and the day's curve.
  private var activePanel: some View {
    HStack(alignment: .bottom, spacing: Tokens.Space.l) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        CardLabel(L10n.Lab.shownDayTrades)
        Text(L10n.Lab.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses))
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(Palette.textPrimary)
      }
      .fixedSize()
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        CardLabel(L10n.Lab.shownDayResult)
        MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.calloutMono.bold())
      }
      .fixedSize()
      DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
        .frame(maxWidth: .infinity)
        .frame(height: Self.sparkHeight)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(Palette.accent.opacity(Tokens.Opacity.wash), in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium)
        .strokeBorder(Palette.accent.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin)
    }
  }

  private func row(
    name: String, version: String?, tag: LocalizedStringResource, color: Color, @ViewBuilder note: () -> some View
  ) -> some View {
    HStack(spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: 0) {
          Text(verbatim: name)
          if let version {
            Text(L10n.Lab.versionSuffix(version))
          }
        }
        .font(Tokens.Typography.calloutMono.bold())
        .foregroundStyle(Palette.textPrimary)
        note()
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
      Spacer(minLength: Tokens.Space.s)
      RoleTag(title: tag, color: color)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium)
        .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
    }
    .accessibilityElement(children: .combine)
  }
}

/// "Today if each version traded": the active strategy's real result through the shown day and
/// each observer's simulated one, as step lines over the session, with a legend row per version.
private struct CurvesCard: View {
  @Environment(AppModel.self) private var model

  /// Widths of the legend's columns, in points: the swatch, the figures and the result.
  static let figuresWidth: CGFloat = 84
  static let resultWidth: CGFloat = 68

  var body: some View {
    Card(model.isLive ? L10n.Lab.curves : L10n.Lab.curvesOnDay, trailing: { trailing }, content: {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if let observers = model.observers?.observers {
          let lines = lines(observers)
          if realDayMatches, let span = span(observers) {
            DayCurvesChart(lines: lines, start: span.start, end: span.end, domain: span.domain, live: model.isLive)
          }
          legend(lines, observers)
          if observers.isEmpty {
            Footnote(L10n.Lab.observersEmpty)
          }
        } else if model.observersError != nil {
          Footnote(L10n.Lab.observersUnavailable, color: Palette.warningText)
        } else {
          ProgressView().controlSize(.small)
        }
        Spacer(minLength: 0)
        Text(L10n.Lab.curvesNote)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .animation(Tokens.Motion.standard, value: model.observers)
    })
  }

  @ViewBuilder private var trailing: some View {
    if model.isLive, model.status?.botState == .running {
      HStack(spacing: Tokens.Space.xs) {
        PulseDot(Palette.profit, size: Tokens.Size.dotSmall, pulsing: false)
        Text(L10n.Lab.curvesRunning)
      }
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.profitText)
    } else if let day = model.observers?.day {
      Text(verbatim: Format.dayLabel(day))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
  }

  /// The design's legend: swatch, name, figures, result; a reason line under a row without one.
  private func legend(_ lines: [DayCurveLine], _ observers: [ObserverV1]) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      if let active = lines.first(where: \.active) {
        legendRow(color: active.color, curve: active.curve, name: Text(L10n.Lab.activeLine(active.name)),
          figures: Text(L10n.Lab.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses)),
          result: model.shownResult)
      }
      ForEach(Array(observers.enumerated()), id: \.element.id) { index, observer in
        legendRow(color: DayCurveLine.color(observerIndex: index), curve: DayCurve.observer(observer),
          name: Text(verbatim: observer.name), figures: figures(observer), result: observer.resultGrossUSD?.value,
          cause: cause(observer))
          .help(help(observer))
          .transition(.opacity)
      }
    }
  }

  private func legendRow(
    color: Color, curve: DayCurve?, name: Text, figures: Text, result: Decimal?, cause: String? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(spacing: Tokens.Space.s) {
        CurveSwatch(color: color, curve: curve)
        name
          .foregroundStyle(Palette.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(Tokens.Shrink.most)
        Spacer(minLength: Tokens.Space.xs)
        figures
          .foregroundStyle(Palette.textQuaternary)
          .lineLimit(1)
          .minimumScaleFactor(Tokens.Shrink.standard)
          .frame(width: Self.figuresWidth, alignment: .leading)
        Group {
          if let result {
            MoneyText(value: result, usd: true, font: Tokens.Typography.calloutMono)
          } else {
            Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
          }
        }
        .frame(width: Self.resultWidth, alignment: .trailing)
      }
      .font(Tokens.Typography.calloutMono)
      if let cause {
        Text(verbatim: cause)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
          .padding(.leading, CurveSwatch.width + Tokens.Space.s)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// "6/6 also traded": how many symbols the observer would have entered the bot also traded;
  /// "no entries" when it would have entered none.
  private func figures(_ observer: ObserverV1) -> Text {
    guard let traded else { return Text(L10n.Lab.decisionCount(observer.decisions.count)) }
    let summary = ObserverSummary(observer, traded: traded)
    guard summary.agreement != nil else { return Text(L10n.Lab.noEntries) }
    return Text(L10n.Lab.alsoTraded(summary.shared.count, summary.entered.count))
  }

  /// Why the row has no result, no line, or a dashed one.
  private func cause(_ observer: ObserverV1) -> String? {
    if observer.resultGrossUSD == nil, let cause = ApiText.prose(observer.resultCauseCodes, text: observer.resultCause) {
      return cause
    }
    if observer.trades == nil, let cause = ApiText.prose(observer.tradesCauseCodes, text: observer.tradesCause) {
      return cause
    }
    if observer.tradesTruncated {
      return String(localized: L10n.Lab.tradesIncomplete(String(localized: L10n.Lab.tradesTruncated)))
    }
    return nil
  }

  /// The tooltip: decisions, the latest one and the symbols both entered.
  private func help(_ observer: ObserverV1) -> Text {
    var lines = [String(localized: L10n.Lab.decisionCount(observer.decisions.count))]
    if let last = observer.decisions.last {
      lines.append(String(localized: L10n.Lab.lastDecision(String(localized: last.action.title), last.symbol,
        Format.marketMinute(last.at.date))))
    }
    if let traded {
      let summary = ObserverSummary(observer, traded: traded)
      if summary.agreement != nil {
        lines.append(String(localized: L10n.Lab.agreement(summary.shared.count, summary.entered.count,
          summary.entered.joined(separator: Format.listSeparator))))
      }
    }
    return Text(verbatim: lines.joined(separator: Format.lineSeparator))
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

  /// The lines run from the session's open (or the day's first event) to now (live) or the
  /// session's close; the axis spans the session when the bot reports its times for that day,
  /// else the recorded events. Nil when nothing was recorded, so no axis is drawn around nothing.
  private func span(_ observers: [ObserverV1]) -> (start: Date, end: Date, domain: ClosedRange<Date>)? {
    var times = observers.flatMap { observer in
      observer.decisions.map(\.at.date) + (observer.trades ?? []).flatMap { [$0.at.date] + [$0.closedAt?.date].compactMap { $0 } }
    }
    times += model.shownTrades.flatMap { [$0.openedAt.date, $0.closedAt.date] }
    guard let first = times.min(), let last = times.max() else { return nil }
    let session = model.jobs?.session.flatMap { $0.day == model.observers?.day ? $0 : nil }
    let start = min(session?.regularOpen.date ?? first, first)
    let close = max(session?.regularClose.date ?? last, last)
    let end = model.isLive ? max(model.status?.writtenAt.date ?? last, last) : close
    return (start, end, start...max(close, end))
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

/// Why the active strategy's signals were refused on the shown day: one compact row per cause,
/// the most frequent first, each cause in its own colour (GET /skipped, counted by
/// `RefusalCount`).
private struct RefusalsCard: View {
  @Environment(AppModel.self) private var model

  /// Width of a cause's label and of its count, in points, as the design's three columns.
  static let labelWidth: CGFloat = 170
  static let countWidth: CGFloat = 30
  /// One colour per cause, in the rows' order.
  static let colors = [Palette.warning, Palette.info, Palette.highlight, Palette.loss, Palette.accent, Palette.profit]

  var body: some View {
    Card(model.isLive ? L10n.Lab.refusalsToday : L10n.Lab.refusals) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        if let signals = model.skipped?.signals {
          let counts = RefusalCount.make(signals)
          if counts.isEmpty {
            Footnote(L10n.Lab.noRefusals)
          }
          let most = Double(counts.first?.count ?? 1)
          ForEach(Array(counts.enumerated()), id: \.element.id) { index, count in
            row(count, share: Double(count.count) / most, color: Self.colors[index % Self.colors.count])
          }
        } else if let error = model.skippedError {
          Footnote(L10n.Trades.notTakenUnavailable(error), color: Palette.warningText)
        } else {
          ProgressView().controlSize(.small)
        }
        Spacer(minLength: 0)
        PlannedLine(text: L10n.Lab.screenerBacklog)
      }
      .animation(Tokens.Motion.standard, value: model.skipped)
    }
  }

  private func row(_ count: RefusalCount, share: Double, color: Color) -> some View {
    HStack(spacing: Tokens.Space.s) {
      title(count.cause)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: Self.labelWidth, alignment: .leading)
      Capsule()
        .fill(Palette.surfaceSunken)
        .overlay(alignment: .leading) {
          GeometryReader { proxy in
            Capsule().fill(color).frame(width: proxy.size.width * share)
          }
        }
        .frame(height: Tokens.Size.bar)
        .accessibilityHidden(true)
      Text(verbatim: String(count.count))
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textPrimary)
        .frame(width: Self.countWidth, alignment: .trailing)
    }
    .help(help(count.cause))
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

/// A BACKLOG tag with what is planned, as the design marks features the bot does not serve yet.
private struct PlannedLine: View {
  let text: LocalizedStringResource

  var body: some View {
    HStack(spacing: Tokens.Space.s) {
      PlannedTag(.backlog)
      Text(text)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .lineLimit(Self.lines)
      Spacer(minLength: 0)
    }
  }

  /// Lines the planned feature may take before it is cut.
  static let lines = 2
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

/// The Lab's replay, as the design's compare card: a strategy version SIMULATED over the last
/// sessions of data fetched on the Mac, or over one of its days, optionally against a second
/// version over the same days (GET/POST /lab/replay), started here and read while the Lab is
/// open. The result is a table with a column per version and their difference. A refusal (the
/// session is open, a run is going, no data) reads as a calm reason.
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
  /// Width of the header's note, which wraps so the title keeps its line, in points.
  static let noteWidth: CGFloat = 96
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
      Text(L10n.Lab.replaySimulated)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: Self.noteWidth, alignment: .trailing)
        .help(Text(L10n.Lab.replayNote))
    }, content: {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        choices
        Button {
          Task { await model.startLabReplay(version: first, compare: second, day: chosenDay) }
        } label: {
          Text(runTitle).frame(maxWidth: .infinity)
        }
        .buttonStyle(.action(.secondary))
        .disabled(running || model.labReplayStarting || replay == nil || (first == nil && !listsNone)
          || (oneDay && chosenDay == nil))
        if running || model.labReplayStarting {
          ProgressView().progressViewStyle(.linear).tint(Palette.info)
        }
        status
        Spacer(minLength: 0)
        Text(L10n.Lab.replayPriority)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    })
    .task(id: model.baseURL) { await model.followLabReplay() }
  }

  /// "Run again" once a replay has a result, else what the next run does.
  private var runTitle: LocalizedStringResource {
    if replay?.state == .done { return L10n.Lab.replayRunAgain }
    return second == nil ? L10n.Lab.replayRun : L10n.Lab.replayRunCompare
  }

  /// Which version, which second version and which days the next run replays, as the design's
  /// chips and two-part switch.
  @ViewBuilder private var choices: some View {
    if runnable.isEmpty, let cause = replay?.versions.first?.cause {
      // Every version the bot lists is refused: say why rather than leave the start dead.
      Text(verbatim: cause)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.warningText)
    }
    if !runnable.isEmpty {
      HStack(spacing: Tokens.Space.s) {
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
          chip(first.flatMap(item).map(name) ?? Format.missing, color: Palette.accent, text: Palette.accentText)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text(L10n.Lab.replayVersion))
        Text(L10n.Lab.replayVersus)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
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
          chip(name(item), color: Palette.highlight, text: Palette.highlightText)
        } else {
          chip(String(localized: L10n.Lab.replayCompareNone), color: Palette.separatorStrong, text: Palette.textTertiary)
        }
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel(Text(L10n.Lab.replayCompare))
      .onChange(of: first) { _, now in
        if compare == now { compare = nil }
      }
      daySwitch
    }
  }

  /// The design's two-part switch: the last sessions, or one day picked from a menu.
  private var daySwitch: some View {
    HStack(spacing: 0) {
      Button {
        oneDay = false
      } label: {
        segment(Text(L10n.Lab.replayLastSessions(replay?.sessions ?? .zero)), on: !oneDay)
      }
      .buttonStyle(.plain)
      Rectangle().fill(Palette.separatorStrong).frame(width: Tokens.Stroke.thin)
      Menu {
        ForEach(replay?.days ?? [], id: \.self) { item in
          Button {
            day = item
            oneDay = true
          } label: {
            Text(verbatim: Format.dayLabel(item))
          }
        }
      } label: {
        segment(oneDayTitle, on: oneDay, menu: true)
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .disabled(replay?.days.isEmpty ?? true)
    }
    .fixedSize()
    .clipShape(.rect(cornerRadius: Tokens.Radius.medium))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.medium)
        .strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(L10n.Lab.replayDays))
  }

  private var oneDayTitle: Text {
    if let chosenDay { return Text(L10n.Lab.replayOneDayOn(Format.dayLabel(chosenDay))) }
    return Text(L10n.Lab.replayOneDay)
  }

  private func segment(_ title: Text, on: Bool, menu: Bool = false) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      title
      if menu {
        Image(systemName: Self.menuSymbol).font(Tokens.Typography.annotation)
      }
    }
    .font(Tokens.Typography.annotationBold)
    .foregroundStyle(on ? Palette.onAccent : Palette.textTertiary)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .background(on ? Palette.info : Color.clear)
    .contentShape(.rect)
  }

  /// A version chip: a dot in the version's colour, its name and a menu mark.
  private func chip(_ title: String, color: Color, text: Color) -> some View {
    HStack(spacing: Tokens.Space.xs) {
      Circle().fill(color).frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
      Text(verbatim: title).lineLimit(1)
      Image(systemName: Self.menuSymbol).font(Tokens.Typography.annotation)
    }
    .font(Tokens.Typography.annotationBold)
    .foregroundStyle(text)
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.xs + Tokens.Space.xxs)
    .background(Palette.surfaceSunken, in: .rect(cornerRadius: Tokens.Radius.small))
    .overlay {
      RoundedRectangle(cornerRadius: Tokens.Radius.small)
        .strokeBorder(color.opacity(Tokens.Opacity.medium), lineWidth: Tokens.Stroke.thin)
    }
    .contentShape(.rect)
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
          table(replay, summary)
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

  /// The design's compare table: a column for the replayed version, one for the second version
  /// and their difference when there is one, a row per figure, then where the data came from.
  @ViewBuilder private func table(_ replay: LabReplayV1, _ summary: LabReplaySummaryV1) -> some View {
    let firstName = String(localized: L10n.Lab.versionName(replay.strategy ?? Format.missing,
      replay.version ?? Format.missing))
    let other = replay.compare?.summary
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      Grid(alignment: .trailing, horizontalSpacing: Tokens.Space.m, verticalSpacing: Tokens.Space.xs) {
        GridRow {
          Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
          Text(verbatim: firstName).foregroundStyle(Palette.accentText)
          if let second = replay.compare, other != nil {
            Text(verbatim: String(localized: L10n.Lab.versionName(second.strategy, second.version)))
              .foregroundStyle(Palette.highlightText)
            Text(L10n.Lab.replayDifference).foregroundStyle(Palette.textQuaternary)
          }
        }
        .font(Tokens.Typography.annotation)
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Shrink.standard)
        compareRow(L10n.Lab.replayTrades, Decimal(summary.trades), other.map { Decimal($0.trades) },
          compared: other != nil, colored: false,
          format: { Money.plain($0, fractionDigits: .zero) },
          delta: { Money.signed($0, fractionDigits: .zero) })
        compareRow(L10n.Lab.replayWinRate, summary.winRatePercent?.value, other?.winRatePercent?.value, compared: other != nil,
          format: { String(localized: L10n.Trades.percent(Money.plain($0, fractionDigits: StatDigits.percent))) },
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
      Text(L10n.Lab.replayData(Format.dayLabel(summary.firstDay), Format.dayLabel(summary.lastDay), summary.sessions))
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
      if let interval = interval(summary) {
        Text(verbatim: interval)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let second = replay.compare, second.summary == nil {
        Text(L10n.Lab.replayCompareFailed(String(localized: L10n.Lab.versionName(second.strategy, second.version)),
          second.cause ?? Format.missing))
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.warningText)
      }
    }
  }

  /// One figure of the version, and of the second version with their difference when compared;
  /// a missing number reads as a dash.
  private func compareRow(
    _ title: LocalizedStringResource, _ first: Decimal?, _ second: Decimal?, compared: Bool = false,
    colored: Bool = true, format: (Decimal) -> String, delta: (Decimal) -> String
  ) -> some View {
    GridRow {
      Text(title)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        .lineLimit(1)
        .minimumScaleFactor(Tokens.Shrink.most)
        .gridColumnAlignment(.leading)
      cell(first, format, colored: colored)
      if compared {
        cell(second, format, colored: colored)
        if let first, let second {
          let difference = second - first
          Text(verbatim: delta(difference))
            .foregroundStyle(colored ? Palette.result(difference) : Palette.textSecondary)
        } else {
          Text(verbatim: Format.missing).foregroundStyle(Palette.textQuaternary)
        }
      }
    }
    .font(Tokens.Typography.calloutMono.bold())
  }

  private func cell(_ value: Decimal?, _ format: (Decimal) -> String, colored: Bool) -> some View {
    Text(verbatim: value.map(format) ?? Format.missing)
      .foregroundStyle(value == nil ? Palette.textQuaternary : Palette.textPrimary)
      .lineLimit(1)
      .minimumScaleFactor(Tokens.Shrink.standard)
  }

  /// "mean R · 95%: −0.21 … +0.57", or nil without an interval.
  private func interval(_ summary: LabReplaySummaryV1) -> String? {
    guard let low = summary.meanRIntervalLow?.value, let high = summary.meanRIntervalHigh?.value else { return nil }
    return String(localized: L10n.Lab.replayMeanRInterval(
      Money.plain(summary.confidencePercent.value, fractionDigits: StatDigits.percent),
      Risk.text(low, fractionDigits: StatDigits.r), Risk.text(high, fractionDigits: StatDigits.r)))
  }
}

/// Explain a symbol: what the active strategy last decided on a symbol on the shown day, check by
/// check, from the decisions the bot recorded (GET /decisions). Opens on the day's latest traded
/// symbol.
private struct ExplainCard: View {
  @Environment(AppModel.self) private var model
  @State private var symbol = ""
  @State private var explain = ExplainModel()

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

  /// The decision to explain: the active strategy's latest, else an observer's.
  private var decision: DecisionV1? {
    guard let list = decisions?.decisions else { return nil }
    return list.last { !$0.observer } ?? list.last
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
          if explain.loading {
            ProgressView().controlSize(.small)
          }
        }
        content
        Spacer(minLength: 0)
        PlannedLine(text: L10n.Lab.explainBacklog)
      }
    }
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
      Footnote(verbatim: error, color: Palette.warningText)
    } else if let decision {
      Text(headline(decision))
        .font(Tokens.Typography.calloutMono)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        ForEach(Array(decision.checks.enumerated()), id: \.offset) { _, check in
          checkRow(check)
        }
        admissionRow(decision.admission)
      }
    } else if decisions != nil {
      Footnote(L10n.Lab.explainNone)
    } else if symbol.isEmpty {
      Footnote(L10n.Lab.explainHint)
    }
  }

  /// "KLMN · 10:43 · IGNORE · cause: round trip / ATR 0.31 > 0.25".
  private func headline(_ decision: DecisionV1) -> LocalizedStringResource {
    let head = [decisions?.symbol ?? symbol, Format.marketMinute(decision.at.date),
      String(localized: decision.action.title).uppercased()].joined(separator: Format.itemSeparator)
    if let reason = RefusalText.text(decision.refusal, cause: decision.refusalCause) {
      return L10n.Lab.explainHeadline(head, reason)
    }
    if let failed = decision.checks.first(where: { !$0.passed }) {
      return L10n.Lab.explainHeadline(head, failed.comparisonText)
    }
    return L10n.Lab.explainHead(head)
  }

  private func checkRow(_ check: CheckV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      mark(check.passed ? Self.passedSymbol : Self.failedSymbol, color: check.passed ? Palette.accent : Palette.loss)
      Text(verbatim: ApiText.rule(check.rule))
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .lineLimit(1)
      Spacer(minLength: Tokens.Space.s)
      Text(verbatim: check.valueText)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .lineLimit(1)
    }
    .help(check.note.isEmpty ? Text(verbatim: ApiText.rule(check.rule)) : Text(verbatim: check.note))
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
    explain.load(symbol: wanted, day: model.shownDay, baseURL: model.baseURL)
  }
}

#if DEBUG
#Preview {
  LabView()
    .environment(PreviewAPI.model())
    .environment(PreviewAPI.advisor())
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
