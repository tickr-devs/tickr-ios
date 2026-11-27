import SwiftUI

// MARK: - hints

/// The apps' own tooltip: a short explanation in a small styled bubble. On the Mac it appears
/// near the view after the pointer rests on it; on the phone a long press shows it in a context
/// menu, which never fires the button it explains.
///
/// On the Mac the bubble is drawn by the window's `hintHost()`, not next to the view: a bubble
/// in the view's own overlay is proposed the view's width (an icon's few points, so its text
/// wrapped letter by letter) and is covered or clipped by whatever its container draws after it.
public struct Hint: ViewModifier {
  #if os(macOS)
  /// A hint showed a moment ago: the next one comes at once, as the system's tooltips do.
  @Environment(\.hintWarm) private var warm
  @State private var shown = false
  @State private var waiting: Task<Void, Never>?
  #endif
  let text: Text

  public init(_ text: Text) { self.text = text }

  public func body(content: Content) -> some View {
    #if os(macOS)
    content
      .onHover { inside in
        waiting?.cancel()
        if inside, warm {
          shown = true
        } else if inside {
          waiting = Task {
            try? await Task.sleep(for: .seconds(Tokens.Motion.hintDelay))
            if !Task.isCancelled { shown = true }
          }
        } else {
          shown = false
        }
      }
      .onDisappear {
        waiting?.cancel()
        shown = false
      }
      .anchorPreference(key: HintRequestKey.self, value: .bounds) { anchor in
        shown ? HintRequest(text: text, target: anchor) : nil
      }
    #else
    // A context menu, not a long-press gesture: the system cancels the tap of a button it opens
    // on, so reading what a button does (flatten, stop) never presses it.
    content
      .contextMenu {
        text
      }
    #endif
  }
}

/// The hint that is showing and the bounds of the view it explains.
struct HintRequest {
  let text: Text
  let target: Anchor<CGRect>
}

/// Carries the showing hint up to the window's `hintHost()`.
struct HintRequestKey: PreferenceKey {
  static let defaultValue: HintRequest? = nil

  static func reduce(value: inout HintRequest?, nextValue: () -> HintRequest?) {
    value = nextValue() ?? value
  }
}

/// Draws the showing hint over the whole window: above the view it explains, or below it when
/// there is no room above, and moved sideways to stay inside the window. While a hint shows, and
/// for `Motion.hintWarmSeconds` after it goes, the next hint skips its delay and its entrance:
/// moving along a row of icons reads each at once, as with the system's tooltips.
struct HintHost: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showing = false
  @State private var warm = false

  func body(content: Content) -> some View {
    content
      .environment(\.hintWarm, warm)
      .overlayPreferenceValue(HintRequestKey.self) { request in
        GeometryReader { proxy in
          let target = request.map { proxy[$0.target] }
          HintPlacement(target: target) {
            if let request {
              HintBubble(text: request.text)
                // It grows from the side of the view it explains (above it, or below it near the
                // window's top), and leaves at once: fading out, it would have no view to stand by.
                .transition(.asymmetric(insertion: reduceMotion || warm ? .opacity
                  : .opacity.combined(with: .scale(scale: Tokens.Motion.pressScale,
                    anchor: HintPlacement.above(target) ? .bottom : .top)),
                  removal: .identity))
            }
          }
          .animation(warm ? nil : Tokens.Motion.quick, value: request != nil)
          .onChange(of: request != nil) { _, now in showing = now }
        }
        .allowsHitTesting(false)
      }
      .task(id: showing) {
        if showing {
          warm = true
        } else if warm {
          try? await Task.sleep(for: .seconds(Tokens.Motion.hintWarmSeconds))
          if !Task.isCancelled { warm = false }
        }
      }
  }
}

extension EnvironmentValues {
  /// A hint showed a moment ago under this `hintHost()` (`Hint` then shows at once).
  @Entry var hintWarm = false
}

/// Places a hint bubble next to `target` inside the space it is given.
struct HintPlacement: Layout {
  /// The bounds of the explained view, in the host's space.
  let target: CGRect?
  /// Where along its width the bubble lines up with the middle of the explained view.
  static let anchorFraction: CGFloat = 0.5

  /// Whether a bubble for `target` goes above it: there is room for a two-line bubble
  /// (`Size.hintRoomAbove`) between it and the top of the window.
  static func above(_ target: CGRect?) -> Bool {
    guard let target else { return true }
    return target.minY >= Tokens.Size.hintRoomAbove
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    proposal.replacingUnspecifiedDimensions()
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let target, let bubble = subviews.first else { return }
    let margin = Tokens.Space.xs
    let width = min(Tokens.Size.hintMaxWidth, max(bounds.width - margin - margin, 0))
    let size = bubble.sizeThatFits(ProposedViewSize(width: width, height: nil))
    let centred = bounds.minX + target.midX - size.width * Self.anchorFraction
    let x = min(max(centred, bounds.minX + margin), bounds.maxX - margin - size.width)
    let above = bounds.minY + target.minY - margin - size.height
    let y = above >= bounds.minY + margin ? above : bounds.minY + target.maxY + margin
    bubble.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
  }
}

/// The bubble of a `Hint`: caption text on a raised surface with a hairline border.
struct HintBubble: View {
  let text: Text

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    text
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textSecondary)
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, Tokens.Space.m)
      .padding(.vertical, Tokens.Space.s)
      .background(Palette.surface, in: shape)
      .overlay(shape.strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
      .shadow(color: Palette.shadow.opacity(Tokens.Opacity.faint), radius: Tokens.Size.shadowRadius,
        y: Tokens.Space.xxs)
  }
}

public extension View {
  /// Explains this view in the apps' tooltip (hover on the Mac, long press on the phone).
  func hint(_ text: Text) -> some View { modifier(Hint(text)) }

  func hint(_ text: LocalizedStringResource) -> some View { modifier(Hint(Text(text))) }

  /// A hint that is already localized or is data.
  func hint(verbatim text: String) -> some View { modifier(Hint(Text(verbatim: text))) }

  /// Draws the hints of the views inside it. Put it on the root of every Mac window and panel:
  /// a hint shows only under a host.
  func hintHost() -> some View { modifier(HintHost()) }
}
