import SwiftUI
import TickrKit
import WidgetKit

#if DEBUG
/// Sample content-states of the four states for the previews (mockup v138): two positions, the
/// day up $15.40, the stops confirmed two seconds ago.
enum LiveSamples {
  /// ABCD: last $12.48, stop $11.90, no target yet, up $2.10.
  static let abcd = ActivityPosition(symbol: "ABCD", last: 12.48, stop: 11.9, target: nil, unrealizedCents: 210)
  /// KLMN: below a dollar, with a target (the bar), up $1.50.
  static let klmn = ActivityPosition(symbol: "KLMN", last: 0.4567, stop: 0.4012, target: 0.5, unrealizedCents: 150)
  /// KLMN without a last price: no knob, the result "—".
  static let klmnUnread = ActivityPosition(symbol: "KLMN", last: nil, stop: 0.4012, target: 0.5, unrealizedCents: nil)
  /// The day's result in cents, and the flat day's.
  static let dayCents = 1540
  static let flatCents = 1430
  /// When the broker last confirmed the stops: two seconds ago, as the previews open.
  static let confirmedAt = Int(Date.now.timeIntervalSince1970) - 2
  /// The paused state's cause (an entry block code).
  static let pauseCause = "entry_stop"

  static let open = TickrActivityAttributes.ContentState(state: .open, dayPnlCents: dayCents, positions: [abcd, klmn],
    stopsConfirmedAt: confirmedAt, reasonCode: nil, alarmSymbol: nil)
  static let paused = TickrActivityAttributes.ContentState(state: .paused, dayPnlCents: dayCents,
    positions: [abcd, klmnUnread], stopsConfirmedAt: confirmedAt, reasonCode: pauseCause, alarmSymbol: nil)
  static let alarm = TickrActivityAttributes.ContentState(state: .alarm, dayPnlCents: -dayCents, positions: [abcd, klmn],
    stopsConfirmedAt: confirmedAt, reasonCode: nil, alarmSymbol: abcd.symbol)
  static let flat = TickrActivityAttributes.ContentState(state: .flat, dayPnlCents: flatCents, positions: [],
    stopsConfirmedAt: nil, reasonCode: nil, alarmSymbol: nil)
}

#Preview(as: .content, using: TickrActivityAttributes()) {
  TickrLiveActivity()
} contentStates: {
  LiveSamples.open
  LiveSamples.paused
  LiveSamples.alarm
  LiveSamples.flat
}

#Preview(as: .dynamicIsland(.compact), using: TickrActivityAttributes()) {
  TickrLiveActivity()
} contentStates: {
  LiveSamples.open
  LiveSamples.paused
  LiveSamples.alarm
  LiveSamples.flat
}

#Preview(as: .dynamicIsland(.minimal), using: TickrActivityAttributes()) {
  TickrLiveActivity()
} contentStates: {
  LiveSamples.open
  LiveSamples.paused
  LiveSamples.alarm
  LiveSamples.flat
}

#Preview(as: .dynamicIsland(.expanded), using: TickrActivityAttributes()) {
  TickrLiveActivity()
} contentStates: {
  LiveSamples.open
  LiveSamples.paused
  LiveSamples.alarm
  LiveSamples.flat
}
#endif
