import Foundation

/// The pairing link `python -m aperture.api pair` leaves in its pairing file:
/// `aperture://pair?url=https%3A%2F%2Fmac.tailnet.ts.net&token=...`.
public struct Pairing: Equatable, Sendable {
  public let url: URL
  public let token: String

  /// The query items a pairing link has, and no others.
  static let fields: Set = ["url", "token"]

  /// Parses a pasted or opened pairing link. Refuses anything that is not exactly that shape:
  /// the address must be HTTPS with a host and no path, query or credentials.
  public static func parse(_ text: String) -> Pairing? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let link = URLComponents(string: trimmed), link.scheme?.lowercased() == "aperture",
      link.host?.lowercased() == "pair", let items = link.queryItems,
      items.count == fields.count, Set(items.map(\.name)) == fields,
      let address = items.first(where: { $0.name == "url" })?.value,
      let token = items.first(where: { $0.name == "token" })?.value,
      !token.isEmpty, token.allSatisfy(Self.isTokenCharacter),
      let target = URLComponents(string: address), target.scheme == "https",
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
