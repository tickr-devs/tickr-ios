import SwiftUI
import TickrDesign
import TickrKit

/// "Watching closely", all symbols: the large sheet the card's "Show all N ›" opens, with every row
/// the bot sent, sorted closest first, by symbol or latest decision first (`WatchingList`).
struct WatchingSheet: View {
  let watching: WatchingV1?
  /// False while a refresh failed and the rows are the last read.
  let current: Bool
  @Environment(\.dismiss) private var dismiss
  @State private var sort = WatchingSort.closest

  /// The orders the iPhone offers, as in the design.
  static let sorts: [WatchingSort] = [.closest, .symbol, .latest]
  /// SF Symbol of the close button.
  static let closeSymbol = "xmark"

  var body: some View {
    let all = watching?.rows ?? []
    let rows = WatchingList.sorted(all, by: sort)
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      header(all)
      sortPicker
      ScrollView {
        LazyVStack(alignment: .leading, spacing: Tokens.Space.m) {
          if all.isEmpty {
            Text(L10n.Watching.none)
              .font(Tokens.Typography.callout)
              .foregroundStyle(Palette.textTertiary)
          }
          // The rows rise one after another as the sheet opens; a new order moves them.
          ForEach(Array(rows.enumerated()), id: \.element.symbol) { index, row in
            WatchingRow(row: row, current: current)
              .padding(.bottom, Tokens.Space.m)
              .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
              }
              .rise(step: index)
          }
          if let watching, watching.total > all.count {
            Text(L10n.Watching.capped(all.count, watching.total))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        .animation(Tokens.Motion.standard, value: rows.map(\.symbol))
        .padding(.bottom, Tokens.Space.xl)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .padding([.horizontal, .top], Tokens.Space.l)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .presentationBackground(Palette.surface)
  }

  /// "Watching closely" over how many symbols and, while reads succeed, "live"; the close button.
  private func header(_ all: [WatchingRowV1]) -> some View {
    let parts = [String(localized: L10n.Watching.symbols(all.count))]
      + (current ? [String(localized: L10n.Watching.live)] : [])
    return HStack(alignment: .top, spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(L10n.Watching.title)
          .font(Tokens.Typography.heading)
          .foregroundStyle(Palette.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(verbatim: parts.joined(separator: Format.separator))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      // A round X in a full touch target.
      Button { dismiss() } label: {
        Image(systemName: Self.closeSymbol)
      }
      .buttonStyle(.icon(compact: true))
      .frame(width: Tokens.Size.touchTarget, height: Tokens.Size.touchTarget)
      .contentShape(Rectangle())
      .accessibilityLabel(Text(L10n.Watching.close))
    }
  }

  /// A segmented control while the three names fit across; wrapping chips when they do not (large
  /// text sizes, longer words), so no name is cut.
  private var sortPicker: some View {
    ViewThatFits(in: .horizontal) {
      Picker(selection: $sort) {
        ForEach(Self.sorts, id: \.self) { item in
          Text(item.title).tag(item)
        }
      } label: {
        Text(L10n.Watching.sortLabel)
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: .infinity)
      ChipFlow {
        ForEach(Self.sorts, id: \.self) { item in
          Button { sort = item } label: { Text(item.title) }
            .buttonStyle(.chip(selected: sort == item))
        }
      }
    }
    .animation(Tokens.Motion.quick, value: sort)
  }
}

extension WatchingSort {
  /// The sort control's name.
  var title: LocalizedStringResource {
    switch self {
    case .closest: L10n.Watching.sortClosest
    case .symbol: L10n.Watching.sortSymbol
    case .quoteAge: L10n.Watching.sortQuoteAge
    case .latest: L10n.Watching.sortLatest
    }
  }
}
