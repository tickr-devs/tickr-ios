import SwiftUI

/// What a card needs to say about a failed read of its own: whether the link to the bot is down
/// (then the connection banner speaks for every card) and the words it uses. Set once at each
/// scene's root (`readFailureContext` in each app), read by every `ReadFailureNote`.
public struct ReadFailureContext: Equatable, Sendable {
  /// The link to the bot is down: cards keep their last known data and leave the failure to the
  /// banner.
  public let connectionDown: Bool
  /// The link is down and nothing was ever read: a card has nothing true to show, so it shows its
  /// outline (`OfflineOutline`), never zeros, "nothing today" or an error of its own.
  public let noData: Bool
  /// The disclosure's label ("Details").
  public let detailsLabel: LocalizedStringResource
  /// The calm placeholder of a card with nothing to show while the link is down.
  public let waiting: LocalizedStringResource

  public init(
    connectionDown: Bool, noData: Bool = false, detailsLabel: LocalizedStringResource,
    waiting: LocalizedStringResource
  ) {
    self.connectionDown = connectionDown
    self.noData = noData
    self.detailsLabel = detailsLabel
    self.waiting = waiting
  }
}

public extension EnvironmentValues {
  /// The context of every `ReadFailureNote` below; nil before a root sets it.
  @Entry var readFailureContext: ReadFailureContext?
}

/// A card's own failed read, said the same everywhere: while the link to the bot is down, nothing
/// at all (the one connection banner says why, owner 2026-11-18: no card repeats it); while it
/// is up, a short plain message, with the technical cause (the API client's words) only behind
/// "Details".
public struct ReadFailureNote: View {
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
      EmptyView()
    } else {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        InfoCaption(message, systemImage: Symbols.failure, tone: tone)
        if let detail, let label = context?.detailsLabel {
          Button {
            withAnimation(Tokens.Motion.quick) { showsDetails.toggle() }
          } label: {
            HStack(spacing: Tokens.Space.xs) {
              Image(systemName: Symbols.next)
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
