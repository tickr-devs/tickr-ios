import SwiftUI
import TickrDesign
import TickrKit

/// Strategy lab: the active strategy now, then every observer (a shadow version that never trades)
/// with the symbols it would have entered, how often the bot agreed and its simulated result.
/// Approving a version stays on the Mac.
struct LabView: View {
  /// Symbol of the version that places orders.
  static let tradesSymbol = "bolt.fill"
  /// Symbol of a shadow version that only watches.
  static let observerSymbol = "eye.fill"
  /// Symbol in front of a warning that the data is a failed or last read.
  static let warningSymbol = "exclamationmark.triangle.fill"

  /// Order in which the blocks rise in (`rise(step:)`).
  private enum Order: Int { case active = 1, versions, replay, advisor, observers, refusals, later }

  @Environment(AppModel.self) private var model
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var lab = Container.shared.labModel()
  @State private var advisor = Container.shared.advisorModel()

  var body: some View {
    Screen(L10n.Lab.title, tab: .lab) {
      if let status = model.status {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          // The label, then its note; the note goes under it at large text sizes.
          RowStack {
            CardLabel(L10n.Lab.active)
            Spacer()
            // One pulse per new trade of the active version (an entry the bot made), still in
            // between; a new day starts still.
            StatusPill(Text(L10n.Lab.trades), tone: .accent, live: true, event: Self.entries(status),
              systemImage: Self.tradesSymbol)
              .id(WireDate(newYorkDateOf: status.writtenAt.date))
          }
          // As on the design: the name with its version and the day's trades under it; the day's
          // result with its curve at the right. At large text sizes the result goes under.
          RowStack(alignment: .top, spacing: Tokens.Space.s) {
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
                Text(verbatim: status.strategy.name)
                  .font(.title3.monospaced().bold())
                  .foregroundStyle(Palette.textPrimary)
                Text(verbatim: L10n.Lab.versionTag(status.strategy.version))
                  .font(Tokens.Typography.annotation)
                  .foregroundStyle(Palette.textQuaternary)
                  .fixedSize()
              }
              Text(Self.daySummary(status))
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            VStack(alignment: typeSize.stacksRows ? .leading : .trailing, spacing: Tokens.Space.xs) {
              Text(verbatim: Money.signedUSD(status.resultTodayUsd.value))
                .font(Tokens.Typography.metric)
                .foregroundStyle(Palette.result(status.resultTodayUsd.value))
                .contentTransition(.numericText())
                .fixedSize()
              let curve = Self.curve(status)
              if curve.count > 1 {
                DrawnSparkline(values: curve, color: Palette.result(status.resultTodayUsd.value))
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

        VersionsCard(curves: curves(status), missing: missing,
          end: WireDate(newYorkDateOf: status.writtenAt.date) == model.today ? model.botNow : status.writtenAt.date)
          .rise(step: Order.versions.rawValue)
        LabReplayCard(lab: lab, url: model.connection.url)
          .rise(step: Order.replay.rawValue)
        AdvisorCard(advisor: advisor, url: model.connection.url)
          .rise(step: Order.advisor.rawValue)
        ObserversCard(lab: lab, traded: Self.traded(status))
          .rise(step: Order.observers.rawValue)
        RefusalsCard(counts: lab.refusals, failure: lab.refusalsFailure)
          .rise(step: Order.refusals.rawValue)
        InfoCaption(L10n.Lab.later)
          .rise(step: Order.later.rawValue)
      }
    }
    .task(id: sessionKey) { await load() }
    .refreshable {
      await model.refresh()
      await load()
      if let url = model.connection.url { await advisor.load(url) }
    }
  }

  /// The address and the status's session; a change reads the observers again.
  private var sessionKey: [String] {
    [model.connection.url?.absoluteString, model.status.map { WireDate(newYorkDateOf: $0.writtenAt.date).text }]
      .compactMap { $0 }
  }

  /// The trading strategy's line, then each observer's whose trades the bot could list.
  private func curves(_ status: StatusV1) -> [VersionCurve] {
    [VersionCurve.active(name: status.strategy.name, version: status.strategy.version, trades: status.tradesToday,
      total: status.resultTodayUsd.value)]
      + (lab.observers?.observers.compactMap { VersionCurve.simulated($0, traded: Self.traded(status)) } ?? [])
  }

  /// The symbols the trading strategy traded or holds on the status's day.
  static func traded(_ status: StatusV1) -> Set<String> {
    Set(status.tradesToday.map(\.symbol) + status.positions.map(\.symbol))
  }

  /// Why an observer has no line: the bot could not list its simulated trades.
  private var missing: [String] {
    (lab.observers?.observers ?? []).filter { $0.trades == nil }.map { observer in
      let cause = ApiText.prose(observer.tradesCauseCodes, text: observer.tradesCause) ?? Format.missing
      return String(localized: L10n.Lab.noTrades(observer.name, observer.version, cause))
    }
  }

  /// Size of the active strategy's day curve, in points, as on the design.
  static let curveWidth: CGFloat = 70
  static let curveHeight: CGFloat = 20

  /// "today · 3 closed · 2 W · 1 L · 1 open".
  static func daySummary(_ status: StatusV1) -> LocalizedStringResource {
    let results = status.tradesToday.map(\.resultUsd.value)
    return L10n.Lab.daySummary(results.count, results.filter { $0 > 0 }.count, results.filter { $0 < 0 }.count,
      status.positions.count)
  }

  /// How many trades the active version entered that day: its closed trades (or ones without a
  /// recorded strategy) and the open positions, each entry once, so a position that closes is
  /// not counted again. It rises once per new entry.
  static func entries(_ status: StatusV1) -> Int {
    let closed = status.tradesToday.filter { $0.strategy == nil || $0.strategy == status.strategy }
      .map { Entry(symbol: $0.symbol, at: $0.openedAt.date) }
    return Set(closed + status.positions.map { Entry(symbol: $0.symbol, at: $0.openedAt.date) }).count
  }

  /// One entry of a trade: its symbol and when it opened.
  private struct Entry: Hashable {
    let symbol: String
    let at: Date
  }

  /// The day's realized result after each closed trade, from zero.
  static func curve(_ status: StatusV1) -> [Double] {
    let sorted = status.tradesToday.sorted { $0.closedAt.date < $1.closedAt.date }
    var total = Decimal.zero
    return [0] + sorted.map { trade in
      total += trade.resultUsd.value
      return NSDecimalNumber(decimal: total).doubleValue
    }
  }

  private func load() async {
    guard let url = model.connection.url, let status = model.status else { return }
    await lab.load(url, day: WireDate(newYorkDateOf: status.writtenAt.date))
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
        ForEach(counts) { count in
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
        TickrLoader(L10n.Common.loading).frame(maxWidth: .infinity)
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

/// Each observer of the day: name and version, the symbols it would have entered, how many of
/// them the bot also traded, and its simulated result (or why there is none).
private struct ObserversCard: View {
  let lab: LabModel
  let traded: Set<String>

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      CardLabel(L10n.Lab.board)
      if let observers = lab.observers {
        // A failed refresh after a good read: the rows stay, marked as the last read.
        if let failure = lab.failure {
          ReadFailureNote(L10n.Lab.failed, detail: failure)
        }
        if observers.observers.isEmpty {
          InfoCaption(L10n.Lab.noObservers)
        }
        ForEach(observers.observers.map { ObserverSummary($0, traded: traded) }) { summary in
          ObserverRow(summary: summary)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      } else if let failure = lab.failure {
        ReadFailureNote(L10n.Lab.failed, detail: failure)
      } else {
        TickrLoader(L10n.Common.loading).frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
  }
}

private struct ObserverRow: View {
  /// Symbol of the overlap with what the bot traded.
  static let agreementSymbol = "circle.lefthalf.filled"

  let summary: ObserverSummary

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      RowStack(spacing: Tokens.Space.s) {
        HStack(spacing: Tokens.Space.s) {
          StateGlyph(LabView.observerSymbol, tone: .highlight,
            label: L10n.Common.strategyVersion(summary.name, summary.version), style: .compact)
          Text(L10n.Common.strategyVersion(summary.name, summary.version))
            .font(.subheadline.monospaced().weight(.semibold))
        }
        Spacer(minLength: 0)
        if let result = summary.result {
          DeltaTag(result, text: Money.signed(result))
        } else {
          Badge(L10n.Lab.noResult, tone: .neutral)
        }
      }
      if summary.result == nil, let cause = summary.resultCauseText {
        InfoCaption(verbatim: cause)
      }
      if let agreement = summary.agreement {
        MeterBar(fraction: agreement, tone: .highlight)
        InfoCaption(L10n.Lab.agreement(summary.shared.count, summary.entered.count,
          summary.entered.joined(separator: Format.separator)), systemImage: Self.agreementSymbol, tone: .highlight)
      } else {
        InfoCaption(L10n.Lab.noEntries)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
