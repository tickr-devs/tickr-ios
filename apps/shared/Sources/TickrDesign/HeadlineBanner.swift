import SwiftUI
import TickrKit

/// The status headline, the first line a person reads (Mac Overview, the Mac menu-bar panel, iOS
/// Home), as mockup v108 draws it: a pill that hugs its text (a dot in the tone's fill that
/// pulses once per new headline, the title in bold and the detail muted, on the tone's 12 % tint
/// inside a 45 % border) and beside it one unsplittable group of facts, the session countdown and
/// the gate badge. The tone comes from `Headline.tone` (or `.highlight` for a recorded day), never
/// from the screen.
///
/// What fits decides the layout, never a count of characters (`ViewThatFits`): the pill and its
/// facts on one row; else the facts under the pill; else the pill takes the whole row and wraps,
/// its corners down to `Tokens.Headline.wrappedRadius`. An alarm always takes the whole row, with
/// the full tone's border and its title in the tone, and hides the gate badge.
public struct HeadlineBanner: View {
  /// How the title and the detail share the pill.
  public enum Arrangement: Sendable {
    /// On one line, the detail after the title (Main and MacMenuBar).
    case inline
    /// The title over the detail (IOSHome), corners `Tokens.Headline.stackedRadius`.
    case stacked
  }

  /// The facts beside the pill, on the live day only.
  public struct Facts {
    /// The gate badge; nil hides it (no status).
    let gate: EntryGate?
    /// The countdown at a moment of this device's clock (the app turns it into the bot's), redrawn
    /// every minute; nil hides it.
    let countdown: @Sendable (Date) -> SessionCountdown?

    public init(gate: EntryGate?, countdown: @escaping @Sendable (Date) -> SessionCountdown?) {
      self.gate = gate
      self.countdown = countdown
    }
  }

  /// SF Symbol in front of the countdown (the boards' clock).
  static let clockSymbol = "clock"
  /// The full stop a title's sentence may end with, dropped when a detail follows it.
  static let fullStop: Character = "."
  /// Between the title and the detail of the inline pill; an alarm's two sentences take a space.
  static let separator = " · "
  static let space = " "

  let title: String
  let detail: String?
  let tone: Tone
  let alarm: Bool
  let pulse: AnyHashable?
  let arrangement: Arrangement
  let facts: Facts?

  /// `pulse`: what a new pulse marks (`Headline.pulse`); nil for a headline that never pulses (a
  /// recorded day, a past view). `alarm`: the headline's severity is `.alarm`.
  public init(
    _ title: String, detail: String? = nil, tone: Tone, alarm: Bool = false, pulse: AnyHashable? = nil,
    arrangement: Arrangement = .inline, facts: Facts? = nil
  ) {
    self.title = title
    self.detail = detail
    self.tone = tone
    self.alarm = alarm
    self.pulse = pulse
    self.arrangement = arrangement
    self.facts = facts
  }

  public var body: some View {
    Group {
      if let facts {
        // The countdown counts down while the screen is open.
        TimelineView(.everyMinute) { context in
          rows(countdown: facts.countdown(context.date), gate: Self.shownGate(facts.gate, alarm: alarm))
        }
      } else {
        rows(countdown: nil, gate: nil)
      }
    }
    // The colour follows the tone, so a change of severity animates even under the same words.
    .animation(Tokens.Motion.standard, value: tone)
    .accessibilityElement(children: .combine)
  }

  /// The gate badge as shown: never under an alarm, which takes the whole row.
  public static func shownGate(_ gate: EntryGate?, alarm: Bool) -> EntryGate? {
    alarm ? nil : gate
  }

  /// The title as the pill writes it: with a detail after it (the inline "·", or the stacked line
  /// under it) a sentence's full stop is dropped ("Outside the regular session · No open
  /// position"), as the boards write it; an alarm keeps its sentences whole.
  public static func shownTitle(_ title: String, alarm: Bool, hasDetail: Bool) -> String {
    guard !alarm, hasDetail, title.last == fullStop else { return title }
    return String(title.dropLast())
  }

