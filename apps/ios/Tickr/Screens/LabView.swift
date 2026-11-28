import SwiftUI
import TickrDesign
import TickrKit

/// Model lab (IOS2Lab board, mockup v155): the version that trades and its day, the replay that
/// compares two versions, and the day's entries the safety rules blocked. The board's version
/// chart, next version and profit by confidence need an API the bot does not have yet.
struct LabView: View {
  /// Symbol in front of a warning that the data is a failed or last read.
  static let warningSymbol = "exclamationmark.triangle.fill"

  /// Order in which the blocks rise in (`rise(step:)`).
  private enum Order: Int { case active = 1, replay, refusals }

  @Environment(AppModel.self) private var model
  @State private var lab = Container.shared.labModel()

  var body: some View {
    Screen(L10n.Lab.title, tab: .lab) {
      if !model.isLive, lab.pastDay?.day != model.shownDay {
        // A recorded day whose record is not read yet, or could not be.
        if let failure = lab.pastDayFailure {
          ReadFailureNote(L10n.Lab.dayFailed, detail: failure)
        } else {
          Skeleton(L10n.Common.loading) {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
              SkeletonTiles(Tokens.Loading.tiles)
              SkeletonLines(Tokens.Loading.fewLines)
            }
          }
          .padding(Tokens.Space.l)
          .tickrCard()
        }
      } else if let status = model.status {
        ActiveCard(active: ActiveDay(status: status, past: model.isLive ? nil : lab.pastDay))
          .rise(step: Order.active.rawValue)
        LabReplayCard(lab: lab, url: model.connection.url)
          .rise(step: Order.replay.rawValue)
        RefusalsCard(counts: lab.refusals, failure: lab.refusalsFailure,
          day: model.isLive ? nil : model.shownDay)
          .rise(step: Order.refusals.rawValue)
      }
    }
    // A recorded day's cards take its skeleton's place without rising (design-system "Loading").
    .loadsInPlace(model.isLive || lab.pastDay?.day == model.shownDay || lab.pastDayFailure != nil)
    .task(id: sessionKey) { await load() }
    .refreshable {
      await model.refresh()
      await load()
    }
  }

  /// The address and the day the Lab shows (the status's session, or the app's recorded day); a
  /// change reads the day again.
  private var sessionKey: [String] {
    [model.connection.url?.absoluteString, labDay?.text].compactMap { $0 }
  }

  /// The day the Lab shows: the app's recorded day, else the status's session.
  private var labDay: WireDate? {
    model.isLive ? model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date) } : model.shownDay
  }

  /// Size of the active strategy's day curve, in points, as on the design.
  static let curveWidth: CGFloat = 70
  static let curveHeight: CGFloat = 20

  /// "Today · 3 closed, 2 won, 1 lost · 1 open", or a recorded day's "Nov 14 · 3 closed, 2 won, 1 lost".
  static func daySummary(_ active: ActiveDay) -> LocalizedStringResource {
    let results = active.closes.map(\.result)
    if let day = active.recordedDay {
      return L10n.Lab.pastDaySummary(DayText.day(day.noonInNewYork), results.count, results.filter { $0 > 0 }.count,
        results.filter { $0 < 0 }.count)
    }
    return L10n.Lab.daySummary(results.count, results.filter { $0 > 0 }.count, results.filter { $0 < 0 }.count,
      active.open)
  }

  /// The day's realized result after each closed trade, from zero.
  static func curve(_ active: ActiveDay) -> [Double] {
    let sorted = active.closes.sorted { $0.at < $1.at }
    var total = Decimal.zero
    return [0] + sorted.map { close in
      total += close.result
      return NSDecimalNumber(decimal: total).doubleValue
    }
  }

  private func load() async {
    guard let url = model.connection.url, let day = labDay else { return }
    await lab.load(url, day: day, past: !model.isLive)
  }
}

/// The trading strategy's day as the Lab shows it: today's from the status, or a recorded day's
/// from its record (GET /days/<date>), never a mix of the two.
struct ActiveDay {
  let name: String
  let version: String
  /// Each closed trade: when it closed and its result.
  let closes: [(at: Date, result: Decimal)]
  /// The day's result as the bot reports it.
  let total: Decimal
  /// Positions still open (none on a recorded day).
  let open: Int
  /// The recorded day shown; nil for the status's session.
  let recordedDay: WireDate?

  init(status: StatusV1, past: DayV1?) {
    if let past {
      let strategy = past.trades.compactMap(\.strategy).first ?? status.strategy
      name = strategy.name
      version = strategy.version
      closes = past.trades.map { (at: $0.closedAt.date, result: $0.resultUsd.value) }
      total = past.resultUsd.value
      open = 0
      recordedDay = past.day
    } else {
      name = status.strategy.name
      version = status.strategy.version
      closes = status.tradesToday.map { (at: $0.closedAt.date, result: $0.resultUsd.value) }
      total = status.resultTodayUsd.value
      open = status.positions.count
      recordedDay = nil
    }
  }
}

