import Foundation
import Security
import Synchronization
import Testing
@testable import Tickr

/// The paired token is stored with one confirmed Keychain write: an update of the item, an add only
/// when there is none, never a delete first, and success only when the Keychain holds the token.
@Suite struct KeychainTests {
  private static let first = "token-first"
  private static let second = "token-second"

  @Test func firstPairingAddsTheToken() {
    let items = MemoryItems()
    let keychain = Keychain(items: items)
    #expect(keychain.saveToken(Self.first))
    #expect(keychain.readToken() == Self.first)
    #expect(items.calls == [.update, .add])
  }

  @Test func pairingAgainUpdatesInPlace() {
    let items = MemoryItems(stored: Self.first)
    let keychain = Keychain(items: items)
    #expect(keychain.saveToken(Self.second))
    #expect(keychain.readToken() == Self.second)
    #expect(items.calls == [.update])
  }

  @Test func theSameTokenIsNotWrittenAgain() {
    let items = MemoryItems(stored: Self.first)
    #expect(Keychain(items: items).saveToken(Self.first))
    #expect(items.calls.isEmpty)
  }

  @Test func aFailedUpdateKeepsTheEarlierToken() {
    let items = MemoryItems(stored: Self.first, updateStatus: errSecInteractionNotAllowed)
    let keychain = Keychain(items: items)
    #expect(!keychain.saveToken(Self.second))
    #expect(keychain.readToken() == Self.first)
    #expect(!items.calls.contains(.delete))
  }

  @Test func aFailedAddIsNoPairing() {
    let items = MemoryItems(addStatus: errSecNotAvailable)
    let keychain = Keychain(items: items)
    #expect(!keychain.saveToken(Self.first))
    #expect(keychain.readToken() == nil)
  }

  @Test func aWriteTheKeychainDidNotKeepIsNoPairing() {
    let items = MemoryItems(stored: Self.first, keepsWrites: false)
    #expect(!Keychain(items: items).saveToken(Self.second))
  }
}

/// One generic-password item in memory, with the status each write answers.
private final class MemoryItems: KeychainItems {
  enum Call: Equatable { case update, add, delete }

  private struct State {
    var stored: Data?
    var calls: [Call] = []
  }

  private let state: Mutex<State>
  private let updateStatus: OSStatus
  private let addStatus: OSStatus
  /// False: writes answer success but the item stays as it was.
  private let keepsWrites: Bool

  init(
    stored: String? = nil, updateStatus: OSStatus = errSecSuccess, addStatus: OSStatus = errSecSuccess,
    keepsWrites: Bool = true
  ) {
    state = Mutex(State(stored: stored.map { Data($0.utf8) }))
    self.updateStatus = updateStatus
    self.addStatus = addStatus
    self.keepsWrites = keepsWrites
  }

  var calls: [Call] { state.withLock { $0.calls } }

  func copy(_ query: [String: Any]) -> Data? { state.withLock { $0.stored } }

  func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
    state.withLock { state in
      state.calls.append(.update)
      guard state.stored != nil else { return errSecItemNotFound }
      guard updateStatus == errSecSuccess else { return updateStatus }
      if keepsWrites { state.stored = attributes[kSecValueData as String] as? Data }
      return errSecSuccess
    }
  }

  func add(_ item: [String: Any]) -> OSStatus {
    state.withLock { state in
      state.calls.append(.add)
      guard addStatus == errSecSuccess else { return addStatus }
      guard state.stored == nil else { return errSecDuplicateItem }
      if keepsWrites { state.stored = item[kSecValueData as String] as? Data }
      return errSecSuccess
    }
  }

  @discardableResult
  func delete(_ query: [String: Any]) -> OSStatus {
    state.withLock { state in
      state.calls.append(.delete)
      state.stored = nil
      return errSecSuccess
    }
  }
}
