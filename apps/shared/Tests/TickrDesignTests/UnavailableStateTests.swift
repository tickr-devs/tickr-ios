import Testing
@testable import TickrDesign

/// The shared empty state of a refused or failed read: the cause in the person's language while
/// the link is up, the plain message without one, the calm wait while the link is down.
@Suite struct UnavailableStateTests {
  @Test func showsTheCause() {
    let cause = "Live charts are turned off in the bot's settings"
    #expect(UnavailableState.content(cause: cause, connectionDown: false) == .cause(cause))
  }

  @Test func withoutACauseShowsTheMessage() {
    #expect(UnavailableState.content(cause: nil, connectionDown: false) == .message)
    #expect(UnavailableState.content(cause: "", connectionDown: false) == .message)
  }

  @Test func waitsWhileTheLinkIsDown() {
    #expect(UnavailableState.content(cause: "x", connectionDown: true) == .waiting)
  }
}
