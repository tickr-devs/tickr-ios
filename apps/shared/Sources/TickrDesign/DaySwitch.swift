import SwiftUI
import TickrKit

/// The shown day on an iPhone screen, as on the IOS2 boards (mockup v155): a capsule with the day
/// ("Today", or "Fri Nov 13") and a down chevron. A tap opens the picker sheet: the day in full,
/// then Today, Previous and Next trading day (a row that leads nowhere is dimmed and refuses taps;
/// a pick closes the sheet) and the hint that a sideways swipe changes the day too (`daySwipe`).
/// With nowhere to go (the demo day, or today with no other recorded day) the day is plain text,
/// never a button that does nothing. The app passes the day's texts and what each step does.
public struct DaySwitch: View {
  /// The capsule's caption: nil on today ("Today"), else the shown day ("Fri Nov 13": a recorded
  /// day, or the last session on a day without one).
  let caption: String?
  /// The day in full, in the sheet and for VoiceOver ("Mon Nov 16 · today").
  let day: String
  /// Another day than the live one is shown: the way back to today leads somewhere.
  let away: Bool
  let steps: DayArrows
  let today: @MainActor () -> Void
  let back: @MainActor () -> Void
  let forward: @MainActor () -> Void
  @State private var open = false

  public init(
    caption: String?, day: String, away: Bool, steps: DayArrows, today: @escaping @MainActor () -> Void,
    back: @escaping @MainActor () -> Void, forward: @escaping @MainActor () -> Void
  ) {
    self.caption = caption
    self.day = day
    self.away = away
    self.steps = steps
    self.today = today
    self.back = back
    self.forward = forward
  }

  /// Somewhere to go from the shown day: an older or newer day, or back to today.
  private var opens: Bool { steps.visible || away }

  public var body: some View {
    if opens {
      Button { open = true } label: { DayCapsule(caption: caption) }
      .buttonStyle(DayButtonStyle())
      .accessibilityLabel(Text(DayWords.label(day)))
      .sheet(isPresented: $open) {
        let shown = $open
        CardSheet(title: DayWords.title, subtitle: nil, close: { shown.wrappedValue = false }, rows: { picker })
      }
    } else {
      DayCapsule(caption: caption, opens: false)
        .accessibilityLabel(Text(DayWords.label(day)))
    }
  }

  /// The day in full, the three steps and the swipe hint.
  private var picker: some View {
    VStack(spacing: Tokens.Space.m) {
      Text(verbatim: day)
        .font(Tokens.Typography.quote)
        .foregroundStyle(Palette.textPrimary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
      VStack(spacing: 0) {
        row(DayWords.today, enabled: away, action: today)
        Divider().overlay(Palette.separator)
        row(DayWords.previous, enabled: steps.canGoBack, action: back)
        Divider().overlay(Palette.separator)
        row(DayWords.next, enabled: steps.canGoForward, action: forward)
      }
      .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
          .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin)
      }
      if steps.visible {
        Text(DayWords.swipeHint)
          .font(.footnote)
          .foregroundStyle(Palette.textQuaternary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private func row(_ title: LocalizedStringResource, enabled: Bool, action: @escaping @MainActor () -> Void) -> some View {
    Button {
      open = false
      action()
    } label: {
      HStack(spacing: Tokens.Space.s) {
        Text(title)
          .font(.body.weight(.medium))
          .foregroundStyle(Palette.textPrimary)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: Tokens.Space.s)
        FooterChevronChip()
      }
      .padding(.horizontal, Tokens.Space.l)
      .frame(maxWidth: .infinity, minHeight: Tokens.Size.dayRow, alignment: .leading)
      .contentShape(Rectangle())
      .dimmedWhenDisabled()
    }
    .buttonStyle(.washPress(Palette.info))
    .disabled(!enabled)
  }
}

/// What the day capsule says: the day ("Today", or "Fri Nov 13") and the down chevron, the face of
/// a `DaySwitch` or of any other control that opens the shown day's choices (the iPhone Chart's
/// menu of recorded days, Activity's calendar), styled `DayButtonStyle`. With nowhere to go
/// (`opens` false) the day alone, as plain text in the capsule's font.
public struct DayCapsule: View {
  /// nil on today ("Today"), else the shown day.
  let caption: String?
  let opens: Bool

  public init(caption: String?, opens: Bool = true) {
    self.caption = caption
    self.opens = opens
  }

  public var body: some View {
    let title = caption.map { Text(verbatim: $0) } ?? Text(DayWords.today)
    if opens {
      HStack(spacing: Tokens.Space.xs + Tokens.Space.xxs) {
        title
        Image(systemName: Symbols.scrollMore)
          .font(Tokens.Typography.annotationBold)
          .foregroundStyle(Palette.textTertiary)
      }
    } else {
      title
        .font(Tokens.Typography.button)
        .foregroundStyle(Palette.textPrimary)
    }
  }
}

/// The day button's capsule (the board's `.daycap`): the chip fill under a strong outline, the day
/// in `Typography.button`, pressed in while held; `Size.dayButton` tall, a `touchTarget`. On a
/// `Menu`, with `.menuStyle(.button)`.
public struct DayButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(Tokens.Typography.button)
      .foregroundStyle(Palette.textPrimary)
      .padding(.leading, Tokens.Space.m + Tokens.Space.xxs)
      .padding(.trailing, Tokens.Space.m)
      .frame(minHeight: Tokens.Size.dayButton)
      .background(Palette.chipFill, in: Capsule())
      .overlay(Capsule().strokeBorder(Palette.separatorStrong, lineWidth: Tokens.Stroke.thin))
      .touchTarget()
      .scaleEffect(configuration.isPressed ? Tokens.Motion.pressScale : 1)
      .animation(Tokens.Motion.quick, value: configuration.isPressed)
  }
}

public extension View {
  /// A sideways swipe across the page changes the shown day, as on the IOS2 boards: to the right
  /// the day before (`back`), to the left the day after (`forward`), each only where `steps` leads
  /// somewhere. Only a move mostly sideways and `Motion.daySwipeDistance` long counts, so a scroll
  /// never changes the day.
  func daySwipe(
    _ steps: DayArrows, back: @escaping @MainActor () -> Void, forward: @escaping @MainActor () -> Void
  ) -> some View {
    simultaneousGesture(DragGesture(minimumDistance: Tokens.Motion.daySwipeDistance).onEnded { drag in
      let sideways = drag.translation.width
      guard abs(sideways) > abs(drag.translation.height) * Tokens.Motion.daySwipeDominance else { return }
      if sideways > 0, steps.canGoBack {
        back()
      } else if sideways < 0, steps.canGoForward {
        forward()
      }
    }, including: steps.visible ? .all : .subviews)
  }
}
