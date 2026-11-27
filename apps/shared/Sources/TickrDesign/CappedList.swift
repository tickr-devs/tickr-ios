import SwiftUI
import TickrKit

/// A list inside a card that grows with the day or the history (fills, signals not taken, journal
/// lines, versions, refusals): the card shows the first rows, which the caller orders latest
/// first, then "Show all N ›" (`CardFooterLink`) on the card's bottom edge, which opens every row
/// in a sheet that scrolls. A card therefore never grows with the list and never scrolls inside.
///
/// How many rows: at least `limit` (the owner's number for this card, 2026-11-18); where the card's
/// height comes from the window (a card filling its grid cell or its column on the Mac), as many
/// more as fit, so a large window fills its cards instead of leaving them half empty. The rows'
/// space takes the card's height and never depends on how many rows it holds, so the count cannot
/// feed back into the card (as `FittingRows`). Put it last in its card: the link reaches the
/// card's edges. `row` gets the row's place in the list (0 for the first) and the row.
public struct CappedList<Item, ID: Hashable, Row: View>: View {
  let items: [Item]
  let id: KeyPath<Item, ID>
  let title: LocalizedStringResource
  let limit: Int
  let spacing: CGFloat
  let endsCard: Bool
  let fills: Bool
  let row: (Int, Item) -> Row
  @State private var showsAll = false
  /// Each shown row's height as last laid out, by id.
  @State private var heights: [ID: CGFloat] = [:]
  /// Height of the rows' space: what the card leaves above the link.
  @State private var available: CGFloat = 0

  /// `title`: the sheet's heading (the card's or the section's title). `spacing`: between rows.
  /// `endsCard`: false for a list with another section under it (the broker's positions above
  /// its orders): the link then stops at the section's end instead of the card's bottom edge.
  /// `fills`: false keeps the card at `limit` rows however tall it is (a board that caps the list).
  public init(
    _ items: [Item], id: KeyPath<Item, ID>, title: LocalizedStringResource, limit: Int = Tokens.Lists.cappedRows,
    spacing: CGFloat = Tokens.Space.s, endsCard: Bool = true, fills: Bool = true,
    @ViewBuilder row: @escaping (Int, Item) -> Row
  ) {
    self.items = items
    self.id = id
    self.title = title
    self.limit = limit
    self.spacing = spacing
    self.endsCard = endsCard
    self.fills = fills
    self.row = row
  }

  public var body: some View {
    let ids = items.map { $0[keyPath: id] }
    let measured = ids.map { heights[$0].map(Double.init) }
    let cap = ListCap(heights: measured, available: fills ? Double(available) : 0, spacing: Double(spacing),
      limit: limit)
    let shown = Array(zip(ids.prefix(cap.shown), items.prefix(cap.shown)).enumerated())
    VStack(alignment: .leading, spacing: 0) {
      Color.clear
        // Never taller than every row: a window with room to spare leaves no gap under a short list.
        .frame(maxWidth: .infinity, minHeight: CGFloat(cap.leastHeight),
          maxHeight: CGFloat(fills ? cap.fullHeight : cap.leastHeight))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { available = $0 }
        .overlay(alignment: .top) {
          VStack(alignment: .leading, spacing: spacing) {
            ForEach(shown, id: \.element.0) { index, pair in
              // Each row at its own full height (text wraps, never cut), whatever the space: the
              // count, not a squeezed row, is what fits the card.
              row(index, pair.1)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[pair.0] = $0 }
            }
          }
        }
        .clipped()
        .onChange(of: ids) { _, current in
          heights = heights.filter { current.contains($0.key) }
        }
      if cap.hidden > 0 {
        CardFooterLink(ListWords.showAll, count: items.count) { showsAll = true }
          .padding(.top, Tokens.Space.m)
          .environment(\.footerLinkInline, !endsCard)
          .accessibilityIdentifier(ListCap.linkID)
          .sheet(isPresented: $showsAll) {
            let open = $showsAll
            let all = Array(zip(ids, items).enumerated())
            CardSheet(title: title, subtitle: ListWords.allLatestFirst(items.count),
              close: { open.wrappedValue = false }, rows: {
                VStack(alignment: .leading, spacing: spacing) {
                  ForEach(all, id: \.element.0) { index, pair in row(index, pair.1) }
                }
              })
          }
      }
    }
  }
}

/// How many of a list's rows a card shows (`CappedList`), how many only the sheet holds, and the
/// heights the rows' space keeps between: at least the first `limit` rows, at most every row.
public struct ListCap: Equatable, Sendable {
  public let shown: Int
  public let hidden: Int
  public let leastHeight: Double
  public let fullHeight: Double
  /// Points of rounding a laid-out space may lose against the rows' sum: a space made exactly as
  /// tall as every row still fits every row.
  static let slack = 0.5
  /// Accessibility ids of the "Show all" link and of its sheet, for the UI tests.
  public static let linkID = "capped-list-show-all"
  public static let sheetID = "capped-list-all"
  /// Accessibility id of the close button of every `CardSheet` (this list's, a card's footer
  /// sheet, the iPhone's day and funnel sheets), for the UI tests.
  public static let closeID = "card-sheet.close"
  /// SF Symbol of the sheet's close button.
  static let closeSymbol = "xmark"

  /// `heights`: each row's measured height in the list's order, nil while not measured (counted
  /// as the tallest measured one); `available`: the rows' space, 0 before it is measured.
  public init(heights: [Double?], available: Double, spacing: Double, limit: Int) {
    let least = max(0, min(heights.count, limit))
    let tallest = heights.compactMap { $0 }.max() ?? 0
    let stack = { (rows: ArraySlice<Double?>) in
      rows.map { $0 ?? tallest }.reduce(0, +) + spacing * Double(max(0, rows.count - 1))
    }
    leastHeight = stack(heights.prefix(least))
    fullHeight = stack(heights[...])
    let fit = RowFit.count(heights, available: available > 0 ? available + Self.slack : 0, spacing: spacing,
      fallback: least)
    shown = max(least, fit)
    hidden = heights.count - shown
  }
}
