import AppKit
import QuartzCore
import SwiftUI
import TickrDesign

/// A row of chips that scrolls slowly to the left in a loop, faded at both ends. Under the pointer
/// it stands still, the chip under the pointer is outlined and a click opens that chip. Still when
/// `moving` is false and with Reduce Motion: then it is an ordinary horizontal scroll view of
/// buttons.
///
/// Why it is built this way (Debug, fixtures, 2026-11-16):
/// - Moving the row from SwiftUI (a `TimelineView` shifting an `offset`) made AppKit lay out the
///   whole window on every frame: the root hosting view, the window's minimum size, its drag
///   margins and cursor rects. That was 49% CPU against 14% for main.
/// - So Core Animation moves the row (`ChipsMarqueeView`), in the render server, and SwiftUI
///   lays out nothing per frame.
/// - Pointer events do not reach SwiftUI views inside a hosting view nested in the screen
///   (no hover, no tracking), so the moving row takes no events at all. The strip itself, which
///   never moves, takes the hover and the click in the screen's own hierarchy. Paused, it knows
///   where each chip is drawn, so it outlines and opens the chip that is under the pointer.
struct ChipsMarquee<Item: Hashable, Chip: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let items: [Item]
  let moving: Bool
  /// Accessibility hint of a chip's button.
  let hint: (Item) -> LocalizedStringResource
  /// Hover help of a chip.
  let help: (Item) -> Text
  /// Whether a chip opens something; one that does not is neither outlined nor clicked.
  let opens: (Item) -> Bool
  /// Opens a chip.
  let open: (Item) -> Void
  let chip: (Item) -> Chip

  /// Width of each chip, in points, measured when the chips change (never per frame).
  @State private var widths: [Item: CGFloat] = [:]
  /// How far the row is drawn shifted to the left while the pointer holds it; nil while it moves.
  @State private var held: CGFloat?
  /// The pointer's place along the strip, in points from its leading edge.
  @State private var pointer: CGFloat = 0
  @State private var handle = ChipsMarqueeHandle()

  var body: some View {
    Group {
      if moving && !reduceMotion {
        marquee
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: Self.spacing) {
            ForEach(items, id: \.self) { item in
              if opens(item) {
                LinkTile(hint(item)) { open(item) } label: { chip(item) }
                  .help(help(item))
              } else {
                chip(item).help(help(item))
              }
            }
          }
        }
      }
    }
    .mask(LinearGradient(
      stops: [.init(color: .clear, location: 0), .init(color: .black, location: Self.fadeEdge),
        .init(color: .black, location: 1 - Self.fadeEdge), .init(color: .clear, location: 1)],
      startPoint: .leading, endPoint: .trailing))
  }

  private var marquee: some View {
    ChipsMarqueeHost(row: { AnyView(row(copy: $0)) }, speed: Tokens.Motion.tickerSpeed, handle: handle)
      // The chips' widths, from a hidden copy laid out with the screen: they change with the
      // chips only.
      .background {
        HStack(spacing: Self.spacing) {
          ForEach(items, id: \.self) { item in
            chip(item).fixedSize()
              .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths[item] = $0 }
          }
        }
        .fixedSize()
        .hidden()
      }
      .contentShape(Rectangle())
      .onContinuousHover(coordinateSpace: .local) { phase in
        switch phase {
        case .active(let location):
          pointer = location.x
          if held == nil { held = handle.hold() }
        case .ended:
          held = nil
          handle.release()
        }
      }
      .onTapGesture(coordinateSpace: .local) { location in
        if let item = spot(at: location.x)?.item, opens(item) { open(item) }
      }
      .help(spot(at: pointer).map { help($0.item) } ?? Text(verbatim: String()))
      // The moving row takes no events, so VoiceOver gets the chips as buttons here.
      .accessibilityRepresentation {
        HStack(spacing: Self.spacing) {
          ForEach(items, id: \.self) { item in
            if opens(item) {
              Button { open(item) } label: { chip(item) }
                .accessibilityHint(Text(hint(item)))
            } else {
              chip(item)
            }
          }
        }
      }
  }

  /// The `copy`-th copy of the row, the chip under the pointer outlined as a link is on hover
  /// (in that copy only: the same symbol may be on screen twice).
  private func row(copy: Int) -> some View {
    let pointed = spot(at: pointer)
    return HStack(spacing: Self.spacing) {
      ForEach(items, id: \.self) { item in
        chip(item).overlay {
          RoundedRectangle(cornerRadius: Tokens.Radius.medium)
            .strokeBorder(Palette.info, lineWidth: Tokens.Stroke.thin)
            .opacity(pointed?.item == item && pointed?.copy == copy && opens(item) ? 1 : 0)
        }
      }
    }
    .padding(.trailing, Self.spacing)
    .fixedSize()
  }

  /// The chip drawn at `x` points from the strip's leading edge while the row is held, and which
  /// copy of the row it is in; nil while the row moves or over a gap.
  private func spot(at x: CGFloat) -> (item: Item, copy: Int)? {
    guard let held else { return nil }
    let spans = items.map { widths[$0] ?? 0 }
    let loop = spans.reduce(0, +) + Self.spacing * CGFloat(items.count)
    guard loop > 0 else { return nil }
    let along = x + held
    guard along >= 0 else { return nil }
    let copy = Int((along / loop).rounded(.down))
    let place = along - CGFloat(copy) * loop
    var start: CGFloat = 0
    for (item, width) in zip(items, spans) {
      if place < start { return nil }
      if place < start + width { return (item, copy) }
      start += width + Self.spacing
    }
    return nil
  }

  /// Space between chips, and after the last one before the next copy.
  static var spacing: CGFloat { Tokens.Space.s }
  /// Share of the strip's width that fades out at each end.
  private static var fadeEdge: Double { ChipsMarqueeView.fadeEdge }
}

