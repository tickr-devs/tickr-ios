import Foundation
import Testing
@testable import TickrKit

/// One store of command keys for every model that sends (iPad: the iPhone screens' and the Mac
/// screens'): a lost send's key survives another model joining the same server, and goes when the
/// models move to another server.
@MainActor
@Suite struct CommandKeyStoreTests {
  private static let mac = URL(string: "https://mac.tailnet.ts.net")!
  private static let other = URL(string: "https://other.tailnet.ts.net")!
  private static let sentAt = Date(timeIntervalSince1970: 1_800_000_000)

  private func storeWithLostSend() -> CommandKeyStore {
    let store = CommandKeyStore()
    store.use(Self.mac)
    store.keys.lost(.stopBot, key: "first", at: Self.sentAt)
    return store
  }

  @Test func theSameServerAgainKeepsALostSendsKey() {
    let store = storeWithLostSend()
    store.use(Self.mac)
    #expect(store.keys.unknown[.stopBot]?.key == "first")
  }

  @Test func anotherServerDropsTheKeys() {
    let store = storeWithLostSend()
    store.use(Self.other)
    #expect(store.keys.unknown.isEmpty)
    #expect(store.server == Self.other)
  }

  @Test func aCommandBeingSentCannotBeginAgainUntilItEnds() {
    let store = CommandKeyStore()
    #expect(store.begin(.stopBot))
    #expect(!store.begin(.stopBot))
    #expect(store.begin(.emergency), "another command is not held up")
    store.end(.stopBot)
    #expect(store.begin(.stopBot))
  }
}
