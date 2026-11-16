import SwiftUI

// MARK: - the emergency stop

/// The emergency stop, the strongest command and always the last: full width, solid red (`lossFill`), white
/// title with a second line saying what it does, in a soft red halo.
///
/// With `hold` (the Mac) it acts only after being held for `hold.seconds`: a sweep fills it from
/// its glyph while held, and letting go or moving away before the end cancels it. Its action then
/// opens the same confirmation a click used to; the hold never replaces that question. VoiceOver's
/// activate action, and the accessibility default action, run the action at once (the
/// confirmation still asks). With Reduce Motion the sweep does not move; the hint says "keep
/// holding" instead.
public struct EmergencyButton: View {
  /// A press-and-hold before the action: how long, and the hints shown before and while holding.
  public struct Hold {
    let seconds: Double
    let prompt: Text
    let holding: Text
    let accessibilityHint: Text

    public init(seconds: Double = Tokens.Command.holdSeconds, prompt: Text, holding: Text, accessibilityHint: Text) {
      self.seconds = seconds
      self.prompt = prompt
      self.holding = holding
      self.accessibilityHint = accessibilityHint
    }
  }

  let title: Text
  let detail: Text
  let symbol: String
  let hold: Hold?
  let tag: Text?
  let action: () -> Void

  public init(
    _ title: Text, detail: Text, symbol: String, hold: Hold? = nil, tag: Text? = nil, action: @escaping () -> Void
  ) {
    self.title = title
    self.detail = detail
    self.symbol = symbol
    self.hold = hold
    self.tag = tag
    self.action = action
  }

  public var body: some View {
    // The face draws the title and its second line itself (`EmergencyFace`); the label is what
    // VoiceOver reads.
    Button(action: action) {
      title
    }
    .buttonStyle(EmergencyButtonStyle(content: EmergencyContent(title: title, detail: detail, symbol: symbol,
      tag: tag), hold: hold))
    // What it does; on the Mac also how to start it (the hold, or the accessibility action).
    .accessibilityHint(hold?.accessibilityHint ?? detail)
  }
}

/// What the emergency stop shows.
private struct EmergencyContent {
  let title: Text
  let detail: Text
  let symbol: String
  let tag: Text?
}

/// The emergency stop's press: a plain press, or (with `hold`) a press-and-hold.
private struct EmergencyButtonStyle: PrimitiveButtonStyle {
  let content: EmergencyContent
  let hold: EmergencyButton.Hold?

  func makeBody(configuration: Configuration) -> some View {
    if let hold {
      HoldToAct(configuration: configuration, content: content, hold: hold)
    } else {
      Button(configuration)
        .buttonStyle(EmergencyPress(content: content))
    }
  }
}

/// The plain press (the phone): the face, pressed while the finger is down.
private struct EmergencyPress: ButtonStyle {
  let content: EmergencyContent

  func makeBody(configuration: Configuration) -> some View {
    EmergencyFace(content: content, pressed: configuration.isPressed, progress: 0, hint: nil)
  }
}

/// The press-and-hold (the Mac). The action runs once the press has lasted `hold.seconds`;
/// released, or moved further than `Tokens.Command.holdSlop`, it is cancelled and nothing runs.
private struct HoldToAct: View {
  @Environment(\.isEnabled) private var enabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var holding = false
  @State private var progress: CGFloat = 0
  let configuration: PrimitiveButtonStyleConfiguration
  let content: EmergencyContent
  let hold: EmergencyButton.Hold

