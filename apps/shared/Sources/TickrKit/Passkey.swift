import Foundation

/// A passkey challenge for the system's passkey sheet (WebAuthn request options).
public struct PasskeyChallenge: Equatable, Sendable {
  public let challenge: Data
  public let relyingParty: String

  init(_ payload: HeadlessPayload?) throws(AccountError) {
    guard let key = payload?.requestOptions?.publicKey, let challenge = Base64URL.decode(key.challenge) else {
      throw .unreadable
    }
    self.challenge = challenge
    self.relyingParty = key.rpId
  }
}

/// What the system's passkey sheet returned (an assertion), sent to tickr.bot as a WebAuthn
/// `PublicKeyCredential` in its JSON form.
public struct PasskeyAssertion: Equatable, Sendable {
  public let credentialID: Data
  public let clientDataJSON: Data
  public let authenticatorData: Data
  public let signature: Data
  public let userID: Data?

  public init(credentialID: Data, clientDataJSON: Data, authenticatorData: Data, signature: Data, userID: Data?) {
    self.credentialID = credentialID
    self.clientDataJSON = clientDataJSON
    self.authenticatorData = authenticatorData
    self.signature = signature
    self.userID = userID
  }

  /// WebAuthn JSON keys and the credential type.
  static let publicKeyType = "public-key"
  static let idKey = "id"
  static let rawIdKey = "rawId"
  static let typeKey = "type"
  static let responseKey = "response"
  static let clientDataKey = "clientDataJSON"
  static let authenticatorDataKey = "authenticatorData"
  static let signatureKey = "signature"
  static let userHandleKey = "userHandle"
  static let extensionsKey = "clientExtensionResults"

  var credential: [String: Any] {
    let id = Base64URL.encode(credentialID)
    var response: [String: Any] = [
      Self.clientDataKey: Base64URL.encode(clientDataJSON),
      Self.authenticatorDataKey: Base64URL.encode(authenticatorData),
      Self.signatureKey: Base64URL.encode(signature),
    ]
    if let userID { response[Self.userHandleKey] = Base64URL.encode(userID) }
    return [Self.idKey: id, Self.rawIdKey: id, Self.typeKey: Self.publicKeyType, Self.responseKey: response,
      Self.extensionsKey: [String: Any]()]
  }
}

/// Base64url without padding (RFC 4648 section 5), as WebAuthn's JSON uses it.
enum Base64URL {
  /// Base64's padding character, which base64url leaves out.
  static let pad = "="
  /// Characters per base64 block: a decoder needs the padding back up to a whole block.
  static let quantum = 4

  static func encode(_ data: Data) -> String {
    data.base64EncodedString().replacing("+", with: "-").replacing("/", with: "_").replacing(pad, with: "")
  }

  static func decode(_ text: String) -> Data? {
    var base64 = text.replacing("-", with: "+").replacing("_", with: "/")
    let rest = base64.count % quantum
    if rest != .zero { base64 += String(repeating: pad, count: quantum - rest) }
    return Data(base64Encoded: base64)
  }
}
