import SwiftUI
import TickrDesign

/// The chart header's symbol and the menu that picks another. Equatable on what it shows, so the
/// chart's refreshes leave an open menu alone (`ChartView.symbolMenu`).
struct SymbolMenu: View {
  let symbol: String?
  let symbols: [String]
  let pick: (String) -> Void

  var body: some View {
    Menu {
      ForEach(symbols, id: \.self) { item in
        Button { pick(item) } label: { Text(verbatim: item) }
      }
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.xs) {
        Text(verbatim: symbol ?? Format.missing)
          .font(Tokens.Typography.metric)
          .foregroundStyle(Palette.textPrimary)
        // The menu's chevron only while there is a symbol to pick: no promise of a menu
        // that would not open.
        if !symbols.isEmpty {
          Image(systemName: ChartView.menuSymbol)
            .font(Tokens.Typography.chevron)
            .foregroundStyle(Palette.textQuaternary)
        }
      }
      .contentShape(.rect)
    }
    .buttonMenuStyle()
    .buttonStyle(.plain)
    .menuIndicator(.hidden)
    .fixedSize()
    .disabled(symbols.isEmpty)
    .tip(Text(L10n.Chart.symbolHelp))
    .accessibilityLabel(Text(L10n.Chart.symbol))
    .accessibilityValue(Text(verbatim: symbol ?? Format.missing))
  }
}

extension SymbolMenu: @MainActor Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.symbol == rhs.symbol && lhs.symbols == rhs.symbols
  }
}
