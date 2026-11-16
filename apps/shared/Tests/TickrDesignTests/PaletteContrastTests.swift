import Foundation
import Testing
@testable import TickrDesign
import TickrKit

/// Every text and its fill in the destructive and emergency command tiers keeps WCAG AA (4.5:1
/// for normal text) in both appearances, computed from the palette's own values. A text drawn at
/// an opacity, and a fill under a shade, are blended first, as the screen shows them.
@Suite struct PaletteContrastTests {
  /// WCAG AA, normal text.
  static let minimum = 4.5

  enum Appearance: String, CaseIterable {
    case light, dark
  }

  /// A colour as sRGB components from 0 to 1.
  struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    init(_ swatch: Swatch, _ appearance: Appearance) {
      let value = appearance == .light ? swatch.light : swatch.dark
      red = Double((value >> 16) & 0xFF) / 255
      green = Double((value >> 8) & 0xFF) / 255
      blue = Double(value & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
      self.red = red
      self.green = green
      self.blue = blue
    }

    /// This colour at `opacity` over `below`.
    func over(_ below: RGB, opacity: Double) -> RGB {
      RGB(red: red * opacity + below.red * (1 - opacity), green: green * opacity + below.green * (1 - opacity),
        blue: blue * opacity + below.blue * (1 - opacity))
    }

    /// WCAG relative luminance.
    var luminance: Double {
      func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
  }

  /// WCAG contrast ratio of two colours.
  static func ratio(_ first: RGB, _ second: RGB) -> Double {
    let lighter = max(first.luminance, second.luminance)
    let darker = min(first.luminance, second.luminance)
    return (lighter + 0.05) / (darker + 0.05)
  }

  /// Each text on its fill, by name.
  static func pairs(_ appearance: Appearance) -> [(String, text: RGB, fill: RGB)] {
    let white = RGB(Swatch.onLoss, appearance)
    let fill = RGB(Swatch.lossFill, appearance)
    let pressed = RGB(Swatch.textPrimary, appearance).over(fill, opacity: Tokens.Command.pressShade)
    let swept = RGB(Swatch.scrim, appearance).over(fill, opacity: Tokens.Command.sweepOpacity)
    let tag = white.over(fill, opacity: Tokens.Opacity.glow)
    let surface = RGB(Swatch.surface, appearance)
    let loss = RGB(Swatch.loss, appearance)
    let lossText = RGB(Swatch.lossText, appearance)
    let washed = loss.over(surface, opacity: Tokens.Opacity.wash)
    let washedPressed = loss.over(surface, opacity: Tokens.Opacity.glow)
    var pairs: [(String, text: RGB, fill: RGB)] = []
    for (name, below) in [("emergency", fill), ("emergency pressed", pressed), ("emergency held", swept)] {
      pairs.append(("\(name) title", white, below))
      pairs.append(("\(name) second line", white.over(below, opacity: Tokens.Command.detailOpacity), below))
      pairs.append(("\(name) hold hint", white.over(below, opacity: Tokens.Opacity.overlay), below))
    }
    pairs.append(("emergency DEMO tag", white, tag))
    pairs.append(("destructive glyph tile", white, fill))
    pairs.append(("destructive title and detail", lossText, washed))
    pairs.append(("destructive pressed", lossText, washedPressed))
    return pairs
  }

  @Test(arguments: Appearance.allCases)
  func commandTiersPassAA(_ appearance: Appearance) {
    for (name, text, fill) in Self.pairs(appearance) {
      let ratio = Self.ratio(text, fill)
      #expect(ratio >= Self.minimum, "\(appearance.rawValue) \(name): \(ratio)")
    }
  }

  /// Every tone's text colour and every verdict's colour is a text role: 4.5:1 on `surface`.
  @Test(arguments: Appearance.allCases)
  func meaningTextsPassAA(_ appearance: Appearance) {
    let surface = RGB(Swatch.surface, appearance)
    let texts: [(String, Swatch)] = Tone.allCases.map { ("tone \($0)", $0.textSwatch) }
      + [Verdict.enter, .hold, .watch, .ignore, .exit].map { ("verdict \($0.rawValue)", $0.textSwatch) }
    for (name, swatch) in texts {
      let ratio = Self.ratio(RGB(swatch, appearance), surface)
      #expect(ratio >= Self.minimum, "\(appearance.rawValue) \(name): \(ratio)")
    }
  }

  /// Why a fill is never text: `info` itself is below 4.5:1 on `surface` in light mode.
  @Test func infoFillIsNotText() {
    #expect(Self.ratio(RGB(Swatch.info, .light), RGB(Swatch.surface, .light)) < Self.minimum)
  }

  /// The ratio itself: white on black is 21:1, and the old dark fill (#F87171) failed.
  @Test func ratioMatchesWCAG() {
    let white = RGB(red: 1, green: 1, blue: 1)
    let black = RGB(red: 0, green: 0, blue: 0)
    #expect(abs(Self.ratio(white, black) - 21) < 0.001)
    let oldDarkFill = RGB(Swatch(light: 0xF87171, dark: 0xF87171), .dark)
    #expect(Self.ratio(white, oldDarkFill) < Self.minimum)
  }
}
