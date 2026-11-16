import SwiftUI

// MARK: - environment

/// The environment the bot runs in, as one badge on every screen of both apps: the Mac window's
/// header, the Mac menu-bar panel, Settings on the Mac and the phone, the phone's Home header.
/// One look everywhere (docs/design-system.md, "Badge"): a `Badge` in the environment's tone, the
/// name in capitals; the demo day also gets a dashed edge, so it never passes for a real
/// environment. The name comes in from the app, already localized; nothing here is a word.
public struct EnvironmentBadge: View {
  /// The environments the bot reports in its status `environment` field (TickrKit's
  /// `BotEnvironment`); a value the app does not know draws as `unknown`.
  public enum Kind: String, Sendable, CaseIterable {
    /// Webull's sandbox: paper money, the only environment the bot trades in for now.
    case sandbox
    /// Webull's production account: real money, so it draws in the alarm colour.
    case production
    /// `tickr demo`: a recorded day replayed, no broker at all.
    case demo
    /// A value newer than the app: shown as a plain fact, never as a known environment.
    case unknown

    /// The environment of the bot's status value (`"sandbox"`), `unknown` for anything else.
    public init(raw: String) {
      self = Kind(rawValue: raw) ?? .unknown
    }

    /// The badge's colour role: Sandbox amber, Production red, the demo day violet.
    public var tone: Tone {
      switch self {
      case .sandbox: return .warning
      case .production: return .loss
      case .demo: return .highlight
      case .unknown: return .neutral
      }
    }

    /// Whether the edge is dashed: only the demo day, which is not a broker environment.
    public var dashed: Bool { self == .demo }
  }

  let name: String
  let kind: Kind
  let label: String

  /// - Parameters:
  ///   - name: The environment's localized name ("Sandbox"); drawn in capitals.
  ///   - raw: The bot's status value ("sandbox"), which picks the colour.
  ///   - accessibilityLabel: What VoiceOver reads, the same on every screen
  ///     ("Environment: Sandbox", TickrKit's `ApiText.environmentLabel`).
  public init(_ name: String, raw: String, accessibilityLabel: String) {
    self.name = name
    self.kind = Kind(raw: raw)
    self.label = accessibilityLabel
  }

  public var body: some View {
    Badge(Text(verbatim: name), fill: kind.tone.fill, color: kind.tone.text, planned: false, dashed: kind.dashed)
      .accessibilityLabel(Text(verbatim: label))
  }
}
