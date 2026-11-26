import SwiftUI
import TickrDesign
import TickrKit

/// Strategy lab: the active strategy now, the replay that compares versions, and why the day's
/// signals were refused.
struct LabView: View {
  /// Symbol in front of a warning that the data is a failed or last read.
  static let warningSymbol = "exclamationmark.triangle.fill"

  /// Order in which the blocks rise in (`rise(step:)`).
  private enum Order: Int { case active = 1, replay, refusals, later }

  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
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
        let active = ActiveDay(status: status, past: model.isLive ? nil : lab.pastDay)
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          // The label, then its note; the note goes under it at large text sizes.
          RowStack {
            CardLabel(L10n.Lab.active)
            Spacer()
            // The active version's role, as every version's role on both apps: a `Badge`.
            Badge(L10n.Lab.trades, tone: .accent)
          }
          // As on the design: the name with its version and the day's trades under it; the day's
          // result with its curve at the right. At large text sizes the result goes under.
          RowStack(alignment: .top, spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(verbatim: active.name)
                  .font(.title3.monospaced().bold())
                  .foregroundStyle(Palette.textPrimary)
                Text(verbatim: L10n.Lab.versionTag(active.version))
                  .font(Tokens.Typography.annotation)
                  .foregroundStyle(Palette.textQuaternary)
                  .fixedSize()
              }
              Text(Self.daySummary(active))
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            VStack(alignment: typeSize.stacksRows ? .leading : .trailing, spacing: Tokens.Space.xs) {
              Text(verbatim: Money.signedUSD(active.total))
                .font(Tokens.Typography.metric)
                .foregroundStyle(Palette.result(active.total))
                .contentTransition(.numericText())
                .fixedSize()
              let curve = Self.curve(active)
              if curve.count > 1 {
                DrawnSparkline(values: curve, color: Palette.result(active.total))
                  .frame(width: Self.curveWidth, height: Self.curveHeight)
                  .accessibilityHidden(true)
              }
            }
          }
          InfoCaption(L10n.Lab.modules)
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tickrCard()
        .rise(step: Order.active.rawValue)

        LabReplayCard(lab: lab, url: model.connection.url)
          .rise(step: Order.replay.rawValue)
        RefusalsCard(counts: lab.refusals, failure: lab.refusalsFailure)
          .rise(step: Order.refusals.rawValue)
        InfoCaption(L10n.Lab.later)
          .rise(step: Order.later.rawValue)
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

  /// "today · 3 closed · 2 W · 1 L · 1 open", or a recorded day's "Nov 14 · 3 closed · 2 W · 1 L".
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

/// Why the active strategy's signals were refused that day: one bar per cause, longest first.
private struct RefusalsCard: View {
  let counts: [RefusalCount]?
  let failure: String?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Lab.refusals)
      if let failure {
        ReadFailureNote(counts == nil ? L10n.Lab.refusalsFailed : L10n.Watching.stale, detail: failure)
      }
      if let counts {
        if counts.isEmpty {
          InfoCaption(L10n.Lab.noRefusals)
        }
        let most = Double(counts.first?.count ?? 1)
        // The most frequent causes, then "Show all N ›".
        CappedList(counts, id: \.id, title: L10n.Lab.refusals, spacing: Tokens.Space.m) { _, count in
          VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.s) {
              StateGlyph(count.cause?.known?.symbol ?? RefusalCode.unknownSymbol, tone: .warning,
                label: causeText(count), style: .compact)
              Group {
                if let code = count.cause?.known {
                  Text(L10n.Cause.title(code))
                } else if let cause = count.cause, cause.hasCode {
                  Text(L10n.Cause.other)
                } else if let cause = count.cause {
                  Text(verbatim: cause.code)
                } else {
                  Text(L10n.Lab.noCause)
                }
              }
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textSecondary)
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

  /// The cause in words, for its glyph's hint.
  private func causeText(_ count: RefusalCount) -> Text {
    if let code = count.cause?.known { return Text(L10n.Cause.title(code)) }
    if let cause = count.cause { return cause.hasCode ? Text(L10n.Cause.other) : Text(verbatim: cause.code) }
    return Text(L10n.Lab.noCause)
  }
}
