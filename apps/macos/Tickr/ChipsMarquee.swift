#if os(macOS)
import AppKit
#endif
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
///   (no hover, no tracking), so the moving row takes no clicks. The strip's own AppKit view
///   (`ChipsMarqueeView`) tracks the pointer in its own coordinates, the very ones it draws the
///   row in. SwiftUI hover on the strip did not: the pages' nested hosting views keep tracking
///   areas at their frames, not where Core Animation draws them, so the hover went stale or never
///   began over parts of the strip and the outline lit a chip beside the pointer (owner,
///   2026-11-19). Paused, the view knows which slots each page draws and where each chip is, so
///   the strip outlines and opens the chip that is under the pointer.
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

  #if os(macOS)
  @State private var handle = ChipsMarqueeHandle()
  #endif

  /// Whether the row moves: on the Mac, while asked and without Reduce Motion. On iPad the row is
  /// the scroll view of buttons, which a finger moves.
  private var moves: Bool {
    #if os(macOS)
    moving && !reduceMotion
    #else
    false
    #endif
  }

  var body: some View {
    Group {
      if moves {
        #if os(macOS)
        marquee
        #endif
      } else {
        ScrollView(.horizontal) {
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
        .withoutScrollIndicators()
      }
    }
    .mask(LinearGradient(
      stops: [.init(color: .clear, location: 0), .init(color: .black, location: Self.fadeEdge),
        .init(color: .black, location: 1 - Self.fadeEdge), .init(color: .clear, location: 1)],
      startPoint: .leading, endPoint: .trailing))
  }

  #if os(macOS)
  private var marquee: some View {
    let pointer = handle.pointer.x
    let pointed = spot(at: pointer)
    return ChipsMarqueeHost(
      page: { AnyView(page($0, pointed: pointed?.slot)) },
      shows: ChipsMarqueeShows(items: items, pointed: pointed?.slot),
      count: items.count, leastChipWidth: leastChipWidth + Self.spacing,
      speed: Tokens.Motion.tickerSpeed, handle: handle)
      .contentShape(Rectangle())
      // Opens the chip that is outlined: the one under the pointer as the strip's view tracks it.
      .onTapGesture {
        if let item = spot(at: handle.pointer.x)?.item, opens(item) { open(item) }
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
        .withoutScrollIndicators()
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

  /// The chip drawn at `point` points from the strip's leading edge while the pointer holds the
  /// row, and its slot; nil off the strip, while the row moves or over a gap.
  private func spot(at point: CGFloat?) -> (item: Item, slot: Int)? {
    guard let point, !items.isEmpty, let shown = handle.shown else { return nil }
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

  #endif

  /// Space between chips, and after the last one before the next copy.
  static var spacing: CGFloat { Tokens.Space.s }
  /// Share of the strip's width that fades out at each end.
  private static var fadeEdge: Double { ChipsMarqueeFade.edge }
}

/// The strip's faded ends (a generic type holds no stored constant).
enum ChipsMarqueeFade {
  /// Share of the strip's width that fades out at each end.
  static let edge = 0.06
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

/// Where the row is along the lead page, kept by the strip itself rather than read back from the
/// screen. Reading the drawn position (the layer's presentation) gave a stale answer in the same
/// turn of the run loop as a hold or a release: the new scroll was not on screen yet, so the
/// redraw that follows a release (the outline goes away) read the row as a whole page further on,
/// and the row jumped to another chip under the pointer (owner, 2026-11-17). So the clock stops
/// while the row is held and the row goes on from the very point where it stopped.
struct MarqueeClock: Equatable {
  /// Points along the lead page where the current scroll started, or where the row stands still.
  private(set) var origin: CGFloat = 0
  /// Media time, in seconds, when the current scroll started; nil while the row stands still.
  private(set) var startedAt: Double?
  /// Points per second.
  private(set) var speed = 0.0

  /// Points along the lead page at media time `now`, never past `limit` (where the page has
  /// scrolled out).
  func shift(at now: Double, limit: CGFloat) -> CGFloat {
    guard let startedAt else { return origin }
    return min(origin + CGFloat((now - startedAt) * speed), max(limit, origin))
  }

  /// Starts a scroll from `shift` at media time `now`.
  mutating func run(from shift: CGFloat, at now: Double, speed: Double) {
    origin = shift
    startedAt = now
    self.speed = speed
  }

  /// Stands the row still at `shift`.
  mutating func stop(at shift: CGFloat) {
    origin = shift
    startedAt = nil
  }
}

/// Where the pointer is over the strip, as the strip's AppKit view tracks it. Observed: the strip
/// outlines the chip under it.
@MainActor
@Observable
final class MarqueePointer {
  /// Points from the strip's leading edge; nil while the pointer is off the strip.
  var x: CGFloat?
}

#if os(macOS)
/// Lets the strip find the chip under the pointer. Not observed: its values change as pages
/// scroll by, and nothing redraws for them (only `pointer` is observed).
@MainActor
final class ChipsMarqueeHandle {
  weak var view: ChipsMarqueeView?
  let pointer = MarqueePointer()

  /// Width of each drawn chip by its slot, in points, as the pages laid them out.
  var widths: [Int: CGFloat] {
    get { view?.widths ?? [:] }
    set { view?.widths = newValue }
  }

  /// The slots drawn, first to last, and how far the first is shifted to the left, in points;
  /// nil when nothing is drawn.
  var shown: (slots: [Int], shift: CGFloat)? { view?.shown }
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
    let view = ChipsMarqueeView(pointer: handle.pointer)
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
/// on from there. It tracks the pointer itself (`pointer`) and holds the row while the pointer is
/// over it; clicks go to the strip around it (`ChipsMarquee`).
final class ChipsMarqueeView: NSView {
  /// Key of the scroll animation, and the key path it drives (the mover's horizontal shift).
  static let animationKey = "chips-marquee"
  static let keyPath = "transform.translation.x"
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
  /// Slot of the lead page's first chip. It only grows as pages turn (a slot's chip is its slot
  /// modulo the count), so the slots a page drew are never renumbered under it.
  private var first = 0
  /// The slots each page draws now.
  private var leadSlots = 0..<0
  private var nextSlots = 0..<0
  /// Where the pointer is over the strip; the strip reads it.
  private let pointer: MarqueePointer
  /// Width of each chip the pages draw, by its slot, in points, as the pages laid them out; only
  /// the slots drawn now are kept.
  var widths: [Int: CGFloat] = [:]
  private var speed = 0.0
  private var held = false
  /// Counts the scrolls started: a scroll that ends after another one started turns no page.
  private var generation = 0
  /// Where the row is along the lead page (`MarqueeClock`).
  private var clock = MarqueeClock()

  init(pointer: MarqueePointer) {
    self.pointer = pointer
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

  // Clicks go to the strip around this view; the pointer is tracked below, in this view's bounds.
  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
    addTrackingArea(NSTrackingArea(
      rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
      owner: self))
  }

  override func mouseEntered(with event: NSEvent) { point(at: event) }

  override func mouseMoved(with event: NSEvent) { point(at: event) }

  override func mouseExited(with event: NSEvent) {
    pointer.x = nil
    release()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil { pointer.x = nil }
  }

  /// Holds the row and tells the strip where the pointer is along it.
  private func point(at event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)
    guard bounds.contains(location) else {
      mouseExited(with: event)
      return
    }
    hold()
    pointer.x = location.x
  }

  /// Width of the lead page, in points: how far the row scrolls before the pages swap.
  var pageWidth: CGFloat { lead.frame.width }
  /// Height of the row, in points.
  private(set) var rowHeight: CGFloat = 0

  /// The slots the pages draw, first to last, and how far the lead page is shifted to the left,
  /// in points.
  var shown: (slots: [Int], shift: CGFloat)? {
    chipCount > 0 ? (Array(leadSlots) + Array(nextSlots), current) : nil
  }

  func show(
    _ page: @escaping (Range<Int>) -> AnyView, shows: AnyHashable, count: Int, leastChipWidth: CGFloat, speed: Double
  ) {
    self.page = page
    chipCount = count
    self.leastChipWidth = leastChipWidth
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
    leadSlots = pages.slots(from: first)
    nextSlots = pages.slots(from: first + pages.size)
    keepWidthsDrawn()
    lead.rootView = page(leadSlots)
    next.rootView = page(nextSlots)
    place()
    turnOrScroll(from: shift)
  }

  /// Forgets the widths of slots no page draws any more.
  private func keepWidthsDrawn() {
    widths = widths.filter { leadSlots.contains($0.key) || nextSlots.contains($0.key) }
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
    // The old next page leads with the slots it drew; the new next page follows them.
    leadSlots = nextSlots
    first = leadSlots.lowerBound
    nextSlots = pages.slots(from: leadSlots.upperBound)
    keepWidthsDrawn()
    next.rootView = page(nextSlots)
    place()
    scroll(from: shift - width)
  }

  /// How far the lead page is shifted to the left now, in points: by the row's own clock, which
  /// stands still while the row is held.
  private var current: CGFloat { clock.shift(at: CACurrentMediaTime(), limit: pageWidth) }

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
      clock.stop(at: start)
      mover.frame.origin.x = -start
      CATransaction.commit()
      return
    }
    let now = CACurrentMediaTime()
    clock.run(from: start, at: now, speed: speed)
    mover.frame.origin.x = -width
    let animation = CABasicAnimation(keyPath: Self.keyPath)
    // From where the row is, not a time offset: an offset animation wraps to its start at the end.
    animation.fromValue = width - start
    animation.toValue = 0
    animation.duration = Double(width - start) / speed
    // Starts at the clock's start, so the drawn row and the clock agree.
    animation.beginTime = layer.convertTime(now, from: nil)
    animation.fillMode = .backwards
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
    guard !held else { return }
    let shift = current
    held = true
    scroll(from: shift)
  }

  /// Lets the row scroll on from where it was held.
  func release() {
    guard held else { return }
    held = false
    turnOrScroll(from: current)
  }
}
#endif
