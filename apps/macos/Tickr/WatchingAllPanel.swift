import SwiftUI
import TickrDesign
import TickrKit

// "Watching closely", all symbols: the panel the card's "Show all N ›" opens over the Overview,
// with the rows of GET /watching in a two-column grid, sorted and filtered here
// (`WatchingList`). Closes with its X, Esc or a click on the dimmed backdrop.

/// Opens the full "Watching closely" list over the screen that hosts it (`watchingAllPanel()`).
struct OpenWatchingAll: Sendable {
  let action: @MainActor @Sendable () -> Void

  @MainActor func callAsFunction() { action() }
}

extension EnvironmentValues {
  /// Set by `watchingAllPanel()`; does nothing on a screen without the panel.
  @Entry var openWatchingAll = OpenWatchingAll {}
}

extension View {
  /// Hosts the full "Watching closely" list: centred over this view on a dimmed backdrop when a
  /// card below calls `openWatchingAll`, nothing at all while closed.
  func watchingAllPanel() -> some View { modifier(WatchingAllPresenter()) }
}

private struct WatchingAllPresenter: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var open = false

  func body(content: Content) -> some View {
    content
      .accessibilityHidden(open)
      .environment(\.openWatchingAll, OpenWatchingAll { [open = $open, still = reduceMotion] in
        withAnimation(still ? nil : Tokens.Motion.standard) { open.wrappedValue = true }
      })
      .overlay(alignment: .top) {
        // Empty while closed, so the Overview pays nothing for the list otherwise.
        ZStack(alignment: .top) {
          if open {
            Palette.scrim.opacity(Tokens.Opacity.faint)
              .contentShape(Rectangle())
              .onTapGesture { close() }
              .accessibilityHidden(true)
              .transition(AnyTransition.opacity)
          }
          if open {
            WatchingAllPanel { close() }
              .padding(.top, WatchingAllPanel.topInset)
              .padding([.horizontal, .bottom], Tokens.Space.l)
              .transition(AnyTransition.opacity
                .combined(with: AnyTransition.offset(y: reduceMotion ? 0 : Tokens.Size.riseOffset)))
          }
        }
      }
  }

  private func close() {
    withAnimation(reduceMotion ? nil : Tokens.Motion.standard) { open = false }
  }
}

/// The panel itself: the title and what the rows show, sort and filter chips, then every row the
/// bot sent in two columns, scrolling inside the panel when they are many.
struct WatchingAllPanel: View {
  @Environment(AppModel.self) private var model
  @State private var sort = WatchingSort.closest
  @State private var filter = WatchingFilter.all
  let close: () -> Void

  /// Width of the panel, in points, as the design's sheet; narrower windows get less.
  static let width: CGFloat = 600
  /// Tallest the panel grows before its rows scroll, in points.
  static let maxHeight: CGFloat = 720
  /// Gap above the panel, under the window's title bar, in points.
  static let topInset: CGFloat = 52
  /// The panel's lift off the dimmed screen: shadow blur and downward offset, in points.
  static let shadowRadius: CGFloat = 30
  static let shadowOffset: CGFloat = 12
  /// The orders the Mac offers (the iPhone's "Latest" is not among them, as in the design).
  static let sorts: [WatchingSort] = [.closest, .symbol, .quoteAge]
  /// Accessibility id of the panel, for the UI tests.
  static let id = "overview-watching-all"

