import ApertureDesign
import ApertureKit
import SwiftUI

// The macOS app's building blocks. Every size, colour and curve comes from the design system
// (docs/design-system.md); screens compose these and do not restyle them.

extension Severity {
  /// Text colour of a headline with this severity.
  var color: Color {
    switch self {
    case .ok: return Palette.profitText
    case .attention: return Palette.warningText
    case .alarm: return Palette.lossText
    }
  }

  /// SF Symbols of the menu-bar extra for each severity.
  static let okSymbol = "camera.aperture"
  static let attentionSymbol = "pause.circle"
  static let alarmSymbol = "exclamationmark.triangle.fill"

  var menuBarSymbol: String {
    switch self {
    case .ok: return Self.okSymbol
    case .attention: return Self.attentionSymbol
    case .alarm: return Self.alarmSymbol
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
    Text(kind == .backlog ? L10n.Planned.backlog : L10n.Planned.needsAPI)
      .font(Tokens.Typography.badge)
      .padding(.horizontal, Tokens.Space.xs)
      .padding(.vertical, Tokens.Space.xxs)
      .foregroundStyle(Palette.highlightText)
      .overlay(
        RoundedRectangle(cornerRadius: Tokens.Radius.small)
          .strokeBorder(Palette.highlight, style: StrokeStyle(lineWidth: Tokens.Stroke.thin, dash: Tokens.Stroke.dashFine)))
      .help(Text(kind == .backlog ? L10n.Planned.backlogHelp : L10n.Planned.needsAPIHelp))
  }
}

/// A capsule badge with a mono label in a role colour.
struct Badge: View {
  let text: Text
  let color: Color

  init(_ title: LocalizedStringResource, color: Color) {
    self.text = Text(title)
    self.color = color
  }

  /// A badge showing data (an environment name, a protocol value), not a sentence.
  init(verbatim text: String, color: Color) {
    self.text = Text(verbatim: text)
    self.color = color
  }

  var body: some View {
    text
      .textCase(.uppercase)
      .font(Tokens.Typography.badge)
      .tracking(Tokens.Typography.badgeTracking)
      .padding(.horizontal, Tokens.Space.s)
      .padding(.vertical, Tokens.Space.xs)
      .foregroundStyle(color)
      .background(color.opacity(Tokens.Opacity.wash), in: Capsule())
      .overlay(Capsule().strokeBorder(color.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin))
  }
}

/// A money value whose digits roll when it changes.
struct MoneyText: View {
  let value: Decimal
  var usd = false
  var font: Font = Tokens.Typography.bodyMono
  var colored = true
  /// A result carries its sign ("+12.40"); an amount such as the room left does not ("292.00").
  var signed = true

  var body: some View {
    Text(verbatim: text)
      .font(font)
      .foregroundStyle(colored ? Palette.result(value) : Palette.textPrimary)
      .contentTransition(.numericText(value: NSDecimalNumber(decimal: value).doubleValue))
      .animation(Tokens.Motion.quick, value: value)
  }

  private var text: String {
    switch (signed, usd) {
    case (true, true): Money.signedUSD(value)
    case (true, false): Money.signed(value)
    case (false, true): Format.usd(value)
    case (false, false): Money.plain(value)
    }
  }
}

/// "label ........ value" on one line. The label is a localization key; the value is data (a
/// number, a price) or an already localized word.
struct StatLine: View {
  let label: Text
  let value: String
  var color: Color = Palette.textPrimary

  init(_ label: LocalizedStringResource, value: String, color: Color = Palette.textPrimary) {
    self.label = Text(label)
    self.value = value
    self.color = color
  }

  init(label: Text, value: String, color: Color = Palette.textPrimary) {
    self.label = label
    self.value = value
    self.color = color
  }

  var body: some View {
    HStack {
      label.foregroundStyle(Palette.textTertiary)
      Spacer(minLength: Tokens.Space.m)
      Text(verbatim: value)
        .font(Tokens.Typography.bodyMono)
        .foregroundStyle(color)
        .contentTransition(.numericText())
    }
    .font(Tokens.Typography.callout)
  }
}

/// A card: section label on top, optional trailing accessory, then the content.
struct Card<Trailing: View, Content: View>: View {
  let title: Text
  var tint: Color?
  let trailing: Trailing
  let content: Content

  init(_ title: LocalizedStringResource, tint: Color? = nil, @ViewBuilder trailing: () -> Trailing,
    @ViewBuilder content: () -> Content) {
    self.title = Text(title)
    self.tint = tint
    self.trailing = trailing()
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      HStack(alignment: .firstTextBaseline) {
        title
          .textCase(.uppercase)
          .font(Tokens.Typography.label)
          .tracking(Tokens.Typography.labelTracking)
          .foregroundStyle(Palette.textQuaternary)
          .accessibilityAddTraits(.isHeader)
        Spacer()
        trailing
      }
      content
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .apertureCard(tint: tint)
  }
}

extension Card where Trailing == EmptyView {
  init(_ title: LocalizedStringResource, tint: Color? = nil, @ViewBuilder content: () -> Content) {
    self.init(title, tint: tint, trailing: { EmptyView() }, content: content)
  }
}

/// A short caption under a card's content (where a value comes from, why a control is off).
struct Footnote: View {
  let text: Text
  var color: Color = Palette.textQuaternary

  init(_ text: LocalizedStringResource, color: Color = Palette.textQuaternary) {
    self.text = Text(text)
    self.color = color
  }

  /// A message that is already localized (an error from the API client).
  init(verbatim text: String, color: Color = Palette.textQuaternary) {
    self.text = Text(verbatim: text)
    self.color = color
  }

