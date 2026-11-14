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

  static func time(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }

  static func clock(_ date: Date) -> String {
    date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
  }

  static func day(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
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
        Label { Text(L10n.Connect.title) } icon: { Image(systemName: "desktopcomputer.and.arrow.down") }
      } description: {
        Text(L10n.Connect.body)
      } actions: {
        NavigationLink { SettingsView() } label: { Text(L10n.Connect.openSettings) }
          .buttonStyle(.borderedProminent)
      }
      .rise()
    } else if model.status == nil, let cause = model.fetchError ?? model.response?.unavailableCause {
      ContentUnavailableView {
        Label { Text(L10n.Connect.noStatus) } icon: { Image(systemName: "antenna.radiowaves.left.and.right.slash") }
      } description: {
        Text(verbatim: cause)
      }
      .rise()
    }
  }
}

/// A label and a value in a small card, used in rows of three.
struct StatTile: View {
  /// Smallest scale the value may shrink to before it truncates.
  static let minimumScale = 0.7

  let label: LocalizedStringResource
  let value: String
  var color: Color = Palette.textPrimary

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
      CardLabel(label)
      Text(verbatim: value)
        .font(Tokens.Typography.bodyMono.bold())
        .foregroundStyle(color)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(Self.minimumScale)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.s)
    .apertureCard(radius: Tokens.Radius.large)
    .accessibilityElement(children: .combine)
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
      .background(Palette.warning.opacity(Tokens.Opacity.wash), in: Capsule())
      .overlay(Capsule().strokeBorder(Palette.warning.opacity(Tokens.Opacity.border)))
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
