import Foundation

/// The pairing link `python -m tickr.api pair` leaves in its pairing file:
/// `tickr://pair?url=https%3A%2F%2Fmac.tailnet.ts.net&token=...`.
public struct Pairing: Equatable, Sendable {
  public let url: URL
  public let token: String

  /// The pairing link's scheme and host, and the address scheme it must carry.
  static let scheme = "tickr"
  static let pairHost = "pair"
  static let addressScheme = "https"
  /// The pairing link's query item names.
  static let urlField = "url"
  static let tokenField = "token"
  /// The query items a pairing link has, and no others.
  static let fields: Set = [urlField, tokenField]

  /// Parses a pasted or opened pairing link. Refuses anything that is not exactly that shape:
  /// the address must be HTTPS with a host and no path, query or credentials.
  public static func parse(_ text: String) -> Pairing? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let link = URLComponents(string: trimmed), link.scheme?.lowercased() == Self.scheme,
      link.host?.lowercased() == Self.pairHost, let items = link.queryItems,
      items.count == Self.fields.count, Set(items.map(\.name)) == Self.fields,
      let address = items.first(where: { $0.name == Self.urlField })?.value,
      let token = items.first(where: { $0.name == Self.tokenField })?.value,
      !token.isEmpty, token.allSatisfy(Self.isTokenCharacter),
      let target = URLComponents(string: address), target.scheme == Self.addressScheme,
      let host = target.host, !host.isEmpty, target.user == nil, target.password == nil,
      target.path.isEmpty || target.path == "/", target.query == nil, target.fragment == nil,
      let url = target.url
    else { return nil }
    return Pairing(url: url, token: token)
  }

  /// `secrets.token_urlsafe` alphabet.
  static func isTokenCharacter(_ c: Character) -> Bool {
    c.isASCII && (c.isLetter || c.isNumber || c == "-" || c == "_")
  }
}
