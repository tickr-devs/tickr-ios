import SwiftUI

/// The apps' one segmented switch, as the iOS Activity screen draws it (Trades / Not taken /
/// Journal): equal segments on a card with a hairline, the chosen one raised on a sunken tile with
/// a hairline of its own. Used wherever one of a few choices switches what a screen shows (the
/// Activity panes, the Chart's range, the Lab's replay span, the Watching closely sort and filter),
/// so every switch in both apps looks alike.
///
/// A title that does not fit its segment wraps onto another line, never cut. Each segment answers
/// taps over the switch's full height (at least `Size.touchTarget` with its padding). The chosen
/// segment carries VoiceOver's selected trait; name the group with `.accessibilityLabel` on the
/// switch.
public struct SegmentSwitch<Value: Hashable>: View {
  let options: [(value: Value, title: Text)]
  @Binding var selection: Value
  /// Accessibility identifier of each segment (UI tests find them by it).
  let identifier: String?

  public init(options: [(value: Value, title: Text)], selection: Binding<Value>, identifier: String? = nil) {
    self.options = options
    _selection = selection
    self.identifier = identifier
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
    HStack(spacing: Tokens.Space.xs) {
      ForEach(Array(options.enumerated()), id: \.offset) { _, option in
        let chosen = option.value == selection
        Button {
          selection = option.value
        } label: {
          option.title
            .font(SegmentSwitchLook.font)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(chosen ? Palette.textPrimary : Palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.iconButton)
            .padding(.horizontal, Tokens.Space.xs)
            .background {
              if chosen {
                let tile = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
                tile.fill(Palette.surfaceSunken)
                  .overlay { tile.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin) }
              }
            }
            // The tap area reaches over the switch's padding, so each segment is a full touch target.
            .padding(.vertical, Tokens.Space.xs)
            .contentShape(Rectangle())
            .padding(.vertical, -Tokens.Space.xs)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
        .accessibilityIdentifier(identifier ?? "")
      }
    }
    .padding(Tokens.Space.xs)
    .background(Palette.surface, in: shape)
    .overlay(shape.strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .animation(Tokens.Motion.quick, value: selection)
  }
}

/// `SegmentSwitch`'s look (a generic type cannot keep static constants of its own).
private enum SegmentSwitchLook {
  /// The segments' titles: footnote semibold, as on the Activity board.
  static let font = Font.footnote.weight(.semibold)
}
