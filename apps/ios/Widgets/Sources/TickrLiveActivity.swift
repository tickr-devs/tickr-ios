import ActivityKit
import SwiftUI
import TickrDesign
import TickrKit
import WidgetKit

/// The extension's widgets: the trading day's Live Activity only.
@main
struct TickrWidgetBundle: WidgetBundle {
  var body: some Widget {
    TickrLiveActivity()
  }
}

/// The trading day's Live Activity (mockup v138), started, updated and ended by the bot's push
/// only: the Lock Screen card and the Dynamic Island (compact, minimal, expanded). The island is
/// always black; the rows are the Lock Screen card's.
struct TickrLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TickrActivityAttributes.self) { context in
      LiveLockScreen(state: context.state)
        .activityBackgroundTint(Palette.surface)
        .activitySystemActionForegroundColor(Palette.textPrimary)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: Tokens.Space.s) {
            BrandMark(size: Tokens.LiveActivity.mark, live: false, drawsIn: false)
            Text(L10n.brand)
              .font(Tokens.LiveActivity.brand)
              .foregroundStyle(Palette.textPrimary)
              .fixedSize()
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          LiveDayResult(result: state.dayResult, font: Tokens.LiveActivity.headerFigure)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: Tokens.Space.s) {
            LiveStateLine(state: state)
            if state.state != .flat {
              LiveRows(state: state)
              LiveStopsLine(state: state)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } compactLeading: {
        LiveCompactLeading(state: state)
      } compactTrailing: {
        LiveCompactTrailing(state: state)
      } minimal: {
        LiveDot(tone: state.minimalTone, ringed: state.state.ringed)
      }
      .keylineTint(state.state.tone.fill)
    }
  }
}

/// The compact island's leading side: the state's dot and the open positions' count, or "Flat".
struct LiveCompactLeading: View {
  let state: TickrActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: Tokens.Space.xs) {
      LiveDot(tone: state.state.tone, ringed: state.state.ringed)
      Group {
        if state.state == .flat {
          Text(L10n.flat)
        } else {
          Text(String(state.positions.count))
        }
      }
      .font(Tokens.LiveActivity.compact)
      .foregroundStyle(Palette.textPrimary)
      .fixedSize()
    }
  }
}

/// The compact island's trailing side: the day's result, or during the alarm the red "!" and
/// the symbol whose stop is not confirmed.
struct LiveCompactTrailing: View {
  /// The alarm's badge.
  static let alarmSymbol = "exclamationmark.circle.fill"

  let state: TickrActivityAttributes.ContentState

  var body: some View {
    if state.state == .alarm, let symbol = state.alarmSymbol {
      HStack(spacing: Tokens.Space.xs) {
        Image(systemName: Self.alarmSymbol)
          .foregroundStyle(Palette.onLoss, Palette.lossFill)
        Text(symbol)
          .foregroundStyle(Palette.lossText)
      }
      .font(Tokens.LiveActivity.compact)
      .fixedSize()
    } else {
      LiveDayResult(result: state.dayResult, font: Tokens.LiveActivity.compactFigure)
    }
  }
}

/// The Lock Screen card: the state's headline beside the day's result, the rows, and when the
/// broker last confirmed the stops (with their prices). Flat shows the day's last word only.
struct LiveLockScreen: View {
  let state: TickrActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        if state.state == .open {
          HStack(spacing: Tokens.Space.s) {
            LiveDot(tone: state.state.tone, ringed: true)
            Text(L10n.protected(state.positions.count))
              .font(Tokens.LiveActivity.line)
              .foregroundStyle(Palette.textPrimary)
              .fixedSize(horizontal: false, vertical: true)
          }
        } else {
          LiveStateLine(state: state)
        }
        Spacer(minLength: Tokens.Space.s)
        LiveDayResult(result: state.dayResult, font: Tokens.LiveActivity.headerFigure)
      }
      if state.state != .flat {
        LiveRows(state: state)
        LiveStopsLine(state: state, prices: true)
      }
    }
    .padding(Tokens.Space.l)
  }
}
