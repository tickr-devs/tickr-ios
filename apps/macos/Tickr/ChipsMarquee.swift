import AppKit
import QuartzCore
import SwiftUI
import TickrDesign

/// A row of chips that scrolls slowly to the left in a loop, faded at both ends. Under the pointer
/// it stands still, the chip under the pointer is outlined and a click opens that chip. Still when
/// `moving` is false and with Reduce Motion: then it is an ordinary horizontal scroll view of
/// buttons.
///
/// Why it is built this way:
/// - Moving the row from SwiftUI (a `TimelineView` shifting an `offset`) made AppKit lay out the
///   whole window on every frame: the root hosting view, the window's minimum size, its drag
///   margins and cursor rects. That was 49% CPU against 14% for main (Debug, fixtures, 2026-11-16).
/// - So Core Animation moves the row (`ChipsMarqueeView`), in the render server, and SwiftUI
///   lays out nothing per frame.
/// - A day's screeners list well over a thousand symbols (1688 on 2026-11-16), which pass at
///   `tickerSpeed` in over two hours a loop. Building every chip (a hidden measuring copy, two
///   copies of the row, VoiceOver's) held the main thread for seconds on each switch to Overview,
///   and the hidden copy was measured again on every update of the screen. So only the chips on
///   screen exist: two pages (`MarqueePages`) side by side, and when the first has scrolled out
///   it is drawn again as the page after the second. The row looks and moves as one long row.
/// - Pointer events do not reach SwiftUI views inside a hosting view nested in the screen
///   (no hover, no tracking), so the moving row takes no events at all. The strip itself, which
///   never moves, takes the hover and the click in the screen's own hierarchy. Paused, it knows
///   where each chip is drawn, so it outlines and opens the chip that is under the pointer.
struct ChipsMarquee<Item: Hashable, Chip: View>: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let items: [Item]
  let moving: Bool
  /// Least width of a chip, in points: how many chips fill a page.
  let leastChipWidth: CGFloat
  /// Accessibility hint of a chip's button.
  let hint: (Item) -> LocalizedStringResource
  /// Hover help of a chip.
  let help: (Item) -> Text
  /// Whether a chip opens something; one that does not is neither outlined nor clicked.
  let opens: (Item) -> Bool
  /// Opens a chip.
  let open: (Item) -> Void
  let chip: (Item) -> Chip

  /// Whether the pointer holds the row still.
  @State private var held = false
  /// The pointer's place along the strip, in points from its leading edge.
  @State private var pointer: CGFloat = 0
  @State private var handle = ChipsMarqueeHandle()

  var body: some View {
    Group {
      if moving && !reduceMotion {
        marquee
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          // Lazy: only the chips in view are built.
          LazyHStack(spacing: Self.spacing) {
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
    let pointed = spot(at: pointer)
    return ChipsMarqueeHost(
      page: { AnyView(page($0, pointed: pointed?.slot)) },
      shows: ChipsMarqueeShows(items: items, pointed: pointed?.slot),
      count: items.count, leastChipWidth: leastChipWidth + Self.spacing,
      speed: Tokens.Motion.tickerSpeed, handle: handle)
      .contentShape(Rectangle())
      .onContinuousHover(coordinateSpace: .local) { phase in
        switch phase {
        case .active(let location):
          if !held {
            handle.hold()
            held = true
          }
          pointer = location.x
        case .ended:
          held = false
          handle.release()
        }
      }
      .onTapGesture(coordinateSpace: .local) { location in
        if let item = spot(at: location.x)?.item, opens(item) { open(item) }
      }
      .help(spot(at: pointer).map { help($0.item) } ?? Text(verbatim: String()))
      // The moving row takes no events, so VoiceOver gets the chips as buttons here; lazy, so
      // only the ones it reaches are built.
      .accessibilityRepresentation {
        ScrollView(.horizontal) {
          LazyHStack(spacing: Self.spacing) {
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
  }

  /// The chips of `slots` (places along the endless row: slot `n` shows item `n` modulo the
  /// count), the one under the pointer outlined as a link is on hover. Each chip's width is told
  /// to the handle, which finds the chip under the pointer by it.
  private func page(_ slots: Range<Int>, pointed: Int?) -> some View {
    HStack(spacing: Self.spacing) {
      // No chips, no slots: a slot's item is its place modulo the count.
      ForEach(items.isEmpty ? 0..<0 : slots, id: \.self) { slot in
        let item = items[slot % items.count]
        chip(item)
          .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.medium)
              .strokeBorder(Palette.info, lineWidth: Tokens.Stroke.thin)
              .opacity(pointed == slot && opens(item) ? 1 : 0)
          }
          .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { [handle] in handle.widths[slot] = $0 }
      }
    }
    .padding(.trailing, Self.spacing)
    .fixedSize()
  }

  /// The chip drawn at `point` points from the strip's leading edge while the row is held, and its
  /// slot; nil while the row moves or over a gap.
  private func spot(at point: CGFloat) -> (item: Item, slot: Int)? {
    guard held, !items.isEmpty, let shown = handle.shown else { return nil }
    let along = point + shown.shift
    guard along >= 0 else { return nil }
    var start: CGFloat = 0
    for slot in shown.slots {
      let width = handle.widths[slot] ?? 0
      if along < start { return nil }
      if along < start + width { return (items[slot % items.count], slot) }
      start += width + Self.spacing
    }
    return nil
  }

  /// Space between chips, and after the last one before the next copy.
  static var spacing: CGFloat { Tokens.Space.s }
  /// Share of the strip's width that fades out at each end.
  private static var fadeEdge: Double { ChipsMarqueeView.fadeEdge }
}

/// What the moving row draws: its chips and the slot outlined under the pointer. The pages are
/// drawn again only when this changes (or when one scrolls out).
struct ChipsMarqueeShows<Item: Hashable>: Hashable {
  let items: [Item]
  let pointed: Int?
}

/// How the endless row is cut into pages: each page holds enough chips to span the strip, so two
/// pages side by side always cover it while the first scrolls out.
struct MarqueePages: Equatable {
  /// Chips on a page.
  let size: Int

  /// Enough chips for a page `stripWidth` points wide when each chip, with its spacing, is at
  /// least `leastChipWidth` points; at least one.
  init(stripWidth: CGFloat, leastChipWidth: CGFloat) {
    let fits = leastChipWidth > 0 ? Int((stripWidth / leastChipWidth).rounded(.up)) : 1
    size = max(fits, 1)
  }

  /// The slots of the page that starts at slot `first`.
  func slots(from first: Int) -> Range<Int> { first..<(first + size) }
}

/// Lets the strip hold the moving row and find the chip under the pointer. Not observed: its
/// values change as pages scroll by, and nothing redraws for them.
@MainActor
final class ChipsMarqueeHandle {
  weak var view: ChipsMarqueeView?
  /// Width of each drawn chip by its slot, in points, as the pages laid them out.
  var widths: [Int: CGFloat] = [:]

  /// The slots drawn, first to last, and how far the first is shifted to the left, in points;
  /// nil when nothing is drawn.
  var shown: (slots: Range<Int>, shift: CGFloat)? { view?.shown }

  /// Stops the row where it is drawn.
  func hold() { view?.hold() }

  /// Lets the row scroll on from where it was held.
  func release() { view?.release() }
}

/// The strip as an AppKit view: two pages of the row, each in a hosting view of its own.
private struct ChipsMarqueeHost: NSViewRepresentable {
  /// The chips of the given slots.
  let page: (Range<Int>) -> AnyView
  /// What the row draws (`ChipsMarqueeShows`): the pages are drawn and measured again only when
  /// it changes, never on every update of the screen around it.
  let shows: AnyHashable
  /// Number of distinct chips.
  let count: Int
  /// Least width of a chip with its spacing, in points.
  let leastChipWidth: CGFloat
  /// Points per second.
  let speed: Double
  let handle: ChipsMarqueeHandle

  func makeNSView(context: Context) -> ChipsMarqueeView {
    let view = ChipsMarqueeView()
    handle.view = view
    return view
  }

  func updateNSView(_ view: ChipsMarqueeView, context: Context) {
    handle.view = view
    view.show(page, shows: shows, count: count, leastChipWidth: leastChipWidth, speed: speed)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: ChipsMarqueeView, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? nsView.pageWidth, height: nsView.rowHeight)
  }
}

/// Clips the row and scrolls it: the mover holds two pages side by side, `lead` then `next`. Its
/// frame stands where the lead page has scrolled out, and a `CABasicAnimation` shifts its layer
/// from where the row is to there. When the animation ends the lead page is drawn again as the
/// page after `next` and the two swap, so the row scrolls on without a seam. Held, the animation
/// is taken off and the mover's frame is put where the row was drawn; released, the scroll goes
/// on from there. It takes no pointer events: the strip around it does (`ChipsMarquee`).
final class ChipsMarqueeView: NSView {
  /// Key of the scroll animation, and the key path it drives (the mover's horizontal shift).
  static let animationKey = "chips-marquee"
  static let keyPath = "transform.translation.x"
  /// Share of the strip's width that fades out at each end.
  static let fadeEdge = 0.06
  /// Pages drawn side by side: the lead one scrolling out and the next one.
  static let pagesDrawn = 2

  private let mover = NSView()
  private var lead = ChipsMarqueeView.host()
  private var next = ChipsMarqueeView.host()
  private var page: (Range<Int>) -> AnyView = { _ in AnyView(EmptyView()) }
  /// What the pages draw now (`ChipsMarqueeShows`).
  private var shows: AnyHashable?
  /// Number of distinct chips.
  private var chipCount = 0
  private var leastChipWidth: CGFloat = 0
  private var pages = MarqueePages(stripWidth: 0, leastChipWidth: 0)
  /// Slot of the lead page's first chip, below `chipCount`.
  private var first = 0
  private var speed = 0.0
  private var held = false
  /// Counts the scrolls started: a scroll that ends after another one started turns no page.
  private var generation = 0

  init() {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.masksToBounds = true
    mover.wantsLayer = true
    mover.addSubview(lead)
    mover.addSubview(next)
    addSubview(mover)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// A page's hosting view. Its own size is read (its intrinsic size) when it is drawn anew,
  /// never per frame. No minimum or maximum: the row never sizes the window.
  private static func host() -> NSHostingView<AnyView> {
    let host = NSHostingView(rootView: AnyView(EmptyView()))
    host.sizingOptions = [.intrinsicContentSize]
    return host
  }

  // The strip around this view takes the pointer: hover and clicks go to it.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  /// Width of the lead page, in points: how far the row scrolls before the pages swap.
  var pageWidth: CGFloat { lead.frame.width }
  /// Height of the row, in points.
  private(set) var rowHeight: CGFloat = 0

  /// The slots drawn and how far the lead page is shifted to the left, in points.
  var shown: (slots: Range<Int>, shift: CGFloat)? {
    chipCount > 0 ? (first..<(first + pages.size * Self.pagesDrawn), current) : nil
  }

  func show(
    _ page: @escaping (Range<Int>) -> AnyView, shows: AnyHashable, count: Int, leastChipWidth: CGFloat, speed: Double
  ) {
    self.page = page
    chipCount = count
    self.leastChipWidth = leastChipWidth
    first = chipCount > 0 ? first % chipCount : 0
    let restart = speed != self.speed
    self.speed = speed
    if shows != self.shows {
      self.shows = shows
      draw(keeping: current)
    } else if restart {
      scroll(from: current)
    }
  }

  override func layout() {
    super.layout()
    // As many chips on a page as the strip needs: a page narrower than the strip leaves a gap.
    let fitted = MarqueePages(stripWidth: bounds.width, leastChipWidth: leastChipWidth)
    if fitted != pages {
      pages = fitted
      draw(keeping: current)
    } else if !held, mover.layer?.animation(forKey: Self.animationKey) == nil {
      // A scroll that ended while no page could turn: go on from there.
      turnOrScroll(from: current)
    }
  }

  /// Draws both pages anew from `first`, measures them and scrolls on from `shift`.
  private func draw(keeping shift: CGFloat) {
    lead.rootView = page(pages.slots(from: first))
    next.rootView = page(pages.slots(from: first + pages.size))
    place()
    turnOrScroll(from: shift)
  }

  /// Puts the pages side by side at their own sizes.
  private func place() {
    let one = lead.intrinsicContentSize
    let two = next.intrinsicContentSize
    rowHeight = max(one.height, two.height)
    lead.frame = CGRect(x: 0, y: 0, width: one.width, height: rowHeight)
    next.frame = CGRect(x: one.width, y: 0, width: two.width, height: rowHeight)
    mover.frame = CGRect(x: mover.frame.minX, y: 0, width: one.width + two.width, height: rowHeight)
  }

  /// Scrolls on from `shift` points along the lead page; a lead page scrolled out first turns:
  /// the next page becomes the lead and the old lead is drawn again as the page after it.
  private func turnOrScroll(from shift: CGFloat) {
    let width = pageWidth
    guard width > 0, shift >= width, chipCount > 0 else {
      scroll(from: shift)
      return
    }
    swap(&lead, &next)
    first = (first + pages.size) % chipCount
    next.rootView = page(pages.slots(from: first + pages.size))
    place()
    scroll(from: shift - width)
  }

  /// How far the lead page is drawn shifted to the left now, in points.
  private var current: CGFloat {
    let shown = (mover.layer?.presentation()?.value(forKeyPath: Self.keyPath) as? CGFloat) ?? 0
    return -(shown + mover.frame.minX)
  }

  /// Scrolls the lead page out from `shift` points along it: the mover's frame stands where the
  /// lead page has scrolled out, and the animation runs from `shift` to there.
  private func scroll(from shift: CGFloat) {
    guard let layer = mover.layer else { return }
    generation += 1
    let width = pageWidth
    let start = min(max(shift, 0), width)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAnimation(forKey: Self.animationKey)
    guard !held, width > 0, speed > 0 else {
      mover.frame.origin.x = -start
      CATransaction.commit()
      return
    }
    mover.frame.origin.x = -width
    let animation = CABasicAnimation(keyPath: Self.keyPath)
    // From where the row is, not a time offset: an offset animation wraps to its start at the end.
    animation.fromValue = width - start
    animation.toValue = 0
    animation.duration = Double(width - start) / speed
    let scrolled = generation
    // decorative: the screeners' ticker is ornament; its caller moves it only while the bot runs (owner, 2026-11-16).
    CATransaction.setCompletionBlock { [weak self] in
      Task { @MainActor in self?.scrolledOut(scrolled) }
    }
    layer.add(animation, forKey: Self.animationKey)
    CATransaction.commit()
  }

  /// The lead page has scrolled out: the pages swap and the row scrolls on.
  private func scrolledOut(_ scrolled: Int) {
    guard scrolled == generation, !held else { return }
    turnOrScroll(from: current)
  }

  /// Stops the row where it is drawn.
  func hold() {
    guard !held, let layer = mover.layer else { return }
    let shift = current
    held = true
    generation += 1
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.removeAnimation(forKey: Self.animationKey)
    mover.frame.origin.x = -shift
    CATransaction.commit()
  }

  /// Lets the row scroll on from where it was held.
  func release() {
    guard held else { return }
    held = false
    turnOrScroll(from: current)
  }
}
