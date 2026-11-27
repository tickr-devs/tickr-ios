import SwiftUI

// Where a loading state sits on a screen, and how it gives way to the content (mockup v102,
// docs/design-system.md "Loading"). The owner's rule (2026-11-19, after jerky loaders on the
// Chart): nothing moves when the data arrives. The skeleton takes the size of the content it
// stands for, the swap is instant (no cross-fade, no rise, no slide), the skeleton sits in the
// same place in the screen's layout as the content, and a re-read of content already shown keeps
// it on screen instead of going back to the skeleton.

/// One place on a screen that shows a skeleton until its content is read, then the content.
///
/// The swap is instant: neither the placeholder nor the content fades, rises or slides, and an
/// animation of the screen around the slot (a phase change, a `rise`) never animates the swap.
/// The placeholder must be the content's size: build it from the content's own sizes (row
/// heights, pane heights, the same text lines), or let the content stand for itself with
/// `.skeleton(_:)`.
///
/// Pass the value the content needs, nil while it is not read yet. Keep the last value while a
/// re-read is in flight: a slot that went back to its skeleton on every refresh would blink.
public struct LoadingSlot<Value, Content: View, Placeholder: View>: View {
  let value: Value?
  let content: (Value) -> Content
  let placeholder: Placeholder

  /// - Parameters:
  ///   - value: what the content shows; nil while it is being read.
  ///   - content: the content, built from the value.
  ///   - placeholder: the skeleton (or, where the read can fail or come back empty, whatever
  ///     stands in that place), the content's size.
  public init(
    _ value: Value?, @ViewBuilder content: @escaping (Value) -> Content, @ViewBuilder placeholder: () -> Placeholder
  ) {
    self.value = value
    self.content = content
    self.placeholder = placeholder()
  }

  public var body: some View {
    ZStack(alignment: .topLeading) {
      if let value {
        content(value)
          .transition(.identity)
      } else {
        placeholder
          .transition(.identity)
      }
    }
    .loadsInPlace(value != nil)
  }
}

/// Content that takes a skeleton's place arrives in place (see `View.loadsInPlace(_:)`).
struct LoadsInPlace: ViewModifier {
  /// The screen around already arrives in place (a Mac section opened before): so does this.
  @Environment(\.arrivesInPlace) private var screenInPlace
  let loaded: Bool
  /// The skeleton has been on screen: what replaces it shows at once, without rising. Content
  /// already read when the place appears still rises in with its screen.
  @State private var stoodIn = false

  func body(content: Content) -> some View {
    content
      .environment(\.arrivesInPlace, screenInPlace || stoodIn || !loaded)
      .onAppear { if !loaded { stoodIn = true } }
      .onChange(of: loaded) { _, now in if !now { stoodIn = true } }
      // Whatever animation the screen runs as the data arrives, the swap itself is not animated.
      .animation(nil, value: loaded)
  }
}

/// Stands a view in for itself while it loads: the view is laid out (with the sample values its
/// caller gives it), so it keeps its own size, but it is not drawn; a skeleton block of its
/// width shows in its place (see `View.skeleton(_:_:)`).
struct SkeletonFit: ViewModifier {
  let loading: Bool
  let kind: SkeletonBlock.Kind

  func body(content: Content) -> some View {
    content
      .opacity(loading ? 0 : 1)
      .accessibilityHidden(loading)
      .overlay(alignment: .leading) {
        if loading {
          Skeleton(nil) { SkeletonBlock(kind) }
            .transition(.identity)
        }
      }
      .animation(nil, value: loading)
  }
}

public extension View {
  /// Marks where a screen (or a part of one: a card, a `Form`) swaps a skeleton for its content:
  /// `loaded` is false while the skeleton shows. Once the skeleton has been on screen, every
  /// `rise` of the content shows at once, in place, and the swap is never animated: the content
  /// takes the skeleton's place without a fade, a slide or a jump. `LoadingSlot` does this
  /// itself; use this where the content is not one view (the sections of a `Form`). Put it on
  /// one view (a screen, a card, a `Form`), never on a `Group` of several, which would give each
  /// of them its own memory of the skeleton.
  func loadsInPlace(_ loaded: Bool) -> some View {
    modifier(LoadsInPlace(loaded: loaded))
  }

  /// While `loading`, this view keeps its place and its size but shows as a skeleton block of its
  /// width (a text line by default): a price, a figure or a line of text that is not read yet.
  /// Give the view sample values of the real ones' length ("$00.00"), so its size is the real
  /// one's. The view itself is hidden from VoiceOver meanwhile; label the screen's skeleton.
  func skeleton(_ loading: Bool, _ kind: SkeletonBlock.Kind = .line) -> some View {
    modifier(SkeletonFit(loading: loading, kind: kind))
  }
}

/// Sample values a view is laid out with while its real ones load (`View.skeleton(_:_:)`): of the
/// usual length, so the skeleton takes the real values' size. Never drawn.
public enum SkeletonSample {
  /// A symbol of the usual length.
  public static let symbol = "ABCD"
  /// A price, in dollars.
  public static let price = 100.0
  /// A change, as a fraction.
  public static let change: Decimal = 0.01
  /// A volume, in shares, of the usual length once compacted.
  public static let volume = 1_000_000.0
  /// Figures in a candle's readout: time, open, high, low, close, volume.
  public static let readoutFigures = 6
}