/// "Which version trades" (IOS2Lab): the active version's name with its version and the Active
/// badge, then its day's result big with the day's trades under it and the day's curve beside it,
/// on a card edged in the accent. At large text sizes the curve goes under the result.
private struct ActiveCard: View {
  let active: ActiveDay

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Lab.active)
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
        Text(verbatim: active.name)
          .font(Tokens.Typography.title3MonoBold)
          .foregroundStyle(Palette.textPrimary)
          .fixedSize(horizontal: false, vertical: true)
          .layoutPriority(1)
        Text(verbatim: L10n.Lab.versionTag(active.version))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize()
        Spacer(minLength: Tokens.Space.s)
        // The version's role, as every version's role on both apps: a `Badge`.
        Badge(L10n.Lab.activeBadge, tone: .accent)
      }
      RowStack(alignment: .bottom, spacing: Tokens.Space.s) {
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          Text(verbatim: Money.signedUSD(active.total))
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.result(active.total))
            .contentTransition(.numericText())
            .fixedSize()
          Text(LabView.daySummary(active))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
        Spacer(minLength: 0)
        let curve = LabView.curve(active)
        if curve.count > 1 {
          DrawnSparkline(values: curve, color: Palette.result(active.total))
            .frame(width: LabView.curveWidth, height: LabView.curveHeight)
            .accessibilityHidden(true)
        }
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(tint: Palette.accent)
  }
}

/// A card title's "i" (the boards' `.info`): a tap shows or hides what the card counts under the
/// title, in place; never a hover. Its touch target is `Size.touchTarget`.
struct InfoToggle: View {
  @Binding var shown: Bool
  /// What VoiceOver calls it ("What this counts").
  let label: LocalizedStringResource

  var body: some View {
    Button {
      withAnimation(Tokens.Motion.quick) { shown.toggle() }
    } label: {
      Image(systemName: InfoCaption.infoSymbol)
        .font(Tokens.Typography.callout)
        .foregroundStyle(shown ? Palette.infoText : Palette.textTertiary)
        .frame(width: Tokens.Size.touchTarget, height: Tokens.Size.touchTarget)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(label))
    .accessibilityAddTraits(shown ? .isSelected : [])
  }
}

/// "Blocked by safety rules" (IOS2Lab): how many times that day the platform's limits refused an
/// entry the active version wanted, big, then one bar per cause, the most frequent first: the
/// first `shownCauses`, then "Show all N ›". The "i" says what it counts.
private struct RefusalsCard: View {
  let counts: [RefusalCount]?
  let failure: String?
  /// The recorded day shown; nil for today.
  let day: WireDate?
  @State private var showsInfo = false

  /// Causes the card shows before "Show all" (the board's three).
  static let shownCauses = 3

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(spacing: 0) {
        CardLabel(L10n.Lab.refusals)
        InfoToggle(shown: $showsInfo, label: L10n.Lab.refusalsAbout)
        Spacer(minLength: 0)
      }
      if showsInfo {
        InfoCaption(L10n.Lab.refusalsInfo)
          .transition(.opacity)
      }
      if let failure {
        ReadFailureNote(counts == nil ? L10n.Lab.refusalsFailed : L10n.Watching.stale, detail: failure)
      }
      if let counts {
        // The day's total, big, with its day ("today", or the recorded day).
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: String(counts.reduce(0) { $0 + $1.count }))
            .font(Tokens.Typography.metric)
            .foregroundStyle(Palette.textPrimary)
            .contentTransition(.numericText())
          Group {
            if let day {
              Text(verbatim: DayText.day(day.noonInNewYork))
            } else {
              Text(L10n.Lab.refusalsToday)
            }
          }
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
        }
        .accessibilityElement(children: .combine)
        if counts.isEmpty {
          InfoCaption(L10n.Lab.noRefusals)
        }
        let most = Double(counts.first?.count ?? 1)
        // The most frequent causes, then "Show all N ›".
        CappedList(counts, id: \.id, title: L10n.Lab.refusals, limit: Self.shownCauses, spacing: Tokens.Space.m,
          fills: false) { _, count in
          VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.s) {
              StateGlyph(count.cause?.known?.symbol ?? RefusalCode.unknownSymbol, tone: .warning,
                label: causeText(count), style: .compact)
              causeText(count)
                .font(Tokens.Typography.callout)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer()
              Text(verbatim: String(count.count))
                .font(Tokens.Typography.calloutMono.bold())
                .foregroundStyle(Palette.textPrimary)
                // One bump each time the bot refused that cause again.
                .bumps(on: count.count)
            }
            MeterBar(fraction: Double(count.count) / most, tone: .warning)
              .accessibilityHidden(true)
          }
          .accessibilityElement(children: .combine)
        }
      } else if failure == nil {
        Skeleton(L10n.Common.loading) { SkeletonRows(Tokens.Loading.rows) }
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }

  /// The cause in words.
  private func causeText(_ count: RefusalCount) -> Text {
    if let code = count.cause?.known { return Text(L10n.Cause.title(code)) }
    if let cause = count.cause { return cause.hasCode ? Text(L10n.Cause.other) : Text(verbatim: cause.code) }
    return Text(L10n.Lab.noCause)
  }
}
