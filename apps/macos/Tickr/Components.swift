import SwiftUI
import TickrDesign
import TickrKit

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

  /// Tone of the menu-bar panel's banner: the design draws a calm headline in the accent (live),
  /// not in profit green.
  var bannerTone: Tone {
    switch self {
    case .ok: return .accent
    case .attention: return .warning
    case .alarm: return .loss
    }
  }

  /// SF Symbols of the menu-bar extra for each severity.
  static let okSymbol = "chart.line.uptrend.xyaxis"
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

/// A money value whose digits roll when it changes.
struct MoneyText: View {
  let value: Decimal
  var usd = false
  var font: Font = Tokens.Typography.bodyMono
  var colored = true
  /// A result carries its sign ("+12.40"); an amount such as the room left does not ("292.00").
  var signed = true
  /// Greyed: a figure as of an older moment, not the current one.
  var muted = false
  /// A colour for an uncoloured figure (the risk room's room left in the accent), instead of the
  /// primary text colour.
  var tint: Color?

  var body: some View {
    Text(verbatim: text)
      .font(font)
      .foregroundStyle(muted ? Palette.textQuaternary : colored ? Palette.result(value) : tint ?? Palette.textPrimary)
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
  var symbol: String?

  init(_ label: LocalizedStringResource, value: String, color: Color = Palette.textPrimary, symbol: String? = nil) {
    self.label = Text(label)
    self.value = value
    self.color = color
    self.symbol = symbol
  }

  init(label: Text, value: String, color: Color = Palette.textPrimary, symbol: String? = nil) {
    self.label = label
    self.value = value
    self.color = color
    self.symbol = symbol
  }

  var body: some View {
    ValueRow(label, systemImage: symbol) {
      Text(verbatim: value).foregroundStyle(color)
    }
  }
}

extension EnvironmentValues {
  /// Whether cards grow to the height they are offered (cards sharing a grid row), instead of
  /// hugging their content.
  @Entry var cardFills = false
  /// Whether a card's header leads with the glowing tone tick (the Overview board); the other
  /// screens' designs label their cards plainly.
  @Entry var cardTicks = true
}

extension View {
  /// Cards in this view grow to the height they are offered, so a grid row's cards line up.
  func filling() -> some View {
    environment(\.cardFills, true)
  }

  /// Cards in this view label themselves plainly, without the tone tick.
  func plainCardLabels() -> some View {
    environment(\.cardTicks, false)
  }
}

extension View {
  /// A cell of a screen's card grid: grows with the window but asks for only a column's least
  /// width, so a long line (a journal entry) cannot make the grid look too wide to fit.
  func gridColumn() -> some View {
    frame(minWidth: Tokens.Size.gridColumnMin, idealWidth: Tokens.Size.gridColumnMin, maxWidth: .infinity,
      maxHeight: .infinity, alignment: .top)
  }
}

/// A card: a section header (glowing tick in the card's tone, label, accessory), then the content.
struct Card<Trailing: View, Content: View>: View {
  @Environment(\.cardFills) private var fills
  @Environment(\.cardTicks) private var ticks
  let title: Text
  var tint: Color?
  var tone: Tone
  /// The card's fill (`CardStyle.fill`).
  var fill: Color
  let trailing: Trailing
  let content: Content

  init(
    _ title: LocalizedStringResource, tint: Color? = nil, tone: Tone = .accent, fill: Color = Palette.surface,
    @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content
  ) {
    self.title = Text(title)
    self.tint = tint
    self.tone = tone
    self.fill = fill
    self.trailing = trailing()
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      if ticks {
        SectionHeader(title, tone: tone) { trailing }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          title
            .textCase(.uppercase)
            .font(Tokens.Typography.label)
            .tracking(Tokens.Typography.labelTracking)
            .foregroundStyle(Palette.textQuaternary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
          Spacer(minLength: Tokens.Space.s)
          trailing
        }
      }
      // A card sharing a row of a set height scrolls under its header when its content is taller.
      if fills {
        ScrollsWhenTall {
          VStack(alignment: .leading, spacing: Tokens.Space.m) { content }
        }
      } else {
        content
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, maxHeight: fills ? .infinity : nil, alignment: .topLeading)
    .tickrCard(radius: Tokens.Radius.large, tint: tint, fill: fill)
  }
}

extension Card where Trailing == EmptyView {
  init(_ title: LocalizedStringResource, tint: Color? = nil, tone: Tone = .accent, @ViewBuilder content: () -> Content) {
    self.init(title, tint: tint, tone: tone, trailing: { EmptyView() }, content: content)
  }
}

/// Content at its own height when the space offered holds it, else in a scroll view of that
/// height: a card in a row of a fixed height (the Overview's middle row) scrolls inside instead
/// of growing the row.
struct ScrollsWhenTall<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ViewThatFits(in: .vertical) {
      content
      ScrollView(.vertical) { content }.scrollBounceBehavior(.basedOnSize)
    }
  }
}

/// A quiet "Details ›" action in a card header or under a message: the ghost button with a
/// chevron, optionally led by a symbol.
struct MoreButton: View {
  let title: Text
  var systemImage: String?
  let action: () -> Void

  init(_ title: LocalizedStringResource, systemImage: String? = nil, action: @escaping () -> Void) {
    self.title = Text(title)
    self.systemImage = systemImage
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: Tokens.Space.xs) {
        if let systemImage { Image(systemName: systemImage) }
        title
        Chevron()
      }
    }
    .buttonStyle(.action(.ghost, size: .compact))
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
    Label {
      text.foregroundStyle(color)
    } icon: {
      Image(systemName: InfoCaption.infoSymbol).foregroundStyle(color.opacity(Tokens.Opacity.overlay))
    }
    .labelStyle(ControlLabelStyle())
    .font(Tokens.Typography.caption)
  }
}

