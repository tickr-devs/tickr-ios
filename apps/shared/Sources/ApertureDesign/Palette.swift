import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The operator apps' colours, from the approved design canvas. Every colour has its own light and
/// dark value (light is a separate palette with its own depth, not an inversion) and follows the
/// system appearance; the apps never offer their own theme switch.
public enum Palette {
    // Surfaces.
    public static let background = Color(light: 0xEEF2FA, dark: 0x070A16)
    public static let card = Color(light: 0xFFFFFF, dark: 0x0E1326)
    public static let deep = Color(light: 0xF6F8FD, dark: 0x0A0F20)
    public static let line = Color(light: 0xE3E8F2, dark: 0x1E2644)
    public static let line2 = Color(light: 0xCFD7E8, dark: 0x2A3459)

    // Text, strongest to weakest.
    public static let text = Color(light: 0x0E1430, dark: 0xE7EAF6)
    public static let text2 = Color(light: 0x262F52, dark: 0xC9CFE6)
    public static let muted = Color(light: 0x475174, dark: 0xA9B2D3)
    public static let dim = Color(light: 0x5F6A8C, dark: 0x8F99BC)

    // Accents. The "strong" variant is for text on a card (it keeps 4.5:1 contrast in both themes);
    // the plain one is for fills, strokes and glows.
    public static let teal = Color(light: 0x0EA5A0, dark: 0x2DD4BF)
    public static let tealStrong = Color(light: 0x0B766F, dark: 0x5EEAD4)
    public static let green = Color(light: 0x10B981, dark: 0x34D399)
    public static let greenStrong = Color(light: 0x047857, dark: 0x6EE7B7)
    public static let pink = Color(light: 0xEC4899, dark: 0xF472B6)
    public static let pinkStrong = Color(light: 0xBE185D, dark: 0xF9A8D4)
    public static let violet = Color(light: 0x8B5CF6, dark: 0xA78BFA)
    public static let violetStrong = Color(light: 0x6D28D9, dark: 0xC4B5FD)
    public static let amber = Color(light: 0xF59E0B, dark: 0xFBBF24)
    public static let amberStrong = Color(light: 0xB45309, dark: 0xFCD34D)
    public static let blue = Color(light: 0x3B82F6, dark: 0x60A5FA)
    public static let blueStrong = Color(light: 0x1D4ED8, dark: 0x93C5FD)
    public static let red = Color(light: 0xEF4444, dark: 0xF87171)
    public static let redStrong = Color(light: 0xB91C1C, dark: 0xFCA5A5)

    /// Fill and text colour for a money result: gains teal/green, losses pink/red, zero muted.
    public static func result(_ value: Decimal) -> Color {
        value > 0 ? greenStrong : value < 0 ? redStrong : muted
    }
}

public extension Color {
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
public struct ApertureBackground: View {
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public var body: some View {
        ZStack {
            Palette.background
            if scheme == .light {
                RadialGradient(
                    colors: [Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255).opacity(0.14), .clear],
                    center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(
                    colors: [Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255).opacity(0.12), .clear],
                    center: UnitPoint(x: 1, y: 0.2), startRadius: 0, endRadius: 380)
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

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(Palette.card))
            .overlay(shape.strokeBorder(tint.map { $0.opacity(0.45) } ?? Palette.line, lineWidth: 1))
            .shadow(
                color: scheme == .light ? Color(red: 40 / 255, green: 60 / 255, blue: 150 / 255).opacity(0.16) : .clear,
                radius: 14, x: 0, y: 8)
    }
}

public extension View {
    /// Wraps the view in the standard card surface.
    func apertureCard(radius: CGFloat = 18, tint: Color? = nil) -> some View {
        modifier(CardStyle(radius: radius, tint: tint))
    }
}

/// The small uppercase monospaced section label used on every card.
public struct CardLabel: View {
    let text: String
    let color: Color

    public init(_ text: String, color: Color = Palette.dim) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}