  private func rows(countdown: SessionCountdown?, gate: EntryGate?) -> some View {
    let hasFacts = countdown != nil || gate != nil
    return ViewThatFits(in: .horizontal) {
      if !alarm {
        HStack(spacing: Tokens.Headline.rowGap) {
          pill(wrapped: false)
          if hasFacts { factsRow(countdown: countdown, gate: gate) }
        }
        if hasFacts {
          VStack(alignment: .leading, spacing: Tokens.Headline.lineGap) {
            pill(wrapped: false)
            factsRow(countdown: countdown, gate: gate)
          }
        }
      }
      VStack(alignment: .leading, spacing: Tokens.Headline.lineGap) {
        pill(wrapped: true)
        if hasFacts { factsRow(countdown: countdown, gate: gate) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: pill

  /// The pill: on one line it hugs its text in a capsule; `wrapped`, it takes the whole row and
  /// its text wraps under smaller corners.
  @ViewBuilder private func pill(wrapped: Bool) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius(wrapped: wrapped), style: .continuous)
    let face = HStack(alignment: wrapped ? .top : .center, spacing: Tokens.Headline.dotGap) {
      PulseDot(tone.fill, pulsing: pulse != nil, event: pulse)
        .padding(.top, wrapped ? Tokens.Headline.wrappedDotTop : 0)
      words
        .fixedSize(horizontal: !wrapped, vertical: true)
    }
    .padding(.vertical, vertical(wrapped: wrapped))
    .padding(.leading, leading(wrapped: wrapped))
    .padding(.trailing, wrapped ? Tokens.Headline.wrappedTrailing : Tokens.Headline.pillTrailing)
    if wrapped {
      face
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint, in: shape)
        .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
    } else {
      face
        .background(tint, in: shape)
        .overlay(shape.strokeBorder(border, lineWidth: borderWidth))
        .fixedSize()
    }
  }

  private var tint: Color { tone.fill.opacity(alarm ? Tokens.Headline.alarmTint : Tokens.Headline.tint) }
  private var border: Color { alarm ? tone.fill : tone.fill.opacity(Tokens.Headline.border) }
  private var borderWidth: CGFloat { alarm ? Tokens.Headline.alarmBorderWidth : Tokens.Headline.borderWidth }

  @ViewBuilder private var words: some View {
    let shown = Self.shownTitle(title, alarm: alarm, hasDetail: detail != nil)
    let titleText = Text(verbatim: shown).font(Tokens.Headline.title)
      .foregroundStyle(alarm ? tone.text : Palette.textPrimary)
    switch arrangement {
    case .inline:
      if let detail {
        let separator = Text(verbatim: alarm ? Self.space : Self.separator).foregroundStyle(Palette.textQuaternary)
        Text("\(titleText)\(separator)\(detailText(detail))").font(Tokens.Headline.detail)
      } else {
        titleText
      }
    case .stacked:
      VStack(alignment: .leading, spacing: Tokens.Headline.stackedLineGap) {
        titleText
        if let detail { detailText(detail).font(Tokens.Headline.detail) }
      }
    }
  }

  private func detailText(_ detail: String) -> Text {
    Text(verbatim: detail).foregroundStyle(alarm ? Palette.textSecondary : Palette.textTertiary)
  }

  private func radius(wrapped: Bool) -> CGFloat {
    if arrangement == .stacked { return Tokens.Headline.stackedRadius }
    return wrapped ? Tokens.Headline.wrappedRadius : Tokens.Headline.pillRadius
  }

  private func vertical(wrapped: Bool) -> CGFloat {
    switch (arrangement, wrapped) {
    case (.stacked, false): return Tokens.Headline.stackedVertical
    case (.stacked, true): return Tokens.Headline.stackedWrappedVertical
    case (.inline, false): return Tokens.Headline.pillVertical
    case (.inline, true): return Tokens.Headline.wrappedVertical
    }
  }

  private func leading(wrapped: Bool) -> CGFloat {
    if arrangement == .stacked && !wrapped { return Tokens.Headline.stackedLeading }
    return wrapped ? Tokens.Headline.wrappedLeading : Tokens.Headline.pillLeading
  }

  // MARK: facts

  /// The countdown and the gate badge: one group that never splits across lines.
  private func factsRow(countdown: SessionCountdown?, gate: EntryGate?) -> some View {
    HStack(spacing: Tokens.Headline.factsGap) {
      if let countdown {
        HStack(spacing: Tokens.Headline.countdownGap) {
          Image(systemName: Self.clockSymbol)
            .foregroundStyle(Palette.textQuaternary)
            .accessibilityHidden(true)
          Text(verbatim: countdown.label).foregroundStyle(Palette.textTertiary)
          Text(verbatim: countdown.value())
            .font(Tokens.Headline.countdownValue)
            .foregroundStyle(Palette.textPrimary)
        }
        .font(Tokens.Headline.countdown)
      }
      if let gate { Badge(gate.title, symbol: gate.symbol, tone: gate.tone) }
    }
    .fixedSize()
  }
}
