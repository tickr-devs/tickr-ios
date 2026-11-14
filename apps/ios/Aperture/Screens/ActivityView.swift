import ApertureDesign
import ApertureKit
import SwiftUI

/// What happened today: the day's result curve, closed trades, signals not taken, and the journal.
/// Past days come with the days API; this screen shows today until then.
struct ActivityView: View {
  enum Pane: String, CaseIterable, Identifiable {
    case trades, skipped, journal
    var id: String { rawValue }

    var title: LocalizedStringResource {
      switch self {
      case .trades: return L10n.Activity.trades
      case .skipped: return L10n.Activity.notTaken
      case .journal: return L10n.Activity.journal
      }
    }
  }

  /// Order in which the blocks rise in (`rise(step:)`); list rows follow one step apart.
  enum Order: Int { case day = 1, picker, list }

  @Environment(AppModel.self) private var model
  @State private var section: Pane = .trades

  var body: some View {
    Screen(L10n.App.activity) {
      ConnectionPrompt()
      if let status = model.status {
        DayCard(status: status, live: model.response?.stale == false).rise(step: Order.day.rawValue)
        Picker(selection: $section) {
          ForEach(Pane.allCases) { Text($0.title).tag($0) }
        } label: {
          Text(L10n.Activity.show)
        }
        .pickerStyle(.segmented)
        .rise(step: Order.picker.rawValue)
        Group {
          switch section {
          case .trades: TradesList(status: status)
          case .skipped: NotTaken()
          case .journal: Journal(events: Board.events(status))
          }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .id(section)
      }
    }
    .animation(Tokens.Motion.standard, value: section)
    .refreshable { await model.refresh() }
  }
}

private struct DayCard: View {
  /// Size of the day's result curve, in points.
  static let curveSize = CGSize(width: 120, height: 50)

  @State private var drawn = false
  let status: StatusV1
  let live: Bool

  var body: some View {
    let stats = Board.dayStats(status)
    let result = stats.resultGrossUsd
    HStack(spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        HStack(spacing: Tokens.Space.s) {
          if live { PulseDot(Palette.profit, size: Tokens.Size.dotSmall) }
          Text(L10n.Common.today(Format.day(status.writtenAt.date)))
        }
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
        Text(verbatim: Money.signedUSD(result))
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.result(result))
          .contentTransition(.numericText(value: NSDecimalNumber(decimal: result).doubleValue))
        Text(L10n.Activity.counts(stats.trades, stats.wins, stats.losses, status.position == nil ? 0 : 1))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      Spacer()
      Sparkline(curve)
        .trim(from: 0, to: drawn ? 1 : 0)
        .stroke(Palette.result(result),
          style: StrokeStyle(lineWidth: Tokens.Stroke.bold, lineCap: .round, lineJoin: .round))
        .frame(width: Self.curveSize.width, height: Self.curveSize.height)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard()
    .onAppear { withAnimation(Tokens.Motion.draw) { drawn = true } }
  }

  /// Running total of closed trades in the order they closed, starting at zero.
  private var curve: [Double] {
    var total = Decimal(0)
    var points: [Double] = [0]
    for trade in status.tradesToday.sorted(by: { $0.closedAt.date < $1.closedAt.date }) {
      total += trade.resultGrossUsd.value
      points.append(NSDecimalNumber(decimal: total).doubleValue)
    }
    return points
  }
}

private struct TradesList: View {
  let status: StatusV1

  var body: some View {
    let trades = status.tradesToday.sorted { $0.closedAt.date > $1.closedAt.date }
    VStack(spacing: Tokens.Space.s) {
      if let position = status.position {
        row(symbol: position.symbol, time: String(localized: L10n.Activity.openSince(Format.time(position.openedAt.date))),
          tag: String(localized: L10n.Activity.openTag),
          color: Palette.accentText,
          result: String(localized: L10n.Common.quantityAt(position.quantity.text, position.entryPrice.text)),
          detail: String(localized: L10n.Activity.stopDetail(position.stop.price?.text ?? Format.missing,
            Board.stopStateTitle(position.stop.state))))
          .rise(step: ActivityView.Order.list.rawValue)
      }
      ForEach(Array(trades.enumerated()), id: \.offset) { index, trade in
        let value = trade.resultGrossUsd.value
        row(symbol: trade.symbol,
          time: Format.time(trade.openedAt.date) + Format.timeRange + Format.time(trade.closedAt.date),
          tag: Board.exitReasonTitle(trade.exitReason).uppercased(),
          color: Palette.result(value),
          result: Money.signed(value),
          detail: String(localized: L10n.Common.quantityAt(trade.quantity.text, trade.entryPrice.text))
            + Format.arrow + trade.exitPrice.text)
          .rise(step: ActivityView.Order.list.rawValue + index)
      }
      if trades.isEmpty && status.position == nil {
        ContentUnavailableView {
          Label { Text(L10n.Activity.noTrades) } icon: { Image(systemName: "clock") }
        } description: {
          Text(L10n.Activity.noTradesBody)
        }
      }
    }
  }

  private func row(symbol: String, time: String, tag: String, color: Color, result: String, detail: String)
    -> some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: symbol).font(Tokens.Typography.calloutMono.bold())
        Text(verbatim: time).font(Tokens.Typography.annotation).foregroundStyle(Palette.textQuaternary)
        Spacer()
        Text(verbatim: tag)
          .font(Tokens.Typography.annotation)
          .padding(.horizontal, Tokens.Space.s)
          .padding(.vertical, Tokens.Space.xxs)
          .foregroundStyle(color)
          .background(color.opacity(Tokens.Opacity.glow), in: Capsule())
        Text(verbatim: result)
          .font(Tokens.Typography.calloutMono.bold())
          .foregroundStyle(color)
      }
      Text(verbatim: detail)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.m)
    .apertureCard(radius: Tokens.Radius.card)
    .accessibilityElement(children: .combine)
  }
}

private struct NotTaken: View {
  var body: some View {
    ContentUnavailableView {
      Label { Text(L10n.Activity.notTakenTitle) } icon: { Image(systemName: "hand.raised") }
    } description: {
      Text(L10n.Activity.notTakenBody)
    }
  }
}

private struct Journal: View {
  /// Rows after this many rise in together, so a long journal does not keep animating.
  static let staggeredRows = 10
  /// Side of an event's dot, in points.
  static let dotSide: CGFloat = 7

  let events: [Board.Event]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: Format.clock(event.time))
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
          Circle().fill(event.tone.color).frame(width: Self.dotSide, height: Self.dotSide)
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            Text(verbatim: event.tag).font(Tokens.Typography.annotationBold).foregroundStyle(event.tone.color)
            Text(verbatim: event.text).font(.footnote).foregroundStyle(Palette.textSecondary)
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .rise(step: ActivityView.Order.list.rawValue + min(index, Self.staggeredRows))
      }
      if events.isEmpty {
        Text(L10n.Activity.nothingYet)
          .font(.subheadline)
          .foregroundStyle(Palette.textTertiary)
          .padding(Tokens.Space.l)
      }
    }
    .padding(.vertical, Tokens.Space.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard(radius: Tokens.Radius.card)
  }
}
