import SwiftUI

// Small animated pieces shared by the operator apps. Motion is part of the design on every screen;
// each piece falls back to a still version when the person has Reduce Motion on.

/// A status dot with a ring that keeps expanding and fading out, meaning "live".
public struct PulseDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    let color: Color
    let size: CGFloat
    let pulsing: Bool

    public init(_ color: Color, size: CGFloat = 8, pulsing: Bool = true) {
        self.color = color
        self.size = size
        self.pulsing = pulsing
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                if pulsing && !reduceMotion {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .scaleEffect(expanded ? 2.2 : 1)
                        .opacity(expanded ? 0 : 0.7)
                        .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false), value: expanded)
                }
            }
            .onAppear { expanded = true }
            .accessibilityHidden(true)
    }
}

/// Fades a view in while it rises a few points, after `delay`; staggered delays make a screen
/// assemble itself on appear.
public struct Rise: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    let delay: Double

    public func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(delay)) { shown = true }
            }
    }
}

public extension View {
    func rise(_ delay: Double = 0) -> some View { modifier(Rise(delay: delay)) }
}

/// A ring that fills to `fraction` (0...1) with a soft breathing halo behind it.
public struct ResultRing<Center: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var breathing = false
    let fraction: Double
    let color: Color
    let lineWidth: CGFloat
    let center: Center

    public init(fraction: Double, color: Color, lineWidth: CGFloat = 10, @ViewBuilder center: () -> Center) {
        self.fraction = min(max(fraction, 0), 1)
        self.color = color
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.4), .clear], center: .center, startRadius: 0, endRadius: 60))
                .padding(10)
                .scaleEffect(breathing ? 1.08 : 1)
                .opacity(breathing ? 0.95 : 0.55)
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: drawn ? fraction : 0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.2, dampingFraction: 0.9), value: fraction)
            center
        }
        .padding(lineWidth / 2)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 1.4, dampingFraction: 0.9)) { drawn = true }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { breathing = true }
            }
        }
    }
}

/// A line through `values`, scaled to fill its frame. Animates when the values change.
public struct Sparkline: Shape {
    public var values: [Double]

    public init(_ values: [Double]) { self.values = values }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let low = values.min(), let high = values.max() else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        let span = high - low == 0 ? 1 : high - low
        for (index, value) in values.enumerated() {
            let point = CGPoint(
                x: rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1),
                y: rect.maxY - rect.height * CGFloat((value - low) / span))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// One entry of the scrolling event ticker.
public struct TickerItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let tag: String
    public let text: String
    public let tone: Tone

    public enum Tone: Sendable { case teal, green, blue, amber, violet, red, muted }

    public init(id: String, tag: String, text: String, tone: Tone) {
        self.id = id
        self.tag = tag
        self.text = text
        self.tone = tone
    }
}

extension TickerItem.Tone {
    var color: Color {
        switch self {
        case .teal: return Palette.tealStrong
        case .green: return Palette.greenStrong
        case .blue: return Palette.blueStrong
        case .amber: return Palette.amberStrong
        case .violet: return Palette.violetStrong
        case .red: return Palette.redStrong
        case .muted: return Palette.muted
        }
    }
}

/// A slowly scrolling strip of recent events (a marquee), paused when `moving` is false or Reduce
/// Motion is on; then it is an ordinary horizontal scroll view.
public struct Ticker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0
    let items: [TickerItem]
    let moving: Bool
    /// Points per second.
    let speed: Double

    public init(_ items: [TickerItem], moving: Bool = true, speed: Double = 22) {
        self.items = items
        self.moving = moving
        self.speed = speed
    }

    public var body: some View {
        Group {
            if moving && !reduceMotion && !items.isEmpty {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let offset = contentWidth > 0 ? -CGFloat((t * speed).truncatingRemainder(dividingBy: Double(contentWidth))) : 0
                    HStack(spacing: 0) {
                        row.background(GeometryReader { proxy in
                            Color.clear.preference(key: WidthKey.self, value: proxy.size.width)
                        })
                        row
                    }
                    .offset(x: offset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onPreferenceChange(WidthKey.self) { contentWidth = $0 }
                .clipped()
            } else {
                ScrollView(.horizontal, showsIndicators: false) { row }
            }
        }
        .mask(LinearGradient(
            stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06),
                    .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
            startPoint: .leading, endPoint: .trailing))
        .accessibilityElement(children: .combine)
    }

    private var row: some View {
        HStack(spacing: 22) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    Text(item.tag).fontWeight(.bold).foregroundStyle(item.tone.color)
                    Text(item.text).foregroundStyle(Palette.muted)
                }
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .fixedSize()
            }
        }
        .padding(.trailing, 22)
    }

    private struct WidthKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}
