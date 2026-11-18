import SwiftUI
import TickrKit

/// The bot's journal as both apps show it (iOS Activity › Journal, the Mac Overview's journal
/// card): one line per event, newest first, with its New York time, a dot and tag in the event's
/// tone, and the line in words (`Board.journal`). An event the bot adds while the list is on
/// screen washes its line once. At the accessibility text sizes time and tag go on top, so the
/// line keeps the whole width.
public struct JournalLines: View {
  @State private var arrived: Set<String> = []
  let events: [Board.Event]

  public init(_ events: [Board.Event]) {
    self.events = events
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(events) { event in
        JournalLine(event, arrived: arrived.contains(event.id))
          .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .animation(Tokens.Motion.standard, value: events.map(\.id))
    .onArrival(of: events.map(\.id)) { arrived = $0 }
  }
}

/// One line of the journal (`JournalLines`; a capped journal card lists them one by one): time,
/// dot, tag and the line in words. `arrived`: the bot added it while the list was on screen, so
/// its line washes once.
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
        ChipFlow(spacing: Tokens.Space.s) {
          HStack(spacing: Tokens.Space.s) {
            dot(event)
            time(event)
          }
          tag(event)
        }
        text(event)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
    } else {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        time(event)
        dot(event)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          tag(event)
          text(event)
        }
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

  private func tag(_ event: Board.Event) -> some View {
    Text(verbatim: event.tag)
      .font(Tokens.Typography.annotationBold)
      .foregroundStyle(Tone(event.tone).text)
  }

  private func text(_ event: Board.Event) -> some View {
    Text(verbatim: event.text)
      .font(Tokens.Typography.annotation)
      .foregroundStyle(Palette.textSecondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