/// Dates, times and numbers as the app shows them. Times are market time (New York); words come
/// from the String Catalog.
enum Format {
  /// Market time zone: every time the app shows is New York time.
  static let newYork = TimeZone(identifier: "America/New_York") ?? .current
  /// Placeholder for a value the app does not have.
  static let missing = "—"
  /// Joins the items of a list ("Gainers, Most active") and the lines of a tooltip.
  static let listSeparator = ", "
  static let lineSeparator = "\n"
  /// Joins the parts of a one-line summary ("1 min +0.06 · 5 min +0.14").
  static let itemSeparator = " · "
  /// Up to this many seconds an age reads in seconds, beyond it in minutes.
  static let secondsShownUpTo = 120
  /// Seconds in a minute.
  static let secondsPerMinute = 60

  /// "14:42:08" in New York time (market time), 24-hour whatever the Mac's clock setting.
  static func marketTime(_ date: Date?) -> String {
    guard let date else { return missing }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = newYork
    return date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
      timeZone: newYork, calendar: calendar))
  }

  /// "14:42" in New York time, 24-hour (`.twoDigits(amPM: .omitted)` would show 02:42).
  static func marketMinute(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = newYork
    return date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
      timeZone: newYork, calendar: calendar))
  }

  /// Date styles of a chart over several sessions or months, in New York time and the person's
  /// language.
  private static func chartStyle(_ style: Date.FormatStyle) -> Date.FormatStyle {
    var style = style
    style.timeZone = newYork
    return style
  }

  /// "Fri 13": the session a five-day axis label starts.
  static func chartSessionDay(_ date: Date) -> String {
    date.formatted(chartStyle(Date.FormatStyle().weekday(.abbreviated).day()))
  }

  /// "Fri 13 14:30": a candle of a five-day chart.
  static func chartSessionMinute(_ date: Date) -> String {
    "\(chartSessionDay(date)) \(marketMinute(date))"
  }

  /// "Fri Nov 13": a daily candle.
  static func chartDay(_ date: Date) -> String {
    date.formatted(chartStyle(Date.FormatStyle().weekday(.abbreviated).month(.abbreviated).day()))
  }

  /// "Nov 9": a weekly candle (its Monday), or the week a one-month axis label starts.
  static func chartMonthDay(_ date: Date) -> String {
    date.formatted(chartStyle(Date.FormatStyle().month(.abbreviated).day()))
  }

  /// "Nov 2026": a monthly candle.
  static func chartMonthYear(_ date: Date) -> String {
    date.formatted(chartStyle(Date.FormatStyle().month(.abbreviated).year()))
  }

  /// "Nov" on a long axis; "2026" where a year begins.
  static func chartMonth(_ date: Date) -> String {
    let january = WireDate.newYork.component(.month, from: date) == 1
    return date.formatted(chartStyle(january ? Date.FormatStyle().year() : Date.FormatStyle().month(.abbreviated)))
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
    String(localized: L10n.Format.seconds(secondsNumber(value)))
  }

  /// "5" for 5.00, "0.5" for 0.50: a setting in seconds without trailing zeros.
  static func secondsNumber(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  /// "4 s": an age or duration in whole seconds, rounded.
  static func wholeSeconds(_ value: Decimal) -> String {
    Money.plain(value, fractionDigits: 0)
  }

  /// "250.00 USD": an amount from the bot's settings.
  static func usd(_ value: Decimal) -> String {
    String(localized: L10n.Format.usd(Money.plain(value)))
  }

  /// "Momentum v3": a strategy and its version.
  static func strategy(_ strategy: StrategyId) -> String {
    String(localized: L10n.Common.strategyVersion(strategy.name, strategy.version))
  }

  /// The same for a strategy named in a decision record.
  static func strategy(_ strategy: StrategyRefV1) -> String {
    String(localized: L10n.Common.strategyVersion(strategy.name, strategy.version))
  }

  static func quantity(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
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

extension AppModel {
  /// Id of the ticker's placeholder item when nothing happened yet.
  static let quietTickerID = "quiet"

  /// The event ticker's entries: the live day's events, newest first, or the recorded day's
  /// closed trades. Shared by Overview's live flow and the strip on top of the other screens.
  var tickerItems: [TickerItem] {
    guard let status, isLive else {
      return shownTrades.map {
        TickerItem(id: $0.tradeId, tag: Board.exitReasonTitle($0.exitReason).uppercased(),
          text: "\($0.symbol) \(Money.signed($0.resultGrossUsd.value))",
          tone: $0.resultGrossUsd.value >= 0 ? .green : .red)
      }
    }
    let events = Board.events(status)
    if events.isEmpty {
      return [TickerItem(id: Self.quietTickerID, tag: String(localized: L10n.Flow.quietTag),
        text: String(localized: L10n.Flow.nothingYet), tone: .muted)]
    }
    return events.map { TickerItem(id: $0.id, tag: $0.tag, text: $0.text, tone: $0.tone.tickerTone) }
  }
}

/// The design's event strip under the title bar: the ticker across the screen's whole width on a
/// sunken bar with a hairline below. Every section but Overview, whose live flow carries it.
struct EventStrip: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Ticker(model.tickerItems, moving: model.isLive)
      .frame(height: Tokens.Size.ticker)
      .padding(.horizontal, Tokens.Space.l)
      .padding(.vertical, Tokens.Space.xs)
      .background(Palette.surfaceSunken)
      .overlay(alignment: .bottom) {
        Rectangle().fill(Palette.separator).frame(height: Tokens.Stroke.thin)
      }
  }
}
