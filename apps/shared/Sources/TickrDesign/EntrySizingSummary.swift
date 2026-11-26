import SwiftUI
import TickrKit

/// The Risk room card's last entry in short (mockup Main): its symbol and time, what was bought,
/// the limit that set the size, and "Limits ›", which opens every sizing limit with the shares it
/// allows and the one that set the size highlighted (`EntrySizingLimits`). With no entry today the
/// popover holds the example stock. The link shows only when there are limits to open.
public struct EntrySizingSummary: View {
  let sizing: EntrySizing
  @State private var open = false

  public init(sizing: EntrySizing) {
    self.sizing = sizing
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        CardLabel(EntrySizing.title)
          .frame(maxWidth: .infinity, alignment: .leading)
        if let meta = sizing.meta {
          Text(verbatim: meta)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
            .fixedSize()
        }
      }
      Text(verbatim: sizing.line)
        .font(Tokens.Typography.calloutMono)
        .fontWeight(.semibold)
        .foregroundStyle(Palette.textPrimary)
        .fixedSize(horizontal: false, vertical: true)
      // The caption beside the link; under it when both do not fit, each wrapping, never cut.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: Tokens.Space.s) {
          caption.frame(maxWidth: .infinity, alignment: .leading)
          limitsLink.fixedSize()
        }
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          caption
          limitsLink
        }
      }
    }
    .padding(.top, Tokens.Space.s)
    .overlay(alignment: .top) {
      Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The limit that set a real entry's size, or why the record cannot say; the example's caption
  /// is in the popover only.
  @ViewBuilder private var caption: some View {
    if sizing.tone != .example, let text = sizing.caption {
      SizingCaption(text: text, color: sizing.captionColor)
    }
  }

  @ViewBuilder private var limitsLink: some View {
    if !sizing.limits.isEmpty {
      HeaderLink(RiskRoomText.limits) { open = true }
        .popover(isPresented: $open, arrowEdge: .bottom) {
          EntrySizingLimits(sizing: sizing)
            .presentationCompactAdaptation(.popover)
        }
    }
  }
}

/// Every sizing limit of the last entry (or of the example stock), in the "Limits ›" popover.
struct EntrySizingLimits: View {
  let sizing: EntrySizing

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(RiskRoomText.limits)
      if let lead = sizing.lead {
        Text(verbatim: lead)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textTertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
      ForEach(Array(sizing.limits.enumerated()), id: \.element.id) { step, limit in
        LimitRow(limit: limit, step: step)
      }
      if let text = sizing.caption {
        SizingCaption(text: text, color: sizing.captionColor)
      }
    }
    .padding(Tokens.Space.l)
    .frame(idealWidth: Tokens.Size.popover, maxWidth: Tokens.Size.popover, alignment: .leading)
    .background(Palette.surface)
  }
}

/// A dot and the caption in its colour: which limit set the size.
struct SizingCaption: View {
  let text: String
  let color: Color

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Circle().fill(color).frame(width: Tokens.Size.dotSmall, height: Tokens.Size.dotSmall)
        .accessibilityHidden(true)
      Text(verbatim: text)
        .font(Tokens.Typography.caption)
        .fontWeight(.semibold)
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
