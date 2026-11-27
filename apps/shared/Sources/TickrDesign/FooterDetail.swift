import SwiftUI
import TickrKit

// What a card keeps one tap away, the same on both apps (mockup v148): a footer link that opens
// a popover or a sheet (`FooterDetail`, "More balances 5 ›", "Why ›"), the sheet itself
// (`CardSheet`, also every row of a `CappedList`), and the chevron of a row that opens in place
// (`ExpandChevron`, `RowExpander`). A card never grows behind a footer link.

/// A card's footer link (`CardFooterLink`, with a count or a short summary) that opens what the
/// card keeps out of sight: a popover on the Mac, a sheet on iOS, each with the title, a close
/// button and `content`. `endsCard`: false for a link with more of the card under it (the board's
/// `.crow`): it reaches the card's sides but not its bottom edge. `id` names the link for the UI
/// tests.
public struct FooterDetail<Content: View>: View {
  let title: LocalizedStringResource
  let count: Int?
  let summary: String?
  let summaryColor: Color
  let endsCard: Bool
  let id: String?
  let content: () -> Content
  @State private var open = false

  public init(
    _ title: LocalizedStringResource, count: Int? = nil, summary: String? = nil,
    summaryColor: Color = Palette.textQuaternary, endsCard: Bool = true, id: String? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.title = title
    self.count = count
    self.summary = summary
    self.summaryColor = summaryColor
    self.endsCard = endsCard
    self.id = id
    self.content = content
  }

  public var body: some View {
    CardFooterLink(title, count: count, summary: summary, summaryColor: summaryColor) { open = true }
      .environment(\.footerLinkInline, !endsCard)
      .accessibilityIdentifier(id ?? "")
      .accessibilityAddTraits(open ? .isSelected : [])
      #if os(macOS)
      .popover(isPresented: $open, arrowEdge: .bottom) { sheet().inPopover() }
      #else
      .sheet(isPresented: $open) { sheet() }
      #endif
  }

  /// Built only when it opens.
  private func sheet() -> CardSheet<Content> {
    let shown = $open
    return CardSheet(title: title, subtitle: nil, close: { shown.wrappedValue = false }, rows: content)
  }
}

/// What a card opens from its footer: the title, an optional line under it ("23 in all · latest
/// first"), the round close button, then the rows, scrolling when they are many. On the iPhone a
/// sheet as tall as the rows (full height when they are more than a screen), with its own
/// navigation for rows that open a page; on the Mac a sheet of `Size.allRowsWidth` or, from a
/// `FooterDetail`, a popover of `Size.popover`. Esc closes it. Any other sheet of a card (the
/// iPhone's day picker, Home's funnel) is one too.
public struct CardSheet<Rows: View>: View {
  let title: LocalizedStringResource
  let subtitle: LocalizedStringResource?
  let close: @MainActor @Sendable () -> Void
  let rows: Rows
  var popover = false

  public init(
    title: LocalizedStringResource, subtitle: LocalizedStringResource?, close: @escaping @MainActor @Sendable () -> Void,
    @ViewBuilder rows: () -> Rows
  ) {
    self.title = title
    self.subtitle = subtitle
    self.close = close
    self.rows = rows()
  }

  /// The same, as the Mac's popover.
  func inPopover() -> Self {
    var sheet = self
    sheet.popover = true
    return sheet
  }

  public var body: some View {
    #if os(iOS)
    NavigationStack { content.toolbar(.hidden, for: .navigationBar) }
      .sheetFitsContent()
      .presentationBackground(Palette.surface)
    #else
    if popover {
      content
        .frame(width: Tokens.Size.popover)
        .frame(maxHeight: Tokens.Size.allRowsHeight)
    } else {
      content
        .frame(minWidth: Tokens.Size.allRowsWidth, minHeight: Tokens.Size.allRowsHeight)
        .presentationBackground(Palette.surface)
    }
    #endif
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: Tokens.Space.s) { rows }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, Tokens.Space.xl)
      }
      .scrollBounceBehavior(.basedOnSize)
      // No scroll bar (#676): the edge fades and the down chevron say there is more.
      .scrollEdgeHints()
    }
    .padding([.horizontal, .top], Tokens.Space.l)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(ListCap.sheetID)
  }

  /// The title and the line under it, then a round X.
  private var header: some View {
    HStack(alignment: .top, spacing: Tokens.Space.s) {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(title)
          .font(Tokens.Typography.heading)
          .foregroundStyle(Palette.textPrimary)
          .accessibilityAddTraits(.isHeader)
        if let subtitle {
          Text(subtitle)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      Button(action: close) {
        Image(systemName: ListCap.closeSymbol)
      }
      .buttonStyle(.icon(compact: true))
      .keyboardShortcut(.cancelAction)
      .help(Text(ListWords.closeHelp))
      .accessibilityLabel(Text(ListWords.close))
      .accessibilityIdentifier(ListCap.closeID)
    }
  }
}

/// The chevron of a row that opens in place (the board's rows of signals not taken, a config
/// table): pointing on while closed, turned down while open.
public struct ExpandChevron: View {
  let open: Bool

  /// How far the chevron turns when open, in degrees: from pointing on to pointing down.
  static let openDegrees: Double = 90

  public init(open: Bool) {
    self.open = open
  }

  public var body: some View {
    Image(systemName: Symbols.next)
      .font(Tokens.Typography.chevron)
      .foregroundStyle(Palette.textQuaternary)
      .rotationEffect(open ? .degrees(Self.openDegrees) : .zero)
      .accessibilityHidden(true)
  }
}

/// A row that discloses its own detail under it: the whole row is the button, its label then the
/// turning chevron (`ExpandChevron`) at the end. For a card's "more", use a `FooterDetail`.
public struct RowExpander<Label: View, Content: View>: View {
  let label: Label
  let content: () -> Content
  @State private var open = false

  public init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {
    self.label = label()
    self.content = content
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      Button {
        withAnimation(Tokens.Motion.quick) { open.toggle() }
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          label.frame(maxWidth: .infinity, alignment: .leading)
          ExpandChevron(open: open)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(open ? .isSelected : [])
      if open {
        content()
          .frame(maxWidth: .infinity, alignment: .leading)
          .transition(.opacity)
      }
    }
  }
}
