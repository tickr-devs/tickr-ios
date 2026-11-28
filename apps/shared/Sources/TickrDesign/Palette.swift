import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The operator apps' colours, from the approved design canvas, as semantic roles. Every role has
/// its own light and dark value (light is a separate palette with its own depth, not an inversion)
/// and follows the system appearance; the apps never offer their own theme switch.
///
/// Screens use roles only. Each meaning has a fill variant (strokes, fills, glows) and a `Text`
/// variant that keeps 4.5:1 contrast on `surface` in both appearances. docs/design-system.md lists
/// every value; this file and that table match one to one.
public enum Palette {
  // MARK: surfaces

  /// Window background behind cards.
  public static let background = Color(light: 0xEEF2FA, dark: 0x070A16)
  /// Cards, panels, popovers.
  public static let surface = Color(Swatch.surface)
  /// Inset areas inside a card: charts, wells.
  public static let surfaceSunken = Color(light: 0xF6F8FD, dark: 0x0A0F20)
  /// Card borders, grid lines, tracks of bars and rings.
  public static let separator = Color(light: 0xE3E8F2, dark: 0x1E2644)
  /// Stronger lines: zero lines, radar rings.
  public static let separatorStrong = Color(light: 0xCFD7E8, dark: 0x2A3459)
  /// The Mac window's title bar, above the sidebar and the screen.
  public static let titleBar = Color(light: 0xF3F6FC, dark: 0x0B1022)
  /// The Mac sidebar's column.
  public static let sidebar = Color(light: 0xF1F4FB, dark: 0x0A0E1E)
  /// A selected sidebar row's fill (with a `separatorStrong` hairline).
  public static let selection = Color(light: 0xE3EBFF, dark: 0x172046)

  // MARK: brand

  /// The brand mark's tile (`BrandMark`, the app icon, the launch screen, the tickr.bot site): a
  /// dark tile in every appearance, top to bottom of its gradient, and its hairline edge.
  public static let brandTileTop = Color(light: 0x141A33, dark: 0x141A33)
  public static let brandTileBottom = Color(light: 0x070A16, dark: 0x070A16)
  public static let brandTileEdge = Color(light: 0x2A3459, dark: 0x2A3459)
  /// The mark's letter on the tile.
  public static let brandLetter = Color(light: 0xE7EAF6, dark: 0xE7EAF6)
  /// The mark's level on the tile: teal in every appearance.
  public static let brandLine = Color(light: 0x2DD4BF, dark: 0x2DD4BF)
  /// The level when nothing about the bot can be known (bot unreachable).
  public static let brandMuted = Color(light: 0x5F6A8C, dark: 0x5F6A8C)
  /// ".bot" in the wordmark (`Wordmark`), as the tickr.bot site draws it (its `--wmdot`).
  public static let wordmarkDomain = Color(light: 0x6B7493, dark: 0x7C86A8)

  // MARK: text, strongest to weakest

  /// Headlines and primary values.
  public static let textPrimary = Color(Swatch.textPrimary)
  /// Body text in rows and lists.
  public static let textSecondary = Color(light: 0x262F52, dark: 0xC9CFE6)
  /// Labels next to values, explanations.
  public static let textTertiary = Color(Swatch.textTertiary)
  /// Section labels, captions, placeholders ("—").
  public static let textQuaternary = Color(light: 0x5F6A8C, dark: 0x8F99BC)
  /// Uppercase section labels (card and sidebar headers, metric names): the boards' `.lbl`, a
  /// touch lighter than `textQuaternary` in light mode, the same in dark.
  public static let textLabel = Color(light: 0x6A7495, dark: 0x8F99BC)

  // MARK: meanings

