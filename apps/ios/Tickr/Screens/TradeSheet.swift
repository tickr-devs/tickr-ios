import SwiftUI
import TickrDesign
import TickrKit

/// A closed trade's sheet from Activity (mockup IOSActivity v134): the result big with its R, the
/// exit reason, then "Details ›" opening a sheet with the rest of what the bot recorded (entry to exit, shares, how
/// fast the broker confirmed the stop, worst and best while open, the code version, where the price
/// went after the exit), and the link to replay another strategy on the same trade.
struct TradeSheet: View {
  let trade: TradeLine
  let activity: ActivityModel
  /// The bot's address; nil leaves out the replay link, which needs it.
  let url: URL?

  @Environment(\.dismiss) private var dismiss
  @State private var another = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
          result
          row(L10n.Activity.tradeExit) {
            Badge(verbatim: Board.exitReasonTitle(trade.exitReason).uppercased(), tone: Tone.exit(trade.exitReason))
          }
          FooterDetail(L10n.Activity.tradeDetails, endsCard: false) { detailRows }
          if url != nil {
            HeaderLink(L10n.Activity.anotherHelp) { another = true }
          }
        }
        .padding(Tokens.Space.l)
      }
      .scrollEdgeHints()
      .background(Palette.background)
      .navigationTitle(Text(verbatim: trade.symbol + Format.separator + Format.time(trade.openedAt)
        + Format.timeRange + Format.time(trade.closedAt)))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(role: .close) { dismiss() }
        }
      }
    }
    .sheetFitsContent()
    .sheet(isPresented: $another) {
      if let url {
        AnotherStrategySheet(activity: activity, url: url, symbol: trade.symbol, day: trade.day,
          botR: trade.resultR, botUsd: trade.result)
      }
    }
  }

  /// The result in dollars, big, and in R beside it.
  private var result: some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
      Text(verbatim: Money.signedUSD(trade.result))
        .font(Tokens.Typography.hero)
        .foregroundStyle(Tone.result(trade.result).text)
      if let r = trade.resultR {
        Text(verbatim: Risk.text(r))
          .font(Tokens.Typography.figure)
          .foregroundStyle(Tone.result(trade.result).text)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var detailRows: some View {
    VStack(alignment: .leading, spacing: Tokens.Space.s) {
      row(L10n.Activity.hintEntryExit) { value(trade.entryPrice + Format.arrow + trade.exitPrice) }
      row(L10n.Activity.hintQuantity) { value(trade.quantity) }
      row(L10n.Activity.hintStopAfter) {
        if let after = trade.stopAfter {
          value(String(localized: L10n.Risk.seconds(Money.plain(after, fractionDigits: 1))), tone: .profit)
        } else {
          Text(L10n.Activity.notRecorded).foregroundStyle(Palette.textQuaternary)
        }
      }
      // Lower bounds: only prices proven while the shares were held count.
      if let mae = trade.mae, let mfe = trade.mfe {
        row(L10n.Activity.worstWhileOpen) { value(Money.signedUSD(mae), tone: Tone.result(mae)) }
        row(L10n.Activity.bestWhileOpen) { value(Money.signedUSD(mfe), tone: Tone.result(mfe)) }
      }
      if let code = trade.codeVersion {
        row(L10n.Activity.hintCodeVersion) { value(code) }
      }
      // Where the price went after the exit, per share, every point the bot sent.
      AfterLine(prices: trade.pricesAfter)
    }
  }

  /// A label on the leading edge and its value on the trailing one; both wrap, never cut.
  private func row<Value: View>(_ label: LocalizedStringResource, @ViewBuilder value: () -> Value) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.m) {
      Text(label)
        .font(Tokens.Typography.callout)
        .foregroundStyle(Palette.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
      value()
        .font(Tokens.Typography.calloutMono)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  private func value(_ text: String, tone: Tone? = nil) -> some View {
    Text(verbatim: text).foregroundStyle(tone?.text ?? Palette.textPrimary)
  }
}
