import SwiftUI

/// A card line that opens in place to show more (mockup v134, "More balances ›", "Details ▾"):
/// its title, an optional short summary at the right ("2 · +$3.55"), and the system's disclosure
/// chevron. The details stay one tap away instead of on the card. The same on both apps.
public struct DisclosureLine<Content: View>: View {
  let title: LocalizedStringResource
  let summary: String?
  let summaryColor: Color
  @ViewBuilder let content: Content
  @State private var open = false

  public init(
    _ title: LocalizedStringResource, summary: String? = nil, summaryColor: Color = Palette.textTertiary,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.summary = summary
    self.summaryColor = summaryColor
    self.content = content()
  }

  public var body: some View {
    DisclosureGroup(isExpanded: $open) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        content
      }
      .padding(.top, Tokens.Space.xs)
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      // The whole line opens and closes it: on macOS a disclosure group's label alone does not
      // (only its small triangle did), so a click on "Details" did nothing.
      Button {
        open.toggle()
      } label: {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(title)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.infoText)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: Tokens.Space.s)
          if let summary {
            Text(verbatim: summary)
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(summaryColor)
              .fixedSize()
          }
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
    }
    .animation(Tokens.Motion.standard, value: open)
  }
}
