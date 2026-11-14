import ApertureDesign
import ApertureKit
import SwiftUI

/// Strategy lab: the active strategy with its shown-day results, and the planned tools for
/// comparing strategies (observers, replays, the advisor), shown disabled until they are built.
struct LabView: View {
  /// Entrance order of the cards.
  private enum Order: Int {
    case active = 0, observers, replay, advisor
  }

  var body: some View {
    ScrollView {
      VStack(spacing: Tokens.Space.l) {
        ActiveStrategyCard().rise(step: Order.active.rawValue)
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          ObserversCard().rise(step: Order.observers.rawValue)
          ReplayCard().rise(step: Order.replay.rawValue)
        }
        AdvisorCard().rise(step: Order.advisor.rawValue)
      }
      .padding(Tokens.Space.xl)
      .frame(maxWidth: Tokens.Size.contentMaxWidth)
    }
  }
}

/// The strategy the bot trades with, and how it did on the shown day.
private struct ActiveStrategyCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.activeStrategy, tint: Palette.accent) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
          Text(verbatim: model.status?.strategy.name ?? model.settings?.activeStrategy ?? Format.missing)
            .font(Tokens.Typography.title)
            .foregroundStyle(Palette.textPrimary)
          if let version = model.status?.strategy.version {
            Badge(verbatim: version, color: Palette.accentText)
          }
        }
        HStack(spacing: Tokens.Space.xl) {
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            CardLabel(L10n.Lab.shownDayTrades)
            Text(L10n.Lab.closedWinsLosses(model.shownTradeCount, model.shownWins, model.shownLosses))
              .font(Tokens.Typography.metric)
              .foregroundStyle(Palette.textPrimary)
          }
          VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
            CardLabel(L10n.Lab.shownDayResult)
            MoneyText(value: model.shownResult, usd: true, font: Tokens.Typography.metric)
          }
          Spacer(minLength: Tokens.Space.l)
          DrawnSparkline(values: model.cumulativeResults, color: Palette.result(model.shownResult))
            .frame(width: Tokens.Size.sideColumn, height: Tokens.Size.sparkline)
        }
        Footnote(L10n.Lab.swapNote)
      }
    }
  }
}

/// Observer strategies: shadow versions that see the same data and never trade.
private struct ObserversCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.observers, trailing: { PlannedTag(.backlog) }) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        if let observers = model.settings?.observers, !observers.isEmpty {
          ForEach(observers, id: \.self) { name in
            HStack(spacing: Tokens.Space.s) {
              Image(systemName: "eye").foregroundStyle(Palette.textQuaternary)
              Text(verbatim: name).font(Tokens.Typography.calloutMono)
            }
          }
        }
        Footnote(L10n.Lab.observersNote)
      }
    }
  }
}

/// Replays of a recorded day: skipped signals as if entered, or another strategy.
private struct ReplayCard: View {
  var body: some View {
    Card(L10n.Lab.replay, trailing: { PlannedTag(.backlog) }) {
      VStack(alignment: .leading, spacing: Tokens.Space.s) {
        Footnote(L10n.Lab.replayNote)
        HStack(spacing: Tokens.Space.s) {
          Button {} label: { Label { Text(L10n.Lab.replayDay) } icon: { Image(systemName: "play.circle") } }
          Button {} label: { Label { Text(L10n.Lab.skippedSignals) } icon: { Image(systemName: "arrow.uturn.right") } }
          Button {} label: { Label { Text(L10n.Lab.compare) } icon: { Image(systemName: "square.split.2x1") } }
        }
        .disabled(true)
      }
    }
  }
}

/// The advisor: proposes new strategy versions from recorded days, for the owner to accept.
private struct AdvisorCard: View {
  var body: some View {
    Card(L10n.Lab.advisor, trailing: { PlannedTag(.backlog) }) {
      HStack(alignment: .top, spacing: Tokens.Space.m) {
        Image(systemName: "sparkles")
          .font(Tokens.Typography.symbol)
          .foregroundStyle(Palette.highlight)
        Footnote(L10n.Lab.advisorNote)
      }
    }
  }
}

#if DEBUG
#Preview {
  LabView()
    .environment(PreviewAPI.model())
    .frame(width: PreviewAPI.windowWidth, height: PreviewAPI.windowHeight)
}
#endif
