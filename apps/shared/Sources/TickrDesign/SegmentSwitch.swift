import SwiftUI

/// The apps' one segmented switch, as the boards' shared spec draws it (`.u-seg`): equal segments
/// on a `surface` track with a `separator` hairline, `SegmentSwitchLook.radius` corners and
/// padding; the chosen segment on `surfaceSunken` in `textPrimary` with a `separatorStrong` line
/// under it, the others in `textTertiary`. A segment may lead with a `DesignGlyph` (the chart
/// type: candles or a line). Used wherever one of a few choices switches what a screen shows (the
/// Activity panes, the Chart's range and type, the Lab's replay span, the Watching closely sort,
/// the Mac's theme), so every switch in both apps looks alike.
///
/// `fit` sizes each segment to its title (`.u-seg.fit`, the Mac Chart's controls); otherwise the
/// segments share the width. A title that does not fit its segment wraps onto another line, never
/// cut. On iOS each segment answers taps over `Size.touchTarget`. The chosen segment carries
/// VoiceOver's selected trait; name the group with `.accessibilityLabel` on the switch.
public struct SegmentSwitch<Value: Hashable>: View {
  /// One segment: its value, its title and an optional glyph before the title.
  public struct Option {
    let value: Value
    let title: Text
    let glyph: DesignGlyph?

    public init(_ value: Value, title: Text, glyph: DesignGlyph? = nil) {
      self.value = value
      self.title = title
      self.glyph = glyph
    }
  }

  let options: [Option]
  @Binding var selection: Value
  let fit: Bool
  /// Accessibility identifier of each segment (UI tests find them by it).
  let identifier: String?

  public init(options: [Option], selection: Binding<Value>, fit: Bool = false, identifier: String? = nil) {
    self.options = options
    _selection = selection
    self.fit = fit
    self.identifier = identifier
  }

  public init(
    options: [(value: Value, title: Text)], selection: Binding<Value>, fit: Bool = false, identifier: String? = nil
  ) {
    self.init(options: options.map { Option($0.value, title: $0.title) }, selection: selection, fit: fit,
      identifier: identifier)
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: SegmentSwitchLook.radius, style: .continuous)
    HStack(spacing: Tokens.Space.xs) {
      ForEach(Array(options.enumerated()), id: \.offset) { _, option in
        segment(option)
      }
    }
    .padding(SegmentSwitchLook.padding)
    .background(Palette.surface, in: shape)
    .overlay(shape.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .fixedSize(horizontal: fit, vertical: false)
    .animation(Tokens.Motion.quick, value: selection)
  }

  private func segment(_ option: Option) -> some View {
    let chosen = option.value == selection
    let tile = RoundedRectangle(cornerRadius: SegmentSwitchLook.segmentRadius, style: .continuous)
    return Button {
      selection = option.value
    } label: {
      HStack(spacing: SegmentSwitchLook.glyphGap) {
        if let glyph = option.glyph {
          DesignGlyphView(glyph, side: SegmentSwitchLook.glyph)
        }
        option.title
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: fit, vertical: true)
      }
      .font(Tokens.Typography.segment)
      .foregroundStyle(chosen ? Palette.textPrimary : Palette.textTertiary)
      .padding(.horizontal, Tokens.Space.m)
      .padding(.vertical, Tokens.Space.xs)
      .frame(maxWidth: fit ? nil : .infinity, minHeight: SegmentSwitchLook.minHeight)
      .background {
        if chosen {
          tile.fill(Palette.surfaceSunken)
            .shadow(color: Palette.separatorStrong, radius: 0, x: 0, y: Tokens.Stroke.thin)
        }
      }
      // The tap area reaches over and under the drawn segment, up to a full touch target.
      .padding(.vertical, SegmentSwitchLook.reach)
      .contentShape(Rectangle())
      .padding(.vertical, -SegmentSwitchLook.reach)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(chosen ? [.isSelected] : [])
    .accessibilityIdentifier(identifier ?? "")
  }
}

/// `SegmentSwitch`'s look (a generic type cannot keep static constants of its own): the boards'
/// `.u-seg`.
enum SegmentSwitchLook {
  /// Corner radius of the track, in points.
  static let radius: CGFloat = 12
  /// Corner radius of the chosen segment, in points.
  static let segmentRadius: CGFloat = 9
  /// The track's padding around the segments, in points.
  static let padding: CGFloat = 3
  /// Side of a segment's glyph, in points.
  static let glyph: CGFloat = 12
  /// Gap between a segment's glyph and its title, in points.
  static let glyphGap: CGFloat = 6
  #if os(iOS)
  /// Least height of a segment, in points (`.u-seg`; 28 on the Mac, `.u-seg.mac`).
  static let minHeight: CGFloat = 32
  /// How far a segment's tap area reaches above and below it, so it answers over
  /// `Size.touchTarget`.
  static let reach = (Tokens.Size.touchTarget - minHeight) / 2
  #else
  /// Least height of a segment, in points (`.u-seg.mac`).
  static let minHeight: CGFloat = 28
  /// The Mac clicks the drawn segment only.
  static let reach: CGFloat = 0
  #endif
}
