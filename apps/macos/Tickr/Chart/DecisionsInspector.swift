import SwiftUI
import TickrDesign
import TickrKit

/// Chart inspector: what the trading strategy and the observers decided about the shown symbol on
/// the shown day, newest first, each with the checks that led to it.
struct DecisionsInspector: View {
  let decisions: DecisionsV1?
  let error: String?
  /// The chart shows a symbol; without one there is nothing to ask the bot about.
  let hasSymbol: Bool
  /// The chart shows one day: decisions are recorded per day, so a longer range has none to read.
  var showsDay = true

  /// Width of the decisions pane beside the chart, in points: narrow enough that at the
  /// window's least width the chart keeps most of the room.
  static let width: CGFloat = 240
  /// Lines a check's name may take: the pane is narrow, and a name cut short no longer read.
  static let ruleLines = 3
  /// Accessibility id of the inspector's content, for the UI tests.
  static let contentID = "chart-decisions-list"

  var body: some View {
    content
      // A fixed least and largest size, whatever the content: the inspector column reported the
      // size of its rows (wrapped texts, a spinner, then the list), the split view resized the
      // column inside its own layout pass, the new width changed that size again, and on
      // macOS 27 AppKit threw ("needs another Update Constraints in Window pass") on opening
      // the Chart with the inspector shown.
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
      .accessibilityIdentifier(Self.contentID)
      .background(Palette.surface)
  }

  @ViewBuilder private var content: some View {
    if !showsDay {
      note(L10n.Chart.decisionsDayOnly, symbol: "calendar")
    } else if let decisions, !decisions.decisions.isEmpty {
      ScrollView {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          ForEach(Array(decisions.decisions.reversed().enumerated()), id: \.offset) { _, decision in
            DecisionRow(decision: decision)
          }
        }
        .padding(Tokens.Space.l)
      }
    } else if let error {
      note(L10n.Chart.decisionsUnavailable(error), symbol: "wifi.exclamationmark")
    } else if decisions != nil || !hasSymbol {
      note(L10n.Chart.noDecisions, symbol: "list.bullet.rectangle")
    } else {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func note(_ text: LocalizedStringResource, symbol: String) -> some View {
    ContentUnavailableView {
      Label { Text(L10n.Chart.decisions) } icon: { Image(systemName: symbol) }
    } description: {
      Text(text)
    }
  }
}

/// One decision: when, what, by which strategy, and its checks.
private struct DecisionRow: View {
  let decision: DecisionV1

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(spacing: Tokens.Space.s) {
        Text(verbatim: Format.marketMinute(decision.at.date))
          .font(Tokens.Typography.calloutMono)
          .foregroundStyle(Palette.textTertiary)
          // Never broken in two ("14:3 / 0"): the badges give way first.
          .fixedSize()
        Badge(decision.action.title, color: decision.action.color)
        Spacer(minLength: 0)
        if decision.observer {
          Badge(L10n.Chart.observerTag, color: Palette.highlightText)
        }
      }
      Text(L10n.Chart.strategyVersion(decision.strategy.name, decision.strategy.version))
        .font(Tokens.Typography.captionMono)
        .foregroundStyle(Palette.textSecondary)
      if let reason = RefusalText.text(decision.refusal, cause: decision.refusalCause) {
        Text(verbatim: reason)
          .font(Tokens.Typography.caption)
          .foregroundStyle(Palette.warningText)
      }
      if let entry = decision.entryPrice, let stop = decision.stopPrice {
        Text(L10n.Chart.entryStop(Format.price(entry.value), Format.price(stop.value)))
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textSecondary)
      }
      ForEach(Array(decision.checks.enumerated()), id: \.offset) { _, check in
        CheckRow(check: check)
      }
    }
    .padding(Tokens.Space.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .tickrCard(radius: Tokens.Radius.large)
  }
}

/// One rule the strategy checked: the measured value against its threshold, passed or not.
private struct CheckRow: View {
  let check: CheckV1

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Group {
        if check.passed {
          Image(systemName: "checkmark.circle.fill")
        } else {
          Image(systemName: "xmark.circle")
        }
      }
      .foregroundStyle(check.passed ? Palette.profitText : Palette.textQuaternary)
      .help(Text(check.passed ? L10n.Chart.checkPassed : L10n.Chart.checkFailed))
      .accessibilityLabel(Text(check.passed ? L10n.Chart.checkPassed : L10n.Chart.checkFailed))
      VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
        // The rule in words (ApiText), wrapped between them over a few lines rather than cut
        // mid-word.
        Text(verbatim: ApiText.rule(check.rule))
          .font(Tokens.Typography.captionMono)
          .lineLimit(DecisionsInspector.ruleLines)
          .fixedSize(horizontal: false, vertical: true)
        Text(verbatim: comparison)
          .font(Tokens.Typography.captionMono)
          .foregroundStyle(Palette.textTertiary)
        if !check.note.isEmpty {
          Text(verbatim: check.note)
            .font(Tokens.Typography.caption)
            .foregroundStyle(Palette.textTertiary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  /// "measured operator threshold" as the bot recorded them; a missing side shows as a dash.
  private var comparison: String {
    "\(check.measured?.text ?? Format.missing) \(check.operator) \(check.threshold?.text ?? Format.missing)"
  }
}

extension Verdict {
  /// The role colour of the decision's badge.
  var color: Color {
    switch self {
    case .enter: Palette.accentText
    case .exit: Palette.warningText
    case .watch: Palette.infoText
    case .hold: Palette.highlightText
    case .ignore: Palette.textTertiary
    }
  }
}

#if DEBUG
#Preview {
  DecisionsInspector(decisions: PreviewAPI.decisions(), error: nil, hasSymbol: true)
    .frame(width: DecisionsInspector.width, height: PreviewAPI.windowHeight)
}
#endif
