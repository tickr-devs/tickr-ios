import SwiftUI

public extension Tokens {
  /// The bot's command buttons on both apps (`CommandButtonStyle`, `EmergencyButton`): three tiers,
  /// secondary, destructive and the emergency stop, as the design's `cmd` and `emg` buttons.
  enum Command {
    #if os(iOS)
    /// Least height of a command, in points: a full-width row of a sheet, over a touch target.
    public static let height: CGFloat = 50
    /// Least height of the emergency stop, two lines inside.
    public static let emergencyHeight: CGFloat = 62
    /// Corner radius of a command.
    public static let radius: CGFloat = 14
    /// The emergency stop's glyph: a round tile this wide, and its symbol (17 pt).
    public static let emergencyGlyph: CGFloat = 30
    public static let emergencySymbolFont = Font.system(.body, weight: .semibold)
    /// Command title (16 pt at the default size; follows Dynamic Type).
    public static let title = Font.system(.callout, weight: .semibold)
    /// The emergency stop's title and its second line (11 pt at the default size).
    public static let emergencyTitle = Font.system(.callout, weight: .bold)
    public static let detail = Font.system(.caption2, weight: .medium)
    /// Space between a command's glyph tile and its title, in points.
    public static let gap: CGFloat = 12
    #else
    /// Least height of a command, in points.
    public static let height: CGFloat = 36
    /// Least height of the emergency stop, two lines inside.
    public static let emergencyHeight: CGFloat = 38
    /// Corner radius of a command.
    public static let radius: CGFloat = 10
    /// The emergency stop's glyph: a tile this wide, and its symbol (17 pt, the design's 20 px
    /// octagon).
    public static let emergencyGlyph: CGFloat = 26
    public static let emergencySymbolFont = Font.system(.title2, weight: .semibold)
    /// Command title (13 pt semibold), the emergency stop's title and its second line (11 pt): the
    /// Mac's body and subheadline text styles.
    public static let title = Font.system(.body, weight: .semibold)
    public static let emergencyTitle = Font.system(.body, weight: .bold)
    public static let detail = Font.system(.subheadline, weight: .medium)
    /// Space between a command's glyph tile and its title, in points.
    public static let gap: CGFloat = 8
    #endif
    /// Least height of a compact command (the menu-bar panel), in points.
    public static let compactHeight: CGFloat = 32
    /// A small command in a card's header (the Safety card's Stop bot): least height and glyph
    /// tile side, in points.
    public static let smallHeight: CGFloat = 26
    public static let smallGlyph: CGFloat = 20
    /// The glyph tile before a command's title: side and corner radius, in points.
    public static let glyph: CGFloat = 24
    public static let glyphRadius: CGFloat = 7
    /// Width of the emergency stop's outer halo, in points.
    public static let halo: CGFloat = 3
    /// Opacity of the emergency stop's halo, of its second line's white, of the hold sweep's
    /// dark shade (`Palette.scrim`), and of the shade a pressed command darkens by.
    public static let haloOpacity = 0.22
    public static let detailOpacity = 0.8
    public static let sweepOpacity = 0.28
    public static let pressShade = 0.06
    /// Opacity of a disabled command (the design's `:disabled`).
    public static let disabledOpacity = 0.38
    /// The soft shadow under a command: radius and drop, in points, and its opacity.
    public static let shadowRadius: CGFloat = 2
    public static let shadowDrop: CGFloat = 1
    public static let shadowOpacity = 0.08
    /// Seconds the emergency stop is held on the Mac before its confirmation opens (the design's
    /// 1.5 s press-and-hold), and how far, in points, the pointer may move while holding.
    public static let holdSeconds = 1.5
    public static let holdSlop: CGFloat = 12
    /// Letter spacing of the "LAST RESORT" caption above the emergency stop, in points.
    public static let captionTracking: CGFloat = 1
  }
}
