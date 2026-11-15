import Foundation
import Security

/// The paired API token, kept in the Keychain on this phone only: never synced, never backed up to
/// another device, and readable after the first unlock so polling works when the app reopens.
/// Registered on the container (`Container.keychain`); nothing else stores the token.
struct Keychain: Sendable {
  /// Keychain service and account of the token item.
  static let service = "local.tickr.ios.api"
  static let account = "bearer-token"

  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account]
  }

  func readToken() -> String? {
    var item: CFTypeRef?
    var search = query
    search[kSecReturnData as String] = true
    search[kSecMatchLimit as String] = kSecMatchLimitOne
    guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  /// Replaces any earlier token, so pairing again leaves exactly one.
  @discardableResult
  func saveToken(_ token: String) -> Bool {
    deleteToken()
    var add = query
    add[kSecValueData as String] = Data(token.utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
  }

  func deleteToken() {
    SecItemDelete(query as CFDictionary)
  }
}
