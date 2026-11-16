import SwiftUI

/// What a card needs to say about a failed read of its own: whether the link to the bot is down
/// (then the connection banner speaks for every card) and the words it uses. Set once at each
/// scene's root (`readFailureContext` in each app), read by every `ReadFailureNote`.
public struct ReadFailureContext: Equatable, Sendable {
  /// The link to the bot is down: cards keep their last known data and leave the failure to the
  /// banner.
  public let connectionDown: Bool
  /// The disclosure's label ("Details").
  public let detailsLabel: LocalizedStringResource
  /// The calm placeholder of a card with nothing to show while the link is down.
  public let waiting: LocalizedStringResource

  public init(connectionDown: Bool, detailsLabel: LocalizedStringResource, waiting: LocalizedStringResource) {
    self.connectionDown = connectionDown
    self.detailsLabel = detailsLabel
    self.waiting = waiting
  }
}

public extension EnvironmentValues {
  /// The context of every `ReadFailureNote` below; nil before a root sets it.
  @Entry var readFailureContext: ReadFailureContext?
}

/// A card's own failed read, said the same everywhere: while the link to the bot is down, a calm
/// "waiting for the connection" (the banner above says why); while it is up, a short plain
/// message, with the technical cause (the API client's words) only behind "Details".
public struct ReadFailureNote: View {
  /// Symbols: a failed read, and a card waiting for the connection.
  public static let failedSymbol = "exclamationmark.triangle.fill"
  static let waitingSymbol = "clock"

  let message: LocalizedStringResource
  let detail: String?
  let tone: Tone
  let defers: Bool
  @Environment(\.readFailureContext) private var context
  @State private var showsDetails = false

  /// `message`: what could not be read, in plain words; `detail`: the technical cause.
  /// `defersToConnection`: false for the failure of something the owner did (a decision, a
  /// command), which is said even while the link is down.
  public init(
    _ message: LocalizedStringResource, detail: String?, tone: Tone = .warning, defersToConnection: Bool = true
  ) {
    self.message = message
    self.detail = detail
    self.tone = tone
    self.defers = defersToConnection
  }

  public var body: some View {
    if defers, let context, context.connectionDown {
      InfoCaption(context.waiting, systemImage: Self.waitingSymbol)
    } else {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        InfoCaption(message, systemImage: Self.failedSymbol, tone: tone)
        if let detail, let label = context?.detailsLabel {
          Button {
            withAnimation(Tokens.Motion.quick) { showsDetails.toggle() }
          } label: {
            HStack(spacing: Tokens.Space.xs) {
              Image(systemName: ConnectionNoticeLook.chevronSymbol)
                .font(Tokens.Typography.chevron)
                .rotationEffect(showsDetails ? .degrees(ConnectionNoticeLook.openDegrees) : .zero)
              Text(label)
            }
            .font(Tokens.Typography.caption.weight(.semibold))
            .foregroundStyle(Palette.textQuaternary)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(showsDetails ? [.isSelected] : [])
          if showsDetails {
            Text(verbatim: detail)
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textTertiary)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, alignment: .leading)
              .textSelection(.enabled)
              .transition(.opacity)
          }
        }
      }
    }
  }
}
