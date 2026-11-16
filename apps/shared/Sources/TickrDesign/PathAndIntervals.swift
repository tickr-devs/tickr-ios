import SwiftUI

/// One step of a path drawn as dots joined by a line, such as an advisor proposal's path
/// (proposed, judged, decided, observer, active).
public struct PathStep: Identifiable {
  /// Reached, refused at this step (the owner rejected), or not reached yet.
  public enum State: Sendable, Hashable {
    case done, refused, pending
  }

  public let id: Int
  public let title: Text
  public let systemImage: String
  public let state: State
  /// The state in words, for VoiceOver (the symbol does not change with it).
  public let value: Text

  public init(id: Int, title: Text, systemImage: String, state: State, value: Text) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.state = state
    self.value = value
  }
}

/// Steps left to right, each a dot with its title under it; the line between two dots is
/// coloured when both are reached. Where the titles do not fit side by side on one line each (a
/// narrow phone, large text), the steps stack top to bottom instead, so no title breaks inside a
/// word. A step that changes state pops (an event, never a loop).
public struct StepPath: View {
  let steps: [PathStep]

  public init(_ steps: [PathStep]) {
    self.steps = steps
  }

  public var body: some View {
    ViewThatFits(in: .horizontal) {
      across
      down
    }
  }

  private var down: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      ForEach(steps) { step in
        HStack(spacing: Tokens.Space.s) {
          dot(step)
          step.title
            .font(Tokens.Typography.annotation)
            .foregroundStyle(step.state == .pending ? Palette.textQuaternary : Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.value)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var across: some View {
    HStack(alignment: .top, spacing: 0) {
      ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
        VStack(spacing: Tokens.Space.xs) {
          ZStack {
            HStack(spacing: 0) {
              line(reached: index > 0 && step.state == .done && steps[index - 1].state == .done, shown: index > 0)
              line(reached: index + 1 < steps.count && step.state == .done && steps[index + 1].state == .done,
                shown: index + 1 < steps.count)
            }
            dot(step)
          }
          step.title
            .font(Tokens.Typography.annotation)
            .foregroundStyle(step.state == .pending ? Palette.textQuaternary : Palette.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize()
            // A gap between neighbouring titles, so the row gives way to the list before they touch.
            .padding(.horizontal, Tokens.Space.xs)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.value)
      }
    }
  }

  private func line(reached: Bool, shown: Bool) -> some View {
    Rectangle()
      .fill(reached ? Palette.highlight : Palette.separatorStrong)
      .frame(height: Tokens.Stroke.bold)
      .opacity(shown ? 1 : 0)
  }

  private func dot(_ step: PathStep) -> some View {
    let fill = step.state == .done ? Palette.highlight : Palette.surface
    let stroke = switch step.state {
    case .done: Palette.highlight
    case .refused: Palette.loss
    case .pending: Palette.separatorStrong
    }
    let symbol = switch step.state {
    case .done: Palette.onAccent
    case .refused: Palette.lossText
    case .pending: Palette.textQuaternary
    }
    return Image(systemName: step.systemImage)
      .font(Tokens.Typography.chevron)
      .foregroundStyle(symbol)
      .frame(width: Tokens.Size.glyphCompact, height: Tokens.Size.glyphCompact)
      .background(fill, in: Circle())
      .overlay(Circle().strokeBorder(stroke, lineWidth: Tokens.Stroke.bold))
      .contentTransition(.symbolEffect(.replace))
      .animation(Tokens.Motion.standard, value: step.state)
  }
}

/// One interval on a shared axis: a mean dot on a bar from low to high. Positions are shares of
/// the width, 0 to 1 (the axis is drawn symmetric around its middle); nil = not computed.
public struct IntervalRow: Identifiable {
  public let id: String
  public let name: String
  public let detail: String
  public let color: Color
  public let low: Double?
  public let mean: Double?
  public let high: Double?
  /// The interval's bounds in words, for VoiceOver (the bar itself is not read).
  public let value: String

  public init(
    id: String, name: String, detail: String, color: Color, low: Double?, mean: Double?, high: Double?, value: String
  ) {
    self.id = id
    self.name = name
    self.detail = detail
    self.color = color
    self.low = low
    self.mean = mean
    self.high = high
    self.value = value
  }
}

/// Intervals on one axis with its zero in the middle, such as base and candidate mean R on a
/// hold-out. `axis` names the middle ("0 R").
public struct IntervalBars: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let rows: [IntervalRow]
  let axis: String

  /// The zero line sits in the middle of the width.
  static let middle: CGFloat = 0.5

  public init(_ rows: [IntervalRow], axis: String) {
    self.rows = rows
    self.axis = axis
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
          HStack {
            Text(verbatim: row.name)
              .font(Tokens.Typography.captionMono.weight(.bold))
              .foregroundStyle(row.color)
            Spacer(minLength: Tokens.Space.s)
            Text(verbatim: row.detail)
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textQuaternary)
          }
          track(row, step: index)
            .frame(height: Tokens.Size.glyphCompact)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: row.value))
      }
      Text(verbatim: axis)
        .font(Tokens.Typography.annotation)
        .foregroundStyle(Palette.textQuaternary)
        .frame(maxWidth: .infinity)
    }
  }

  /// The bars grow in one after another as they appear, as the design's do; a bar and its mean
  /// move only when the run's interval changes.
  private func track(_ row: IntervalRow, step: Int) -> some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let middle = geometry.size.height * Self.middle
      ZStack(alignment: .topLeading) {
        Rectangle()
          .fill(Palette.separatorStrong)
          .frame(width: Tokens.Stroke.thin, height: geometry.size.height)
          .position(x: width * Self.middle, y: middle)
        if let low = row.low, let high = row.high {
          Capsule()
            .fill(row.color.opacity(Tokens.Opacity.border))
            .frame(width: max(width * CGFloat(high - low), Tokens.Size.dotSmall), height: Tokens.Size.dotSmall)
            .grows(with: [low, high], step: step)
            .position(x: width * CGFloat(low + high) * Self.middle, y: middle)
        }
        if let mean = row.mean {
          Circle()
            .fill(row.color)
            .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
            .overlay(Circle().strokeBorder(Palette.surface, lineWidth: Tokens.Stroke.bold))
            .position(x: width * CGFloat(mean), y: middle)
        }
      }
      .animation(reduceMotion ? nil : Tokens.Motion.fill, value: [row.low, row.mean, row.high])
    }
  }
}
