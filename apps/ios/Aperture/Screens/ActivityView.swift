import ApertureDesign
import ApertureKit
import SwiftUI

/// What happened today: the day's result curve, closed trades, signals not taken, and the journal.
/// Past days come with the days API; this screen shows today until then.
struct ActivityView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case trades = "Trades", skipped = "Not taken", journal = "Journal"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @State private var section: Pane = .trades

    var body: some View {
        Screen("Activity") {
            ConnectionPrompt()
            if let status = model.status {
                DayCard(status: status, live: model.response?.stale == false).rise(0.05)
                Picker("Show", selection: $section) {
                    ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .rise(0.1)
                Group {
                    switch section {
                    case .trades: TradesList(status: status)
                    case .skipped: NotTaken()
                    case .journal: Journal(events: Board.events(status))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id(section)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.9), value: section)
        .refreshable { await model.refresh() }
    }
}

private struct DayCard: View {
    @State private var drawn = false
    let status: StatusV1
    let live: Bool

    var body: some View {
        let stats = Board.dayStats(status)
        let result = stats.resultGrossUsd
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if live { PulseDot(Palette.green, size: 6) }
                    Text(status.writtenAt.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) + " · today")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.muted)
                Text(Money.signedUSD(result))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.result(result))
                    .contentTransition(.numericText(value: NSDecimalNumber(decimal: result).doubleValue))
                Text("\(stats.trades) closed · \(stats.wins) W · \(stats.losses) L · \(status.position == nil ? 0 : 1) open")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            Spacer()
            Sparkline(curve)
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(Palette.result(result), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 120, height: 50)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .apertureCard()
        .onAppear { withAnimation(.easeInOut(duration: 1.6)) { drawn = true } }
    }

    /// Running total of closed trades in the order they closed, starting at zero.
    private var curve: [Double] {
        var total = Decimal(0)
        var points: [Double] = [0]
        for trade in status.tradesToday.sorted(by: { $0.closedAt.date < $1.closedAt.date }) {
            total += trade.resultGrossUsd.value
            points.append(NSDecimalNumber(decimal: total).doubleValue)
        }
        return points
    }
}

private struct TradesList: View {
    let status: StatusV1

    var body: some View {
        let trades = status.tradesToday.sorted { $0.closedAt.date > $1.closedAt.date }
        VStack(spacing: 8) {
            if let position = status.position {
                row(symbol: position.symbol, time: "open \(Format.time(position.openedAt.date))", tag: "OPEN",
                    color: Palette.tealStrong, result: "\(position.quantity) @ \(position.entryPrice)",
                    detail: "stop \(position.stop.price?.text ?? "—") · \(position.stop.state.rawValue)")
                    .rise(0.12)
            }
            ForEach(Array(trades.enumerated()), id: \.offset) { index, trade in
                let value = trade.resultGrossUsd.value
                row(symbol: trade.symbol,
                    time: "\(Format.time(trade.openedAt.date))–\(Format.time(trade.closedAt.date))",
                    tag: trade.exitReason.uppercased(),
                    color: Palette.result(value),
                    result: Money.signed(value),
                    detail: "\(trade.quantity) @ \(trade.entryPrice) → \(trade.exitPrice)")
                    .rise(0.15 + Double(index) * 0.05)
            }
            if trades.isEmpty && status.position == nil {
                ContentUnavailableView("No trades yet today", systemImage: "clock",
                                       description: Text("Closed trades appear here with their result."))
            }
        }
    }

    private func row(symbol: String, time: String, tag: String, color: Color, result: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(symbol).font(.system(size: 14, weight: .bold, design: .monospaced))
                Text(time).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.dim)
                Spacer()
                Text(tag)
                    .font(.system(size: 10.5, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(color)
                    .background(color.opacity(0.14), in: Capsule())
                Text(result)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            Text(detail)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .apertureCard(radius: 16)
        .accessibilityElement(children: .combine)
    }
}

private struct NotTaken: View {
    var body: some View {
        ContentUnavailableView {
            Label("Signals not taken", systemImage: "hand.raised")
        } description: {
            Text("Refused signals with their cause and a what-if result appear here once the bot's API publishes them.")
        }
    }
}

private struct Journal: View {
    let events: [Board.Event]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(Format.clock(event.time))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Circle().fill(event.tone.color).frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.tag).font(.system(size: 10.5, weight: .bold, design: .monospaced)).foregroundStyle(event.tone.color)
                        Text(event.text).font(.system(size: 12.5)).foregroundStyle(Palette.text2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .rise(0.1 + Double(min(index, 10)) * 0.04)
            }
            if events.isEmpty {
                Text("Nothing recorded yet today.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .padding(14)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .apertureCard(radius: 16)
    }
}