  var body: some View {
    EmergencyFace(content: content, pressed: holding, progress: progress,
      hint: holding ? hold.holding : hold.prompt)
      .onLongPressGesture(minimumDuration: hold.seconds, maximumDistance: Tokens.Command.holdSlop) {
        guard enabled else { return }
        configuration.trigger()
      } onPressingChanged: { pressing in
        holding = pressing && enabled
        if holding && !reduceMotion {
          withAnimation(.linear(duration: hold.seconds)) { progress = 1 }
        } else {
          // Let go (or done): the sweep empties at once; with Reduce Motion it never moves.
          var still = Transaction()
          still.disablesAnimations = true
          withTransaction(still) { progress = 0 }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(content.title)
      .accessibilityAddTraits(.isButton)
      // VoiceOver and other assistive input skip the hold: the confirmation still asks.
      .accessibilityAction {
        guard enabled else { return }
        configuration.trigger()
      }
  }
}

/// How the emergency stop looks: `lossFill`, a `loss` halo, white glyph, the title block, the hold hint and
/// the sweep of a hold in progress.
private struct EmergencyFace: View {
  @Environment(\.isEnabled) private var enabled
  /// The glyph's side, growing with Dynamic Type (iOS) so the symbol stays inside it.
  @ScaledMetric(relativeTo: .callout) private var glyphSide = Tokens.Command.emergencyGlyph
  @State private var hovered = false
  let content: EmergencyContent
  let pressed: Bool
  let progress: CGFloat
  let hint: Text?

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Command.radius, style: .continuous)
    let glyphCenter = Tokens.Space.s + glyphSide / 2
    HStack(spacing: Tokens.Space.s + Tokens.Space.xxs) {
      glyph
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        // The title with the hold hint beside it, or the hint under it when both do not fit.
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            title.fixedSize()
            Spacer(minLength: 0)
            hintText
          }
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            title.fixedSize(horizontal: false, vertical: true)
            hintText
          }
        }
        content.detail
          .font(Tokens.Command.detail)
          .foregroundStyle(Palette.onLoss.opacity(Tokens.Command.detailOpacity))
          .fixedSize(horizontal: false, vertical: true)
      }
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      if let tag = content.tag {
        CommandTag(tag, onFill: true)
      }
    }
    .foregroundStyle(Palette.onLoss)
    .padding(.leading, Tokens.Space.s)
    .padding(.trailing, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.xs + Tokens.Space.xxs)
    .frame(maxWidth: .infinity, minHeight: Tokens.Command.emergencyHeight, alignment: .leading)
    .background {
      shape.fill(Palette.lossFill)
        .overlay(shape.fill(Palette.textPrimary.opacity(pressed ? Tokens.Command.pressShade : 0)))
        .overlay {
          // The hold's sweep, a conic fill from the glyph, as the design's ring. It darkens the
          // red (a white sweep would take the white title under 4.5:1).
          HoldSweep(progress: progress, center: glyphCenter)
            .fill(Palette.scrim.opacity(Tokens.Command.sweepOpacity))
            .clipShape(shape)
        }
    }
    .background {
      shape.inset(by: -Tokens.Command.halo)
        .fill(enabled ? Palette.loss.opacity(Tokens.Command.haloOpacity) : .clear)
    }
    .contentShape(shape)
    .opacity(enabled ? 1 : Tokens.Command.disabledOpacity)
    .scaleEffect(pressed && enabled ? Tokens.Motion.pressScale : 1)
    .offset(y: enabled && hovered && !pressed ? -Tokens.Motion.hoverLift : 0)
    .animation(Tokens.Motion.quick, value: pressed)
    .animation(Tokens.Motion.quick, value: hovered)
    .onHover { hovered = $0 }
  }

  private var title: some View {
    content.title.font(Tokens.Command.emergencyTitle)
  }

  @ViewBuilder private var hintText: some View {
    if let hint {
      hint
        .font(Tokens.Typography.label)
        .foregroundStyle(Palette.onLoss.opacity(Tokens.Opacity.overlay))
        // A few words: always whole.
        .fixedSize()
        .contentTransition(.opacity)
    }
  }

  @ViewBuilder private var glyph: some View {
    let image = Image(systemName: content.symbol)
      .font(Tokens.Command.emergencySymbolFont)
      .frame(width: glyphSide, height: glyphSide)
      .accessibilityHidden(true)
    #if os(iOS)
    image.background(Circle().fill(Palette.onLoss.opacity(Tokens.Opacity.flash)))
    #else
    image
    #endif
  }
}

/// A pie from `center` (a point on the vertical middle line, from the leading edge), from twelve
/// o'clock clockwise through `progress` of a full turn, large enough to cover the button.
struct HoldSweep: Shape {
  var progress: CGFloat
  let center: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  /// A quarter turn back from the angle zero (three o'clock): the sweep starts at twelve.
  static let start = Angle.degrees(-90)
  /// Degrees in a full turn.
  static let fullTurn = 360.0

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard progress > 0 else { return path }
    let origin = CGPoint(x: rect.minX + center, y: rect.midY)
    let radius = hypot(rect.width, rect.height)
    path.move(to: origin)
    path.addArc(center: origin, radius: radius, startAngle: Self.start,
      endAngle: Self.start + .degrees(Self.fullTurn * Double(min(progress, 1))), clockwise: false)
    path.closeSubpath()
    return path
  }
}
