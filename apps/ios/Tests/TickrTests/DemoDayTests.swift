import Foundation
import Testing
@testable import Tickr
import TickrKit

/// The "Demo day" switch on the phone: the address and the paired token never change, requests go
/// under /demo of the same address, and the token still goes only to the paired host.
@Suite struct DemoDayTests {
  private static let mac = "https://mac.tailnet.ts.net"

  private func paired() throws -> Connection {
    Connection(paired: try #require(URL(string: Self.mac)), token: "token")
  }

  @Test func onTalksToTheDemoBehindThePairedAddress() throws {
    let connection = try paired().demo(true)
    #expect(connection.url?.absoluteString == Self.mac + "/demo")
    #expect(connection.address == Self.mac)
    #expect(connection.pairedAddress == Self.mac)
    // The token goes to the paired host (the bot's API keeps it; the demo never sees it).
    #expect(connection.bearer == "token")
  }

  @Test func offIsTheRememberedAddressWithItsToken() throws {
    let connection = try paired().demo(true).demo(false)
    #expect(connection == (try paired()))
    #expect(connection.url?.absoluteString == Self.mac)
    #expect(connection.bearer == "token")
  }

  @Test func theTokenNeverGoesToAnotherHost() throws {
    let connection = try paired().demo(true)
    let elsewhere = try #require(URL(string: "https://elsewhere.example/demo/status"))
    #expect(connection.bearer(for: elsewhere) == nil)
    // Over plain HTTP (the Simulator's loopback address) no token is ever sent.
    let local = Connection(address: Connection.simulatorAddress).demo(true)
    #expect(local.url?.absoluteString == Connection.simulatorAddress + "/demo")
    #expect(local.bearer == nil)
  }

  @Test func editingTheAddressKeepsTheSwitch() throws {
    let moved = try paired().demo(true).moved(to: "http://127.0.0.1:9000")
    #expect(moved.demo)
    #expect(moved.token == nil)
    #expect(moved.url?.absoluteString == "http://127.0.0.1:9000/demo")
  }

  @Test func savedAndLoadedWithTheAddress() throws {
    let defaults = try #require(UserDefaults(suiteName: "DemoDayTests"))
    defaults.removePersistentDomain(forName: "DemoDayTests")
    defaults.set(Self.mac, forKey: Connection.defaultsKey)
    defaults.set(true, forKey: Connection.demoKey)
    #expect(Connection.load(defaults).demo)
    defaults.set(false, forKey: Connection.demoKey)
    #expect(!Connection.load(defaults).demo)
    defaults.removePersistentDomain(forName: "DemoDayTests")
  }

  @MainActor
  @Test func everyConfirmationNamesWhereTheCommandGoes() {
    #expect(BotControl.target("Stops the bot.", demo: true).key == "control.toDemo")
    #expect(BotControl.target("Stops the bot.", demo: false).key == "control.toBot")
    let demo = String(localized: BotControl.target("Stops the bot.", demo: true))
    #expect(demo.hasPrefix("Stops the bot.") && demo.contains("DEMO"))
  }
}
