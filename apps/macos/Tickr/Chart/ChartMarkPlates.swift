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

  /// In priority order: the first keeps its place when two would meet.
  let plates: [Plate]
  let proxy: ChartProxy

  var body: some View {
    GeometryReader { geometry in
      if let plotFrame = proxy.plotFrame {
        let plot = geometry[plotFrame]
        // The part of the plot on screen: the price pane's plot is as wide as the whole day.
        let frame = plot.intersection(CGRect(origin: .zero, size: geometry.size))
        if !frame.isNull {
          let centres = MarkPlateLayout.place(
            items(origin: plot.origin), in: frame, offset: Self.markOffset, gap: Tokens.Space.xxs)
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
