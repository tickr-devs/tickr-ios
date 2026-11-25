import SwiftUI
import TickrDesign
import TickrKit

// What the Live Activity says and in which colour (mockup v138): teal while every stop is
// protected, amber while entries are paused, red only for the alarm (a stop not confirmed), grey
// once flat; the day's result green when up and pink when down (`Palette.result`).

extension LiveActivityState {
  /// The state dot's tone.
  var tone: Tone {
    switch self {
    case .open: .accent
    case .paused: .warning
    case .alarm: .loss
    case .flat: .neutral
    }
  }

  /// Whether the dot wears a ring: open (protected) and the alarm.
  var ringed: Bool { self == .open || self == .alarm }
}

extension TickrActivityAttributes.ContentState {
  /// The minimal island's dot: the day's sign while open, the state's tone otherwise.
  var minimalTone: Tone { state == .open ? Tone.result(dayResult) : state.tone }

  /// The coloured line of a state that is not plain open: why entries are paused, which stop is
  /// not confirmed, or the day's last word once flat.
  var stateLine: LocalizedStringResource? {
    switch state {
    case .open: nil
    case .paused: pauseReason.map(L10n.pausedBecause) ?? L10n.paused
    case .alarm: alarmSymbol.map(L10n.alarmFor) ?? L10n.alarm
    case .flat: L10n.flatDay(Money.signedUSD(dayResult))
    }
  }

  /// Whether a row is tinted red: the alarm's position, or one without a stop.
  func alarmed(_ position: ActivityPosition) -> Bool {
    position.stop == nil || (state == .alarm && position.symbol == alarmSymbol)
  }

  /// The subject of the stops line: every stop (`prices` names them, for the Lock Screen), or
  /// during the alarm every other position's; nil without a confirmed stop to name.
  func stopsSubject(prices: Bool) -> String? {
    let confirmed = positions.filter { !alarmed($0) }
    guard stopsConfirmed != nil, !confirmed.isEmpty else { return nil }
    guard state == .alarm else {
      let list = confirmed.compactMap(\.stop).map(Money.usdPrice).joined(separator: LiveText.separator)
      return String(localized: prices ? L10n.stopsAt(list) : L10n.stops)
    }
    return confirmed.compactMap { position in
      position.stop.map { stop in
        String(localized: prices ? L10n.symbolStopAt(position.symbol, Money.usdPrice(stop))
          : L10n.symbolStop(position.symbol))
      }
    }.joined(separator: LiveText.separator)
  }
}

/// Pieces of the activity's texts that are not words.
enum LiveText {
  /// Between the prices or positions of the stops line: "Stops $11.90 · $8.78".
  static let separator = " · "
}

/// The state's dot: filled in its tone, ringed while open or in alarm.
struct LiveDot: View {
  let tone: Tone
  var ringed = false

  var body: some View {
    Circle()
      .fill(tone.fill)
      .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
      .frame(width: ringed ? Tokens.LiveActivity.dotRing : Tokens.Size.dot,
        height: ringed ? Tokens.LiveActivity.dotRing : Tokens.Size.dot)
      .overlay {
        if ringed { Circle().strokeBorder(tone.fill, lineWidth: Tokens.Stroke.regular) }
      }
      .accessibilityHidden(true)
  }
}

/// The day's result in dollars: green up, pink down, tabular so it never shifts.
struct LiveDayResult: View {
  let result: Decimal
  let font: Font

  var body: some View {
    Text(Money.signedUSD(result))
      .font(font)
      .monospacedDigit()
      .foregroundStyle(Palette.result(result))
      .fixedSize()
  }
}

/// "Stops confirmed at broker 2 s ago": the time keeps counting on its own (no push per second);
/// hidden until the broker has confirmed the stops once.
struct LiveStopsLine: View {
  let state: TickrActivityAttributes.ContentState
  /// The Lock Screen names each stop's price; the island does not.
  var prices = false

  var body: some View {
    if let subject = state.stopsSubject(prices: prices), let confirmed = state.stopsConfirmed {
      Text(TextSlot(String(localized: L10n.confirmed(subject, TextSlot.marker))),
        around: Text(confirmed, style: .relative))
        .font(Tokens.LiveActivity.footnote)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
