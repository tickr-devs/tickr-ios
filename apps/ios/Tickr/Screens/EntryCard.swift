import SwiftUI
import TickrDesign
import TickrKit

/// An own entry order working with nothing filled, on Home under the open positions (mockup v160,
/// "Proposal: cancel an entry order"): the symbol with Cancel entry, then the order's words
/// (`EntryFacts`). Cancel entry asks in an action sheet (Cancel entry, Keep), then sends
/// cancel-own-orders for the symbol after Face ID (`BotControl.confirmAndSend`). "Cancelling…"
/// follows until a broker read shows the order gone; "Cancelled at broker" stays a moment.
struct EntryCard: View {
  @Environment(AppModel.self) private var model
  let row: EntryRow
  @State private var asking = false

  /// Accessibility id prefix of the card and of its Cancel entry, for the UI tests.
  static let idPrefix = "working-entry-"
  static let cancelPrefix = "cancel-entry-"

  var body: some View {
    let command = OperatorCommand.cancelEntry(row.symbol)
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      HStack(spacing: Tokens.Space.s) {
        EntryDot(row.phase)
        SymbolText(row.symbol)
          .font(Tokens.Typography.figure)
          .foregroundStyle(Palette.textPrimary)
        Spacer(minLength: Tokens.Space.s)
        if row.phase != .cancelled {
          Button(role: .destructive) {
            asking = true
          } label: {
            Label { Text(EntryText.cancel) } icon: { Image(systemName: EntryLook.cancelSymbol) }
          }
          .buttonStyle(.command(.destructive, size: .small, tag: model.connection.demo ? Text(L10n.Control.demoTag) : nil))
          .fixedSize()
          .disabled(!model.canCommand || row.phase != .working)
          .inFlight(model.inFlight == command ? Text(command.inFlightTitle) : nil)
          .accessibilityHint(Text(EntryText.cancelHint))
          .accessibilityIdentifier(Self.cancelPrefix + row.symbol)
        }
      }
      EntryFacts(row)
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
}

extension AppModel {
  /// The bot's working entries, with where each one's cancel stands, and those just cancelled
  /// (`EntryCancelWatch`).
  var entryRows: [EntryRow] { entryWatch.rows(status, inFlight: inFlight) }
}
