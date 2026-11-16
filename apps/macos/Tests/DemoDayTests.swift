import FactoryTesting
import Foundation
import Testing
import TickrKit
@testable import TickrMac

/// Answers every request with an error: these tests look at where the model points and what it
/// lets the owner pick, never at what it reads.
private final class NoNetwork: URLProtocol {
  static func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [NoNetwork.self]
    return URLSession(configuration: configuration)
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
  override func stopLoading() {}
}

@MainActor
@Suite("Demo day switch (macOS)", .container)
struct DemoDayTests {
  let bot = URL(string: "http://127.0.0.1:8766")!
  let demo = DemoDay.address

  init() {
    Container.shared.urlSession.register { NoNetwork.session() }
  }

  @Test("On, the app talks to the demo day it carries; off, to the bot's address again")
  func addressSwap() {
    let model = AppModel(baseURL: bot)
    #expect(model.baseURL == bot)
    model.setDemoDay(true)
    #expect(model.baseURL == demo)
    #expect(model.address == bot)
    model.setDemoDay(false)
    #expect(model.baseURL == bot)
    #expect(model.address == bot)
  }

  @Test("A new bot address while the demo is on is remembered for when it is off")
  func newAddressWhileOn() throws {
    let model = AppModel(baseURL: bot, demoDay: true)
    #expect(model.baseURL == demo)
    let other = try #require(URL(string: "http://127.0.0.1:9000"))
    model.connect(to: other)
    #expect(model.address == other)
    #expect(model.baseURL == demo)
    model.setDemoDay(false)
    #expect(model.baseURL == other)
  }

  @Test("On, the day stays on the demo day: no other day can be picked")
  func dayLock() throws {
    let model = AppModel(baseURL: bot)
    let past = try WireDate("2026-11-12")
    model.selectedDay = past
    #expect(model.selectedDay == past)
    model.setDemoDay(true)
    #expect(model.dayLocked)
    #expect(model.selectedDay == nil)
    #expect(model.isLive)
    model.selectedDay = past
    #expect(model.selectedDay == nil)
    model.showPreviousDay()
    #expect(model.selectedDay == nil)
    #expect(model.previousDay == nil)
    model.setDemoDay(false)
    #expect(!model.dayLocked)
    model.selectedDay = past
    #expect(model.selectedDay == past)
  }

  @Test("Every command confirmation names where the command goes")
  func confirmationNamesTheTarget() {
    #expect(BotControls.confirmation("Closes MVLD.", demo: true).key == "bot.confirmToDemo")
    #expect(BotControls.confirmation("Closes MVLD.", demo: false).key == "bot.confirmToBot")
    let demo = String(localized: BotControls.confirmation("Closes MVLD.", demo: true))
    #expect(demo.hasPrefix("Closes MVLD.") && demo.contains("DEMO"))
  }
}
