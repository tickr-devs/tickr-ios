import SwiftUI

/// Content loading (mockup v102, v121): the shape of the real layout in `SkeletonBlock`s that
/// breathe in place, fading from full to `Loading.breathLow` and back once every
/// `Loading.breathSeconds`. Nothing moves across it (owner 2026-11-19: the old sweeping band read
/// as a jerky loader however it was tuned); never a radar and never the system spinner; nothing
/// real is shown until the data is ready.
///
/// Put the blocks (and grid lines, `SkeletonGridLine`) inside, laid out exactly as the content
/// they stand for. VoiceOver reads the skeleton once, by `label` ("Loading symbols").
///
/// Ornament (design-system rule 5): it marks no data, only that a read is in flight, and it is on
/// screen only while one is. The breath is a function of the wall clock (`breath(at:)`), so
/// every skeleton breathes together and one built again (a re-layout, a re-read, another screen)
/// goes on where the breath is: it has no start to jump back to. Under Reduce Motion the
/// skeleton stands still at full opacity.
public struct Skeleton<Content: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  let label: Text?
  let content: Content

  /// - Parameters:
  ///   - label: what is loading, read by VoiceOver; nil where a caption beside it already says
  ///     so, or for a part of a screen whose other skeleton carries the name.
  public init(_ label: LocalizedStringResource?, @ViewBuilder content: () -> Content) {
    self.label = label.map { Text($0) }
    self.content = content()
  }

  /// The skeleton's opacity at `date`: full at the start of each breath, `breathLow` halfway,
  /// eased like a cosine, so it never jumps; the same for every skeleton at the same moment.
  public static func breath(at date: Date) -> Double {
    let seconds = Tokens.Loading.breathSeconds
    let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: seconds) / seconds
    let low = Tokens.Loading.breathLow
    // cos² of half a turn per breath: 1 at its ends, 0 halfway, with no corner anywhere.
    let swing = cos(phase * .pi)
    return low + (1 - low) * swing * swing
  }

  public var body: some View {
    // decorative: the skeleton breathes while a read is in flight, only while it shows (mockup v121, rule 5).
    TimelineView(.animation(minimumInterval: Tokens.Loading.breathFrameSeconds,
      paused: reduceMotion || scenePhase != .active)) { context in
      content
        .opacity(reduceMotion ? 1 : Self.breath(at: context.date))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label ?? Text(verbatim: ""))
    .accessibilityHidden(label == nil)
    .accessibilityAddTraits(.updatesFrequently)
  }
}

/// How the button spinner moves.
public enum SkeletonMotion: Equatable, Sendable {
  /// The spinner turns.
  case sweep
  /// Reduce Motion: nothing turns; the opacity pulses gently.
  case pulse
}

/// One block of a skeleton, in the shape of what it stands for.
public struct SkeletonBlock: View {
  /// What the block stands for, which sets its height and corner radius.
  public enum Kind: Sendable, Hashable {
    /// A line of text (`Loading.lineHeight`).
    case line
    /// A value: a price, a figure (`Loading.valueHeight`).
    case value
    /// A pill: a badge, a chip (`Loading.pillHeight`).
    case pill
    /// A block of its own height (a glyph, a sparkline, a candle), radius `Loading.blockRadius`.
    case block(height: CGFloat)
    /// A block as tall as the view it stands for (a chip, a button), radius `Loading.pillRadius`;
    /// used with `View.skeleton(_:_:)`.
    case fill
  }

  let kind: Kind
  let width: CGFloat?

  /// - Parameter width: the block's width; nil fills the width it is offered.
  public init(_ kind: Kind = .line, width: CGFloat? = nil) {
    self.kind = kind
    self.width = width
  }

  /// The fill of every skeleton block: `separatorStrong` mixed into `surfaceSunken`.
  public static let fill = Palette.surfaceSunken.mix(with: Palette.separatorStrong, by: Tokens.Loading.blockMix)

  public var body: some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
      .fill(Self.fill)
      .frame(width: width, height: height)
      .frame(maxWidth: width == nil ? .infinity : nil, maxHeight: height == nil ? .infinity : nil,
        alignment: .leading)
  }

  /// The block's height; nil fills the height it is offered (`fill`).
  var height: CGFloat? {
    switch kind {
    case .line: Tokens.Loading.lineHeight
    case .value: Tokens.Loading.valueHeight
    case .pill: Tokens.Loading.pillHeight
    case .block(let height): height
    case .fill: nil
    }
  }

  var radius: CGFloat {
    switch kind {
    case .line: Tokens.Loading.lineRadius
    case .value: Tokens.Loading.blockRadius
    case .pill, .fill: Tokens.Loading.pillRadius
    case .block(let height): min(Tokens.Loading.blockRadius, height / 2)
    }
  }
}

/// A grid line of a skeleton (an axis grid, a row divider): `separator` at `Loading.gridOpacity`.
public struct SkeletonGridLine: View {
  public enum Axis: Sendable { case horizontal, vertical }
  let axis: Axis

  public init(_ axis: Axis = .horizontal) {
    self.axis = axis
  }

  /// The colour of every skeleton grid line.
  public static let color = Palette.separator.opacity(Tokens.Loading.gridOpacity)

  public var body: some View {
    Rectangle()
      .fill(Self.color)
      .frame(width: axis == .vertical ? Tokens.Stroke.hairline : nil,
        height: axis == .horizontal ? Tokens.Stroke.hairline : nil)
  }
}
