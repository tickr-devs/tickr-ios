import ApertureDesign
import ApertureKit
import SwiftUI

/// Why the bot acted here: what the trading strategy and its observers decided on the chosen
/// symbol that day (GET /decisions), each decision with the checks behind it. Entries and exits
/// show first; the bar-by-bar watching and holding open on request.
struct DecisionsCard: View {
  let decisions: DecisionsV1?
  let failure: String?
  @State private var showsAll = false

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      CardLabel(ChartText.decisions)
      if let decisions {
        let all = Array(decisions.decisions.reversed())
        let key = all.filter { $0.action == .enter || $0.action == .exit }
        let shown = showsAll ? all : key
        if all.isEmpty {
          note(ChartText.noDecisions)
        } else if shown.isEmpty {
          note(ChartText.noEntries)
        }
        LazyVStack(alignment: .leading, spacing: Tokens.Space.s) {
          ForEach(shown, id: \.self) { decision in
            DecisionRow(decision: decision)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        if all.count > key.count {
          Button {
            showsAll.toggle()
          } label: {
            Text(showsAll ? ChartText.keyDecisions : ChartText.allDecisions(all.count))
          }
          .buttonStyle(.borderless)
          .font(Tokens.Typography.captionMono)
        }
      } else if let failure {
        note(ChartText.decisionsFailed(failure))
      } else {
        ProgressView().frame(maxWidth: .infinity)
      }
    }
    .padding(Tokens.Space.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .apertureCard()
    .animation(Tokens.Motion.standard, value: showsAll)
  }

  private func note(_ text: LocalizedStringResource) -> some View {
    Text(text)
      .font(Tokens.Typography.callout)
      .foregroundStyle(Palette.textTertiary)
  }
}

/// One decision: time, action, strategy (observers marked) and, when opened, its checks.
private struct DecisionRow: View {
  let decision: DecisionV1
  @State private var open = false

  var body: some View {
    DisclosureGroup(isExpanded: $open) {
      VStack(alignment: .leading, spacing: Tokens.Space.xs) {
        if let entry = decision.entryPrice, let stop = decision.stopPrice {
          Text(ChartText.entryStop(entry.text, stop.text))
            .font(Tokens.Typography.captionMono)
            .foregroundStyle(Palette.textSecondary)
        }
        ForEach(Array(decision.checks.enumerated()), id: \.offset) { _, check in
          CheckLine(check: check)
        }
      }
      .padding(.top, Tokens.Space.xs)
    } label: {
      HStack(spacing: Tokens.Space.s) {
        Text(decision.at.date, format: ChartFormat.time)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
        Text(decision.action.title)
          .font(Tokens.Typography.annotationBold)
          .padding(.horizontal, Tokens.Space.s)
          .padding(.vertical, Tokens.Space.xxs)
          .foregroundStyle(decision.action.color)
          .background(decision.action.color.opacity(Tokens.Opacity.wash), in: Capsule())
        Text(ChartText.strategy(decision.strategy.name, decision.strategy.version))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textSecondary)
          .lineLimit(1)
        if decision.observer {
          Text(ChartText.observer)
            .font(Tokens.Typography.annotation)
            .foregroundStyle(Palette.highlight)
        }
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
        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.profit)
      } else {
        Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.loss)
      }
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        Text(verbatim: check.rule)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textPrimary)
        Text(verbatim: [check.measured?.text ?? ChartFormat.missing, check.operator,
          check.threshold?.text ?? ChartFormat.missing].joined(separator: ChartFormat.space))
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

  /// Entries in the accent, exits in the info colour, the rest muted.
  var color: Color {
    switch self {
    case .enter: return Palette.accentText
    case .exit: return Palette.info
    case .ignore, .watch, .hold: return Palette.textTertiary
    }
  }
}
