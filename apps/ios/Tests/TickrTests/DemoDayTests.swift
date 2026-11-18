import Foundation
import Testing
@testable import Tickr
import TickrKit

/// The "Demo day" switch on the phone: the address and the paired token never change, requests go
/// to the demo day the app carries (never the network, no token), and off is the paired address.
@Suite struct DemoDayTests {
  private static let mac = "https://mac.tailnet.ts.net"

  private func paired() throws -> Connection {
    Connection(paired: try #require(URL(string: Self.mac)), token: "token")
  }

  @Test func onTalksToTheDemoTheAppCarries() throws {
    let connection = try paired().demo(true)
    #expect(connection.url == DemoDay.address)
    #expect(connection.address == Self.mac)
    #expect(connection.pairedAddress == Self.mac)
    #expect(connection.token == "token")
    // The token never goes to the demo day: it is no host of the pairing.
    #expect(connection.bearer == nil)
  }

  @Test func onWorksWithoutAnyAddress() {
    // Away from the Mac, never paired: the demo day still has its address.
    #expect(Connection(address: "").url == nil)
    #expect(Connection(address: "").demo(true).url == DemoDay.address)
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
    // Over plain HTTP no token is ever sent to another machine, only to this one (the
    // Simulator reading the phone's listener on the Mac's loopback).
    let local = Connection(address: "http://127.0.0.1:8767")
    #expect(local.bearer == nil)
    let lan = try #require(URL(string: "http://192.168.1.5:8767/status"))
    let loopback = try #require(URL(string: "http://127.0.0.1:8767/status"))
    #expect(!Connection.carriesToken(lan))
    #expect(Connection.carriesToken(loopback))
  }

  @Test func editingTheAddressKeepsTheSwitch() throws {
    let moved = try paired().demo(true).moved(to: "http://127.0.0.1:9000")
    #expect(moved.demo)
    #expect(moved.token == nil)
    #expect(moved.url == DemoDay.address)
    #expect(moved.demo(false).url?.absoluteString == "http://127.0.0.1:9000")
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

  /// The file `pair-simulator` leaves: the address and the token, both required.
  @Test func theSimulatorPairingFileNeedsBothFields() {
    let good = Data(#"{"address": "http://127.0.0.1:8767", "token": "abc"}"#.utf8)
    #expect(SimulatorPairing.decode(good) == SimulatorPairing(address: "http://127.0.0.1:8767", token: "abc"))
    #expect(SimulatorPairing.decode(Data(#"{"address": "http://127.0.0.1:8767", "token": ""}"#.utf8)) == nil)
    #expect(SimulatorPairing.decode(Data(#"{"token": "abc"}"#.utf8)) == nil)
    #expect(SimulatorPairing.decode(Data("abc".utf8)) == nil)
  }
}
