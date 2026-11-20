import Foundation
import SwiftUI
import TickrKit

/// The shapes a column of figures takes (owner, 2026-11-20: the chart's readout jumped from one
/// line to two and back while scrubbing the bars, as volume and change grew a digit): each text
/// with its digits written as one digit, without repeats. In a font with equal-width digits
/// (`monospacedDigit`, a monospaced design) two texts of one shape are equally wide, so a slot as
/// wide as the widest shape holds every figure of the column.
public enum FigureShapes {
  /// The digit every digit stands as in a shape.
  static let digit: Character = "0"

  /// The shapes of `texts`, in their first order.
  public static func shapes(_ texts: some Sequence<String>) -> [String] {
    var seen = Set<String>()
    var shapes: [String] = []
    for text in texts {
      let shape = String(text.map { $0.isASCII && $0.isNumber ? digit : $0 })
      if seen.insert(shape).inserted { shapes.append(shape) }
    }
    return shapes
  }

  /// The shapes `format` gives a column of `values`, without formatting every value (a 5D chart
  /// of minute bars holds thousands): figures of one sign and one power of ten have one shape,
  /// except where rounding or a unit step (999.96K is "1M") reaches the next, so the smallest
  /// and the largest of each such bucket stand for it. Values that are not finite are left out.
  public static func of(_ values: some Sequence<Double>, _ format: (Double) -> String) -> [String] {
    of(values, by: { $0 }, format)
  }

  /// The same for items whose figure is `value` of each; `part` splits the buckets further where
  /// the item itself changes the format (a price change has four decimals below one dollar).
  public static func of<Item>(
    _ items: some Sequence<Item>, by value: (Item) -> Double, part: (Item) -> Bool = { _ in false },
    _ format: (Item) -> String
  ) -> [String] {
    var buckets: [Bucket: Ends<Item>] = [:]
    for item in items {
      let figure = value(item)
      guard figure.isFinite else { continue }
      let key = Bucket(figure, part: part(item))
      if var ends = buckets[key] {
        ends.take(item, figure)
        buckets[key] = ends
      } else {
        buckets[key] = Ends(item, figure)
      }
    }
    let ends = buckets.sorted { $0.key < $1.key }.flatMap { [$0.value.low.item, $0.value.high.item] }
    return shapes(ends.map(format))
  }

  /// The longest of `shapes`: in a monospaced font (both apps' chart figures) the widest.
  public static func longest(_ shapes: [String]) -> String {
    shapes.max { $0.count < $1.count } ?? ""
  }

  /// The items with the smallest and the largest figure of a bucket.
  private struct Ends<Item> {
    var low: (item: Item, figure: Double)
    var high: (item: Item, figure: Double)

    init(_ item: Item, _ figure: Double) {
      low = (item, figure)
      high = (item, figure)
    }

    mutating func take(_ item: Item, _ figure: Double) {
      if figure < low.figure { low = (item, figure) }
      if figure > high.figure { high = (item, figure) }
    }
  }

  /// A value's sign and power of ten.
  private struct Bucket: Hashable, Comparable {
    let sign: Int
    let decade: Int
    let part: Bool

    init(_ value: Double, part: Bool) {
      sign = value > 0 ? 1 : (value < 0 ? -1 : 0)
      decade = value == 0 ? 0 : Int(log10(abs(value)).rounded(.down))
      self.part = part
    }

    static func < (lhs: Bucket, rhs: Bucket) -> Bool {
      (lhs.sign, lhs.decade, lhs.part ? 1 : 0) < (rhs.sign, rhs.decade, rhs.part ? 1 : 0)
    }
  }
}

/// The shapes of a chart readout's columns over all of a chart's candles (both apps): its open,
/// high, low and close share one slot width, its volume and its change from the candle before
/// each their own. It formats every volume: build it once per series (`ChartPlot`, the iPhone's
/// `ChartModel`), never in a view's body.
public struct ReadoutShapes: Sendable {
  public let price: [String]
  public let volume: [String]
  /// The change in percent ("+0.08%").
  public let change: [String]
  /// The change in price ("+0.21"), at the tick of the price it changed to.
  public let priceChange: [String]

  public init(_ candles: [Candle]) {
    price = FigureShapes.of(candles.lazy.flatMap { [$0.low, $0.high, $0.open, $0.close] }, Money.price)
    // Every volume: a compact volume drops a ".0" ("100K", "123.4K", "980K"), so the ends of a
    // power of ten do not stand for the figures between them. Built once per series.
    volume = FigureShapes.shapes(candles.lazy.map { Volume.compact($0.volume) })
    let changes = candles.indices.lazy.compactMap { candles.change(at: $0) }
    change = FigureShapes.of(changes, by: \.fraction) { Percent.signed(fraction: $0.fraction) }
    let subPenny = { (change: CandleChange) in abs(Money.decimal(change.price)) < Money.subPennyBelow }
    let written = { (change: CandleChange) in Money.priceChange(change.amount, at: change.price) }
    priceChange = FigureShapes.of(changes, by: \.amount, part: subPenny, written)
  }
}

/// A figure whose width never changes while its value does: as wide as the widest of `shapes`
/// (`FigureShapes`), the value drawn over that room. Text is never cut: a value wider than every
/// shape widens the slot.
public struct SteadyFigure: View {
  let text: String
  let shapes: [String]
  let alignment: Alignment

  public init(_ text: String, shapes: [String], alignment: Alignment = .leading) {
    self.text = text
    self.shapes = shapes
    self.alignment = alignment
  }

  public var body: some View {
    ZStack(alignment: alignment) {
      ForEach(shapes, id: \.self) { shape in
        Text(verbatim: shape).hidden().accessibilityHidden(true)
      }
      Text(verbatim: text)
    }
    .fixedSize()
  }
}

/// A row that always stays on one line at one height (the chart's readout, both apps): `content`
/// in `font` with `spacing` between its items where that fits across, else with `tightSpacing`,
/// else in `compactFont`. The row is as tall as one line of `font` whichever is drawn, so
/// switching between them moves nothing below it. With `SteadyFigure` values the choice holds for
/// the whole chart, so scrubbing never switches it.
public struct OneLineFit<Content: View>: View {
  let font: Font
  let compactFont: Font
  let spacing: CGFloat
  let tightSpacing: CGFloat
  let alignment: Alignment
  let content: (CGFloat) -> Content

  /// A one-line sample with an ascender and a descender: the row's height.
  static var lineSample: String { TextMeasure.lineSample }

  public init(
    font: Font, compactFont: Font, spacing: CGFloat, tightSpacing: CGFloat, alignment: Alignment = .leading,
    @ViewBuilder content: @escaping (CGFloat) -> Content
  ) {
    self.font = font
    self.compactFont = compactFont
    self.spacing = spacing
    self.tightSpacing = tightSpacing
    self.alignment = alignment
    self.content = content
  }

  public var body: some View {
    ZStack(alignment: alignment) {
      Text(verbatim: Self.lineSample)
        .font(font)
        .hidden()
        .accessibilityHidden(true)
      ViewThatFits(in: .horizontal) {
        content(spacing).font(font).fixedSize()
        content(tightSpacing).font(font).fixedSize()
        content(tightSpacing).font(compactFont).fixedSize()
      }
    }
    .frame(minWidth: 0, maxWidth: .infinity, alignment: alignment)
  }
}
