import SwiftUI

// MARK: - the bot's commands

/// A bot command, as the design's `cmd` button: a glyph tile, then the title left-aligned, then an
/// optional short mono detail (the menu bar's "2 positions" after Close all), then (when commands
/// go to the demo day) a small "DEMO" pill. Three looks, never confusable:
/// `secondary` (pause, resume, cancel orders) on the card surface with a glyph tinted in its tone;
/// `destructive` (flatten, stop bot) washed red with a solid red (`lossFill`) glyph tile; `primary` (start the
/// bot) in the accent fill. The emergency stop is its own button (`EmergencyButton`).
///
/// Give it a `Label` (title and SF Symbol). A title never truncates: it wraps onto more lines.
public struct CommandButtonStyle: ButtonStyle {
  public enum Tier: Sendable, Hashable {
    case secondary(Tone), destructive, primary
  }

  /// `regular` in a card or a sheet, `compact` in the menu-bar panel, `small` in a card's header.
  public enum Size: Sendable, Hashable, CaseIterable {
    case regular, compact, small
  }

  let tier: Tier
  let size: Size
  let detail: Text?
  let tag: Text?

  /// - Parameters:
  ///   - detail: a few words after the title in the command's colour, always whole, as the
  ///     number of positions Close all closes.
  ///   - tag: the pill at the trailing end, as "DEMO" while commands go to the demo day.
  public init(_ tier: Tier, size: Size = .regular, detail: Text? = nil, tag: Text? = nil) {
    self.tier = tier
    self.size = size
    self.detail = detail
    self.tag = tag
  }

  public func makeBody(configuration: Configuration) -> some View {
    CommandButtonBody(configuration: configuration, tier: tier, size: size, detail: detail, tag: tag)
  }
}

public extension ButtonStyle where Self == CommandButtonStyle {
  /// `.buttonStyle(.command(.destructive))`, `.buttonStyle(.command(.secondary(.warning), tag: demo))`.
  static func command(
    _ tier: CommandButtonStyle.Tier, size: CommandButtonStyle.Size = .regular, detail: Text? = nil, tag: Text? = nil
  ) -> CommandButtonStyle {
    CommandButtonStyle(tier, size: size, detail: detail, tag: tag)
  }
}

private struct CommandButtonBody: View {
  @Environment(\.isEnabled) private var enabled
  @Environment(\.colorScheme) private var scheme
  @State private var hovered = false
  let configuration: ButtonStyleConfiguration
  let tier: CommandButtonStyle.Tier
  let size: CommandButtonStyle.Size
  let detail: Text?
  let tag: Text?

  var body: some View {
    let small = size == .small
    let shape = RoundedRectangle(cornerRadius: small ? Tokens.Command.smallRadius : Tokens.Command.radius, style: .continuous)
    let pressed = configuration.isPressed && enabled
    configuration.label
      .labelStyle(CommandLabelStyle(tier: tier, small: small, detail: detail, tag: tag))
      .font(small ? Tokens.Typography.buttonCompact : Tokens.Command.title)
      .foregroundStyle(foreground)
      .padding(.leading, small ? Tokens.Space.xxs + Tokens.Stroke.thin : Tokens.Space.xs + Tokens.Space.xxs)
      .padding(.trailing, Tokens.Space.s + Tokens.Space.xxs)
      .padding(.vertical, small ? Tokens.Stroke.thin : Tokens.Space.xs)
      // Fills its cell: a row of commands (`CommandColumns`) gives each the row's height.
      .frame(maxWidth: small ? nil : .infinity, minHeight: height, maxHeight: small ? nil : .infinity,
        alignment: .leading)
      .background { fill(shape, pressed: pressed) }
      .overlay { shape.strokeBorder(border, lineWidth: Tokens.Stroke.thin) }
      .overlay {
        // The light theme's top highlight inside the surface, as the design's inset shadow.
        if scheme == .light && enabled && tier != .primary {
          shape.inset(by: Tokens.Stroke.thin)
            .trim(from: 0, to: 1)
            .stroke(LinearGradient(colors: [Palette.sheen.opacity(Tokens.Opacity.overlay), .clear],
              startPoint: .top, endPoint: .center), lineWidth: Tokens.Stroke.thin)
            .allowsHitTesting(false)
        }
      }
      .shadow(color: enabled ? Palette.shadow.opacity(Tokens.Command.shadowOpacity) : .clear,
        radius: Tokens.Command.shadowRadius, y: Tokens.Command.shadowDrop)
      .contentShape(shape)
      .opacity(enabled ? 1 : Tokens.Command.disabledOpacity)
      .scaleEffect(pressed ? Tokens.Motion.pressScale : 1)
      // Under the pointer an enabled command lifts a point, as the design's buttons do.
      .offset(y: enabled && hovered && !pressed ? -Tokens.Motion.hoverLift : 0)
      .animation(Tokens.Motion.quick, value: pressed)
      .animation(Tokens.Motion.quick, value: hovered)
      .onHover { hovered = $0 }
  }

