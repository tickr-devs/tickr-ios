import SwiftUI

// MARK: - hints

/// The apps' own tooltip: a short explanation in a small styled bubble. On the Mac it appears
/// above the view after the pointer rests on it; on the phone a long press shows it in a context
/// menu, which never fires the button it explains.
public struct Hint: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false
  @State private var waiting: Task<Void, Never>?
  let text: Text

  public init(_ text: Text) { self.text = text }

  public func body(content: Content) -> some View {
    #if os(macOS)
    content
      .onHover { inside in
        waiting?.cancel()
        if inside {
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
      .overlay(alignment: .top) {
        if shown {
          HintBubble(text: text)
            .alignmentGuide(.top) { $0[.bottom] + Tokens.Space.xs }
            .transition(reduceMotion ? .opacity
              : .opacity.combined(with: .scale(scale: Tokens.Motion.pressScale, anchor: .bottom)))
            .allowsHitTesting(false)
        }
      }
      .zIndex(shown ? 1 : 0)
      .animation(Tokens.Motion.quick, value: shown)
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

/// The bubble of a `Hint`: caption text on a raised surface with a hairline border.
struct HintBubble: View {
  let text: Text

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
    text
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textSecondary)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: Tokens.Size.hintMaxWidth, alignment: .leading)
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
}
