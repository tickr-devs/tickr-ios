import SwiftUI
import TickrKit

/// The four steps of a close-and-stop (boards Main and IOSHome), one line each: a dot (green
/// done, amber under way, grey not reached), the step and when it began. Driven only by the
/// bot's status (`StopWatch.steps`); the step under way pulses once per status read (`event`),
/// and stays still with Reduce Motion on (`PulseDot`).
public struct StopStepsList: View {
  let rows: [StopStepRow]
  /// Changes on each status read: the step under way pulses then.
  let event: AnyHashable?

  public init(_ rows: [StopStepRow], event: AnyHashable?) {
    self.rows = rows
    self.event = event
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
        if index > 0 { StopRule() }
        HStack(spacing: Tokens.Space.s) {
          PulseDot(color(row.phase), pulsing: row.phase == .running, event: event)
          Text(row.title)
            .font(Tokens.Typography.callout.weight(row.phase == .running ? .semibold : .regular))
            .foregroundStyle(row.phase == .waiting ? Palette.textQuaternary : Palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: Tokens.Space.s)
          if let since = row.since {
            Text(verbatim: ClockText.seconds(since))
              .font(Tokens.Typography.captionMono)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        .padding(.vertical, Tokens.Space.xs)
        .accessibilityElement(children: .combine)
      }
    }
    .padding(.horizontal, Tokens.Space.m)
    .padding(.vertical, Tokens.Space.xxs)
    .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.medium, style: .continuous)
      .strokeBorder(Palette.separator, lineWidth: Tokens.Stroke.thin))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(StopText.closeAndStop))
  }

  private func color(_ phase: StopStepRow.Phase) -> Color {
    switch phase {
    case .done: Palette.profit
    case .running: Palette.warning
    case .waiting: Palette.separatorStrong
    }
  }
}

/// "Bot stopped · N positions open" (boards Main and IOSHome): a standing amber panel in place of
/// the positions, never a popup. The stop time, what nobody does for these positions now, each
/// position as the stopped bot last knew it (symbol, shares, broker stop), the time of that
/// knowledge, and the app's own Start bot (`start`).
public struct StoppedPositionsPanel<Start: View>: View {
  let panel: StoppedPositions
  let start: Start

  public init(_ panel: StoppedPositions, @ViewBuilder start: () -> Start) {
    self.panel = panel
    self.start = start()
  }

  public var body: some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.Radius.large, style: .continuous)
    VStack(alignment: .leading, spacing: Tokens.Space.m) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Tokens.Space.m) {
          heading
          Spacer(minLength: Tokens.Space.s)
          start.fixedSize()
        }
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          heading
          start
        }
      }
      Text(StopText.stoppedBody)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      table
      Text(panel.note)
        .font(Tokens.Typography.caption)
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.warning.opacity(Tokens.Opacity.wash), in: shape)
    .overlay(shape.strokeBorder(Palette.warning.opacity(Tokens.Opacity.border), lineWidth: Tokens.Stroke.thin))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(panel.title))
  }

  private var heading: some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: StopRule.panelSymbol)
        .font(Tokens.Typography.symbol)
        .foregroundStyle(Palette.warningText)
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(panel.title)
          .font(Tokens.Typography.callout.weight(.bold))
          .foregroundStyle(Palette.warningText)
          .fixedSize(horizontal: false, vertical: true)
        Text(panel.since)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var table: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: Tokens.Space.m) {
        Text(StopText.symbolColumn).frame(width: StopRule.symbolWidth, alignment: .leading)
        Text(StopText.quantityColumn).frame(maxWidth: .infinity, alignment: .leading)
        Text(StopText.stopColumn)
      }
      .font(Tokens.Typography.caption)
      .foregroundStyle(Palette.textQuaternary)
      .padding(.bottom, Tokens.Space.xs)
      ForEach(panel.rows) { row in
        StopRule()
        HStack(spacing: Tokens.Space.m) {
          Text(verbatim: row.symbol)
            .font(Tokens.Typography.calloutMono.weight(.bold))
            .foregroundStyle(Palette.textPrimary)
            .frame(width: StopRule.symbolWidth, alignment: .leading)
          Text(StopText.shares(Shares.text(row.quantity)))
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(verbatim: row.stop.map { Money.dollar + Money.price($0) } ?? Money.missing)
            .font(Tokens.Typography.calloutMono)
            .foregroundStyle(Palette.warningText)
        }
        .padding(.vertical, Tokens.Space.xs)
        .accessibilityElement(children: .combine)
      }
    }
  }
}

/// The thin line between two rows of the steps or the panel's table, and the panel's constants
/// (a generic view cannot hold stored ones).
struct StopRule: View {
  /// Width of the panel's symbol column, in points (the boards' 56).
  static let symbolWidth: CGFloat = Tokens.Size.iconWell + Tokens.Space.m
  /// SF Symbol of the stopped-with-positions panel.
  static let panelSymbol = "exclamationmark.triangle.fill"

  var body: some View {
    Rectangle()
      .fill(Palette.separator)
      .frame(height: Tokens.Stroke.thin)
      .accessibilityHidden(true)
  }
}
