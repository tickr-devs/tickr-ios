import ApertureDesign
import ApertureKit
import SwiftUI

extension Severity {
    var color: Color {
        switch self {
        case .ok: return Palette.greenStrong
        case .attention: return Palette.amberStrong
        case .alarm: return Palette.redStrong
        }
    }

    var fill: Color {
        switch self {
        case .ok: return Palette.green
        case .attention: return Palette.amber
        case .alarm: return Palette.red
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .ok: return "camera.aperture"
        case .attention: return "pause.circle"
        case .alarm: return "exclamationmark.triangle.fill"
        }
    }
}

/// A small marker for something that is not built yet: BACKLOG (planned) or NEEDS API (a
/// proposal that needs a new local-API read or command).
struct PlannedTag: View {
    enum Kind { case backlog, needsAPI }
    let kind: Kind

    init(_ kind: Kind = .backlog) { self.kind = kind }

    var body: some View {
        Text(kind == .backlog ? "BACKLOG" : "NEEDS API")
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .foregroundStyle(Palette.violetStrong)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.violet, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            .help(kind == .backlog ? "Planned, not built yet (docs/backlog.md)." : "Needs a new local-API read or command.")
    }
}

/// A rounded capsule badge with a mono label.
struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1))
    }
}

/// A money value whose digits roll when it changes.
struct MoneyText: View {
    let value: Decimal
    var usd = false
    var size: CGFloat = 15
    var weight: Font.Weight = .semibold
    var colored = true

    var body: some View {
        Text(usd ? Money.signedUSD(value) : Money.signed(value))
            .font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundStyle(colored ? Palette.result(value) : Palette.text)
            .contentTransition(.numericText(value: NSDecimalNumber(decimal: value).doubleValue))
            .animation(.snappy, value: value)
    }
}

/// "label ........ value" on one line, value monospaced.
struct StatLine: View {
    let label: String
    let value: String
    var color: Color = Palette.text

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Palette.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .font(.callout)
    }
}

/// A card with a label row on top.
struct Card<Trailing: View, Content: View>: View {
    let title: String
    var tint: Color?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                CardLabel(title)
                Spacer()
                trailing
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .apertureCard(tint: tint)
    }
}

extension Card where Trailing == EmptyView {
    init(_ title: String, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tint = tint
        self.trailing = EmptyView()
        self.content = content()
    }
}

/// The aperture mark: six blades turning slowly inside a ring.
struct ApertureLogo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 56

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let angle = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 24) / 24 * 360
            Canvas { gc, canvas in
                let r = min(canvas.width, canvas.height) / 2
                let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                gc.stroke(Path(ellipseIn: CGRect(x: c.x - r + 1, y: c.y - r + 1, width: 2 * r - 2, height: 2 * r - 2)),
                          with: .color(Palette.violet), lineWidth: 2)
                for blade in 0..<6 {
                    let a = (angle + Double(blade) * 60) * .pi / 180
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + r * 0.75 * cos(a), y: c.y + r * 0.75 * sin(a)))
                    p.addLine(to: CGPoint(x: c.x + r * 0.5 * cos(a + 1.2), y: c.y + r * 0.5 * sin(a + 1.2)))
                    gc.stroke(p, with: .color(Palette.teal), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
                gc.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.22, y: c.y - r * 0.22, width: r * 0.44, height: r * 0.44)),
                        with: .color(Palette.violet.opacity(0.85)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A sparkline that draws itself in on appear and when its values change.
struct DrawnSparkline: View {
    let values: [Double]
    let color: Color
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Sparkline(values)
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .onAppear { draw() }
            .onChange(of: values) { draw() }
            .accessibilityHidden(true)
    }

    private func draw() {
        progress = reduceMotion ? 1 : 0
        withAnimation(.easeOut(duration: 1.6)) { progress = 1 }
    }
}

enum Format {
    static let newYork = TimeZone(identifier: "America/New_York")!

    /// "10:42:08" in New York time (market time).
    static func marketTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        var style = Date.FormatStyle(date: .omitted, time: .standard)
        style.timeZone = newYork
        return date.formatted(style)
    }

    /// "10:42" in New York time.
    static func marketMinute(_ date: Date) -> String {
        var style = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
        style.timeZone = newYork
        return date.formatted(style)
    }

    /// "Fri Nov 13".
    static func dayLabel(_ day: WireDate) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = newYork
        return day.noonInNewYork.formatted(style)
    }

    /// "3 s ago", "2 min ago".
    static func age(since date: Date?, now: Date) -> String {
        guard let date else { return "never" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        return seconds < 120 ? "\(seconds) s ago" : "\(seconds / 60) min ago"
    }

    static func price(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return Money.plain(value)
    }

    static func quantity(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
