import SwiftUI

/// The design's on/off switch (the boards' `.sw`): a capsule track with a round knob that slides
/// to the right when on. On is the track in `tint` (teal for a preference, amber for the demo
/// day), off is `separatorStrong`; the knob is the card colour. Drawn by SwiftUI, so it keeps its
/// colours in a window that is not key (AppKit's switch turns grey there, which read as off).
/// The label is VoiceOver's name; put the visible title beside the switch.
public struct DesignSwitchStyle: ToggleStyle {
  let tint: Color

  public init(tint: Color) {
    self.tint = tint
  }

  public func makeBody(configuration: Configuration) -> some View {
    DesignSwitchFace(isOn: configuration.isOn, tint: tint)
      .onTapGesture { configuration.isOn.toggle() }
      #if os(iOS)
      // A light tick as the knob lands, as the system switch gives.
      .sensoryFeedback(.selection, trigger: configuration.isOn)
      #endif
      // VoiceOver and keyboard access get the system switch with its label: on, off, toggle.
      .accessibilityRepresentation {
        Toggle(isOn: configuration.$isOn) { configuration.label }
      }
  }
}

/// The track and knob of a `DesignSwitchStyle`.
private struct DesignSwitchFace: View {
  @Environment(\.isEnabled) private var enabled
  let isOn: Bool
  let tint: Color

  var body: some View {
    Capsule()
      .fill(isOn ? tint : Palette.separatorStrong)
      .frame(width: Tokens.Switch.width, height: Tokens.Switch.height)
      .overlay(alignment: isOn ? .trailing : .leading) {
        Circle()
          .fill(Palette.surface)
          .frame(width: Tokens.Switch.knob, height: Tokens.Switch.knob)
          .padding(Tokens.Switch.inset)
      }
      .contentShape(Capsule())
      .opacity(enabled ? 1 : Tokens.Opacity.faint)
      .animation(Tokens.Motion.quick, value: isOn)
  }
}

public extension ToggleStyle where Self == DesignSwitchStyle {
  /// `.toggleStyle(.designSwitch(tint: Palette.accent))`.
  static func designSwitch(tint: Color) -> DesignSwitchStyle { DesignSwitchStyle(tint: tint) }
}
