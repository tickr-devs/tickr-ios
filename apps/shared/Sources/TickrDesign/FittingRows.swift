import SwiftUI

/// The rows of a card sized to its grid cell (the Mac Overview board), then the card's footer link
/// ("Show all", `CardFooterLink`) on its bottom edge: as many rows, top first, as fit the space the
/// cell leaves under the header and over the footer. The card is filled with rows, never an empty
/// band, and the footer never floats in its middle. `footer` gets how many rows are shown (for
/// "closest 3 of 7"). The rows' space takes the cell's height and never depends on how many rows it
/// holds (at least the tallest row), so the count cannot feed back into the cell.
public struct FittingRows<Item, ID: Hashable, Row: View, Footer: View>: View {
  let items: [Item]
  let id: KeyPath<Item, ID>
  let spacing: CGFloat
  let fallback: Int
  let row: (Int, Item) -> Row
  let footer: (Int) -> Footer
  /// Each shown row's height as last laid out, by id.
  @State private var heights: [ID: CGFloat] = [:]
  /// Height of the rows' space: the cell less the header and the footer.
  @State private var available: CGFloat = 0

  /// `fallback` rows show until the space and a row are measured (the first layout pass).
  public init(
    _ items: [Item], id: KeyPath<Item, ID>, spacing: CGFloat, fallback: Int,
    @ViewBuilder row: @escaping (Int, Item) -> Row, @ViewBuilder footer: @escaping (Int) -> Footer
  ) {
    self.items = items
    self.id = id
    self.spacing = spacing
    self.fallback = fallback
    self.row = row
    self.footer = footer
  }

  public var body: some View {
    let ids = items.map { $0[keyPath: id] }
    let count = RowFit.count(ids.map { heights[$0].map(Double.init) }, available: Double(available),
      spacing: Double(spacing), fallback: fallback)
    Color.clear
      .frame(maxWidth: .infinity, minHeight: heights.values.max() ?? 0, maxHeight: .infinity)
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { available = $0 }
      .overlay(alignment: .top) {
        VStack(spacing: spacing) {
          ForEach(Array(zip(ids.prefix(count), items.prefix(count)).enumerated()), id: \.element.0) { index, pair in
            row(index, pair.1)
              .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[pair.0] = $0 }
          }
        }
      }
      .clipped()
      .onChange(of: ids) { _, current in
        heights = heights.filter { current.contains($0.key) }
      }
    footer(count)
  }
}

/// How many rows fit a card's height (`FittingRows`).
public enum RowFit {
  /// How many rows, stacked `spacing` apart, fit in `available` points: each row at its measured
  /// height (`heights`, in the card's order), a row not measured yet at the tallest measured one.
  /// At least one row when there is any; `fallback` until the space or every row is unmeasured.
  public static func count(_ heights: [Double?], available: Double, spacing: Double, fallback: Int) -> Int {
    guard !heights.isEmpty else { return 0 }
    guard available > 0, let tallest = heights.compactMap({ $0 }).max() else {
      return min(fallback, heights.count)
    }
    var used = 0.0
    var count = 0
    for height in heights {
      let next = used + (count == 0 ? 0 : spacing) + (height ?? tallest)
      if next > available { break }
      used = next
      count += 1
    }
    return max(count, 1)
  }
}