  var body: some View {
    text.font(Tokens.Typography.caption).foregroundStyle(color)
  }
}

/// The aperture mark: six blades turning slowly inside a ring.
struct ApertureLogo: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var size: CGFloat = Tokens.Size.logo

  /// Number of blades.
  static let blades = 6
  /// Seconds for one full turn of the blades (slower than other rotating marks: it is decoration).
  static let turnSeconds = 24.0
  /// Blade start and end as a share of the radius, and the angle each blade spans, in radians.
  static let bladeOuter = 0.75
  static let bladeInner = 0.5
  static let bladeSweep = 1.2
  /// Radius of the centre dot as a share of the radius.
  static let core = 0.22

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { context in
      let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
        .truncatingRemainder(dividingBy: Self.turnSeconds) / Self.turnSeconds
      Canvas { graphics, canvas in
        draw(in: graphics, size: canvas, turn: turn)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private func draw(in graphics: GraphicsContext, size canvas: CGSize, turn: Double) {
    let radius = min(canvas.width, canvas.height) / 2
    let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
    let ring = CGRect(origin: .zero, size: canvas).insetBy(dx: Tokens.Stroke.thin, dy: Tokens.Stroke.thin)
    graphics.stroke(Path(ellipseIn: ring), with: .color(Palette.highlight), lineWidth: Tokens.Stroke.bold)
    let full = Geometry.fullTurn
    for blade in 0..<Self.blades {
      let angle = (turn + Double(blade) / Double(Self.blades)) * full
      var path = Path()
      path.move(to: point(center, radius * Self.bladeOuter, angle))
      path.addLine(to: point(center, radius * Self.bladeInner, angle + Self.bladeSweep))
      graphics.stroke(path, with: .color(Palette.accent), style: StrokeStyle(lineWidth: Tokens.Stroke.bold, lineCap: .round))
    }
    let coreRadius = radius * Self.core
    let core = CGRect(origin: center, size: .zero).insetBy(dx: -coreRadius, dy: -coreRadius)
    graphics.fill(Path(ellipseIn: core), with: .color(Palette.highlight.opacity(Tokens.Opacity.overlay)))
  }

  private func point(_ center: CGPoint, _ distance: Double, _ angle: Double) -> CGPoint {
    CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle))
  }
}

/// Dates, times and numbers as the app shows them. Times are market time (New York); words come
/// from the String Catalog.
enum Format {
  /// Market time zone: every time the app shows is New York time.
  static let newYork = TimeZone(identifier: "America/New_York") ?? .current
  /// Placeholder for a value the app does not have.
  static let missing = "—"
  /// Up to this many seconds an age reads in seconds, beyond it in minutes.
  static let secondsShownUpTo = 120
  /// Seconds in a minute.
  static let secondsPerMinute = 60

  /// "10:42:08" in New York time (market time).
  static func marketTime(_ date: Date?) -> String {
    guard let date else { return missing }
    var style = Date.FormatStyle(date: .omitted, time: .standard)
    style.timeZone = newYork
    return date.formatted(style)
  }

  /// "14:42" in New York time, 24-hour (`.twoDigits(amPM: .omitted)` would show 02:42).
  static func marketMinute(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = newYork
    return date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
      timeZone: newYork, calendar: calendar))
  }

  /// "Fri Nov 13" in the person's language.
  static func dayLabel(_ day: WireDate) -> String {
    var style = Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()
    style.timeZone = newYork
    return day.noonInNewYork.formatted(style)
  }

  /// "3 s ago", "2 min ago".
  static func age(since date: Date?, now: Date) -> String {
    guard let date else { return String(localized: L10n.Format.never) }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < secondsShownUpTo { return String(localized: L10n.Format.secondsAgo(seconds)) }
    return String(localized: L10n.Format.minutesAgo(seconds / secondsPerMinute))
  }

  static func price(_ value: Decimal?) -> String {
    guard let value else { return missing }
    return Money.plain(value)
  }

  /// "5 s": a duration from the bot's settings.
  static func seconds(_ value: Decimal) -> String {
    String(localized: L10n.Format.seconds(Money.plain(value)))
  }

  /// "250.00 USD": an amount from the bot's settings.
  static func usd(_ value: Decimal) -> String {
    String(localized: L10n.Format.usd(Money.plain(value)))
  }

  /// "Momentum v3": a strategy and its version.
  static func strategy(_ strategy: StrategyId) -> String {
    String(localized: L10n.Common.strategyVersion(strategy.name, strategy.version))
  }

  static func quantity(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }
}

/// Facts about the running app, read from its bundle rather than written into views.
enum AppInfo {
  /// Info.plist key of the product name.
  static let bundleNameKey = "CFBundleName"

  /// The product name shown in the header ("Aperture"), from the bundle or the process.
  static var name: String {
    Bundle.main.object(forInfoDictionaryKey: bundleNameKey) as? String ?? ProcessInfo.processInfo.processName
  }
}

extension StreamHealth {
  /// The quote stream's state in the person's language.
  var title: String {
    switch self {
    case .fresh: return String(localized: L10n.Stream.fresh)
    case .quiet: return String(localized: L10n.Stream.quiet)
    case .lost: return String(localized: L10n.Stream.lost)
    case .off: return String(localized: L10n.Stream.off)
    }
  }
}

extension BotState {
  /// The bot's state in the person's language.
  var title: String {
    switch self {
    case .starting: return String(localized: L10n.BotState.starting)
    case .running: return String(localized: L10n.BotState.running)
    case .stopping: return String(localized: L10n.BotState.stopping)
    case .stopped: return String(localized: L10n.BotState.stopped)
    }
  }
}

/// Plane geometry the drawings share.
enum Geometry {
  /// One full turn, in radians.
  static let fullTurn = Double.pi * 2
}
