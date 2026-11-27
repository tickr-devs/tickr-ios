import Foundation
import Testing
@testable import Tickr
import TickrKit

/// The "Demo day" switch on the phone: the address and the sign-in never change, requests go to
/// the demo day the app carries (never the network, no token), and off is the bot with the sign-in.
@MainActor
@Suite struct DemoDayTests {
  private let signedIn = Connection(signedIn: true)

  @Test func onTalksToTheDemoTheAppCarries() {
    let connection = signedIn.demo(true)
    #expect(connection.url == DemoDay.address)
    #expect(connection.address == BotAddress.url)
    #expect(connection.signedIn)
    // The sign-in never goes to the demo day: it is not the bot's address.
    #expect(!connection.endpoint(for: DemoDay.address).signedIn)
  }

  @Test func onWorksWithoutSigningIn() {
    // Never signed in: the sign-in is shown and nothing is read, but the demo day still has its address.
    #expect(Connection().url == nil && Connection().needsSignIn)
    #expect(Connection().demo(true).url == DemoDay.address)
    #expect(!Connection().demo(true).needsSignIn)
  }

  @Test func offIsTheBotWithItsSignIn() {
    let connection = signedIn.demo(true).demo(false)
    #expect(connection == signedIn)
    #expect(connection.url == BotAddress.url)
    #expect(connection.endpoint(for: BotAddress.url).signedIn)
  }

  @Test func theSignInNeverGoesToAnotherHost() throws {
    let elsewhere = try #require(URL(string: "https://elsewhere.example/demo/status"))
    #expect(!signedIn.endpoint(for: elsewhere).signedIn)
    // Over plain HTTP no token is ever sent to another machine, only to this one (the
    // Simulator reading the phone's listener on the Mac's loopback).
    let lan = try #require(URL(string: "http://192.168.1.5:8767/status"))
    let loopback = try #require(URL(string: "http://127.0.0.1:8767/status"))
    #expect(!Connection.carriesToken(lan))
    #expect(Connection.carriesToken(loopback))
  }

  @Test func theSimulatorsTokenGoesOnlyToItsAddress() throws {
    let mac = try #require(URL(string: "http://127.0.0.1:8767"))
    let simulator = Connection(address: mac, simulatorToken: "token")
    #expect(!simulator.needsSignIn)
    #expect(simulator.endpoint(for: mac.appending(path: "status")).token == "token")
    #expect(simulator.endpoint(for: BotAddress.url).token == nil)
  }

  @Test func aDevelopmentAddressNeedsNoSignInAndGetsNoToken() throws {
    let defaults = try #require(UserDefaults(suiteName: "DemoDayTests.address"))
    defaults.removePersistentDomain(forName: "DemoDayTests.address")
    defaults.set("http://127.0.0.1:9000", forKey: Connection.addressKey)
    let connection = Connection.load(defaults)
    let url = try #require(connection.url)
    #expect(url.absoluteString == "http://127.0.0.1:9000")
    #expect(connection.endpoint(for: url).token == nil && !connection.endpoint(for: url).signedIn)
    defaults.removePersistentDomain(forName: "DemoDayTests.address")
  }

  @Test func theSwitchIsSavedAndLoaded() throws {
    let defaults = try #require(UserDefaults(suiteName: "DemoDayTests"))
    defaults.removePersistentDomain(forName: "DemoDayTests")
    defaults.set("http://127.0.0.1:9000", forKey: Connection.addressKey)
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
  @Test func theSimulatorTokenFileNeedsBothFields() {
    let good = Data(#"{"address": "http://127.0.0.1:8767", "token": "abc"}"#.utf8)
    #expect(SimulatorToken.decode(good) == SimulatorToken(address: "http://127.0.0.1:8767", token: "abc"))
    #expect(SimulatorToken.decode(Data(#"{"address": "http://127.0.0.1:8767", "token": ""}"#.utf8)) == nil)
    #expect(SimulatorToken.decode(Data(#"{"token": "abc"}"#.utf8)) == nil)
    #expect(SimulatorToken.decode(Data("abc".utf8)) == nil)
  }
}
