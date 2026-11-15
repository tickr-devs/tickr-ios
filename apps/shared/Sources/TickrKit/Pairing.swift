import Foundation

/// The pairing link `python -m tickr.api pair` leaves in its pairing file:
/// `tickr://pair?url=https%3A%2F%2Fmac.tailnet.ts.net&code=...`. The code is not the token: the
/// phone redeems it once at the Mac (`APIClient.redeemPairing`) for its token, so a copy of the link
/// left anywhere is worthless afterwards.
public struct Pairing: Equatable, Sendable {
  public let url: URL
  public let code: String

  /// The pairing link's scheme and host, and the address scheme it must carry.
  static let scheme = "tickr"
  static let pairHost = "pair"
  static let addressScheme = "https"
  /// The pairing link's query item names.
  static let urlField = "url"
  static let codeField = "code"
  /// The query items a pairing link has, and no others.
  static let fields: Set = [urlField, codeField]

  /// Parses a pasted or opened pairing link. Refuses anything that is not exactly that shape:
  /// the address must be HTTPS with a host and no path, query or credentials.
  public static func parse(_ text: String) -> Pairing? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let link = URLComponents(string: trimmed), link.scheme?.lowercased() == Self.scheme,
      link.host?.lowercased() == Self.pairHost, let items = link.queryItems,
      items.count == Self.fields.count, Set(items.map(\.name)) == Self.fields,
      let address = items.first(where: { $0.name == Self.urlField })?.value,
      let code = items.first(where: { $0.name == Self.codeField })?.value,
      !code.isEmpty, code.allSatisfy(Self.isCodeCharacter),
      let target = URLComponents(string: address), target.scheme == Self.addressScheme,
      let host = target.host, !host.isEmpty, target.user == nil, target.password == nil,
      target.path.isEmpty || target.path == "/", target.query == nil, target.fragment == nil,
      let url = target.url
    else { return nil }
    return Pairing(url: url, code: code)
  }

  /// `secrets.token_urlsafe` alphabet.
  static func isCodeCharacter(_ c: Character) -> Bool {
    c.isASCII && (c.isLetter || c.isNumber || c == "-" || c == "_")
  }
}
