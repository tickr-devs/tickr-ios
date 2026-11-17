import SwiftUI

// Motion that marks a change of the bot's data, as the design's boards draw it: a bar growing to
// its new length, a new row's flash, a figure counting to its new value. Each plays once per real
// change (and once as it appears), never on a timer, and shows its still final state with Reduce
// Motion (docs/design-system.md, rule 5).

/// Grows a bar in from its leading edge as it appears, then moves it to its new length each time
/// `value` changes: one move per change of the data, still in between. Still with Reduce Motion.
struct Grow: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var grown = false
  let value: AnyHashable
  let delay: Double

  func body(content: Content) -> some View {
    let isGrown = grown || reduceMotion
    content
      .scaleEffect(x: isGrown ? 1 : 0, anchor: .leading)
      .animation(reduceMotion ? nil : Tokens.Motion.fill, value: value)
      .onAppear {
        withAnimation(reduceMotion ? nil : Tokens.Motion.fill.delay(delay)) { grown = true }
      }
  }
}

public extension View {
  /// Grows in from the leading edge on appear (the `step`-th bar of a list, `Motion.stagger`
  /// apart) and moves to each new length when `value` changes.
  func grows(with value: some Hashable, step: Int = 0) -> some View {
    modifier(Grow(value: AnyHashable(value), delay: Double(step) * Tokens.Motion.stagger))
  }
}

/// Tints a row once as it arrives (a journal line, a signal the bot just skipped) and fades the
/// tint out: one flash per genuinely new row, nothing for rows already shown or with Reduce Motion.
struct ArrivalFlash: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var flashes = 0
  let arrived: Bool
  let color: Color
  /// How far the tint reaches past the row on each side, so neighbouring cells join up.
  let outset: EdgeInsets

  func body(content: Content) -> some View {
    content
      .background {
        RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
          .fill(color)
          .phaseAnimator([false, true], trigger: flashes) { tint, lit in
            tint.opacity(lit ? Tokens.Opacity.flash : 0)
          } animation: { lit in
            lit ? Tokens.Motion.quick : Tokens.Motion.flash
          }
          .padding(EdgeInsets(top: -outset.top, leading: -outset.leading, bottom: -outset.bottom,
            trailing: -outset.trailing))
          .allowsHitTesting(false)
      }
      .onAppear { flash(arrived) }
      .onChange(of: arrived) { _, now in flash(now) }
  }

  private func flash(_ now: Bool) {
    if now && !reduceMotion { flashes += 1 }
  }
}

public extension View {
  /// One fading tint in `color` when `arrived` (the row is new in this change of its list; see
  /// `onArrival`), reaching `outset` past the row.
  func arrivalFlash(_ arrived: Bool, color: Color, outset: EdgeInsets = EdgeInsets()) -> some View {
    modifier(ArrivalFlash(arrived: arrived, color: color, outset: outset))
  }

  /// Calls `perform` with the ids that are new in each change of `ids`. None on the first value,
  /// and none when no id carries over (a different list: another day, a reconnect), so only a
  /// row the bot just added counts as arrived.
  func onArrival<ID: Hashable>(of ids: [ID], perform: @escaping (Set<ID>) -> Void) -> some View {
    onChange(of: ids) { old, new in
      let kept = Set(old).intersection(new)
      perform(kept.isEmpty ? [] : Set(new).subtracting(old))
    }
  }
}

/// Grows a count a little and settles it back (`Motion.bump`, the boards' `bumpA/B`) once each time
/// it rises: one bump per real rise of the data, nothing when it falls, stays or first appears, and
/// nothing with Reduce Motion.
struct CountBump: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bumps = 0
  let count: Int

  func body(content: Content) -> some View {
    content
      .phaseAnimator([false, true], trigger: bumps) { view, grown in
        view.scaleEffect(grown ? Tokens.Motion.bumpScale : 1)
      } animation: { _ in
        Tokens.Motion.bump
      }
      .onChange(of: count) { old, new in
        if Self.rises(from: old, to: new) && !reduceMotion { bumps += 1 }
      }
  }

  /// Whether a change of the count is a rise, the one change that bumps it.
  nonisolated static func rises(from old: Int, to new: Int) -> Bool { new > old }
}

public extension View {
  /// Every change that comes with a new `period` (another shown day) lands at once: no crossfade
  /// of one day's words over the other's and no figure counting from one day's to the other's.
  func jumps<Period: Equatable>(on period: Period) -> some View {
    transaction(value: period) { transaction in
      transaction.animation = nil
      transaction.disablesAnimations = true
    }
  }

  /// One bump each time `count` rises (see `CountBump`): a refusal counted again, say.
  func bumps(on count: Int) -> some View { modifier(CountBump(count: count)) }
}

/// A figure that counts up from zero as it appears and counts on to each new value (`Motion.fill`),
/// as the design's figures do; at its value at once with Reduce Motion. `format` writes a value.
public struct CountingText: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown: Double = 0
  /// The period `shown` is of.
  @State private var shownPeriod: AnyHashable?
  let value: Double
  /// What the figure is of (the shown day): when it changes, the figure is another day's and shows
  /// at once, never counting through values no day had.
  let period: AnyHashable?
  let format: (Double) -> String

  public init(_ value: Double, period: AnyHashable? = nil, format: @escaping (Double) -> String) {
    self.value = value
    self.period = period
    self.format = format
  }

  public var body: some View {
    CountedText(value: shown, format: format)
      .onAppear(perform: count)
      .onChange(of: value, count)
      .onChange(of: period, count)
      // VoiceOver reads the figure itself, never a step of the count.
      .accessibilityLabel(Text(verbatim: format(value)))
  }

  private func count() {
    // Another period's figure lands at once; the first appearance and a new value of the same
    // period count.
    let samePeriod = shownPeriod == period || shown == 0
    shownPeriod = period
    withAnimation(reduceMotion || !samePeriod ? nil : Tokens.Motion.fill) { shown = value }
  }
}

/// The text of a `CountingText` at one step of its count: SwiftUI animates `value` frame by frame.
private struct CountedText: View, Animatable {
  var value: Double
  let format: (Double) -> String

  nonisolated var animatableData: Double {
    get { value }
    set { value = newValue }
  }

  var body: some View { Text(verbatim: format(value)) }
}
