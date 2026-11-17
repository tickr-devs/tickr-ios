import Foundation

/// The price axis's own labels beside the level tags on it (the last price, an entry, a stop,
/// the high and low on screen): a tag says where its price is, so an axis label it would cover
/// gives way and is hidden ("11.80" never under "L 11.78"). One rule for the Mac and the phone.
public enum AxisLabels {
  /// Whether an axis label at `value` stays: no tag shown at `tags` lies closer than
  /// `clearance`, all in the axis's units. Closer than that the two would overlap.
  public static func shows(_ value: Double, tags: [Double], clearance: Double) -> Bool {
    !tags.contains { abs($0 - value) < clearance }
  }

  /// How close, in the axis's units, a label's centre may come to a tag's before they overlap:
  /// half a label's height and half a tag's (`labelHeight`, `tagHeight`, in points), on an axis
  /// `height` points tall showing `span` units. An axis not laid out yet hides nothing.
  public static func clearance(labelHeight: Double, tagHeight: Double, span: Double, height: Double) -> Double {
    guard height > 0, span > 0 else { return 0 }
    return (labelHeight + tagHeight) / 2 * span / height
  }

  /// A tag on the axis, at `y` points from the axis's top: a coloured plate (the last price, an
  /// entry, a stop) or plain words (the high and low on screen).
  public struct Tag: Equatable, Sendable {
    public let y: Double
    public let plain: Bool

    public init(y: Double, plain: Bool) {
      self.y = y
      self.plain = plain
    }
  }

  /// Where each tag is drawn, in the same order, `nil` for one left out: the plates top to
  /// bottom, each at least `spacing` points under the one above (one that would cover another
  /// moves down); a plain tag within `spacing` of a plate is left out, the plate already saying
  /// where the price is.
  public static func placed(_ tags: [Tag], spacing: Double) -> [Double?] {
    var shown = [Double?](repeating: nil, count: tags.count)
    var last: Double?
    for index in tags.indices.filter({ !tags[$0].plain }).sorted(by: { tags[$0].y < tags[$1].y }) {
      let y = last.map { max(tags[index].y, $0 + spacing) } ?? tags[index].y
      shown[index] = y
      last = y
    }
    let plates = shown.compactMap { $0 }
    for index in tags.indices where tags[index].plain && !plates.contains(where: { abs($0 - tags[index].y) < spacing }) {
      shown[index] = tags[index].y
    }
    return shown
  }
}
