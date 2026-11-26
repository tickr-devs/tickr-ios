import SwiftUI

/// Content loading (mockup v102, loader E "assembly", owner 2026-11-25): the shape of the real
/// layout in `SkeletonBlock`s that stand still, and, on a skeleton that names what loads, a 2 pt
/// `RunningBar` just above it whose `accent` segment crosses once every `Loading.barSeconds`.
/// Never a sweeping shimmer over the blocks (owner 2026-11-19), never a radar and never the
/// system spinner; nothing real is shown until the data is ready.
///
/// Put the blocks (and grid lines, `SkeletonGridLine`) inside, laid out exactly as the content
/// they stand for. VoiceOver reads the skeleton once, by `label` ("Loading symbols").
///
/// The bar sits in the space above the skeleton (a card's padding) as an overlay, so it takes no
/// room and the content that replaces the skeleton lands without a jump. A skeleton with no
/// label (a value standing for itself, a part of a screen whose other skeleton carries the name)
/// has no bar unless asked, so a card shows one bar however many blocks it holds.
public struct Skeleton<Content: View>: View {
  let label: Text?
  let runs: Bool
  let content: Content

  /// - Parameters:
  ///   - label: what is loading, read by VoiceOver; nil where a caption beside it already says
  ///     so, or for a part of a screen whose other skeleton carries the name.
  ///   - runs: whether the running bar shows above it; nil shows it when there is a label. A
  ///     card whose own title names what loads passes true with no label.
  public init(_ label: LocalizedStringResource?, runs: Bool? = nil, @ViewBuilder content: () -> Content) {
    self.label = label.map { Text($0) }
    self.runs = runs ?? (label != nil)
    self.content = content()
  }

  public var body: some View {
    content
      .overlay(alignment: .top) {
        if runs {
          RunningBar()
            .alignmentGuide(.top) { $0[.bottom] + Tokens.Space.s }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(label ?? Text(verbatim: ""))
      .accessibilityHidden(label == nil)
      .accessibilityAddTraits(.updatesFrequently)
  }
}

/// The running bar of a loading card (loader E): a 2 pt `accent` track at 10% whose ends fade
/// out, and an `accent` segment a third of its width that crosses it once every
/// `Loading.barSeconds`, eased in and out. It marks no data, only that a read is in flight.
///
/// The segment's place is a function of the wall clock (`offset(at:)`), so every bar runs
/// together and one built again (a re-layout, a re-read) goes on where the run is. Under Reduce
/// Motion, or while the app is not active, the segment stands still in the middle.
public struct RunningBar: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  public init() {}

  /// Where the segment's leading edge is at `date`, as a share of the track's width: from a
  /// segment's width before the track's start to the track's end, eased (`Loading.barCurve`).
  public static func offset(at date: Date) -> Double {
    let seconds = Tokens.Loading.barSeconds
    let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: seconds) / seconds
    let share = Tokens.Loading.barShare
    return -share + (1 + share) * Tokens.Loading.barCurve.value(at: phase)
  }

  /// The segment's place under Reduce Motion: in the middle of the track.
  public static let restOffset = (1 - Tokens.Loading.barShare) / 2

  public var body: some View {
    let still = reduceMotion || scenePhase != .active
    // decorative: the bar runs while a read is in flight, only while its skeleton shows (loader E).
    TimelineView(.animation(paused: still)) { context in
      Canvas { canvas, size in
        let offset = still ? Self.restOffset : Self.offset(at: context.date)
        let segment = CGRect(x: size.width * offset, y: 0, width: size.width * Tokens.Loading.barShare,
          height: size.height)
        canvas.fill(Path(CGRect(origin: .zero, size: size)),
          with: .color(Palette.accent.opacity(Tokens.Loading.barTrackOpacity)))
        canvas.fill(Path(roundedRect: segment, cornerRadius: size.height / 2), with: .color(Palette.accent))
      }
    }
    .frame(height: Tokens.Loading.progressHeight)
    .mask {
      LinearGradient(stops: [
        .init(color: .clear, location: 0),
        .init(color: .black, location: Tokens.Loading.barFade),
        .init(color: .black, location: 1 - Tokens.Loading.barFade),
        .init(color: .clear, location: 1),
      ], startPoint: .leading, endPoint: .trailing)
    }
    .accessibilityHidden(true)
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
