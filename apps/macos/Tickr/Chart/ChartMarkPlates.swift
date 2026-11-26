import Charts
import SwiftUI
import TickrDesign

/// The price pane's trade and decision plates, drawn over the chart where `MarkPlateLayout` puts
/// them (none covers another), instead of each mark's own annotation, which Swift Charts places
/// without regard for its neighbours.
struct ChartMarkPlates: View {
  struct Plate {
    let time: Date
    let price: Double
    let label: LocalizedStringResource
    let color: Color
    let textColor: Color
    let side: MarkPlateLayout.Side
  }

  /// A candle's reach on the chart, wick to wick, across its body.
  struct Column {
    let start: Date
    let end: Date
    let low: Double
    let high: Double
  }

  /// In priority order: the first keeps its place when two would meet.
  let plates: [Plate]
  /// What the plates keep clear of where they can: the candles drawn, and every mark's glyph.
  let columns: [Column]
  let glyphs: [(time: Date, price: Double)]
  let proxy: ChartProxy

  var body: some View {
    GeometryReader { geometry in
      if let plotFrame = proxy.plotFrame {
        let plot = geometry[plotFrame]
        // The part of the plot on screen: the price pane's plot is as wide as the whole day.
        let frame = plot.intersection(CGRect(origin: .zero, size: geometry.size))
        if !frame.isNull {
          let centres = MarkPlateLayout.place(
            items(origin: plot.origin),
            avoiding: .init(candles: candleRects(origin: plot.origin), glyphs: glyphRects(origin: plot.origin)),
            in: frame, offset: Self.markOffset, gap: Tokens.Space.xxs)
          ForEach(plates.indices, id: \.self) { index in
            if let centre = centres[index] {
              let plate = plates[index]
              ChartMarkPlate(plate.label, color: plate.color, textColor: plate.textColor)
                .position(centre)
            }
          }
        }
      }
    }
    .allowsHitTesting(false)
  }

  private func items(origin: CGPoint) -> [MarkPlateLayout.Item] {
    plates.indices.compactMap { index in
      let plate = plates[index]
      guard let point = proxy.position(for: (x: plate.time, y: plate.price)) else { return nil }
      return MarkPlateLayout.Item(
        id: index, anchor: CGPoint(x: origin.x + point.x, y: origin.y + point.y),
        size: Self.size(plate.label), side: plate.side)
    }
  }

  private func candleRects(origin: CGPoint) -> [CGRect] {
    columns.compactMap { column -> CGRect? in
      guard let left = proxy.position(forX: column.start), let right = proxy.position(forX: column.end),
        let top = proxy.position(forY: column.high), let bottom = proxy.position(forY: column.low)
      else { return nil }
      return CGRect(x: origin.x + left, y: origin.y + top, width: right - left, height: bottom - top)
    }
  }

  private func glyphRects(origin: CGPoint) -> [CGRect] {
    let side = TextMeasure.lineHeight(Self.font)
    return glyphs.compactMap { glyph -> CGRect? in
      guard let point = proxy.position(for: (x: glyph.time, y: glyph.price)) else { return nil }
      return CGRect(x: origin.x + point.x - side / 2, y: origin.y + point.y - side / 2, width: side, height: side)
    }
  }

  /// The plate's font, as `ChartMarkPlate` draws it.
  private static var font: PlatformFont {
    PlatformFont.monospacedSystemFont(
      ofSize: TextMeasure.pointSize(mac: Tokens.Typography.annotationSize, ios: .caption2), weight: .bold)
  }

  /// From a mark's centre to its plate: half the mark's glyph (drawn at the annotation size) and
  /// the space Swift Charts left between a mark and its annotation.
  private static var markOffset: CGFloat { TextMeasure.lineHeight(font) / 2 + Tokens.Space.xxs }

  /// A `ChartMarkPlate`'s size: its upper-case text in the plate's font, and its padding.
  private static func size(_ label: LocalizedStringResource) -> CGSize {
    let text = String(localized: label).uppercased()
    return CGSize(
      width: TextMeasure.width(text, font: font) + Tokens.Space.xs + Tokens.Space.xs,
      height: TextMeasure.lineHeight(font) + Tokens.Space.xxs + Tokens.Space.xxs)
  }
}
