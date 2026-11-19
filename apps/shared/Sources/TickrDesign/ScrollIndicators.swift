import SwiftUI
import TickrKit

// MARK: - scroll indicators

public extension View {
  /// Hides the scroll indicators of every scroll view, list and form below this view (owner,
  /// 2026-11-18: no scroll bars anywhere, on the Mac or the phone). `.never` also overrides the
  /// Mac's "Always show scroll bars" setting. Each scene's root applies it once; sheets and
  /// popovers inherit it. The `scrollbars` rule of `check_swift_rules.py` keeps the apps from
  /// setting indicators view by view, so this stays the one place.
  func withoutScrollIndicators() -> some View {
    scrollIndicators(.never, axes: [.horizontal, .vertical])
  }

  /// What stands in for the hidden indicators on a vertical scroll view, list or form (owner's
  /// pick, variant B of the 2026-11-18 mockups): an edge with more content beyond it fades the
  /// content out, and while more is below, a small capsule with a down chevron sits on the bottom
  /// edge; a click or tap on it scrolls a page. At the top and the end the hints go away.
  /// Apply it on the scroll view itself (it reads that view's geometry and position).
  func scrollEdgeHints() -> some View {
    modifier(ScrollEdgeHints(external: nil, pages: true))
  }

  /// `scrollEdgeHints()` for a `Form` or `List`: the edge fades only, no chevron. A scroll
  /// position cannot move a form (checked on the iPhone simulator, 2026-11-18: neither
  /// `scrollTo(y:)` nor `scrollTo(edge:)` moves it), and a chevron that does nothing on a tap is
  /// a control that lies.
  func scrollEdgeFades() -> some View {
    modifier(ScrollEdgeHints(external: nil, pages: false))
  }

  /// `scrollEdgeHints()` for a scroll view whose position the screen also drives (a pane that
  /// goes back to the top when another tab is picked): the hints scroll through the same binding.
  func scrollEdgeHints(position: Binding<ScrollPosition>) -> some View {
    modifier(ScrollEdgeHints(external: position, pages: true))
  }
}

/// Which edges of a scroll view have more content beyond them, and the insets (a bar drawn over
/// the content, as the phone's tab bar) the hints keep clear of.
struct ScrollEdges: Equatable {
  var above = false
  var below = false
  var insetTop: CGFloat = 0
  var insetBottom: CGFloat = 0

  init() {}

  /// `containerSize` is the visible height between the insets (measured on iPhone 18 Pro: an
  /// 874 pt screen, insets 62 and 96, container 716), and the content's top sits at
  /// `-insets.top` while scrolled to the top.
  init(_ geometry: ScrollGeometry) {
    let tolerance = Tokens.Scroll.edgeTolerance
    insetTop = geometry.contentInsets.top
    insetBottom = geometry.contentInsets.bottom
    let shownTop = geometry.contentOffset.y + insetTop
    above = shownTop > tolerance
    below = geometry.contentSize.height - shownTop - geometry.containerSize.height > tolerance
  }
}

/// Where the chevron takes the scroll view next: one more page, or the very bottom.
enum ScrollStep: Equatable {
  /// The scroll position's y (0 = the content's top at the top of the visible area).
  case offset(CGFloat)
  /// The end of the content: what is left is no more than a page.
  case bottom
}

/// Where the next page starts: kept out of view state, so following the scroll every frame
/// redraws nothing. Measured like `ScrollEdges`, from the content's top shown below the top
/// inset, because that is how a scroll position's y counts (owner, 2026-11-19: with the phone's
/// 62 pt top inset counted in, the last tap stopped that much short of the end, the chevron
/// stayed, and the next tap did nothing).
@MainActor final class ScrollPage {
  /// How far the content's top is above the visible area's top.
  var shown: CGFloat = 0
  /// The visible height between the insets.
  var visible: CGFloat = 0
  /// The largest `shown`: the content's end at the visible area's bottom.
  var end: CGFloat = 0

  func follow(_ geometry: ScrollGeometry) {
    follow(offset: geometry.contentOffset.y, insetTop: geometry.contentInsets.top,
      content: geometry.contentSize.height, container: geometry.containerSize.height)
  }

  func follow(offset: CGFloat, insetTop: CGFloat, content: CGFloat, container: CGFloat) {
    shown = offset + insetTop
    visible = container
    end = content - container
  }

  /// One page further down; when no more than a page is left (or a page would leave less than
  /// the edge tolerance, which a scroll position may not move by), the bottom itself, so a tap
  /// always ends with the end in view and the chevron gone.
  var next: ScrollStep {
    let target = shown + visible * Tokens.Scroll.pageShare
    return target >= end - Tokens.Scroll.edgeTolerance ? .bottom : .offset(target)
  }
}

struct ScrollEdgeHints: ViewModifier {
  let external: Binding<ScrollPosition>?
  /// Whether the chevron shows (it pages the scroll view down).
  let pages: Bool
  @State private var own = ScrollPosition(edge: .top)
  @State private var edges = ScrollEdges()
  @State private var page = ScrollPage()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var position: Binding<ScrollPosition> { external ?? $own }
  private var motion: Animation? { reduceMotion ? nil : .easeOut(duration: Tokens.Scroll.fadeSeconds) }

  func body(content: Content) -> some View {
    content
      .scrollPosition(position)
      .onScrollGeometryChange(for: ScrollEdges.self) { ScrollEdges($0) } action: { _, new in
        edges = new
      }
      .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, new in
        page.follow(new)
      }
      // The scroll view's frame stops at the insets while its content runs on under the bars:
      // the mask reaches under them too, so content there shows as before unless more is beyond.
      .mask { fadeMask.animation(motion, value: edges).ignoresSafeArea() }
      .overlay(alignment: .bottom) {
        if pages && edges.below {
          chevron
            .padding(.bottom, Tokens.Space.s)
            .transition(.opacity)
        }
      }
      .animation(motion, value: edges.below)
  }

  /// Opaque where the content shows, fading to clear over `Tokens.Scroll.fade` at an edge with
  /// more beyond it; past that edge (under a bar) the content is hidden while more is there.
  private var fadeMask: some View {
    VStack(spacing: 0) {
      Color.clear.frame(height: edges.above ? edges.insetTop : 0)
      LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
        .frame(height: edges.above ? Tokens.Scroll.fade : 0)
      Color.black
      LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
        .frame(height: edges.below ? Tokens.Scroll.fade : 0)
      Color.clear.frame(height: edges.below ? edges.insetBottom : 0)
    }
  }

  private var chevron: some View {
    Button {
      withAnimation(reduceMotion ? nil : Tokens.Motion.standard) {
        switch page.next {
        case .offset(let y): position.wrappedValue.scrollTo(y: y)
        case .bottom: position.wrappedValue.scrollTo(edge: .bottom)
        }
      }
    } label: {
      Image(systemName: Symbols.scrollMore)
        .font(Tokens.Scroll.chevronFont)
        .foregroundStyle(Palette.textTertiary)
        .frame(width: Tokens.Scroll.capsuleWidth, height: Tokens.Scroll.capsuleHeight)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
        .shadow(color: Palette.shadow.opacity(Tokens.Opacity.faint), radius: Tokens.Size.shadowRadius,
          y: Tokens.Space.xxs)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(ScrollText.more))
    .hint(ScrollText.more)
  }
}
