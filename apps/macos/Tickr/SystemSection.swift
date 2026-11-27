import SwiftUI
import TickrDesign
import TickrKit

/// The design's "System" card in Settings › General (GET /system, mockup v120): the shared
/// `SystemPanel` in this app's settings card, with the summary pill beside its title.
struct SystemSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(SystemText.title) {
      if let system = model.system {
        SystemPanel(system, now: model.botNow)
      } else if let error = model.systemError {
        ReadFailureNote(SystemText.readFailed, detail: error)
      } else {
        SystemPanelLoading()
      }
    } trailing: {
      if let system = model.system { SystemPill(system) }
    }
  }
}

/// The design's "Morning check" in Settings › General (GET /system `morning_check`): the result
/// big, in the check's colour, with the failed checks under it and every check one footer link
/// away; when it ran at the trailing edge. Nothing here runs a check again: the API has no such
/// command.
struct MorningCheckSection: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    SettingsCard(SystemText.morningCheck) {
      if let system = model.system {
        if let check = system.morningCheck {
          Text(Self.summary(check))
            .font(Tokens.Typography.heading)
            .foregroundStyle(SystemCard.morningCheck(system).tone.text)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(check.checks.filter { !$0.passed }, id: \.name) { row($0) }
          FooterDetail(L10n.Settings.showAllChecks, count: check.checks.count) {
            ForEach(check.checks, id: \.name) { row($0) }
          }
        } else {
          Text(verbatim: system.morningCheckCauseText ?? Format.missing)
            .font(Tokens.Typography.callout)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else if let error = model.systemError {
        ReadFailureNote(SystemText.readFailed, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.fewLines) }
      }
    } trailing: {
      if let check = model.system?.morningCheck {
        // New York day and time, so an older result never reads as today's.
        Text(verbatim: DayText.day(check.day) + Format.itemSeparator + ClockText.minutes(check.finishedAt.date))
          .font(Tokens.Typography.annotation)
          .foregroundStyle(Palette.textQuaternary)
      }
    }
  }

  /// The big line: every check passed, how many failed, or the outcome that is neither.
  static func summary(_ check: MorningCheckV1) -> LocalizedStringResource {
    let failed = check.checks.filter { !$0.passed }.count
    switch check.outcome {
    case .noSession: return SystemText.noSession
    case .configInvalid: return SystemText.configInvalid
    case .ready where failed == 0: return L10n.Settings.morningAllPassed(check.checks.count)
    case .ready, .failed:
      // A failure the record does not pin on a check says only that it failed, and when.
      guard failed > 0 else { return SystemText.failed(ClockText.minutes(check.finishedAt.date)) }
      return L10n.Settings.morningFailed(failed, check.checks.count)
    }
  }

  /// One check: a check or a cross in its colour, and its name.
  private func row(_ check: PreflightCheckV1) -> some View {
    HStack(spacing: Tokens.Space.s) {
      Image(systemName: check.passed ? Symbols.passed : Symbols.failed)
        .foregroundStyle(check.passed ? Palette.profit : Palette.loss)
        .accessibilityLabel(Text(check.passed ? L10n.Settings.checkPassed : L10n.Settings.checkFailed))
      Text(SystemText.check(check.name))
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }
}