  /// Live and brand: running bot, live flow, the logo, focus.
  public static let accent = Color(Swatch.accent)
  public static let accentText = Color(Swatch.accentText)
  /// Fill of a primary button, and the text drawn on it (4.5:1 in both appearances).
  public static let accentFill = Color(light: 0x0B766F, dark: 0x2DD4BF)
  public static let onAccent = Color(light: 0xFFFFFF, dark: 0x04131A)
  /// The light sheen across the top of a filled control.
  public static let sheen = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
  /// Money gained, a verified stop, healthy state.
  public static let profit = Color(Swatch.profit)
  public static let profitText = Color(Swatch.profitText)
  /// Money lost, a missing stop, an alarm, destructive actions.
  public static let loss = Color(Swatch.loss)
  public static let lossText = Color(Swatch.lossText)
  /// A solid red fill with text or a symbol on it in `onLoss` (the emergency stop, a destructive
  /// command's glyph tile): deeper than `loss`, so white on it keeps 4.5:1 in both appearances
  /// (`loss` itself is for strokes, washes, halos and charts, never behind text).
  public static let lossFill = Color(Swatch.lossFill)
  /// Text and symbols on a solid `lossFill`.
  public static let onLoss = Color(Swatch.onLoss)
  /// Attention: paused, blocked, stale, a closed gate.
  public static let warning = Color(Swatch.warning)
  public static let warningText = Color(Swatch.warningText)
  /// Information and orders: entries, commands in flight, reconciliation.
  public static let info = Color(Swatch.info)
  public static let infoText = Color(Swatch.infoText)
  /// Context that is not live: environment, recorded days, planned (BACKLOG) features.
  public static let highlight = Color(Swatch.highlight)
  public static let highlightText = Color(Swatch.highlightText)

  /// An unselected chip's fill (ranges, intervals, studies; selected chips take `selection`).
  public static let chipFill = Color(light: 0xF3F6FD, dark: 0x111834)

  // MARK: chart series

  /// A candle that closed at or above its open: its wick and edge (the Chart board's `--teal`).
  public static let candleUp = accent
  /// The body of a rising candle: the teal at three quarters (the board's
  /// `color-mix(var(--teal) 75%, transparent)`), so the edge reads around it.
  public static let candleUpBody = accent.opacity(0.75)
  /// A candle that closed below its open: wick, edge and solid body (the board's `--pink`, the
  /// pink of a loss in the apps; red stays for danger).
  public static let candleDown = seriesATR
  /// VWAP line.
  public static let seriesVWAP = warning
  /// Fast EMA line.
  public static let seriesFastEMA = accent
  /// Slow EMA line.
  public static let seriesSlowEMA = highlight
  /// ATR line and its label.
  public static let seriesATR = Color(Swatch.seriesATR)
  public static let seriesATRText = Color(Swatch.seriesATRText)
  /// Universe filter stage in the live flow.
  public static let seriesUniverse = seriesATR
  /// The live-flow stages that no meaning above colours (mockup v151: nine stages, nine hues). Each
  /// has a fill (dots, rings, bars, glows) and a `Text` variant for words (4.5:1 on `surface`).
  /// Priced.
  public static let cyan = Color(Swatch.cyan)
  public static let cyanText = Color(Swatch.cyanText)
  /// Bought.
  public static let orange = Color(Swatch.orange)
  public static let orangeText = Color(Swatch.orangeText)
  /// Checked (the broker matches our records).
  public static let lime = Color(Swatch.lime)
  public static let limeText = Color(Swatch.limeText)

  /// A symbol the funnel dropped (mockup v100: pink; red stays for danger).
  public static let dropped = seriesATR
  public static let droppedText = seriesATRText
  /// The ticker dots falling through the funnel sheet's bars (`FunnelDrops`, mockup v159): white
  /// with a glow of it, in both appearances, and their dark rim (at `Opacity.funnelDropRim`).
  public static let funnelDrop = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
  public static let funnelDropRim = Color(light: 0x000000, dark: 0x000000)

  // MARK: light-mode depth

  /// The two soft corner glows of the light background (indigo top left, teal right).
  public static let glowIndigo = Color(light: 0x6366F1, dark: 0x6366F1)
  public static let glowTeal = Color(light: 0x14B8A6, dark: 0x14B8A6)
  /// Blue-tinted card shadow in light mode.
  public static let shadow = Color(light: 0x283C96, dark: 0x283C96)
  /// Deep navy behind an overlay panel (the Mac "Watching closely" list), at `Opacity.faint`, and its shadow.
  public static let scrim = Color(Swatch.scrim)

  /// Text colour for a money result: gains profit, losses the series pink, zero tertiary, by the
  /// value as shown (`Tone.result`, the one place the sign of a result picks its colour).
  public static func result(_ value: Decimal) -> Color {
    Tone.result(value).text
  }

  // MARK: hue names (iOS app until it moves to roles)