/// Lets the strip hold the moving row and read where it holds it.
@MainActor
final class ChipsMarqueeHandle {
  weak var view: ChipsMarqueeView?

  /// Stops the row where it is drawn; returns how far it is shifted to the left, in points.
  func hold() -> CGFloat { view?.hold() ?? 0 }

  /// Lets the row scroll on from where it was held.
  func release() { view?.release() }
}

/// The strip as an AppKit view: the copies of the row live in a hosting view of their own.
private struct ChipsMarqueeHost: NSViewRepresentable {
  /// A copy of the row, by its place in the strip (0 first).
  let row: (Int) -> AnyView
  /// Points per second.
  let speed: Double
  let handle: ChipsMarqueeHandle

  func makeNSView(context: Context) -> ChipsMarqueeView {
    let view = ChipsMarqueeView(row: row)
    handle.view = view
    return view
  }

  func updateNSView(_ view: ChipsMarqueeView, context: Context) {
    handle.view = view
    view.show(row, speed: speed)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: ChipsMarqueeView, context: Context) -> CGSize? {
    let size = nsView.rowSize
    return CGSize(width: proposal.width ?? nsView.loopWidth, height: size.height)
  }
}

/// Clips the row and scrolls it: a `CABasicAnimation` shifts the layer of `mover`, which holds the
/// hosting view. Held, the animation is taken off and the mover's frame is put where the row was
/// drawn; released, the scroll goes on from there. It takes no pointer events: the strip around
/// it does (`ChipsMarquee`).
final class ChipsMarqueeView: NSView {
  /// Key of the scroll animation, and the key path it drives (the mover's horizontal shift).
  static let animationKey = "chips-marquee"
  static let keyPath = "transform.translation.x"
  /// Fewest copies of the row side by side: one leaving, one coming in.
  static let fewestCopies = 2
  /// Share of the strip's width that fades out at each end.
  static let fadeEdge = 0.06

  private let mover = NSView()
  private let host: NSHostingView<AnyView>
  private var row: (Int) -> AnyView
  /// Copies of the row in the hosting view: enough to fill the strip while one loop scrolls by.
  private var copies = ChipsMarqueeView.fewestCopies
  private var speed = 0.0
  /// Width of one copy of the row, in points: one loop of the scroll.
  private var loop: CGFloat = 0
  private var held = false

