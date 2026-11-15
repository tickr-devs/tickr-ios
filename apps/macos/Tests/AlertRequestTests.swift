@testable import ApertureMac
import Testing

/// The notify mode's command line (the bot runs `<executable> --notify-alert TITLE TEXT`).
@Suite struct AlertRequestTests {
  @Test func readsTheTitleAndTextAfterTheFlag() {
    let request = AlertRequest(arguments: ["/Applications/Tickr.app/Contents/MacOS/Tickr", "--notify-alert", "Tickr: stop-rejected", "AAPL"])
    #expect(request?.title == "Tickr: stop-rejected")
    #expect(request?.text == "AAPL")
  }

  @Test func startsTheAppForAnyOtherCommandLine() {
    #expect(AlertRequest(arguments: ["Tickr"]) == nil)
    #expect(AlertRequest(arguments: ["Tickr", "-appearance", "dark", "x"]) == nil)
    #expect(AlertRequest(arguments: ["Tickr", "--notify-alert", "only a title"]) == nil)
    #expect(AlertRequest(arguments: ["Tickr", "--notify-alert", "t", "x", "extra"]) == nil)
  }

  @Test func onlyAShownAlertExitsWithZero() {
    #expect(AlertExit.shown.rawValue == 0)
    #expect(AlertExit.notAllowed.rawValue != 0)
    #expect(AlertExit.failed.rawValue != 0)
  }
}