  private var height: CGFloat {
    switch size {
    case .regular: return Tokens.Command.height
    case .compact: return Tokens.Command.compactHeight
    case .small: return Tokens.Command.smallHeight
    }
  }

  @ViewBuilder private func fill(_ shape: RoundedRectangle, pressed: Bool) -> some View {
    switch tier {
    case .secondary:
      shape.fill(Palette.surface)
        .overlay(shape.fill(Palette.textPrimary.opacity(pressed ? Tokens.Command.pressShade : 0)))
    case .destructive:
      shape.fill(Palette.surface)
        .overlay(shape.fill(Palette.loss.opacity(pressed ? Tokens.Opacity.glow : Tokens.Opacity.wash)))
    case .primary:
      shape.fill(Palette.accentFill)
        .overlay(shape.fill(Palette.textPrimary.opacity(pressed ? Tokens.Command.pressShade : 0)))
    }
  }

  private var foreground: Color {
    switch tier {
    case .secondary: return Palette.textPrimary
    case .destructive: return Palette.lossText
    case .primary: return Palette.onAccent
    }
  }

  /// The border, a step stronger under the pointer.
  private var border: Color {
    let strong = enabled && hovered
    switch tier {
    case .secondary: return strong ? Palette.textQuaternary : Palette.separatorStrong
    case .destructive: return Palette.loss.opacity(strong ? Tokens.Opacity.medium : Tokens.Opacity.border)
    case .primary: return Palette.accentFill
    }
  }
}

/// A command's label: the symbol on its glyph tile, the title (wrapping, never cut), the detail,
/// the tag.
private struct CommandLabelStyle: LabelStyle {
  let tier: CommandButtonStyle.Tier
  let small: Bool
  let detail: Text?
  let tag: Text?

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: small ? Tokens.Space.xs + Tokens.Space.xxs : Tokens.Command.gap) {
      CommandGlyph(icon: configuration.icon, small: small, color: glyphColor, fill: glyphFill)
      configuration.title
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: small ? nil : .infinity, alignment: .leading)
      if let detail {
        detail
          .font(Tokens.Typography.label)
          // A few words: always whole, on one line; the title wraps first.
          .fixedSize()
      }
      if let tag {
        CommandTag(tag)
      }
    }
  }

  private var glyphColor: Color {
    switch tier {
    case .secondary(let tone): return tone.text
    case .destructive: return Palette.onLoss
    case .primary: return Palette.onAccent
    }
  }

  private var glyphFill: Color {
    switch tier {
    case .secondary(let tone): return tone.fill.opacity(Tokens.Opacity.glow)
    case .destructive: return Palette.lossFill
    case .primary: return Palette.sheen.opacity(Tokens.Command.haloOpacity)
    }
  }
}

/// A command's glyph tile. It grows with Dynamic Type (iOS), so a large symbol stays inside it.
private struct CommandGlyph<Icon: View>: View {
  @ScaledMetric(relativeTo: .callout) private var side = Tokens.Command.glyph
  @ScaledMetric(relativeTo: .callout) private var smallSide = Tokens.Command.smallGlyph
  let icon: Icon
  let small: Bool
  let color: Color
  let fill: Color

  var body: some View {
    let tile = RoundedRectangle(cornerRadius: small ? Tokens.Radius.small : Tokens.Command.glyphRadius,
      style: .continuous)
    icon
      .font(Tokens.Typography.symbolCompact)
      .imageScale(.small)
      .foregroundStyle(color)
      .frame(width: small ? smallSide : side, height: small ? smallSide : side)
      .background(tile.fill(fill))
      .accessibilityHidden(true)
  }
}