  var body: some View {
    let all = model.watching?.rows ?? []
    let shown = WatchingList.rows(all, sort: sort, filter: filter)
    VStack(alignment: .leading, spacing: 0) {
      header(all)
      controls(all)
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
      ScrollsWhenTall {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          if shown.isEmpty {
            Footnote(all.isEmpty ? L10n.Watching.none : L10n.Watching.noneFiltered)
          }
          LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Space.s, alignment: .top),
            GridItem(.flexible(), spacing: Tokens.Space.s, alignment: .top)],
            alignment: .leading, spacing: Tokens.Space.s) {
            // The rows rise in one after another as the panel opens; a new order moves them.
            ForEach(Array(shown.enumerated()), id: \.element.symbol) { index, row in
              ChartLink(row.symbol) { WatchingRow(row: row) }
                .rise(step: index)
            }
          }
        }
        .padding(Tokens.Space.l)
        .animation(Tokens.Motion.standard, value: shown.map(\.symbol))
      }
    }
    .frame(maxWidth: Self.width)
    // As tall as its rows up to the cap; the card hugs them, the rest above the cap scrolls.
    .tickrCard(radius: Tokens.Radius.large)
    .shadow(color: Palette.scrim.opacity(Tokens.Opacity.border), radius: Self.shadowRadius, y: Self.shadowOffset)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
    .accessibilityLabel(Text(L10n.Watching.panelLabel))
    .accessibilityIdentifier(Self.id)
    .frame(maxHeight: Self.maxHeight, alignment: .top)
  }

  /// "Watching closely" over how many symbols, what each row shows and, on the live day, "live".
  private func header(_ all: [WatchingRowV1]) -> some View {
    let parts = [String(localized: L10n.Watching.symbols(all.count)), String(localized: L10n.Watching.columns)]
      + (model.isLive ? [String(localized: L10n.Watching.live)] : [])
    return HStack(alignment: .top, spacing: Tokens.Space.m) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(L10n.Watching.title)
          .font(Tokens.Typography.heading)
          .foregroundStyle(Palette.textPrimary)
          .accessibilityAddTraits(.isHeader)
        Text(verbatim: parts.joined(separator: Format.itemSeparator))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      Button(action: close) {
        Image(systemName: Self.closeSymbol)
      }
      .buttonStyle(.icon(compact: true))
      .keyboardShortcut(.cancelAction)
      .help(Text(L10n.Watching.closeHelp))
      .accessibilityLabel(Text(L10n.Watching.close))
    }
    .padding([.horizontal, .top], Tokens.Space.l)
    .padding(.bottom, Tokens.Space.s)
  }

  /// SF Symbol of the close button.
  static let closeSymbol = "xmark"

  /// Sort chips on the left, the verdict filter with its counts on the right; the filter goes
  /// under the sort when both do not fit on one line, and each wraps its own chips.
  private func controls(_ all: [WatchingRowV1]) -> some View {
    let sorts = ChipFlow(spacing: Tokens.Space.xs) {
      Text(L10n.Watching.sortLabel)
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Typography.labelTracking)
        .foregroundStyle(Palette.textQuaternary)
        .padding(.trailing, Tokens.Space.xs)
      ForEach(Self.sorts, id: \.self) { item in
        Button { sort = item } label: { Text(item.title) }
          .buttonStyle(.chip(selected: sort == item))
      }
    }
    let filters = ChipFlow(spacing: Tokens.Space.xs) {
      ForEach(WatchingFilter.allCases, id: \.self) { item in
        Button { filter = item } label: { Text(item.title(WatchingList.count(all, item))) }
          .buttonStyle(.chip(selected: filter == item))
      }
    }
    return ViewThatFits(in: .horizontal) {
      HStack(spacing: Tokens.Space.m) {
        sorts.fixedSize()
        Spacer(minLength: 0)
        filters.fixedSize()
      }
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        sorts
        filters
      }
    }
    .padding(.horizontal, Tokens.Space.l)
    .padding(.bottom, Tokens.Space.m)
  }
}

extension WatchingSort {
  /// The chip's name.
  var title: LocalizedStringResource {
    switch self {
    case .closest: L10n.Watching.sortClosest
    case .symbol: L10n.Watching.sortSymbol
    case .quoteAge: L10n.Watching.sortQuoteAge
    case .latest: L10n.Watching.sortLatest
    }
  }
}

extension WatchingFilter {
  /// The chip's name with how many rows it keeps.
  func title(_ count: Int) -> LocalizedStringResource {
    switch self {
    case .all: L10n.Watching.filterAll(count)
    case .watch: L10n.Watching.filterWatch(count)
    case .ignore: L10n.Watching.filterIgnore(count)
    }
  }
}
