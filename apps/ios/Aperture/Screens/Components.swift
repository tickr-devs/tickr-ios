import ApertureDesign
import ApertureKit
import SwiftUI

extension Severity {
  var tint: Color {
    switch self {
    case .ok: return Palette.accentText
    case .attention: return Palette.warningText
    case .alarm: return Palette.lossText
    }
  }
}

extension Board.Event.Tone {
  var ticker: TickerItem.Tone {
    switch self {
    case .teal: return .teal
    case .green: return .green
    case .blue: return .blue
    case .amber: return .amber
    case .violet: return .violet
    case .red: return .red
    case .muted: return .muted
    }
  }

  var color: Color {
    switch self {
    case .teal: return Palette.accent
    case .green: return Palette.profit
    case .blue: return Palette.info
    case .amber: return Palette.warning
    case .violet: return Palette.highlight
    case .red: return Palette.loss
    case .muted: return Palette.textQuaternary
    }
  }
}

extension StopState {
  var isProtected: Bool { self == .verified }
}

extension BotState {
  /// The bot's state as a person reads it.
  var title: LocalizedStringResource {
    switch self {
    case .starting: return L10n.BotState.starting
    case .running: return L10n.BotState.running
    case .stopping: return L10n.BotState.stopping
    case .stopped: return L10n.BotState.stopped
    }
  }
}

extension StreamHealth {
  /// The quote stream's health as a person reads it.
  var title: LocalizedStringResource {
    switch self {
    case .fresh: return L10n.Stream.fresh
    case .quiet: return L10n.Stream.quiet
    case .lost: return L10n.Stream.lost
    case .off: return L10n.Stream.off
    }
  }
}

extension StatusV1 {
  /// The bot may open a position now: no entry block, no operator pause, and the trading gate open.
  var entriesAllowed: Bool { entryBlock == nil && !entryStop && tradingGate.open }

  /// Entries are held only by an ordinary state the bot reports without attention (its own trade
  /// open, outside the regular session, after the last entry time, no session today): a calm
  /// "not now", grey, never a warning.
  var entriesCalm: Bool {
    guard let entryBlock, !entryBlock.attention else { return false }
    return !entryStop && tradingGate.open
  }
}

extension DecimalString {
  var signedMoney: String { Money.signed(value) }
}

/// Money and time formatting used across screens.
enum Format {
  /// Shown where a value is missing.
  static let missing = "—"
  /// Percent sign after a number.
  static let percentSign = "%"
  /// Between the two times of a trade.
  static let timeRange = "–"
  /// Between a trade's entry and its exit price.
  static let arrow = " → "
  /// Between two facts on one line.
  static let separator = " · "
  /// Between two figures of one tile, such as MAE and MFE.
  static let slash = " / "

  /// "14:06": 24-hour New York time, as the design shows every time and the bot keeps its
  /// sessions, whatever the phone's clock setting and time zone.
  static func time(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
      timeZone: WireDate.newYork.timeZone, calendar: WireDate.newYork))
  }

  /// "14:06:09", the same with seconds.
  static func clock(_ date: Date) -> String {
    date.formatted(Date.VerbatimFormatStyle(
      format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
      timeZone: WireDate.newYork.timeZone, calendar: WireDate.newYork))
  }

  /// "Fri, Nov 13" in the person's language: the New York day, as the bot keeps its sessions,
  /// whatever the phone's time zone (noon in New York is already the next day from UTC+7 eastward).
  static func day(_ date: Date) -> String {
    var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
    style.timeZone = WireDate.newYork.timeZone
    return date.formatted(style)
  }

  static func timeOrDash(_ time: WireTime?) -> String {
    time.map { clock($0.date) } ?? missing
  }

  /// "updated 3 s ago" from the API's age of the status document.
  static func age(_ response: StatusResponseV1?) -> LocalizedStringResource {
    guard let response, let age = response.ageSeconds else { return L10n.Age.none }
    let seconds = NSDecimalNumber(decimal: age.value).intValue
    return response.stale ? L10n.Age.stale(seconds) : L10n.Age.updated(seconds)
  }
}

