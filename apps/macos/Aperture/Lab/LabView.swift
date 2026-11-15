import ApertureDesign
import ApertureKit
import SwiftUI

/// Strategy lab: the active strategy with its shown-day results, and the planned tools for
/// comparing strategies (observers, replays, the advisor), shown disabled until they are built.
struct LabView: View {
  /// Entrance order of the cards.
  private enum Order: Int {
    case active = 0, observers, refusals, replay, advisor
  }

  var body: some View {
    ScrollView {
      VStack(spacing: Tokens.Space.l) {
        ActiveStrategyCard().rise(step: Order.active.rawValue)
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          ObserversCard().rise(step: Order.observers.rawValue)
          RefusalsCard().rise(step: Order.refusals.rawValue)
        }
        HStack(alignment: .top, spacing: Tokens.Space.l) {
          ReplayCard().rise(step: Order.replay.rawValue)
          AdvisorCard().rise(step: Order.advisor.rawValue)
        }
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

/// Observer strategies: shadow versions that see the same data and never trade, with what they
/// decided on the shown day.
private struct ObserversCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.observers) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if let observers = model.observers?.observers {
          if observers.isEmpty {
            Footnote(L10n.Lab.observersEmpty)
          }
          ForEach(observers, id: \.self) { observer in
            ObserverRow(observer: observer, live: model.isLive, traded: traded)
              .transition(.opacity)
          }
        } else if model.observersError != nil {
          Footnote(L10n.Lab.observersUnavailable, color: Palette.warningText)
        }
        Footnote(L10n.Lab.observersNote)
      }
      .animation(Tokens.Motion.standard, value: model.observers)
    }
  }

  /// Symbols the bot traded or holds on the observers' day, to compare each observer's entries
  /// with; nil while that day's trades are not read, so no row claims the bot traded none.
  private var traded: Set<String>? {
    guard let day = model.observers?.day else { return nil }
    if model.isLive {
      guard let status = model.status, day == model.today else { return nil }
      return Set(status.tradesToday.map(\.symbol) + status.positions.map(\.symbol))
    }
    guard let document = model.dayDocument, document.day == day else { return nil }
    return Set(document.trades.map(\.symbol))
  }
}

/// Why the active strategy's signals were refused on the shown day: one bar per cause, the most
/// frequent first (GET /skipped, counted by `RefusalCount`).
private struct RefusalsCard: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Card(L10n.Lab.refusals) {
      VStack(alignment: .leading, spacing: Tokens.Space.m) {
        if let signals = model.skipped?.signals {
          let counts = RefusalCount.make(signals)
          if counts.isEmpty {
            Footnote(L10n.Lab.noRefusals)
          }
          let most = Double(counts.first?.count ?? 1)
          ForEach(counts) { count in
            VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
              HStack(alignment: .firstTextBaseline) {
                title(count.cause)
                  .font(Tokens.Typography.callout)
                  .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(verbatim: String(count.count))
                  .font(Tokens.Typography.calloutMono.bold())
                  .foregroundStyle(Palette.textPrimary)
              }
              ProgressView(value: Double(count.count), total: most)
                .tint(Palette.warning)
                .accessibilityHidden(true)
            }
            .help(Text(verbatim: count.cause?.code ?? String(localized: L10n.Lab.noCause)))
            .accessibilityElement(children: .combine)
          }
        } else if let error = model.skippedError {
          Footnote(L10n.Trades.notTakenUnavailable(error), color: Palette.warningText)
        } else {
          ProgressView().controlSize(.small)
        }
      }
      .animation(Tokens.Motion.standard, value: model.skipped)
    }
  }

  private func title(_ cause: RefusalCause?) -> Text {
    if let code = cause?.known { return Text(L10n.Cause.title(code)) }
    if let cause { return Text(verbatim: cause.code) }
    return Text(L10n.Lab.noCause)
  }
}

/// One observer: name and version, how many decisions it made, the latest one and its result.
struct ObserverRow: View {
  let observer: ObserverV1
  let live: Bool
  /// Symbols the bot traded that day; when given, the row says how many of the observer's entries
  /// the bot also took.
  var traded: Set<String>?

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
      HStack(spacing: Tokens.Space.s) {
        PulseDot(Palette.highlight, size: Tokens.Size.dotSmall, pulsing: live)
        Text(verbatim: observer.name).font(Tokens.Typography.calloutMono)
        Badge(verbatim: observer.version, color: Palette.accentText)
        Spacer()
        if let result = observer.resultGrossUSD {
          MoneyText(value: result.value, usd: true, font: Tokens.Typography.calloutMono)
        } else {
          // The bot says why it has no result (no captured bars, no decisions...).
          Text(verbatim: Format.missing)
            .foregroundStyle(Palette.textQuaternary)
            .help(observer.resultCause.map { Text(verbatim: $0) } ?? Text(L10n.Lab.resultPending))
        }
      }
      HStack(spacing: Tokens.Space.s) {
        Text(L10n.Lab.decisionCount(observer.decisions.count))
        if let last = observer.decisions.last {
          Text(L10n.Lab.lastDecision(String(localized: last.action.title), last.symbol,
            Format.marketMinute(last.at.date)))
        }
      }
      .font(Tokens.Typography.captionMono)
      .foregroundStyle(Palette.textTertiary)
      if observer.resultGrossUSD == nil, let cause = observer.resultCause {
        Text(verbatim: cause)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.textQuaternary)
      }
      if let traded {
        agreement(ObserverSummary(observer, traded: traded))
      }
    }
  }

  /// How many of the symbols the observer would have entered the bot also traded, as a bar.
  @ViewBuilder private func agreement(_ summary: ObserverSummary) -> some View {
    if let share = summary.agreement {
      ProgressView(value: share)
        .tint(Palette.highlight)
        .accessibilityHidden(true)
      Text(L10n.Lab.agreement(summary.shared.count, summary.entered.count,
        summary.entered.joined(separator: Format.listSeparator)))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
    } else {
      Text(L10n.Lab.noEntries)
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textTertiary)
    }
  }
}

extension Verdict {
  /// The decision as the app names it.
  var title: LocalizedStringResource {
    switch self {
    case .ignore: L10n.Lab.verdictIgnore
    case .watch: L10n.Lab.verdictWatch
    case .enter: L10n.Lab.verdictEnter
    case .hold: L10n.Lab.verdictHold
    case .exit: L10n.Lab.verdictExit
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
