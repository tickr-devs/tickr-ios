import SwiftUI
import TickrKit

/// The bot's journal as both apps show it (iOS Activity › Journal, the Mac Overview's journal
/// card; mockups IOSActivity, Main): one line per event, newest first, with its New York time, a
/// dot in the event's tone and the event in plain words, its tag first ("Stop set ABCD 100 @
/// 3.95", `Board.journal`). An event the bot adds while the list is on screen washes its line
/// once. At the accessibility text sizes time and dot go on top, so the words keep the width.
public struct JournalLines: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var arrived: Set<String> = []
  let events: [Board.Event]

  public init(_ events: [Board.Event]) {
    self.events = events
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(events) { event in
        JournalLine(event, arrived: arrived.contains(event.id))
          .transition(.asymmetric(insertion: .moving(from: .top, reduceMotion: reduceMotion), removal: .opacity))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .animation(Tokens.Motion.standard, value: events.map(\.id))
    .onArrival(of: events.map(\.id)) { arrived = $0 }
  }
}

/// One line of the journal (`JournalLines`; a capped journal card lists them one by one): time,
/// dot and the event in plain words, its tag first in the event's tone. `arrived`: the bot added
/// it while the list was on screen, so its line washes once.
public struct JournalLine: View {
  /// Side of an event's dot, in points.
  static let dotSide: CGFloat = 7

  @Environment(\.dynamicTypeSize) private var typeSize
  let event: Board.Event
  let arrived: Bool

  public init(_ event: Board.Event, arrived: Bool = false) {
    self.event = event
    self.arrived = arrived
  }

  public var body: some View {
    line(event)
      .padding(.vertical, Tokens.Space.xs)
      .arrivalFlash(arrived, color: Tone(event.tone).fill)
  }

  @ViewBuilder
  private func line(_ event: Board.Event) -> some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        HStack(spacing: Tokens.Space.s) {
          dot(event)
          time(event)
        }
        words(event)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
    } else {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        time(event)
        dot(event)
        words(event)
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .combine)
    }
  }

  private func time(_ event: Board.Event) -> some View {
    Text(verbatim: ClockText.seconds(event.time))
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textQuaternary)
  }

  private func dot(_ event: Board.Event) -> some View {
    Circle().fill(Tone(event.tone).fill).frame(width: Self.dotSide, height: Self.dotSide)
  }

  /// "Stop set ABCD 100 @ 3.95": the tag in plain words and the event's tone, then the line.
  private func words(_ event: Board.Event) -> some View {
    Text(Self.attributed(event))
      .font(Tokens.Typography.annotation)
      .fixedSize(horizontal: false, vertical: true)
  }

  static func attributed(_ event: Board.Event) -> AttributedString {
    var tag = AttributedString(event.plainTag)
    tag.swiftUI.foregroundColor = Tone(event.tone).text
    tag.swiftUI.font = Tokens.Typography.annotationBold
    guard !event.text.isEmpty else { return tag }
    var text = AttributedString(Self.space + event.text)
    text.swiftUI.foregroundColor = Palette.textSecondary
    return tag + text
  }

  /// Between the tag and the line.
  static let space = " "
}
