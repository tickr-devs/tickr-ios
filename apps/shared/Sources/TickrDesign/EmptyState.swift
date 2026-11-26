import SwiftUI

/// A view with nothing to show yet, said the same everywhere in both apps: the system's empty
/// state (a quiet SF Symbol, a plain title and an optional line under it), centred in the room it
/// is given (never pinned to a corner of its card). The brand mark is not used here: it stands
/// for the app, not for missing data (owner, 2026-11-25). A refused or failed read is
/// `UnavailableState` instead.
public struct EmptyState: View {
  /// Nothing yet: a calm, normal emptiness.
  public static let nothingSymbol = "tray"
  /// The list could not be read, so its emptiness says nothing.
  public static let unavailableSymbol = "icloud.slash"

  let title: Text
  let detail: Text?
  let symbol: String

  /// `title`: what is missing; `detail`: why or what comes next; `symbol`: `unavailableSymbol`
  /// when the emptiness is not the calm normal (a list that could not be read).
  public init(_ title: Text, detail: Text? = nil, symbol: String = Self.nothingSymbol) {
    self.title = title
    self.detail = detail
    self.symbol = symbol
  }

  public init(
    _ title: LocalizedStringResource, detail: LocalizedStringResource? = nil, symbol: String = Self.nothingSymbol
  ) {
    self.init(Text(title), detail: detail.map { Text($0) }, symbol: symbol)
  }

  public var body: some View {
    ContentUnavailableView {
      Label { title } icon: { Image(systemName: symbol) }
    } description: {
      if let detail { detail }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
