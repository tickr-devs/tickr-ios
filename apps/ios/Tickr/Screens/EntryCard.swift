import SwiftUI
import TickrDesign
import TickrKit

/// An own entry order working with nothing filled, on Home under the open positions (mockups v160
/// and v162): the symbol with Cancel entry, then the order's words
/// (`EntryFacts`). Cancel entry asks in an action sheet (Cancel entry, Keep), then sends
/// cancel-own-orders for the symbol after Face ID (`BotControl.confirmAndSend`). "Cancelling…"
/// follows until a broker read shows the order gone; "Cancelled at broker" stays a moment.
/// `compact` is the row beside open positions or other entries (mockup v162): the symbol with its
/// label, the order and a short state line, and a Cancel pill with a full touch target.
struct EntryCard: View {
  @Environment(AppModel.self) private var model
  let row: EntryRow
  var compact = false
  @State private var asking = false

  /// Accessibility id prefix of the card and of its Cancel entry, for the UI tests.
  static let idPrefix = "working-entry-"
  static let cancelPrefix = "cancel-entry-"

  var body: some View {
    let command = OperatorCommand.cancelEntry(row.symbol)
    Group {
      if compact {
        HStack(spacing: Tokens.Space.s) {
          VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.s) {
              EntryDot(row.phase)
              SymbolText(row.symbol)
                .font(Tokens.Typography.figure)
                .foregroundStyle(Palette.textPrimary)
              EntryBadge(row)
            }
            EntryFacts(row, compact: true)
          }
          Spacer(minLength: Tokens.Space.s)
          cancelButton(command)
        }
      } else {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
          HStack(spacing: Tokens.Space.s) {
            EntryDot(row.phase)
            SymbolText(row.symbol)
              .font(Tokens.Typography.figure)
              .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: Tokens.Space.s)
            cancelButton(command)
          }
          EntryFacts(row)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Tokens.Space.l)
    .tickrCard()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.idPrefix + row.symbol)
    .confirmationDialog(Text(EntryText.question(row.symbol)), isPresented: $asking, titleVisibility: .visible) {
      if model.canCommand {
        Button(role: .destructive) {
          Task { await BotControl.confirmAndSend(command, model: model) }
        } label: {
          Text(EntryText.cancel)
        }
      }
      Button(role: .cancel) {} label: { Text(EntryText.keep) }
    } message: {
      Text(BotControl.target(String(localized: EntryText.explanation(Shares.text(row.quantity),
        Money.price(row.limitPrice))), demo: model.connection.demo))
    }
  }

  /// Cancel entry, or the compact row's Cancel pill, while the entry is not yet cancelled.
  @ViewBuilder private func cancelButton(_ command: OperatorCommand) -> some View {
    if row.phase != .cancelled {
      Button(role: .destructive) {
        asking = true
      } label: {
        Label { Text(compact ? EntryText.cancelShort : EntryText.cancel) } icon: { Image(systemName: EntryLook.cancelSymbol) }
      }
      .buttonStyle(.command(.destructive, size: .small, tag: model.connection.demo ? Text(L10n.Control.demoTag) : nil))
      .fixedSize()
      .frame(minHeight: Tokens.Size.touchTarget)
      .contentShape(Rectangle())
      .disabled(!model.canCommand || row.phase != .working)
      .inFlight(model.inFlight == command ? Text(command.inFlightTitle) : nil)
      .accessibilityLabel(Text(compact ? EntryText.cancelFor(row.symbol) : EntryText.cancel))
      .accessibilityHint(Text(EntryText.cancelHint))
      .accessibilityIdentifier(Self.cancelPrefix + row.symbol)
    }
  }
}

extension AppModel {
  /// The bot's working entries, with where each one's cancel stands, and those just cancelled
  /// (`EntryCancelWatch`).
  var entryRows: [EntryRow] { entryWatch.rows(status, inFlight: inFlight) }
}