  init(row: @escaping (Int) -> AnyView) {
    self.row = row
    host = NSHostingView(rootView: Self.strip(row, copies: Self.fewestCopies))
    // The row's own size is read here (its intrinsic size); it changes only with the
    // chips, never per frame. No minimum or maximum: the row never sizes the window.
    host.sizingOptions = [.intrinsicContentSize]
    super.init(frame: .zero)
    wantsLayer = true
    layer?.masksToBounds = true
    mover.wantsLayer = true
    mover.addSubview(host)
    addSubview(mover)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  // The strip around this view takes the pointer: hover and clicks go to it.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  /// Size of all copies of the row, in points.
  var rowSize: CGSize { host.intrinsicContentSize }
  /// Width of one copy, in points.
  var loopWidth: CGFloat { rowSize.width / CGFloat(copies) }

  /// The copies side by side; VoiceOver reads the strip's own buttons instead.
  private static func strip(_ row: @escaping (Int) -> AnyView, copies: Int) -> AnyView {
    AnyView(HStack(spacing: 0) {
      ForEach(0..<copies, id: \.self) { copy in row(copy) }
    }
    .accessibilityHidden(true))
  }

  func show(_ row: @escaping (Int) -> AnyView, speed: Double) {
    self.row = row
    host.rootView = Self.strip(row, copies: copies)
    let restart = speed != self.speed
    self.speed = speed
    place(restart: restart)
  }

  override func layout() {
    super.layout()
    place(restart: false)
  }

  /// Sizes the row and restarts the scroll when one loop's width changed (new chips).
  private func place(restart: Bool) {
    // As many copies as the strip needs: a row narrower than the strip leaves no gap at its end.
    let one = loopWidth
    if one > 0 {
      let needed = max(Self.fewestCopies, Int((bounds.width / one).rounded(.up)) + 1)
      if needed != copies {
        copies = needed
        host.rootView = Self.strip(row, copies: copies)
      }
    }
    let size = host.intrinsicContentSize
    host.frame = CGRect(origin: .zero, size: size)
    mover.frame = CGRect(x: mover.frame.minX, y: 0, width: size.width, height: size.height)
    let width = size.width / CGFloat(copies)
    let changed = width != loop
    loop = width
    guard !held else { return }
    if changed || restart || mover.layer?.animation(forKey: Self.animationKey) == nil {
      scroll(from: current)
    }
  }

  /// How far the row is drawn shifted to the left now, in points.
  private var current: CGFloat {
    let shown = (mover.layer?.presentation()?.value(forKeyPath: Self.keyPath) as? CGFloat) ?? 0
    return -(shown + mover.frame.minX)
  }

  private func scroll(from shift: CGFloat) {
    guard let layer = mover.layer else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAnimation(forKey: Self.animationKey)
    mover.frame.origin.x = 0
    if loop > 0, speed > 0 {
      let animation = CABasicAnimation(keyPath: Self.keyPath)
      animation.fromValue = 0
      animation.toValue = -loop
      animation.duration = Double(loop) / speed
      // decorative: the screeners' ticker is ornament; its caller moves it only while the bot runs (owner, 2026-11-16).
      animation.repeatCount = .infinity
      // Kept while the window is hidden or the app is in the background, so it resumes.
      animation.isRemovedOnCompletion = false
      animation.timeOffset = Double(min(max(shift, 0), loop)) / speed
      layer.add(animation, forKey: Self.animationKey)
    }
    CATransaction.commit()
  }

  /// Stops the row where it is drawn and returns its shift to the left, in points.
  func hold() -> CGFloat {
    if !held, let layer = mover.layer {
      let shift = current
      held = true
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      layer.removeAnimation(forKey: Self.animationKey)
      mover.frame.origin.x = -shift
      CATransaction.commit()
    }
    return -mover.frame.minX
  }

  /// Lets the row scroll on from where it was held.
  func release() {
    guard held else { return }
    held = false
    scroll(from: current)
  }
}