  @available(*, deprecated, renamed: "surface") public static var card: Color { surface }
  @available(*, deprecated, renamed: "surfaceSunken") public static var deep: Color { surfaceSunken }
  @available(*, deprecated, renamed: "separator") public static var line: Color { separator }
  @available(*, deprecated, renamed: "separatorStrong") public static var line2: Color { separatorStrong }
  @available(*, deprecated, renamed: "textPrimary") public static var text: Color { textPrimary }
  @available(*, deprecated, renamed: "textSecondary") public static var text2: Color { textSecondary }
  @available(*, deprecated, renamed: "textTertiary") public static var muted: Color { textTertiary }
  @available(*, deprecated, renamed: "textQuaternary") public static var dim: Color { textQuaternary }
  @available(*, deprecated, renamed: "accent") public static var teal: Color { accent }
  @available(*, deprecated, renamed: "accentText") public static var tealStrong: Color { accentText }
  @available(*, deprecated, renamed: "profit") public static var green: Color { profit }
  @available(*, deprecated, renamed: "profitText") public static var greenStrong: Color { profitText }
  @available(*, deprecated, renamed: "seriesATR") public static var pink: Color { seriesATR }
  @available(*, deprecated, renamed: "seriesATRText") public static var pinkStrong: Color { seriesATRText }
  @available(*, deprecated, renamed: "highlight") public static var violet: Color { highlight }
  @available(*, deprecated, renamed: "highlightText") public static var violetStrong: Color { highlightText }
  @available(*, deprecated, renamed: "warning") public static var amber: Color { warning }
  @available(*, deprecated, renamed: "warningText") public static var amberStrong: Color { warningText }
  @available(*, deprecated, renamed: "info") public static var blue: Color { info }
  @available(*, deprecated, renamed: "infoText") public static var blueStrong: Color { infoText }
  @available(*, deprecated, renamed: "loss") public static var red: Color { loss }
  @available(*, deprecated, renamed: "lossText") public static var redStrong: Color { lossText }
}

/// The raw light and dark values (0xRRGGBB) of the roles the bot's command tiers pair as text and
/// fill, kept as numbers so a test can compute their contrast (`PaletteContrastTests`).
public struct Swatch: Sendable, Hashable {
  public let light: UInt32
  public let dark: UInt32

  public init(light: UInt32, dark: UInt32) {
    self.light = light
    self.dark = dark
  }

  public static let surface = Swatch(light: 0xFFFFFF, dark: 0x0E1326)
  public static let textPrimary = Swatch(light: 0x0E1430, dark: 0xE7EAF6)
  public static let loss = Swatch(light: 0xEF4444, dark: 0xF87171)
  public static let lossText = Swatch(light: 0xB91C1C, dark: 0xFCA5A5)
  /// The text roles a tone, a verdict or a headline may draw text in (each 4.5:1 on `surface`).
  public static let textTertiary = Swatch(light: 0x475174, dark: 0xA9B2D3)
  public static let accentText = Swatch(light: 0x0B766F, dark: 0x5EEAD4)
  public static let profitText = Swatch(light: 0x047857, dark: 0x6EE7B7)
  public static let warningText = Swatch(light: 0xB45309, dark: 0xFCD34D)
  public static let infoText = Swatch(light: 0x1D4ED8, dark: 0x93C5FD)
  public static let highlightText = Swatch(light: 0x6D28D9, dark: 0xC4B5FD)
  public static let seriesATRText = Swatch(light: 0xBE185D, dark: 0xF9A8D4)
  public static let cyanText = Swatch(light: 0x0E7490, dark: 0x22D3EE)
  public static let orangeText = Swatch(light: 0xC2410C, dark: 0xFB923C)
  public static let limeText = Swatch(light: 0x4D7C0F, dark: 0xA3E635)
  /// `info` itself, a fill: below 4.5:1 on `surface` in light mode, so never text (a test proves it).
  public static let info = Swatch(light: 0x3B82F6, dark: 0x60A5FA)
  /// The fills of the live flow's nine stages (`PipelineStage.fillSwatch`), with `info`.
  public static let accent = Swatch(light: 0x0EA5A0, dark: 0x2DD4BF)
  public static let profit = Swatch(light: 0x10B981, dark: 0x34D399)
  public static let warning = Swatch(light: 0xF59E0B, dark: 0xFBBF24)
  public static let highlight = Swatch(light: 0x8B5CF6, dark: 0xA78BFA)
  public static let seriesATR = Swatch(light: 0xEC4899, dark: 0xF472B6)
  public static let cyan = Swatch(light: 0x0891B2, dark: 0x22D3EE)
  public static let orange = Swatch(light: 0xEA580C, dark: 0xFB923C)
  public static let lime = Swatch(light: 0x65A30D, dark: 0xA3E635)
  public static let lossFill = Swatch(light: 0xB91C1C, dark: 0x991B1B)
  public static let onLoss = Swatch(light: 0xFFFFFF, dark: 0xFFFFFF)
  public static let scrim = Swatch(light: 0x080C1E, dark: 0x080C1E)
}

