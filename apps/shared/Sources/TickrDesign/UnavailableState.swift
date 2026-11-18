import SwiftUI

/// A view with nothing to show because its read was refused or failed, said the same in both
/// apps: a warning symbol (never the calm empty mark), a plain title, and why in the person's
/// language (`ErrorText.cause`), never the API's own words or status. While the link to the bot
/// is down the connection banner says why, so it shows only the quiet outline of content
/// (`OfflineOutline`) instead.
public struct UnavailableState: View {
  /// What the description shows.
  enum Content: Equatable {
    /// The link to the bot is down: the banner speaks, the view waits.
    case waiting
    /// Why the read was refused, in the person's language.
    case cause(String)
    /// No cause was given: the plain message only.
    case message
  }

  let title: LocalizedStringResource
  let message: LocalizedStringResource
  let cause: String?
  @Environment(\.readFailureContext) private var context

  /// `title`: what is unavailable; `message`: a plain line said when no cause is known; `cause`:
  /// why, already in the person's language.
  public init(_ title: LocalizedStringResource, message: LocalizedStringResource, cause: String?) {
    self.title = title
    self.message = message
    self.cause = cause
  }

  /// The description for a cause while the link is up or down; an empty cause says nothing.
  static func content(cause: String?, connectionDown: Bool) -> Content {
    if connectionDown { return .waiting }
    guard let cause, !cause.isEmpty else { return .message }
    return .cause(cause)
  }

  public var body: some View {
    if Self.content(cause: cause, connectionDown: context?.connectionDown ?? false) == .waiting {
      OfflineOutline(Tokens.Loading.lines)
    } else {
      unavailable
    }
  }

  private var unavailable: some View {
    ContentUnavailableView {
      Label { Text(title) } icon: { Image(systemName: Symbols.failure) }
    } description: {
      switch Self.content(cause: cause, connectionDown: context?.connectionDown ?? false) {
      case .waiting:
        EmptyView()
      case .cause(let text):
        Text(verbatim: text)
      case .message:
        Text(message)
      }
    }
  }
}
