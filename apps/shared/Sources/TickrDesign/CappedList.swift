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
  let row: (Int, Item) -> Row
  @State private var showsAll = false
  /// Each shown row's height as last laid out, by id.
  @State private var heights: [ID: CGFloat] = [:]
  /// Height of the rows' space: what the card leaves above the link.
  @State private var available: CGFloat = 0

  /// `title`: the sheet's heading (the card's or the section's title). `spacing`: between rows.
  /// `endsCard`: false for a list with another section under it (the broker's positions above
  /// its orders): the link then stops at the section's end instead of the card's bottom edge.
  public init(
    _ items: [Item], id: KeyPath<Item, ID>, title: LocalizedStringResource, limit: Int = Tokens.Lists.cappedRows,
    spacing: CGFloat = Tokens.Space.s, endsCard: Bool = true, @ViewBuilder row: @escaping (Int, Item) -> Row
  ) {
    self.items = items
    self.id = id
    self.title = title
    self.limit = limit
    self.spacing = spacing
    self.endsCard = endsCard
    self.row = row
  }

  public var body: some View {
    let ids = items.map { $0[keyPath: id] }
    let measured = ids.map { heights[$0].map(Double.init) }
    let cap = ListCap(heights: measured, available: Double(available), spacing: Double(spacing), limit: limit)
    let shown = Array(zip(ids.prefix(cap.shown), items.prefix(cap.shown)).enumerated())
    VStack(alignment: .leading, spacing: 0) {
      Color.clear
        // Never taller than every row: a window with room to spare leaves no gap under a short list.
        .frame(maxWidth: .infinity, minHeight: CGFloat(cap.leastHeight), maxHeight: CGFloat(cap.fullHeight))
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
            AllRowsSheet(title: title, count: items.count, close: { open.wrappedValue = false }, rows: {
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

/// Every row of a capped list: the card's title, how many rows, the close button, then the rows,
/// scrolling when they are many. On the iPhone a sheet as tall as the rows (full height when they
/// are more than a screen), with its own navigation for rows that open a page; a sheet of
/// `Size.allRowsWidth` on the Mac; Esc closes it.
struct AllRowsSheet<Rows: View>: View {
  let title: LocalizedStringResource
  let count: Int
  let close: @MainActor @Sendable () -> Void
  let rows: Rows

  init(
    title: LocalizedStringResource, count: Int, close: @escaping @MainActor @Sendable () -> Void,
    @ViewBuilder rows: () -> Rows
  ) {
    self.title = title
    self.count = count
    self.close = close
    self.rows = rows()
  }

  var body: some View {
    #if os(iOS)
    NavigationStack { content.toolbar(.hidden, for: .navigationBar) }
      .sheetFitsContent()
      .presentationBackground(Palette.surface)
    #else
    content
      .frame(minWidth: Tokens.Size.allRowsWidth, minHeight: Tokens.Size.allRowsHeight)
      .presentationBackground(Palette.surface)
    #endif
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: Tokens.Space.s) { rows }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, Tokens.Space.xl)
      }
      .scrollBounceBehavior(.basedOnSize)
      // No scroll bar (#676): the edge fades and the down chevron say there is more.
      .scrollEdgeHints()
    }
    .padding([.horizontal, .top], Tokens.Space.l)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(ListCap.sheetID)
  }

  /// The card's title and how many rows, then a round X.
  private var header: some View {
    HStack(alignment: .top, spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(title)
          .font(Tokens.Typography.heading)
          .foregroundStyle(Palette.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(ListWords.allLatestFirst(count))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      Button(action: close) {
        Image(systemName: ListCap.closeSymbol)
      }
      .buttonStyle(.icon(compact: true))
      .keyboardShortcut(.cancelAction)
      .help(Text(ListWords.closeHelp))
      .accessibilityLabel(Text(ListWords.close))
    }
  }
}