public extension Color {
  /// A colour with a swatch's light and dark values.
  init(_ swatch: Swatch) {
    self.init(light: swatch.light, dark: swatch.dark)
  }

  /// A colour with separate light and dark appearance values, given as 0xRRGGBB.
  init(light: UInt32, dark: UInt32) {
    #if canImport(UIKit)
    self.init(uiColor: UIColor { traits in
      UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
    })
    #elseif canImport(AppKit)
    self.init(nsColor: NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return NSColor(rgb: isDark ? dark : light)
    })
    #endif
  }
}

#if canImport(UIKit)
extension UIColor {
  convenience init(rgb: UInt32) {
    self.init(
      red: CGFloat((rgb >> 16) & 0xFF) / 255,
      green: CGFloat((rgb >> 8) & 0xFF) / 255,
      blue: CGFloat(rgb & 0xFF) / 255,
      alpha: 1)
  }
}
#elseif canImport(AppKit)
extension NSColor {
  convenience init(rgb: UInt32) {
    self.init(
      srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
      green: CGFloat((rgb >> 8) & 0xFF) / 255,
      blue: CGFloat(rgb & 0xFF) / 255,
      alpha: 1)
  }
}
#endif

/// The app background: flat dark ink in dark mode; in light mode a pale blue-grey with two soft
/// indigo and teal glows in the corners, as on the canvas.
public struct TickrBackground: View {
  @Environment(\.colorScheme) private var scheme

  /// How far each light-mode glow reaches from its centre, in points.
  static let glowRadius: CGFloat = 420
  /// Centre of the teal glow: the right edge, a fifth of the way down.
  static let tealGlowCenter = UnitPoint(x: 1, y: 0.2)

  public init() {}

  public var body: some View {
    ZStack {
      Palette.background
      if scheme == .light {
        RadialGradient(
          colors: [Palette.glowIndigo.opacity(Tokens.Opacity.glow), .clear],
          center: .topLeading, startRadius: 0, endRadius: Self.glowRadius)
        RadialGradient(
          colors: [Palette.glowTeal.opacity(Tokens.Opacity.glow), .clear],
          center: Self.tealGlowCenter, startRadius: 0, endRadius: Self.glowRadius)
      }
    }
    .ignoresSafeArea()
  }
}

/// A rounded card: hairline border in dark mode; white with a soft blue-tinted shadow in light mode.
public struct CardStyle: ViewModifier {
  @Environment(\.colorScheme) private var scheme
  let radius: CGFloat
  let tint: Color?
  /// The card's fill: `surface`, or `surfaceSunken` for a console-like card (the Mac journal).
  var fill = Palette.surface

  public func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    content
      .background(shape.fill(fill))
      .overlay(shape.strokeBorder(tint.map { $0.opacity(Tokens.Opacity.border) } ?? Palette.separator,
        lineWidth: Tokens.Stroke.thin))
      .shadow(
        color: scheme == .light ? Palette.shadow.opacity(Tokens.Opacity.shadow) : .clear,
        radius: Tokens.Size.shadowRadius, x: 0, y: Tokens.Size.shadowOffset)
  }
}

public extension View {
  /// Wraps the view in the standard card surface.
  func tickrCard(radius: CGFloat = Tokens.Radius.card, tint: Color? = nil, fill: Color = Palette.surface) -> some View {
    modifier(CardStyle(radius: radius, tint: tint, fill: fill))
  }
}

/// The small uppercase monospaced section label used on every card. Its title is a localization
/// key (String Catalog), shown uppercase in the person's language.
public struct CardLabel: View {
  let title: Text
  let color: Color

  public init(_ title: LocalizedStringResource, color: Color = Palette.textLabel) {
    self.title = Text(title)
    self.color = color
  }

  /// Text that is already localized or is data (a symbol). Prefer the localized initializer.
  @_disfavoredOverload
  public init(_ text: String, color: Color = Palette.textLabel) {
    self.title = Text(verbatim: text)
    self.color = color
  }

  public var body: some View {
    title
      .textCase(.uppercase)
      .font(Tokens.Typography.label)
      .tracking(Tokens.Typography.labelTracking)
      .foregroundStyle(color)
      .accessibilityAddTraits(.isHeader)
  }
}
