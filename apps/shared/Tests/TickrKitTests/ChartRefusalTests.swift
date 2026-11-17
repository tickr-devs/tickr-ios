import Foundation
import Testing
@testable import TickrKit

/// GET /chart's refusals (error-v1 with `cause_codes`) said in the person's language: the chart's
/// empty state shows the cause alone, never the API's status, error code or the bot's words.
@Suite struct ChartRefusalTests {
  private func refusal(_ json: String) throws -> ErrorV1 {
    try Wire.decoder().decode(ErrorV1.self, from: Data(json.utf8))
  }

  @Test func chartOffIsSaidInPlainWords() throws {
    let off = try refusal("""
      {"error": "unavailable", "cause": "chart market data is off ([chart] webull_enabled = false)",
       "api_version": 1, "cause_codes": [{"code": "chart_off", "params": {}}]}
      """)
    #expect(off.causeText == "Live charts are off on the bot until the chart checks pass")
    #expect(off.causeText == ProseReason.chartOff.text([:]))
    #expect(!off.causeText.contains("webull_enabled"))
  }

  @Test func valuesFillTheSentence() throws {
    let delayed = try refusal("""
      {"error": "unavailable", "cause": "market data is delayed: data delayed by 15 min for ABCD",
       "api_version": 1, "cause_codes": [{"code": "chart_data_delayed", "params": {"minutes": "15", "symbols": "ABCD"}}]}
      """)
    #expect(delayed.causeText == "Market data for ABCD is delayed by 15 min; the chart shows live data only")
    #expect(ProseReason.chartDataDelayed.text(["detail": "x"]) == "Market data is delayed; the chart shows live data only")
  }

  /// The empty state's cause: a refusal's cause alone; any other error as its description.
  @Test func errorCauseDropsTheStatus() throws {
    let off = ProseReason.chartOff.text([:]) ?? ""
    let refused = APIError.refused(status: 503, error: "unavailable", cause: off)
    #expect(ErrorText.cause(refused) == off)
    #expect(ErrorText.text(refused) == "API refused (503 unavailable): \(off)")
    #expect(ErrorText.cause(APIError.unreachable("down")) == ErrorText.text(APIError.unreachable("down")))
  }
}