/// The small violet pill at a command's end while commands go to the demo day ("DEMO"); white on
/// the emergency stop's red. Its edge is dashed like the demo day's `EnvironmentBadge` (the
/// IOSHome board's `.dm`), so the demo reads in one look on every surface.
public struct CommandTag: View {
  let text: Text
  let onFill: Bool

  public init(_ text: Text, onFill: Bool = false) {
    self.text = text
    self.onFill = onFill
  }

  public var body: some View {
    text
      .textCase(.uppercase)
      .font(Tokens.Typography.badge)
      .tracking(Tokens.Typography.badgeTracking)
      .fixedSize()
      .foregroundStyle(onFill ? Palette.onLoss : Palette.highlightText)
      .padding(.horizontal, Tokens.Space.xs + Tokens.Space.xxs)
      .padding(.vertical, Tokens.Space.xxs)
      .background(Capsule().fill(onFill ? Palette.onLoss.opacity(Tokens.Opacity.glow)
        : Palette.highlight.opacity(Tokens.Opacity.glow)))
      .overlay(Capsule().strokeBorder(onFill ? Palette.onLoss.opacity(Tokens.Opacity.medium)
        : Palette.highlight.opacity(Tokens.Opacity.border),
        style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine)))
  }
}

/// The hairline with a small mono caption ("LAST RESORT") that sets the emergency stop apart from
/// the commands above it, so it never sits next to Flatten.
public struct LastResortDivider: View {
  let title: Text

  public init(_ title: Text) {
    self.title = title
  }

  public var body: some View {
    HStack(spacing: Tokens.Space.s) {
      #if os(iOS)
      line
      #endif
      title
        .textCase(.uppercase)
        .font(Tokens.Typography.label)
        .tracking(Tokens.Command.captionTracking)
        .foregroundStyle(Palette.textLabel)
        // Two short words: always on one line; the hairlines give way.
        .fixedSize()
      line
    }
    .padding(.top, Tokens.Space.xxs)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var line: some View {
    Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin).frame(minWidth: Tokens.Space.l)
  }
}

// MARK: - rows of commands

/// Commands side by side in equal columns, as many as fit: up to `columns` when every title fits
/// on one line in its column, fewer otherwise, down to one under another (where a long title
/// wraps). Each row's commands share one height, and a short last row shares the full width.
public struct CommandColumns: Layout {
  let columns: Int
  let spacing: CGFloat

  public init(columns: Int, spacing: CGFloat = Tokens.Space.s) {
    self.columns = columns
    self.spacing = spacing
  }

  /// How many columns fit in `width`, given the widest command's one-line width.
  public static func fitting(_ columns: Int, widest: CGFloat, count: Int, in width: CGFloat, spacing: CGFloat) -> Int {
    var fit = max(min(columns, count), 1)
    while fit > 1 && CGFloat(fit) * widest + CGFloat(fit - 1) * spacing > width {
      fit -= 1
    }
    return fit
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard !subviews.isEmpty else { return .zero }
    let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    let count = max(min(columns, subviews.count), 1)
    let width = proposal.width ?? (CGFloat(count) * widest + CGFloat(count - 1) * spacing)
    let rows = layoutRows(width: width, subviews: subviews)
    let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
    return CGSize(width: width, height: height)
  }

  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in layoutRows(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in row.indices {
        subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: row.cellWidth,
          height: row.height))
        x += row.cellWidth + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    let indices: Range<Int>
    let cellWidth: CGFloat
    let height: CGFloat
  }

  private func layoutRows(width: CGFloat, subviews: Subviews) -> [Row] {
    let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    let fit = Self.fitting(columns, widest: widest, count: subviews.count, in: width, spacing: spacing)
    return stride(from: 0, to: subviews.count, by: fit).map { start in
      let indices = start..<min(start + fit, subviews.count)
      let cellWidth = max((width - CGFloat(indices.count - 1) * spacing) / CGFloat(indices.count), 0)
      let height = indices.map { subviews[$0].sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }
        .max() ?? 0
      return Row(indices: indices, cellWidth: cellWidth, height: height)
    }
  }
}
