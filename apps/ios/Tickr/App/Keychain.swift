import Foundation
import Security

/// The paired API token, kept in the Keychain on this phone only: never synced, never backed up to
/// another device, and readable after the first unlock so polling works when the app reopens.
/// Registered on the container (`Container.keychain`); nothing else stores the token.
struct Keychain: Sendable {
  /// Keychain service and account of the token item. The item already belongs to this app alone
  /// (its team and bundle id), so the service names only what it holds.
  static let service = "api-token"
  static let account = "bearer-token"

  /// The Security calls the token goes through (`SecItems` on the phone; tests give their own).
  let items: any KeychainItems

  init(items: any KeychainItems = SecItems()) {
    self.items = items
  }

  private var query: [String: Any] {
    [kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account]
  }

  func readToken() -> String? {
    var search = query
    search[kSecReturnData as String] = true
    search[kSecMatchLimit as String] = kSecMatchLimitOne
    guard let data = items.copy(search) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  /// Puts `token` in place of any earlier one in one Keychain write (an update of the item, an add
  /// only when there is none), then reads it back. True only when the Keychain holds exactly
  /// `token` afterwards: a failed write never deletes the earlier token first, so it can neither
  /// report a pairing that a restart would lose nor lose the pairing that worked before. Nothing
  /// is written when the Keychain already holds `token`.
  @discardableResult
  func saveToken(_ token: String) -> Bool {
    if readToken() == token { return true }
    let value = Data(token.utf8)
    let attributes: [String: Any] = [
      kSecValueData as String: value,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    var status = items.update(query, attributes)
    if status == errSecItemNotFound {
      var add = query
      add.merge(attributes) { _, new in new }
      status = items.add(add)
    }
    return status == errSecSuccess && readToken() == token
  }

  func deleteToken() {
    items.delete(query)
  }
}

/// The four Keychain calls the token needs, so tests can run them in memory and make one fail.
protocol KeychainItems: Sendable {
  /// The data of the item `query` finds, or nil when there is none or it cannot be read.
  func copy(_ query: [String: Any]) -> Data?
  /// `SecItemUpdate`: the item `query` finds takes `attributes`.
  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
  /// `SecItemAdd` of a new item.
  func add(_ item: [String: Any]) -> OSStatus
  /// `SecItemDelete`.
  @discardableResult
  func delete(_ query: [String: Any]) -> OSStatus
}

/// This phone's Keychain.
struct SecItems: KeychainItems {
  func copy(_ query: [String: Any]) -> Data? {
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
    return item as? Data
  }

  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
    SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
  }

  func add(_ item: [String: Any]) -> OSStatus {
    SecItemAdd(item as CFDictionary, nil)
  }

  @discardableResult
  func delete(_ query: [String: Any]) -> OSStatus {
    SecItemDelete(query as CFDictionary)
  }
}
