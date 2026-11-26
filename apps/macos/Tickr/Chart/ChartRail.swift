import SwiftUI
import TickrDesign
import TickrKit

/// The Chart's right rail (mockup MacChart): the symbols to chart (open positions, waiting
/// symbols, the screeners' first ones), what the bot decided at the pointed candle, and the shown
/// symbol's open position. A fixed width; it scrolls on its own when taller than the window.
struct ChartRail: View {
  @Environment(AppModel.self) private var model
  let symbol: String?
  /// Symbols the chart can show; the list offers the ones among them.
  let symbols: [String]
  let pick: (String) -> Void
  let plot: ChartPlot?
  let pointer: ChartPointer
  let decisions: DecisionsV1?
  let error: String?
  let showsDay: Bool
  let position: PositionRow?

  /// Width of the rail, in points: narrow enough that at the window's least width the chart keeps
  /// most of the room.
  static let width: CGFloat = 240
  /// Most screener candidates the list shows.
  static let candidateLimit = 5

  var body: some View {
    ScrollView {
      VStack(spacing: Tokens.Space.m) {
        SymbolList(
          rows: rows, positions: model.positions.count, symbol: symbol, pick: pick)
        ChartExplainCard(
          symbol: symbol, plot: plot, pointer: pointer, decisions: decisions, error: error, showsDay: showsDay)
        if let position {
          PositionCard(row: position)
        }
      }
    }
    .scrollEdgeHints()
    // A fixed least and largest size, whatever the content: a pane that reported the size of its
    // rows (wrapped texts, a spinner, then the list) resized the window's columns inside AppKit's
    // layout pass, and on macOS 27 AppKit threw ("needs another Update Constraints in Window
    // pass").
    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
  }

  /// Open positions first, then the symbols the strategy is watching, then the screeners'
  /// candidates not listed yet.
  private var rows: [SymbolList.Row] {
    var seen = Set<String>()
    var rows: [SymbolList.Row] = []
    for row in model.positions where seen.insert(row.id).inserted {
      let verified = row.position.stop.state.isProtected
      let note = row.stop.map {
        verified ? L10n.Chart.railStop(Format.price($0)) : L10n.Chart.railStopUnverified(Format.price($0))
      }
      rows.append(SymbolList.Row(symbol: row.id, kind: .position, note: note))
    }
    for watched in model.watching?.rows ?? [] where watched.verdict == .watch && seen.insert(watched.symbol).inserted {
      rows.append(SymbolList.Row(
        symbol: watched.symbol, kind: .watch, note: L10n.Chart.railSince(Format.marketMinute(watched.at.date))))
    }
    for chip in Self.candidates(model.flow) where seen.insert(chip.symbol).inserted {
      rows.append(SymbolList.Row(symbol: chip.symbol, kind: .candidate, note: Self.screenerNote(chip)))
    }
    return rows.filter { symbols.contains($0.symbol) }
  }

  /// Symbols the strategy is watching (its latest verdict is WATCH).
  static func watched(_ watching: WatchingV1?) -> [String] {
    (watching?.rows ?? []).filter { $0.verdict == .watch }.map(\.symbol)
  }

  /// The screeners' symbols the universe admitted, at most `candidateLimit`.
  static func candidates(_ flow: FlowV1?) -> [FlowChipV1] {
    Array((flow?.chips ?? []).filter { $0.excludedCause == nil }.prefix(candidateLimit))
  }

  /// "gainers +16.6%": the candidate's first screener and its change from the previous close.
  private static func screenerNote(_ chip: FlowChipV1) -> LocalizedStringResource? {
    guard let source = chip.sources.first else { return nil }
    let name = switch source {
    case .gainers: String(localized: L10n.Chart.sourceGainers)
    case .losers: String(localized: L10n.Chart.sourceLosers)
    case .topActives: String(localized: L10n.Chart.sourceActives)
    }
    let change = chip.changePct.map {
      Percent.signed(points: $0.value, fractionDigits: Percent.moverDigits)
    }
    return L10n.Chart.railScreener(name, change ?? Format.missing)
  }
}