extension DynamicTypeSize {
  /// Rows of several parts (a symbol, figures, a tag) stack their parts from the largest standard
  /// text size up, so words and figures stay whole instead of breaking letter by letter.
  var stacksRows: Bool { self >= .xxxLarge }
}

/// A row at ordinary text sizes that becomes a leading-aligned column when the text size
/// `stacksRows`; alignment and spacing as an `HStack`'s.
struct RowStack<Content: View>: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  let alignment: VerticalAlignment
  let spacing: CGFloat?
  let content: Content

  init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
    self.alignment = alignment
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    let layout = typeSize.stacksRows
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
      : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
    layout { content }
  }
}

/// Every tab draws on the same background and keeps its own navigation stack.
struct Screen<Content: View>: View {
  let title: LocalizedStringResource
  let content: Content

  init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Tokens.Space.m) { content }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.bottom, Tokens.Space.xl)
    }
    .scrollContentBackground(.hidden)
    .background(ApertureBackground())
    .navigationTitle(Text(title))
  }
}

/// Shown instead of data when the phone has no address for the bot or cannot reach it.
struct ConnectionPrompt: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    if !model.isConfigured {
      ContentUnavailableView {
        Label { Text(L10n.Connect.title) } icon: { BrandMark.empty() }
      } description: {
        Text(L10n.Connect.body)
      } actions: {
        NavigationLink { SettingsView() } label: { Text(L10n.Connect.openSettings) }
          .buttonStyle(.action(.primary))
      }
      .rise()
    } else if model.status == nil, let cause = model.fetchError ?? model.response?.unavailableCause {
      ContentUnavailableView {
        Label { Text(L10n.Connect.noStatus) } icon: { BrandMark.empty(.muted) }
      } description: {
        Text(verbatim: cause)
      }
      .rise()
    }
  }
}

/// A label and a value in a small card, used in rows of three.
struct StatTile: View {
  let label: LocalizedStringResource
  let value: String
  var color: Color = Palette.textPrimary

  var body: some View {
    MetricChip(label, value: value, tone: tone, color: color)
  }

  /// The chip's rail: the value's colour when it carries a meaning, else none.
  private var tone: Tone? {
    switch color {
    case Palette.profitText: return .profit
    case Palette.lossText: return .loss
    case Palette.warningText: return .warning
    default: return nil
    }
  }
}

/// The environment badge (SANDBOX / PRODUCTION) from the status document.
struct EnvironmentBadge: View {
  let environment: String

  var body: some View {
    Text(verbatim: environment.uppercased())
      .font(Tokens.Typography.badge)
      .tracking(Tokens.Typography.badgeTracking)
      .padding(.horizontal, Tokens.Space.s)
      .padding(.vertical, Tokens.Space.xs)
      .foregroundStyle(Palette.warningText)
      .background(Palette.warning.opacity(Tokens.Opacity.wash), in: RoundedRectangle(cornerRadius: Tokens.Radius.small))
      .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.small).strokeBorder(Palette.warning.opacity(Tokens.Opacity.border)))
      .accessibilityLabel(Text(L10n.Connect.environment(environment)))
  }
}

/// The command notice floating at the top of the screen, with haptics, gone after a few seconds.
struct NoticeOverlay: ViewModifier {
  /// Seconds a notice stays on screen.
  static let seconds = 4.0

