import SwiftUI
import TickrDesign
import TickrKit

/// Why the bot acted here: what the trading strategy and its observers decided on the chosen
/// symbol that day (GET /decisions), each decision with the checks behind it. The trading
/// strategy leads, observers follow under their own label; the same verdict repeated bar after
/// bar is one row with a count. Entries and exits show first; watching and holding open on request.
struct DecisionsCard: View {
  let decisions: DecisionsV1?
  let failure: String?
  @State private var showsAll = false

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(ChartText.decisions)
      if let decisions {
        let list = DecisionList(decisions.decisions, everything: showsAll)
        if list.total == 0 {
          note(ChartText.noDecisions)
        } else {
          CardLabel(ChartText.tradingStrategy)
          if list.strategy.isEmpty {
            note(showsAll ? ChartText.noStrategyDecisions : ChartText.noEntries)
          }
        }
        runs(list.strategy)
        if !list.observers.isEmpty {
          CardLabel(ChartText.observers)
            .padding(.top, Tokens.Space.s)
          ForEach(list.observers, id: \.self) { observer in
            runs(observer)
          }
        }
        if list.total > list.key {
          Button {
            showsAll.toggle()
          } label: {
            Text(showsAll ? ChartText.keyDecisions : ChartText.allDecisions(list.total))
          }
          // A quiet in-card action, the apps' ghost button (never the system's borderless look).
          .buttonStyle(.action(.ghost, size: .compact))
        }
      } else if let failure {
        ReadFailureNote(ChartText.decisionsFailed, detail: failure)
      } else {
        TickrLoader(L10n.Common.loading).frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard()
    .animation(Tokens.Motion.standard, value: showsAll)
  }

  private func runs(_ runs: [DecisionRun]) -> some View {
    LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
      ForEach(runs, id: \.self) { run in
        DecisionRow(run: run)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  private func note(_ text: LocalizedStringResource) -> some View {
    Text(text)
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textTertiary)
  }
}

/// One decision, or a run of the same one: time, action, strategy (observers marked), how many
/// bars in a row and since when, and, when opened, the checks of the newest one.
private struct DecisionRow: View {
  let run: DecisionRun
  @State private var open = false

  private var decision: DecisionV1 { run.latest }

  var body: some View {
    DisclosureGroup(isExpanded: $open) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        if let entry = decision.entryPrice, let stop = decision.stopPrice {
          Text(ChartText.entryStop(Money.price(entry.value), Money.price(stop.value)))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textSecondary)
        }
        ForEach(Array(decision.checks.enumerated()), id: \.offset) { _, check in
          CheckLine(check: check)
        }
      }
      .padding(.top, Tokens.Space.xs)
    } label: {
      // As the design's rows: a dot in the verdict's colour, what the bot did and which strategy,
      // and the time at the end; at large text sizes the pieces wrap whole.
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
        Circle()
          .fill(decision.action.dotColor)
          .frame(width: Tokens.Size.dot, height: Tokens.Size.dot)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
          ChipFlow(spacing: Tokens.Space.xs) {
            Text(decision.action.title)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(Palette.textPrimary)
            Text(ChartText.strategy(decision.strategy.name, decision.strategy.version))
              .font(.footnote)
              .foregroundStyle(Palette.textSecondary)
            if decision.observer {
              Text(ChartText.observer)
                .font(Tokens.Typography.annotation)
                .foregroundStyle(Palette.highlightText)
            }
          }
          if run.count > 1 {
            Text(ChartText.repeats(run.count, run.earliest.at.date.formatted(ChartFormat.time)))
              .font(Tokens.Typography.annotation)
              .foregroundStyle(Palette.textQuaternary)
          }
        }
        Spacer(minLength: Tokens.Space.s)
        Text(decision.at.date, format: ChartFormat.time)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
          .fixedSize()
      }
    }
    .tint(Palette.textTertiary)
  }
}

/// A rule the strategy checked: `rule measured operator threshold`, passed or not.
private struct CheckLine: View {
  let check: CheckV1

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      if check.passed {
        Image(systemName: Symbols.passed).foregroundStyle(Palette.profit)
      } else {
        Image(systemName: Symbols.failed).foregroundStyle(Palette.loss)
      }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: ApiText.rule(check.rule))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textPrimary)
        // What it measured against what it needs, never a comparison a failed check contradicts.
        Text(verbatim: check.valueText)
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textTertiary)
        if !check.note.isEmpty {
          Text(verbatim: check.note)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

extension Verdict {
  /// The decision as the app names it.
  var title: LocalizedStringResource {
    switch self {
    case .ignore: return ChartText.verdictIgnore
    case .watch: return ChartText.verdictWatch
    case .enter: return ChartText.verdictEnter
    case .hold: return ChartText.verdictHold
    case .exit: return ChartText.verdictExit
    }
  }

  /// The decision's dot, as on the design's chart: entries green, watching amber, exits in the
  /// info colour, the rest muted.
  var dotColor: Color {
    switch self {
    case .enter: return Palette.profit
    case .watch: return Palette.warning
    case .exit: return Palette.info
    case .ignore, .hold: return Palette.textQuaternary
    }
  }
}
