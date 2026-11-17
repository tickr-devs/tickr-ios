import SwiftUI
import TickrDesign
import TickrKit

/// The bot's configuration file as it is on disk now (GET /config), read-only: whether the next
/// start would load it, whether it changed since the API loaded it, and every key with its value
/// and comment, table by table. Editing comes later, behind a backup and a restart.
struct ConfigView: View {
  /// Symbols of the file states (valid and invalid draw `Symbols.passed` and `Symbols.failed`).
  static let changedSymbol = "arrow.triangle.2.circlepath"
  static let editSymbol = "pencil"

  /// Order in which the blocks rise in (`rise(step:)`): the file's state, then its tables.
  private enum Order: Int { case file = 1, tables }

  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      Section {
      } header: {
        PushedHeader(title: L10n.Settings.configuration, back: L10n.Settings.title, action: dismiss)
          .formHeaderRow()
      }
      if let config = model.config {
        Section {
          Group {
            LabeledContent {
              if config.valid {
                StatusPill(L10n.Settings.configValid, systemImage: Symbols.passed, tone: .profit)
              } else {
                StatusPill(L10n.Settings.configInvalid, systemImage: Symbols.failed, tone: .loss)
              }
            } label: {
              Text(verbatim: config.file).font(Tokens.Typography.bodyMono)
            }
            if let error = config.error {
              InfoCaption(verbatim: error, tone: .loss)
            }
            if config.changedSinceStart {
              InfoCaption(L10n.Settings.configChangedHint, systemImage: Self.changedSymbol, tone: .warning)
            }
            SettingsRow(L10n.Settings.configEdit, systemImage: Self.editSymbol, tone: .neutral) {
              Badge(L10n.Settings.notYet, tone: .highlight, planned: true)
            }
          }
          .rise(step: Order.file.rawValue)
        } footer: {
          Text(L10n.Settings.configFooter)
        }
        ForEach(config.sections, id: \.name) { section in
          Section {
            ForEach(section.keys, id: \.key) { key in
              VStack(alignment: .leading, spacing: Tokens.Space.xxs) {
                Text(verbatim: key.key).font(Tokens.Typography.bodyMono)
                Text(verbatim: key.value)
                  .font(Tokens.Typography.captionMono)
                  .foregroundStyle(Palette.warningText)
                  .textSelection(.enabled)
                if !key.comment.isEmpty {
                  Text(verbatim: key.comment)
                    .font(Tokens.Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
              .accessibilityElement(children: .combine)
              .rise(step: Order.tables.rawValue)
            }
          } header: {
            Text(verbatim: section.name.isEmpty ? String(localized: L10n.Settings.configTop) : section.name)
              .font(Tokens.Typography.captionMono)
          }
        }
      } else if let error = model.configError {
        ReadFailureNote(L10n.ReadFailed.config, detail: error)
      } else {
        Skeleton(L10n.Common.loading) { SkeletonLines(Tokens.Loading.manyLines) }
      }
    }
    .contentMargins(.top, 0, for: .scrollContent)
    .pushedScreen(L10n.Settings.configuration)
    .task(id: model.connection.url) { await model.refreshConfig() }
    .refreshable { await model.refreshConfig() }
  }
}