/// "Symbols": the symbols to chart, the shown one highlighted.
private struct SymbolList: View {
  struct Row: Identifiable {
    enum Kind { case position, watch, candidate }
    let symbol: String
    let kind: Kind
    let note: LocalizedStringResource?

    var id: String { symbol }
  }

  let rows: [Row]
  let positions: Int
  let symbol: String?
  let pick: (String) -> Void

  /// Width of the symbol column, in points.
  static let symbolWidth: CGFloat = 46

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        CardLabel(L10n.Chart.rail)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Text(L10n.Chart.railCount(positions))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize()
      }
      .padding(.bottom, Tokens.Space.xs)
      if rows.isEmpty {
        Text(L10n.Chart.railEmpty)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .offlineOutline(lines: Tokens.Loading.fewLines)
      }
      ForEach(rows) { row in
        Button { pick(row.symbol) } label: { label(row) }
          .buttonStyle(.plain)
      }
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(radius: Tokens.Radius.large)
    .animation(Tokens.Motion.quick, value: symbol)
  }

  private func label(_ row: Row) -> some View {
    let selected = row.symbol == symbol
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    return HStack(spacing: Tokens.Space.s) {
      SymbolText(row.symbol)
        .font(Tokens.Typography.calloutMono.bold())
        .foregroundStyle(Palette.textPrimary)
        .frame(width: Self.symbolWidth, alignment: .leading)
      tag(row.kind)
      Spacer(minLength: Tokens.Space.xs)
      if let note = row.note {
        Text(note)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
          .multilineTextAlignment(.trailing)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, Tokens.Space.s)
    .padding(.vertical, Tokens.Space.s)
    .background(selected ? Palette.selection : .clear, in: shape)
    .overlay(shape.strokeBorder(selected ? Palette.separatorStrong : .clear, lineWidth: Tokens.Stroke.thin))
    .contentShape(shape)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @ViewBuilder private func tag(_ kind: Row.Kind) -> some View {
    switch kind {
    case .position: Badge(L10n.Chart.railPosition, color: Palette.accentText)
    case .watch: Badge(L10n.Chart.railWatch, color: Palette.infoText)
    case .candidate: Badge(L10n.Chart.railCandidate, color: Palette.textTertiary)
    }
  }
}

/// "Open position" (mockup MacChart): the R it stands at now, big, then its entry and its stop as
/// the chart draws them.
private struct PositionCard: View {
  let row: PositionRow

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        CardLabel(L10n.Chart.positionOnChart)
        Spacer(minLength: Tokens.Space.s)
        let r = row.resultR ?? row.latestResultR
        Text(verbatim: r.map(Risk.text) ?? Format.missing)
          .font(Tokens.Typography.figure)
          .foregroundStyle(r.map(Palette.result) ?? Palette.textQuaternary)
        Text(L10n.Chart.positionRNow)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      VStack(spacing: Tokens.Space.xs) {
        line(L10n.Chart.positionEntry) {
          Text(L10n.Chart.positionEntryValue(
            Format.marketMinute(row.position.openedAt.date), Format.price(row.entry), Format.quantity(row.quantity)))
            .foregroundStyle(Palette.textPrimary)
        }
        line(L10n.Chart.positionStop) { stop }
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textTertiary)
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(radius: Tokens.Radius.large)
  }

  /// "label ........ value", the value right-aligned.
  private func line<Value: View>(_ label: LocalizedStringResource, @ViewBuilder value: () -> Value) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(label)
      Spacer(minLength: Tokens.Space.xs)
      value()
    }
  }

  /// The stop's price, then its state as a `Badge` (as on the iOS position chain) in the state's
  /// tone (`StopState.tone`): green VERIFIED, amber pending, red missing or unknown.
  @ViewBuilder private var stop: some View {
    if let price = row.stop {
      let state = row.position.stop.state
      HStack(spacing: Tokens.Space.xs) {
        Text(verbatim: Format.price(price)).foregroundStyle(Palette.lossText)
        Badge(verbatim: Board.stopStateTitle(state), color: state.tone.text)
      }
    } else {
      Text(L10n.Chart.positionNoStop).foregroundStyle(Palette.lossText)
    }
  }
}