  @Environment(AppModel.self) private var model

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        if let notice = model.notice {
          Text(verbatim: notice.text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color(notice.tone))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.m)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: Palette.shadow.opacity(Tokens.Opacity.shadow), radius: Tokens.Size.shadowRadius,
              y: Tokens.Size.shadowOffset)
            .padding(.horizontal, Tokens.Space.xl)
            .padding(.top, Tokens.Space.s)
            .transition(.move(edge: .top).combined(with: .opacity))
            .id(notice.id)
            .task(id: notice.id) {
              try? await Task.sleep(for: .seconds(Self.seconds))
              if model.notice?.id == notice.id { model.notice = nil }
            }
            .onTapGesture { model.notice = nil }
        }
      }
      .animation(Tokens.Motion.standard, value: model.notice)
      .sensoryFeedback(trigger: model.notice) { _, new in
        switch new?.tone {
        case .success: return .success
        case .failure: return .error
        case .info: return .impact(weight: .light)
        case nil: return nil
        }
      }
  }

  private func color(_ tone: Notice.Tone) -> Color {
    switch tone {
    case .info: return Palette.infoText
    case .success: return Palette.profitText
    case .failure: return Palette.lossText
    }
  }
}

/// A position's protection as a compact shield glyph: green when the broker stop is verified, red
/// otherwise, pulsing once each time its state or price changes while unprotected. Its hint names the
/// symbol and the state.
struct StopGlyph: View {
  let state: StopState
  let symbol: String
  /// The stop's price: a moved stop is a change too.
  var price: DecimalString?

  /// Symbols of the stop states, and of a stop level next to a price.
  static let verifiedSymbol = "checkmark.shield.fill"
  static let pendingSymbol = "hourglass"
  static let missingSymbol = "xmark.shield.fill"
  static let unknownSymbol = "exclamationmark.shield.fill"
  static let levelSymbol = "shield.lefthalf.filled"

  var body: some View {
    StateGlyph(glyph, tone: tone, label: Text(verbatim: symbol + Format.separator + Board.stopStateTitle(state)),
      live: !state.isProtected, event: [AnyHashable(state), AnyHashable(price)], style: .compact)
  }

  private var glyph: String { Self.stateSymbol(state) }

  private var tone: Tone { Self.stateTone(state) }

  /// The symbol of a stop state: a checked shield, an hourglass, a crossed or an exclaimed shield.
  static func stateSymbol(_ state: StopState) -> String {
    switch state {
    case .verified: return Self.verifiedSymbol
    case .pending: return Self.pendingSymbol
    case .missing: return Self.missingSymbol
    case .unknown: return Self.unknownSymbol
    }
  }

  /// The tone of a stop state: green verified, amber pending, red missing or unknown.
  static func stateTone(_ state: StopState) -> Tone {
    switch state {
    case .verified: return .profit
    case .pending: return .warning
    case .missing, .unknown: return .loss
    }
  }
}

/// A settings row's leading icon, as iOS settings draw them: a white symbol on a small solid tile
/// in the row's tone. Decorative: the row's own label carries the meaning.
struct SettingsIcon: View {
  let systemImage: String
  let tone: Tone

  init(_ systemImage: String, tone: Tone) {
    self.systemImage = systemImage
    self.tone = tone
  }

  var body: some View {
    Image(systemName: systemImage)
      .font(Tokens.Typography.caption.weight(.semibold))
      .foregroundStyle(Palette.sheen)
      .frame(width: Tokens.Size.iconButtonCompact, height: Tokens.Size.iconButtonCompact)
      .background(tone.fill, in: RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
      .accessibilityHidden(true)
  }
}

/// A form row with a `SettingsIcon` in front of its label and any value view after it.
struct SettingsRow<Value: View>: View {
  let label: LocalizedStringResource
  let systemImage: String
  let tone: Tone
  let value: Value

  init(_ label: LocalizedStringResource, systemImage: String, tone: Tone, @ViewBuilder value: () -> Value) {
    self.label = label
    self.systemImage = systemImage
    self.tone = tone
    self.value = value()
  }

  var body: some View {
    LabeledContent {
      value
    } label: {
      Label { Text(label) } icon: { SettingsIcon(systemImage, tone: tone) }
    }
  }
}
